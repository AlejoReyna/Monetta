import { AccountRegistrationConflictError } from '../../src/domain/accountErrors.js';
import type {
  AppAccountsRepository,
  CustomersRepository,
  OrdersRepository,
  PrivacyRequestsRepository,
  PushTokensRepository,
  WebhookEventsRepository,
} from '../../src/domain/ports.js';
import type {
  AppAccountRecord,
  AppAccountCredentials,
  AppAccountRegistration,
  AppSessionCreation,
  CustomerRecord,
  MirroredOrder,
  OrderRecord,
  PrivacyDataRequestRecord,
  PrivacyFulfillmentInput,
  PrivacyRequestView,
  PushTokenRecord,
  WebhookDeliveryStatus,
  WebhookEventRecord,
} from '../../src/domain/types.js';

export class InMemoryAppAccountsRepository implements AppAccountsRepository {
  readonly byId = new Map<string, AppAccountRecord>();
  readonly accountIdByTokenHash = new Map<string, string>();
  private readonly accountIdByDeviceId = new Map<string, string>();
  private readonly expiresAtByTokenHash = new Map<string, Date>();
  private readonly tokenHashByDeviceId = new Map<string, string>();
  private readonly passwordHashById = new Map<string, string>();

  async register(record: AppAccountRegistration): Promise<AppAccountRecord> {
    if (this.accountIdByDeviceId.has(record.deviceId)) {
      throw new AccountRegistrationConflictError('device');
    }
    const emailTaken = [...this.byId.values()].some(
      (candidate) => candidate.email.toLowerCase() === record.email.toLowerCase(),
    );
    if (emailTaken) {
      throw new AccountRegistrationConflictError('email');
    }
    const now = new Date();
    const account: AppAccountRecord = {
      id: record.accountId,
      email: record.email,
      displayName: record.displayName,
      emailVerified: false,
      shopifyCustomerId: null,
      createdAt: now,
      updatedAt: now,
    };
    this.byId.set(record.accountId, account);
    this.passwordHashById.set(record.accountId, record.passwordHash);
    this.accountIdByDeviceId.set(record.deviceId, record.accountId);
    this.tokenHashByDeviceId.set(record.deviceId, record.tokenHash);
    this.accountIdByTokenHash.set(record.tokenHash, record.accountId);
    this.expiresAtByTokenHash.set(record.tokenHash, record.expiresAt);
    return account;
  }

  async findCredentialsByEmail(email: string): Promise<AppAccountCredentials | null> {
    const account = [...this.byId.values()].find(
      (candidate) => candidate.email.toLowerCase() === email.toLowerCase(),
    );
    if (account === undefined) return null;
    const passwordHash = this.passwordHashById.get(account.id);
    return passwordHash === undefined ? null : { ...account, passwordHash };
  }

  async createSession(record: AppSessionCreation): Promise<void> {
    const oldTokenHash = this.tokenHashByDeviceId.get(record.deviceId);
    if (oldTokenHash !== undefined) {
      this.accountIdByTokenHash.delete(oldTokenHash);
      this.expiresAtByTokenHash.delete(oldTokenHash);
    }
    this.accountIdByDeviceId.set(record.deviceId, record.accountId);
    this.tokenHashByDeviceId.set(record.deviceId, record.tokenHash);
    this.accountIdByTokenHash.set(record.tokenHash, record.accountId);
    this.expiresAtByTokenHash.set(record.tokenHash, record.expiresAt);
  }

  async findByTokenHash(tokenHash: string): Promise<AppAccountRecord | null> {
    const expiresAt = this.expiresAtByTokenHash.get(tokenHash);
    if (expiresAt === undefined || expiresAt <= new Date()) return null;
    const id = this.accountIdByTokenHash.get(tokenHash);
    return id === undefined ? null : (this.byId.get(id) ?? null);
  }

  async revokeToken(tokenHash: string): Promise<void> {
    this.accountIdByTokenHash.delete(tokenHash);
    this.expiresAtByTokenHash.delete(tokenHash);
  }
}

export class InMemoryCustomersRepository implements CustomersRepository {
  readonly byId = new Map<string, CustomerRecord>();

  async ensureExists(shopifyCustomerId: string): Promise<void> {
    if (this.byId.has(shopifyCustomerId)) return;
    this.byId.set(shopifyCustomerId, {
      shopifyCustomerId,
      email: null,
      firstName: null,
      lastName: null,
      phone: null,
      marketingConsent: false,
    });
  }

  async upsert(record: CustomerRecord): Promise<void> {
    this.byId.set(record.shopifyCustomerId, record);
  }

  async delete(shopifyCustomerId: string): Promise<void> {
    this.byId.delete(shopifyCustomerId);
  }

  async deleteAll(): Promise<void> {
    this.byId.clear();
  }
}

interface StoredOrder extends OrderRecord {
  id: number;
}

export class InMemoryOrdersRepository implements OrdersRepository {
  readonly rows: StoredOrder[] = [];
  private nextId = 1;

  async upsertByShopifyOrderId(order: OrderRecord): Promise<void> {
    if (order.shopifyOrderId !== null) {
      const existing = this.rows.find((r) => r.shopifyOrderId === order.shopifyOrderId);
      if (existing) {
        const existingTs = existing.shopifyUpdatedAt?.getTime();
        const incomingTs = order.shopifyUpdatedAt?.getTime();
        if (
          existingTs !== undefined &&
          incomingTs !== undefined &&
          incomingTs < existingTs
        ) {
          return;
        }
        Object.assign(existing, order, {
          attributionCode: order.attributionCode ?? existing.attributionCode,
          shopifyUpdatedAt: order.shopifyUpdatedAt ?? existing.shopifyUpdatedAt,
          paymentMethod: order.paymentMethod ?? existing.paymentMethod ?? null,
          checkoutToken: order.checkoutToken ?? existing.checkoutToken ?? null,
          cartToken: order.cartToken ?? existing.cartToken ?? null,
        });
        return;
      }
    }
    this.rows.push({
      ...order,
      paymentMethod: order.paymentMethod ?? null,
      checkoutToken: order.checkoutToken ?? null,
      cartToken: order.cartToken ?? null,
      id: this.nextId++,
    });
  }

  async linkApartadoByAttributionCode(
    attributionCode: string,
    shopifyOrderId: string,
  ): Promise<boolean> {
    const row = this.rows.find(
      (r) => r.attributionCode === attributionCode && r.shopifyOrderId === null,
    );
    if (!row) return false;
    row.shopifyOrderId = shopifyOrderId;
    return true;
  }

  async detachCustomer(shopifyCustomerId: string): Promise<void> {
    for (const row of this.rows) {
      if (row.customerId === shopifyCustomerId) row.customerId = null;
    }
  }

  async listForCustomer(shopifyCustomerId: string): Promise<MirroredOrder[]> {
    return this.rows
      .filter((r) => r.customerId === shopifyCustomerId)
      .map((r) => ({ ...r, updatedAt: new Date() }))
      .sort((a, b) => (b.placedAt?.getTime() ?? 0) - (a.placedAt?.getTime() ?? 0));
  }

  async deleteAll(): Promise<void> {
    this.rows.length = 0;
  }
}

export type StoredWebhookEvent = {
  webhookId: string;
  topic: string;
  shopifyResourceId: string | null;
  payloadHash: string;
  shopDomain?: string | null;
  status: WebhookDeliveryStatus;
  attemptCount: number;
  processedAt: Date | null;
  lastError: string | null;
  claimedAt: Date | null;
};

export class InMemoryWebhookEventsRepository implements WebhookEventsRepository {
  readonly byWebhookId = new Map<string, StoredWebhookEvent>();

  /** Test hook: force a claim to look stale so reclaim paths can be exercised. */
  staleClaimAfterMs = 5 * 60 * 1000;

  async tryClaim(event: WebhookEventRecord): Promise<boolean> {
    const existing = this.byWebhookId.get(event.webhookId);
    const now = new Date();
    if (!existing) {
      this.byWebhookId.set(event.webhookId, {
        webhookId: event.webhookId,
        topic: event.topic,
        shopifyResourceId: event.shopifyResourceId,
        payloadHash: event.payloadHash,
        shopDomain: event.shopDomain ?? null,
        status: 'processing',
        attemptCount: 1,
        processedAt: null,
        lastError: null,
        claimedAt: now,
      });
      return true;
    }
    const stale =
      existing.status === 'processing' &&
      existing.claimedAt !== null &&
      now.getTime() - existing.claimedAt.getTime() >= this.staleClaimAfterMs;
    if (existing.status === 'completed') return false;
    if (existing.status === 'processing' && !stale) throw new Error('Webhook busy; retry');
    existing.status = 'processing';
    existing.attemptCount += 1;
    existing.claimedAt = now;
    existing.payloadHash = event.payloadHash;
    existing.topic = event.topic;
    existing.shopifyResourceId = event.shopifyResourceId ?? existing.shopifyResourceId;
    existing.shopDomain = event.shopDomain ?? existing.shopDomain;
    existing.lastError = null;
    existing.processedAt = null;
    return true;
  }

  async markCompleted(webhookId: string): Promise<void> {
    const row = this.byWebhookId.get(webhookId);
    if (row) {
      row.status = 'completed';
      row.processedAt = new Date();
      row.lastError = null;
    }
  }

  async markFailed(webhookId: string, error: string): Promise<void> {
    const row = this.byWebhookId.get(webhookId);
    if (row && row.status === 'processing') {
      row.status = 'failed';
      row.lastError = error.slice(0, 2000);
      row.processedAt = null;
    }
  }
}

export class InMemoryPrivacyRequestsRepository implements PrivacyRequestsRepository {
  readonly byWebhookId = new Map<string, PrivacyRequestView>();

  async openDataRequest(record: PrivacyDataRequestRecord): Promise<void> {
    if (this.byWebhookId.has(record.webhookId)) return;
    this.byWebhookId.set(record.webhookId, {
      webhookId: record.webhookId,
      shopifyCustomerId: record.shopifyCustomerId,
      kind: 'customers/data_request',
      status: 'open',
      receivedAt: new Date(),
      fulfilledAt: null,
      notes: null,
      exportArtifactRef: null,
      operator: null,
    });
  }

  async openRedactRequest(record: PrivacyDataRequestRecord): Promise<void> {
    if (this.byWebhookId.has(record.webhookId)) return;
    this.byWebhookId.set(record.webhookId, {
      webhookId: record.webhookId,
      shopifyCustomerId: record.shopifyCustomerId,
      kind: 'customers/redact',
      status: 'fulfilled',
      receivedAt: new Date(),
      fulfilledAt: new Date(),
      notes: 'Automatic mirror/engagement/token redaction applied by webhook handler',
      exportArtifactRef: null,
      operator: 'webhook:customers/redact',
    });
  }

  async listOpen(): Promise<readonly PrivacyRequestView[]> {
    return [...this.byWebhookId.values()].filter((row) => row.status === 'open');
  }

  async markFulfilled(input: PrivacyFulfillmentInput): Promise<boolean> {
    const row = this.byWebhookId.get(input.webhookId);
    if (!row || row.status !== 'open') return false;
    this.byWebhookId.set(input.webhookId, {
      ...row,
      status: 'fulfilled',
      fulfilledAt: new Date(),
      notes: input.notes ?? row.notes,
      exportArtifactRef: input.exportArtifactRef ?? row.exportArtifactRef,
      operator: input.operator,
    });
    return true;
  }

  async markCancelled(input: PrivacyFulfillmentInput): Promise<boolean> {
    const row = this.byWebhookId.get(input.webhookId);
    if (!row || row.status !== 'open') return false;
    this.byWebhookId.set(input.webhookId, {
      ...row,
      status: 'cancelled',
      fulfilledAt: new Date(),
      notes: input.notes ?? row.notes,
      operator: input.operator,
    });
    return true;
  }
}


export class InMemoryPushTokensRepository implements PushTokensRepository {
  readonly byDeviceId = new Map<string, PushTokenRecord>();

  async upsert(token: PushTokenRecord): Promise<boolean> {
    const existing = this.byDeviceId.get(token.deviceId);
    if (
      existing?.customerId !== null &&
      existing?.customerId !== undefined &&
      existing.customerId !== token.customerId
    ) {
      return false;
    }
    this.byDeviceId.set(token.deviceId, token);
    return true;
  }

  async deleteAllForCustomer(shopifyCustomerId: string): Promise<void> {
    for (const [deviceId, token] of this.byDeviceId) {
      if (token.customerId === shopifyCustomerId) this.byDeviceId.delete(deviceId);
    }
  }

  async deleteAll(): Promise<void> {
    this.byDeviceId.clear();
  }
}

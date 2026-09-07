import { AccountRegistrationConflictError } from '../../src/domain/accountErrors.js';
import type {
  AppAccountsRepository,
  CustomersRepository,
  OrdersRepository,
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
  PushTokenRecord,
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
        Object.assign(existing, order, {
          attributionCode: order.attributionCode ?? existing.attributionCode,
        });
        return;
      }
    }
    this.rows.push({ ...order, id: this.nextId++ });
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

export class InMemoryWebhookEventsRepository implements WebhookEventsRepository {
  readonly byWebhookId = new Map<string, WebhookEventRecord & { processedAt: Date | null }>();

  async recordIfNew(event: WebhookEventRecord): Promise<boolean> {
    if (this.byWebhookId.has(event.webhookId)) return false;
    this.byWebhookId.set(event.webhookId, { ...event, processedAt: null });
    return true;
  }

  async markProcessed(webhookId: string): Promise<void> {
    const row = this.byWebhookId.get(webhookId);
    if (row) row.processedAt = new Date();
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

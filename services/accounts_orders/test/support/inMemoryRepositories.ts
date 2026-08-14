import type {
  CustomersRepository,
  OrdersRepository,
  PushTokensRepository,
  WebhookEventsRepository,
} from '../../src/domain/ports.js';
import type {
  CustomerRecord,
  MirroredOrder,
  OrderRecord,
  PushTokenRecord,
  WebhookEventRecord,
} from '../../src/domain/types.js';

export class InMemoryCustomersRepository implements CustomersRepository {
  readonly byId = new Map<string, CustomerRecord>();

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

  async upsert(token: PushTokenRecord): Promise<void> {
    this.byDeviceId.set(token.deviceId, token);
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

import type pg from 'pg';
import type { PrivacyRequestsRepository } from '../domain/ports.js';
import type { PrivacyDataRequestRecord } from '../domain/types.js';

export class PgPrivacyRequestsRepository implements PrivacyRequestsRepository {
  constructor(private readonly pool: pg.Pool) {}

  async openDataRequest(record: PrivacyDataRequestRecord): Promise<void> {
    await this.pool.query(
      `INSERT INTO privacy_requests (webhook_id, kind, shopify_customer_id, status)
       VALUES ($1, 'customers/data_request', $2, 'open')
       ON CONFLICT (webhook_id) DO NOTHING`,
      [record.webhookId, record.shopifyCustomerId],
    );
  }
}

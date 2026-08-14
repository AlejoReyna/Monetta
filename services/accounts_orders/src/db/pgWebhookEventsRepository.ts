import type pg from 'pg';
import type { WebhookEventsRepository } from '../domain/ports.js';
import type { WebhookEventRecord } from '../domain/types.js';

export class PgWebhookEventsRepository implements WebhookEventsRepository {
  constructor(private readonly pool: pg.Pool) {}

  async recordIfNew(event: WebhookEventRecord): Promise<boolean> {
    const result = await this.pool.query(
      `INSERT INTO webhook_events (webhook_id, topic, shopify_resource_id, payload_hash)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (webhook_id) DO NOTHING`,
      [event.webhookId, event.topic, event.shopifyResourceId, event.payloadHash],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async markProcessed(webhookId: string): Promise<void> {
    await this.pool.query('UPDATE webhook_events SET processed_at = now() WHERE webhook_id = $1', [
      webhookId,
    ]);
  }
}

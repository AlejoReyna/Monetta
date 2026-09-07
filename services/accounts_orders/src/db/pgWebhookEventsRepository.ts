import type pg from 'pg';
import type { WebhookEventsRepository } from '../domain/ports.js';
import type { WebhookEventRecord } from '../domain/types.js';

/** Stale `processing` claims older than this may be reclaimed (process crash). */
const STALE_CLAIM_INTERVAL = "interval '5 minutes'";

export class PgWebhookEventsRepository implements WebhookEventsRepository {
  constructor(private readonly pool: pg.Pool) {}

  async tryClaim(event: WebhookEventRecord): Promise<boolean> {
    // INSERT new as processing, or reclaim pending/failed/stale-processing.
    // ON CONFLICT … WHERE means RETURNING is empty when the row is completed
    // or freshly processing — concurrent duplicates correctly lose the race.
    const result = await this.pool.query(
      `INSERT INTO webhook_events (
         webhook_id, topic, shopify_resource_id, payload_hash,
         status, attempt_count, claimed_at, shop_domain
       ) VALUES ($1, $2, $3, $4, 'processing', 1, now(), $5)
       ON CONFLICT (webhook_id) DO UPDATE SET
         status = 'processing',
         attempt_count = webhook_events.attempt_count + 1,
         claimed_at = now(),
         payload_hash = EXCLUDED.payload_hash,
         topic = EXCLUDED.topic,
         shopify_resource_id = COALESCE(EXCLUDED.shopify_resource_id, webhook_events.shopify_resource_id),
         shop_domain = COALESCE(EXCLUDED.shop_domain, webhook_events.shop_domain),
         last_error = NULL,
         processed_at = NULL
       WHERE webhook_events.status IN ('pending', 'failed')
          OR (
            webhook_events.status = 'processing'
            AND webhook_events.claimed_at < now() - ${STALE_CLAIM_INTERVAL}
          )
       RETURNING webhook_id`,
      [
        event.webhookId,
        event.topic,
        event.shopifyResourceId,
        event.payloadHash,
        event.shopDomain ?? null,
      ],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async markCompleted(webhookId: string): Promise<void> {
    await this.pool.query(
      `UPDATE webhook_events
       SET status = 'completed', processed_at = now(), last_error = NULL
       WHERE webhook_id = $1`,
      [webhookId],
    );
  }

  async markFailed(webhookId: string, error: string): Promise<void> {
    await this.pool.query(
      `UPDATE webhook_events
       SET status = 'failed', last_error = $2, processed_at = NULL
       WHERE webhook_id = $1 AND status = 'processing'`,
      [webhookId, error.slice(0, 2000)],
    );
  }
}

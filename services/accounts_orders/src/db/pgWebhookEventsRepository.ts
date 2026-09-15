import pg from 'pg';
import type { WebhookEventsRepository } from '../domain/ports.js';
import type { WebhookEventRecord } from '../domain/types.js';

/** A busy delivery must produce a retryable HTTP failure, never an ACK. */
export class WebhookBusyError extends Error {
  constructor() { super('Webhook is still processing; retry delivery'); }
}

/**
 * Transaction advisory locks serialize a delivery across processes. Unlike a
 * timed lease, a live slow worker cannot be overtaken. PostgreSQL releases
 * the lock on rollback/connection/process death; the next HTTP delivery recovers
 * immediately. All effects must be idempotent by their business key.
 */
export class PgWebhookEventsRepository implements WebhookEventsRepository {
  private readonly claims = new Map<string, pg.PoolClient>();
  private readonly claimPool: pg.Pool;
  constructor(pool: pg.Pool) {
    // Holding every connection from the effects pool would deadlock a burst
    // of deliveries. A bounded, separate pool reserves effect capacity.
    this.claimPool = new pg.Pool({...pool.options, max: 4});
  }

  async tryClaim(event: WebhookEventRecord): Promise<boolean> {
    const client = await this.claimPool.connect();
    try {
      await client.query('BEGIN');
      const lock = await client.query(
        'SELECT pg_try_advisory_xact_lock(hashtextextended($1, 0)) AS acquired',
        [event.webhookId],
      );
      if (lock.rows[0].acquired !== true) throw new WebhookBusyError();
      const existing = await client.query(
        'SELECT status, payload_hash, shop_domain FROM webhook_events WHERE webhook_id = $1',
        [event.webhookId],
      );
      const row = existing.rows[0];
      if (row && (row.payload_hash !== event.payloadHash ||
          (row.shop_domain && row.shop_domain !== event.shopDomain))) {
        throw new Error('Webhook identity conflicts with stored delivery');
      }
      if (row?.status === 'completed') {
        await client.query('ROLLBACK');
        client.release(true);
        return false;
      }
      await client.query(
        `INSERT INTO webhook_events
          (webhook_id, topic, shopify_resource_id, payload_hash, status, attempt_count, claimed_at, shop_domain)
         VALUES ($1, $2, $3, $4, 'processing', 1, now(), $5)
         ON CONFLICT (webhook_id) DO UPDATE SET status = 'processing',
           attempt_count = webhook_events.attempt_count + 1, claimed_at = now(),
           last_error = NULL, processed_at = NULL`,
        [event.webhookId, event.topic, event.shopifyResourceId, event.payloadHash, event.shopDomain ?? null],
      );
      // Prevent an idle-client error from terminating the process. A lost
      // connection is destroyed on release; no completion can be acknowledged.
      client.on('error', () => {
        if (this.claims.get(event.webhookId) === client) {
          this.claims.delete(event.webhookId);
          client.release(true);
        }
      });
      this.claims.set(event.webhookId, client);
      return true;
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { /* disconnected */ }
      client.release(true);
      throw error;
    }
  }

  async markCompleted(webhookId: string): Promise<void> {
    await this.finish(webhookId, 'completed', null);
  }

  async markFailed(webhookId: string, error: string): Promise<void> {
    await this.finish(webhookId, 'failed', error.slice(0, 2000));
  }

  private async finish(id: string, status: string, error: string | null): Promise<void> {
    const client = this.claims.get(id);
    if (!client) throw new Error('Webhook claim ownership lost');
    this.claims.delete(id);
    try {
      await client.query(
        `UPDATE webhook_events SET status = $2, last_error = $3,
         processed_at = CASE WHEN $2 = 'completed' THEN now() ELSE NULL END
         WHERE webhook_id = $1`, [id, status, error],
      );
      await client.query('COMMIT');
    } finally {
      // ROLLBACK is harmless after COMMIT and releases locks after failure.
      try { await client.query('ROLLBACK'); } catch { /* disconnected */ }
      client.release(true);
    }
  }
}

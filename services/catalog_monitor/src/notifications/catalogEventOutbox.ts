import { createHmac } from 'node:crypto';
import type pg from 'pg';

interface OutboxRow {
  readonly id: string;
  readonly payload: Record<string, unknown>;
  readonly attempt_count: number;
}

export class CatalogEventOutbox {
  constructor(
    private readonly pool: pg.Pool,
    private readonly endpoint: string,
    private readonly secret: string,
    private readonly fetchFn: typeof fetch = fetch,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async dispatchOnce(limit = 50): Promise<number> {
    const rows = await this.claim(limit);
    for (const row of rows) {
      await this.dispatch(row);
    }
    return rows.length;
  }

  private async claim(limit: number): Promise<readonly OutboxRow[]> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query<OutboxRow>(
        `SELECT id, payload, attempt_count
           FROM notification_event_outbox
          WHERE (
              status IN ('pending', 'retry') AND next_attempt_at <= $1
            ) OR (
              status = 'sending' AND updated_at < $1 - interval '10 minutes'
            )
          ORDER BY created_at
          LIMIT $2
          FOR UPDATE SKIP LOCKED`,
        [this.now(), limit],
      );
      if (result.rows.length > 0) {
        await client.query(
          `UPDATE notification_event_outbox
              SET status = 'sending', attempt_count = attempt_count + 1, updated_at = $2
            WHERE id = ANY($1::uuid[])`,
          [result.rows.map((row) => row.id), this.now()],
        );
      }
      await client.query('COMMIT');
      return result.rows;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private async dispatch(row: OutboxRow): Promise<void> {
    const timestamp = this.now().toISOString();
    const body = JSON.stringify(row.payload);
    const signature = createHmac('sha256', this.secret)
      .update(timestamp)
      .update('.')
      .update(body)
      .digest('hex');
    try {
      const response = await this.fetchFn(this.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Monetta-Timestamp': timestamp,
          'X-Monetta-Signature': signature,
        },
        body,
        signal: AbortSignal.timeout(15_000),
      });
      if (response.ok) {
        await this.pool.query(
          `UPDATE notification_event_outbox
              SET status = 'delivered', delivered_at = $2, updated_at = $2, last_error = NULL
            WHERE id = $1`,
          [row.id, this.now()],
        );
        return;
      }
      const retryable = response.status === 429 || response.status >= 500;
      await this.fail(row, `http_${response.status}`, retryable);
    } catch (error) {
      await this.fail(
        row,
        error instanceof Error ? error.name : 'network_error',
        true,
      );
    }
  }

  private async fail(row: OutboxRow, reason: string, retryable: boolean) {
    const attempt = row.attempt_count + 1;
    const retry = retryable && attempt < 12;
    const seconds = Math.min(3600, 10 * 2 ** Math.min(attempt, 8));
    await this.pool.query(
      `UPDATE notification_event_outbox
          SET status = $2,
              next_attempt_at = $3,
              last_error = $4,
              updated_at = $5
        WHERE id = $1`,
      [
        row.id,
        retry ? 'retry' : 'dead',
        new Date(this.now().getTime() + seconds * 1000),
        reason.slice(0, 300),
        this.now(),
      ],
    );
  }
}

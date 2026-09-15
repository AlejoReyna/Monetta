import type pg from 'pg';

export interface InternalRequestReplayRepository {
  claim(input: { readonly requestId: string; readonly expiresAt: Date }): Promise<boolean>;
}

export class PgInternalRequestReplayRepository implements InternalRequestReplayRepository {
  constructor(private readonly pool: pg.Pool) {}

  async claim(input: { readonly requestId: string; readonly expiresAt: Date }): Promise<boolean> {
    await this.pool.query(
      'DELETE FROM internal_admin_request_replays WHERE expires_at <= now()',
    );
    const result = await this.pool.query(
      `INSERT INTO internal_admin_request_replays (request_id, expires_at)
       VALUES ($1, $2) ON CONFLICT (request_id) DO NOTHING`,
      [input.requestId, input.expiresAt],
    );
    return (result.rowCount ?? 0) > 0;
  }
}

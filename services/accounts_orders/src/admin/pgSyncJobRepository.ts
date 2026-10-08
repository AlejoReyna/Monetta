import type pg from 'pg';
import type {
  AdminSyncChannel,
  AdminSyncJobRecord,
  AdminSyncJobRepository,
  AdminSyncJobStatus,
  StoredAdminSyncChannel,
} from './syncPorts.js';

interface SyncJobRow {
  id: string;
  actor_id: string;
  channel: StoredAdminSyncChannel;
  status: AdminSyncJobStatus;
  error_code: string | null;
  cursor: string | null;
  pages_processed: number;
  products_seen: number;
  created_at: Date;
  updated_at: Date;
}

function fromRow(row: SyncJobRow): AdminSyncJobRecord {
  return {
    id: row.id,
    actorId: row.actor_id,
    channel: row.channel,
    status: row.status,
    errorCode: row.error_code,
    cursor: row.cursor,
    pagesProcessed: Number(row.pages_processed ?? 0),
    productsSeen: Number(row.products_seen ?? 0),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class PgAdminSyncJobRepository implements AdminSyncJobRepository {
  constructor(private readonly pool: pg.Pool) {}

  async create(input: {
    readonly id: string;
    readonly actorId: string;
    readonly channel: AdminSyncChannel;
  }): Promise<AdminSyncJobRecord> {
    const result = await this.pool.query<SyncJobRow>(
      `INSERT INTO admin_sync_jobs (id, actor_id, channel, status)
       VALUES ($1, $2, $3, 'pending')
       RETURNING id, actor_id, channel, status, error_code, cursor,
                 pages_processed, products_seen, created_at, updated_at`,
      [input.id, input.actorId, input.channel],
    );
    const row = result.rows[0];
    if (row === undefined) throw new Error('sync job create returned no row');
    return fromRow(row);
  }

  async find(id: string): Promise<AdminSyncJobRecord | null> {
    const result = await this.pool.query<SyncJobRow>(
      `SELECT id, actor_id, channel, status, error_code, cursor,
              pages_processed, products_seen, created_at, updated_at
         FROM admin_sync_jobs WHERE id = $1`,
      [id],
    );
    return result.rows[0] === undefined ? null : fromRow(result.rows[0]);
  }

  async update(input: {
    readonly id: string;
    readonly status: AdminSyncJobStatus;
    readonly errorCode?: string | null;
    readonly cursor?: string | null;
    readonly pagesProcessed?: number;
    readonly productsSeen?: number;
  }): Promise<void> {
    // When errorCode is explicitly null (success), clear it. When undefined, keep prior.
    const clearError = input.errorCode === null;
    const setError = input.errorCode !== undefined && input.errorCode !== null;
    await this.pool.query(
      `UPDATE admin_sync_jobs
          SET status = $2,
              error_code = CASE
                WHEN $3::boolean THEN NULL
                WHEN $4::boolean THEN $5
                ELSE error_code
              END,
              cursor = COALESCE($6, cursor),
              pages_processed = COALESCE($7, pages_processed),
              products_seen = COALESCE($8, products_seen),
              updated_at = now()
        WHERE id = $1`,
      [
        input.id,
        input.status,
        clearError,
        setError,
        input.errorCode ?? null,
        input.cursor === undefined ? null : input.cursor,
        input.pagesProcessed === undefined ? null : input.pagesProcessed,
        input.productsSeen === undefined ? null : input.productsSeen,
      ],
    );
  }

  async listRecoverable(input?: {
    readonly olderThanMs?: number;
    readonly limit?: number;
  }): Promise<readonly AdminSyncJobRecord[]> {
    const olderThanMs = input?.olderThanMs ?? 30_000;
    const limit = Math.max(1, Math.min(100, input?.limit ?? 20));
    const result = await this.pool.query<SyncJobRow>(
      `SELECT id, actor_id, channel, status, error_code, cursor,
              pages_processed, products_seen, created_at, updated_at
         FROM admin_sync_jobs
        WHERE status IN ('pending', 'running')
          AND updated_at < now() - make_interval(secs => $1::double precision / 1000.0)
        ORDER BY updated_at ASC
        LIMIT $2`,
      [olderThanMs, limit],
    );
    return result.rows.map(fromRow);
  }
}

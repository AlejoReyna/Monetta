import type pg from 'pg';
import type {
  AdminSyncChannel,
  AdminSyncJobRecord,
  AdminSyncJobRepository,
  AdminSyncJobStatus,
} from './syncPorts.js';

interface SyncJobRow {
  id: string;
  actor_id: string;
  channel: AdminSyncChannel;
  status: AdminSyncJobStatus;
  error_code: string | null;
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
       RETURNING id, actor_id, channel, status, error_code, created_at, updated_at`,
      [input.id, input.actorId, input.channel],
    );
    const row = result.rows[0];
    if (row === undefined) throw new Error('sync job create returned no row');
    return fromRow(row);
  }

  async find(id: string): Promise<AdminSyncJobRecord | null> {
    const result = await this.pool.query<SyncJobRow>(
      `SELECT id, actor_id, channel, status, error_code, created_at, updated_at
         FROM admin_sync_jobs WHERE id = $1`,
      [id],
    );
    return result.rows[0] === undefined ? null : fromRow(result.rows[0]);
  }

  async update(input: {
    readonly id: string;
    readonly status: AdminSyncJobStatus;
    readonly errorCode?: string | null;
  }): Promise<void> {
    await this.pool.query(
      `UPDATE admin_sync_jobs
          SET status = $2, error_code = $3, updated_at = now()
        WHERE id = $1`,
      [input.id, input.status, input.errorCode ?? null],
    );
  }
}

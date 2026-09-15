import type pg from 'pg';
import type { DashboardSessionRecord, DashboardSessionStore } from '../api/session.js';

interface SessionRow {
  token_sha256: string;
  created_at: Date;
  expires_at: Date;
  last_seen_at: Date;
  label: string | null;
}

function fromRow(row: SessionRow): DashboardSessionRecord {
  return {
    tokenSha256: row.token_sha256,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    lastSeenAt: row.last_seen_at,
    label: row.label,
  };
}

/**
 * Postgres-backed dashboard session store for `dashboard_sessions`
 * (migration `010_dashboard_sessions.sql`). Only SHA-256 token hashes are
 * persisted; raw tokens never touch the database.
 */
export class PgDashboardSessionRepository implements DashboardSessionStore {
  constructor(private readonly pool: pg.Pool) {}

  async create(params: { tokenSha256: string; expiresAt: Date; label?: string | null }): Promise<void> {
    await this.pool.query(
      `INSERT INTO dashboard_sessions (token_sha256, expires_at, label)
       VALUES ($1, $2, $3)
       ON CONFLICT (token_sha256) DO UPDATE SET
         expires_at = EXCLUDED.expires_at,
         last_seen_at = now(),
         label = EXCLUDED.label`,
      [params.tokenSha256, params.expiresAt, params.label ?? null],
    );
  }

  async findByTokenHash(tokenSha256: string): Promise<DashboardSessionRecord | null> {
    const { rows } = await this.pool.query<SessionRow>(
      'SELECT token_sha256, created_at, expires_at, last_seen_at, label FROM dashboard_sessions WHERE token_sha256 = $1',
      [tokenSha256],
    );
    const row = rows[0];
    return row === undefined ? null : fromRow(row);
  }

  async touch(tokenSha256: string, now: Date): Promise<void> {
    await this.pool.query(
      'UPDATE dashboard_sessions SET last_seen_at = $2 WHERE token_sha256 = $1',
      [tokenSha256, now],
    );
  }

  async revoke(tokenSha256: string): Promise<void> {
    await this.pool.query('DELETE FROM dashboard_sessions WHERE token_sha256 = $1', [tokenSha256]);
  }

  async deleteExpired(now: Date): Promise<number> {
    const { rowCount } = await this.pool.query(
      'DELETE FROM dashboard_sessions WHERE expires_at <= $1',
      [now],
    );
    return rowCount ?? 0;
  }
}

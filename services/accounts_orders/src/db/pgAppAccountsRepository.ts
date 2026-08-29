import type pg from 'pg';
import type { AppAccountsRepository } from '../domain/ports.js';
import type {
  AppAccountCredentials,
  AppAccountRecord,
  AppAccountRegistration,
  AppSessionCreation,
} from '../domain/types.js';

interface AppAccountRow {
  id: string;
  email: string;
  display_name: string | null;
  email_verified: boolean;
  shopify_customer_id: string | null;
  password_hash?: string | null;
  created_at: Date;
  updated_at: Date;
}

function fromRow(row: AppAccountRow): AppAccountRecord {
  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name,
    emailVerified: row.email_verified,
    shopifyCustomerId: row.shopify_customer_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class PgAppAccountsRepository implements AppAccountsRepository {
  constructor(private readonly pool: pg.Pool) {}

  async register(record: AppAccountRegistration): Promise<AppAccountRecord> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      // Serialize registrations for one device so concurrent retries cannot
      // create an orphan account before the UNIQUE(device_id) upsert wins.
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [record.deviceId]);
      const existing = await client.query<AppAccountRow>(
        `SELECT a.id, a.email, a.display_name, a.email_verified, a.shopify_customer_id,
                a.created_at, a.updated_at
           FROM app_accounts a
           JOIN app_sessions s ON s.account_id = a.id
          WHERE s.device_id = $1
          FOR UPDATE OF a`,
        [record.deviceId],
      );

      const accountId = existing.rows[0]?.id ?? record.accountId;
      const account = existing.rows[0] === undefined
        ? await client.query<AppAccountRow>(
            `INSERT INTO app_accounts (id, email, display_name, password_hash)
             VALUES ($1, $2, $3, $4)
             RETURNING id, email, display_name, email_verified, shopify_customer_id,
                       created_at, updated_at`,
            [accountId, record.email, record.displayName, record.passwordHash],
          )
        : await client.query<AppAccountRow>(
            `UPDATE app_accounts
                SET email = $2, display_name = $3, password_hash = $4, updated_at = now()
              WHERE id = $1
              RETURNING id, email, display_name, email_verified, shopify_customer_id,
                        created_at, updated_at`,
            [accountId, record.email, record.displayName, record.passwordHash],
          );

      await client.query(
        `INSERT INTO app_sessions (token_hash, account_id, device_id, expires_at)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (device_id) DO UPDATE SET
           token_hash = EXCLUDED.token_hash,
           account_id = EXCLUDED.account_id,
           expires_at = EXCLUDED.expires_at,
           created_at = now()`,
        [record.tokenHash, accountId, record.deviceId, record.expiresAt],
      );
      await client.query('COMMIT');
      return fromRow(account.rows[0]!);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async findCredentialsByEmail(email: string): Promise<AppAccountCredentials | null> {
    const result = await this.pool.query<AppAccountRow>(
      `SELECT id, email, display_name, email_verified, shopify_customer_id, password_hash,
              created_at, updated_at
         FROM app_accounts
        WHERE lower(email) = lower($1)`,
      [email],
    );
    const row = result.rows[0];
    if (row === undefined || row.password_hash == null) return null;
    return { ...fromRow(row), passwordHash: row.password_hash };
  }

  async createSession(record: AppSessionCreation): Promise<void> {
    await this.pool.query(
      `INSERT INTO app_sessions (token_hash, account_id, device_id, expires_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (device_id) DO UPDATE SET
         token_hash = EXCLUDED.token_hash,
         account_id = EXCLUDED.account_id,
         expires_at = EXCLUDED.expires_at,
         created_at = now()`,
      [record.tokenHash, record.accountId, record.deviceId, record.expiresAt],
    );
  }

  async findByTokenHash(tokenHash: string): Promise<AppAccountRecord | null> {
    const result = await this.pool.query<AppAccountRow>(
      `SELECT a.id, a.email, a.display_name, a.email_verified, a.shopify_customer_id,
              a.created_at, a.updated_at
         FROM app_accounts a
         JOIN app_sessions s ON s.account_id = a.id
        WHERE s.token_hash = $1 AND s.expires_at > now()`,
      [tokenHash],
    );
    return result.rows[0] === undefined ? null : fromRow(result.rows[0]);
  }

  async revokeToken(tokenHash: string): Promise<void> {
    await this.pool.query('DELETE FROM app_sessions WHERE token_hash = $1', [tokenHash]);
  }
}

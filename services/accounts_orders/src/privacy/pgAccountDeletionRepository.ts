import type pg from 'pg';
import type {
  AccountDeletionAuditEntry,
  AccountDeletionAuditRepository,
  AccountDeletionProgress,
  AccountDeletionStateRepository,
} from './ports.js';
import { sanitizeAuditSteps, sanitizeInternalId } from './redact.js';

interface StateRow {
  shopify_customer_id: string;
  status: 'in_progress' | 'completed';
  firebase_auth: 'pending' | 'done';
  firestore: 'pending' | 'done';
  postgres: 'pending' | 'done';
  shopify_erasure: 'pending' | 'requested';
  app_account_id: string | null;
  firebase_uid: string | null;
}

interface AuditRow {
  shopify_customer_id: string;
  app_account_id: string | null;
  firebase_uid: string | null;
  result: string;
  steps: Record<string, string>;
  created_at: Date;
}

function fromState(row: StateRow): AccountDeletionProgress {
  return {
    shopifyCustomerId: row.shopify_customer_id,
    status: row.status,
    firebaseAuth: row.firebase_auth,
    firestore: row.firestore,
    postgres: row.postgres,
    shopifyErasure: row.shopify_erasure,
    appAccountId: row.app_account_id,
    firebaseUid: row.firebase_uid,
  };
}

export class PgAccountDeletionStateRepository implements AccountDeletionStateRepository {
  constructor(private readonly pool: pg.Pool) {}

  async get(shopifyCustomerId: string): Promise<AccountDeletionProgress | null> {
    const result = await this.pool.query<StateRow>(
      `SELECT shopify_customer_id, status, firebase_auth, firestore, postgres,
              shopify_erasure, app_account_id, firebase_uid
         FROM account_deletion_state
        WHERE shopify_customer_id = $1`,
      [shopifyCustomerId],
    );
    return result.rows[0] === undefined ? null : fromState(result.rows[0]);
  }

  async claim(shopifyCustomerId: string): Promise<AccountDeletionProgress> {
    await this.pool.query(
      `INSERT INTO account_deletion_state
         (shopify_customer_id, status, firebase_auth, firestore, postgres, shopify_erasure)
       VALUES ($1, 'in_progress', 'pending', 'pending', 'pending', 'pending')
       ON CONFLICT (shopify_customer_id) DO NOTHING`,
      [shopifyCustomerId],
    );
    const claimed = await this.get(shopifyCustomerId);
    if (claimed === null) throw new Error('account_deletion_claim_failed');
    return claimed;
  }

  async save(progress: AccountDeletionProgress): Promise<void> {
    await this.pool.query(
      `UPDATE account_deletion_state
          SET status = $2,
              firebase_auth = $3,
              firestore = $4,
              postgres = $5,
              shopify_erasure = $6,
              app_account_id = $7,
              firebase_uid = $8,
              updated_at = now(),
              completed_at = CASE WHEN $2 = 'completed' THEN COALESCE(completed_at, now()) ELSE completed_at END
        WHERE shopify_customer_id = $1`,
      [
        progress.shopifyCustomerId,
        progress.status,
        progress.firebaseAuth,
        progress.firestore,
        progress.postgres,
        progress.shopifyErasure,
        sanitizeInternalId(progress.appAccountId),
        sanitizeInternalId(progress.firebaseUid),
      ],
    );
  }
}

export class PgAccountDeletionAuditRepository implements AccountDeletionAuditRepository {
  constructor(private readonly pool: pg.Pool) {}

  async append(
    entry: Omit<AccountDeletionAuditEntry, 'createdAt'> & { readonly createdAt?: string },
  ): Promise<AccountDeletionAuditEntry> {
    const customerId = sanitizeInternalId(entry.shopifyCustomerId);
    if (customerId === null) throw new Error('invalid_audit_customer');
    const steps = sanitizeAuditSteps({ ...entry.steps });
    const createdAt = entry.createdAt ?? new Date().toISOString();
    const result = await this.pool.query<AuditRow>(
      `INSERT INTO account_deletion_audit
         (shopify_customer_id, app_account_id, firebase_uid, result, steps, created_at)
       VALUES ($1, $2, $3, $4, $5::jsonb, $6)
       RETURNING shopify_customer_id, app_account_id, firebase_uid, result, steps, created_at`,
      [
        customerId,
        sanitizeInternalId(entry.appAccountId),
        sanitizeInternalId(entry.firebaseUid),
        entry.result,
        JSON.stringify(steps),
        createdAt,
      ],
    );
    const row = result.rows[0];
    if (row === undefined) throw new Error('audit_insert_failed');
    return {
      shopifyCustomerId: row.shopify_customer_id,
      appAccountId: row.app_account_id,
      firebaseUid: row.firebase_uid,
      result: row.result,
      steps: sanitizeAuditSteps(row.steps ?? {}),
      createdAt: row.created_at.toISOString(),
    };
  }

  async list(shopifyCustomerId: string): Promise<readonly AccountDeletionAuditEntry[]> {
    const result = await this.pool.query<AuditRow>(
      `SELECT shopify_customer_id, app_account_id, firebase_uid, result, steps, created_at
         FROM account_deletion_audit
        WHERE shopify_customer_id = $1
        ORDER BY created_at ASC, id ASC`,
      [shopifyCustomerId],
    );
    return result.rows.map((row) => ({
      shopifyCustomerId: row.shopify_customer_id,
      appAccountId: row.app_account_id,
      firebaseUid: row.firebase_uid,
      result: row.result,
      steps: sanitizeAuditSteps(row.steps ?? {}),
      createdAt: row.created_at.toISOString(),
    }));
  }
}

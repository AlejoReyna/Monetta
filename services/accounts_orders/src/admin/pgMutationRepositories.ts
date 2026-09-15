import type pg from 'pg';
import type {
  AdminAuditLogger,
  AdminAuditReader,
  AdminAuditRecord,
  AdminIdempotencyRepository,
} from './mutationPorts.js';
import type { AdminActor } from './types.js';

interface IdempotencyRow {
  actor_id: string;
  idempotency_key: string;
  operation: string;
  body_hash: string;
  status_code: number | null;
  response_body: unknown | null;
  request_id: string;
  created_at: Date;
  expires_at: Date;
}

function fromRow(row: IdempotencyRow) {
  return {
    actorId: row.actor_id,
    idempotencyKey: row.idempotency_key,
    operation: row.operation,
    bodyHash: row.body_hash,
    statusCode: row.status_code,
    responseBody: row.response_body,
    requestId: row.request_id,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
  };
}

export class PgAdminIdempotencyRepository implements AdminIdempotencyRepository {
  constructor(private readonly pool: pg.Pool) {}

  async claim(input: {
    readonly actorId: string;
    readonly idempotencyKey: string;
    readonly operation: string;
    readonly bodyHash: string;
    readonly requestId: string;
    readonly expiresAt: Date;
  }) {
    await this.pool.query(
      `DELETE FROM admin_idempotency_keys
        WHERE actor_id = $1 AND idempotency_key = $2 AND expires_at <= now()`,
      [input.actorId, input.idempotencyKey],
    );
    await this.pool.query(
      `INSERT INTO admin_idempotency_keys
         (actor_id, idempotency_key, operation, body_hash, request_id, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (actor_id, idempotency_key) DO NOTHING`,
      [
        input.actorId,
        input.idempotencyKey,
        input.operation,
        input.bodyHash,
        input.requestId,
        input.expiresAt,
      ],
    );
    const result = await this.pool.query<IdempotencyRow>(
      `SELECT actor_id, idempotency_key, operation, body_hash, status_code,
              response_body, request_id, created_at, expires_at
         FROM admin_idempotency_keys
        WHERE actor_id = $1 AND idempotency_key = $2`,
      [input.actorId, input.idempotencyKey],
    );
    const row = result.rows[0];
    if (row === undefined) throw new Error('idempotency record disappeared');
    const record = fromRow(row);
    if (record.operation !== input.operation || record.bodyHash !== input.bodyHash) {
      return { outcome: 'conflict', record } as const;
    }
    if (record.statusCode === null || record.responseBody === null) {
      return record.requestId === input.requestId
        ? { outcome: 'claimed', record } as const
        : { outcome: 'conflict', record } as const;
    }
    return { outcome: 'replay', record } as const;
  }

  async complete(input: {
    readonly actorId: string;
    readonly idempotencyKey: string;
    readonly statusCode: number;
    readonly responseBody: unknown;
  }): Promise<void> {
    await this.pool.query(
      `UPDATE admin_idempotency_keys
          SET status_code = $3, response_body = $4::jsonb
        WHERE actor_id = $1 AND idempotency_key = $2`,
      [input.actorId, input.idempotencyKey, input.statusCode, JSON.stringify(input.responseBody)],
    );
  }
}

export class PgAdminAuditLogger implements AdminAuditLogger, AdminAuditReader {
  constructor(private readonly pool: pg.Pool) {}

  async record(input: {
    readonly actor: AdminActor;
    readonly requestId: string;
    readonly action: string;
    readonly targetType: string;
    readonly targetId: string;
    readonly outcome: 'success' | 'rejected' | 'failed';
    readonly errorCode?: string;
    readonly before?: Record<string, unknown>;
    readonly after?: Record<string, unknown>;
  }): Promise<void> {
    const metadata = {
      requestId: input.requestId,
      provider: input.actor.provider,
      subjectType: input.actor.subject.type,
      outcome: input.outcome,
      ...(input.errorCode === undefined ? {} : { errorCode: input.errorCode }),
      ...(input.before === undefined ? {} : { before: input.before }),
      ...(input.after === undefined ? {} : { after: input.after }),
    };
    await this.pool.query(
      `INSERT INTO admin_audit_events
         (actor_id, action, resource_type, resource_id, metadata)
       VALUES ($1, $2, $3, $4, $5::jsonb)`,
      [
        input.actor.id,
        input.action,
        input.targetType,
        input.targetId,
        JSON.stringify(metadata),
      ],
    );
  }

  async list(input: {
    readonly beforeId: number | null;
    readonly limit: number;
  }): Promise<readonly AdminAuditRecord[]> {
    const result = input.beforeId === null
      ? await this.pool.query<AuditRow>(
          `SELECT id, actor_id, action, resource_type, resource_id, metadata, created_at
             FROM admin_audit_events
            ORDER BY id DESC LIMIT $1`,
          [input.limit],
        )
      : await this.pool.query<AuditRow>(
          `SELECT id, actor_id, action, resource_type, resource_id, metadata, created_at
             FROM admin_audit_events
            WHERE id < $1
            ORDER BY id DESC LIMIT $2`,
          [input.beforeId, input.limit],
        );
    return result.rows.map((row) => ({
      id: Number(row.id),
      actorId: row.actor_id,
      action: row.action,
      resourceType: row.resource_type,
      resourceId: row.resource_id,
      metadata: row.metadata ?? {},
      createdAt: row.created_at,
    }));
  }
}

interface AuditRow {
  id: string | number;
  actor_id: string;
  action: string;
  resource_type: string;
  resource_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: Date;
}

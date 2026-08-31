import type {
  AdminAuditLogger,
  AdminAuditReader,
  AdminAuditRecord,
  AdminIdempotencyRepository,
  AdminMutationRateLimiter,
} from '../../src/admin/mutationPorts.js';
import type { AdminActor } from '../../src/admin/types.js';
import type {
  AdminSyncChannel,
  AdminSyncJobRecord,
  AdminSyncJobRepository,
  AdminSyncJobStatus,
} from '../../src/admin/syncPorts.js';

export class InMemoryAdminIdempotencyRepository implements AdminIdempotencyRepository {
  readonly rows = new Map<string, {
    actorId: string;
    idempotencyKey: string;
    operation: string;
    bodyHash: string;
    statusCode: number | null;
    responseBody: unknown | null;
    requestId: string;
    createdAt: Date;
    expiresAt: Date;
  }>();

  async claim(input: {
    readonly actorId: string;
    readonly idempotencyKey: string;
    readonly operation: string;
    readonly bodyHash: string;
    readonly requestId: string;
    readonly expiresAt: Date;
  }) {
    const key = `${input.actorId}:${input.idempotencyKey}`;
    const existing = this.rows.get(key);
    if (existing === undefined || existing.expiresAt <= new Date()) {
      const record = {
        ...input,
        statusCode: null,
        responseBody: null,
        createdAt: new Date(),
      };
      this.rows.set(key, record);
      return { outcome: 'claimed', record } as const;
    }
    if (existing.operation !== input.operation || existing.bodyHash !== input.bodyHash) {
      return { outcome: 'conflict', record: existing } as const;
    }
    if (existing.statusCode === null || existing.responseBody === null) {
      return existing.requestId === input.requestId
        ? { outcome: 'claimed', record: existing } as const
        : { outcome: 'conflict', record: existing } as const;
    }
    return { outcome: 'replay', record: existing } as const;
  }

  async complete(input: {
    readonly actorId: string;
    readonly idempotencyKey: string;
    readonly statusCode: number;
    readonly responseBody: unknown;
  }): Promise<void> {
    const record = this.rows.get(`${input.actorId}:${input.idempotencyKey}`);
    if (record === undefined) throw new Error('missing idempotency record');
    record.statusCode = input.statusCode;
    record.responseBody = input.responseBody;
  }
}

export class InMemoryAdminAuditLogger implements AdminAuditLogger, AdminAuditReader {
  readonly events: Array<{
    actor: AdminActor;
    requestId: string;
    action: string;
    targetType: string;
    targetId: string;
    outcome: 'success' | 'rejected' | 'failed';
    errorCode?: string;
    before?: Record<string, unknown>;
    after?: Record<string, unknown>;
  }> = [];

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
    this.events.push({ ...input });
  }

  async list(input: {
    readonly beforeId: number | null;
    readonly limit: number;
  }): Promise<readonly AdminAuditRecord[]> {
    const records = this.events.map((event, index) => ({
      id: index + 1,
      actorId: event.actor.id,
      action: event.action,
      resourceType: event.targetType,
      resourceId: event.targetId,
      metadata: {
        requestId: event.requestId,
        outcome: event.outcome,
        ...(event.errorCode === undefined ? {} : { errorCode: event.errorCode }),
        ...(event.before === undefined ? {} : { before: event.before }),
        ...(event.after === undefined ? {} : { after: event.after }),
      },
      createdAt: new Date(index + 1),
    } satisfies AdminAuditRecord));
    return records
      .filter((record) => input.beforeId === null || record.id < input.beforeId)
      .reverse()
      .slice(0, input.limit);
  }
}

export class AllowingAdminRateLimiter implements AdminMutationRateLimiter {
  calls = 0;

  allow(_actorId: string, _operation: string): boolean {
    this.calls += 1;
    return true;
  }
}

export class InMemoryAdminSyncJobRepository implements AdminSyncJobRepository {
  readonly rows = new Map<string, AdminSyncJobRecord>();

  async create(input: {
    readonly id: string;
    readonly actorId: string;
    readonly channel: AdminSyncChannel;
  }): Promise<AdminSyncJobRecord> {
    const now = new Date();
    const job: AdminSyncJobRecord = {
      ...input,
      status: 'pending',
      errorCode: null,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(job.id, job);
    return job;
  }

  async find(id: string): Promise<AdminSyncJobRecord | null> {
    return this.rows.get(id) ?? null;
  }

  async update(input: {
    readonly id: string;
    readonly status: AdminSyncJobStatus;
    readonly errorCode?: string | null;
  }): Promise<void> {
    const existing = this.rows.get(input.id);
    if (existing === undefined) throw new Error('missing sync job');
    this.rows.set(input.id, {
      ...existing,
      status: input.status,
      errorCode: input.errorCode ?? null,
      updatedAt: new Date(),
    });
  }
}

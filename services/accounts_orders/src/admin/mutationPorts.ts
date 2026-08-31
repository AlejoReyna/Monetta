import type { AdminActor } from './types.js';

export interface AdminIdempotencyRecord {
  readonly actorId: string;
  readonly idempotencyKey: string;
  readonly operation: string;
  readonly bodyHash: string;
  readonly statusCode: number | null;
  readonly responseBody: unknown | null;
  readonly requestId: string;
  readonly createdAt: Date;
  readonly expiresAt: Date;
}

export type IdempotencyClaim =
  | { readonly outcome: 'claimed'; readonly record: AdminIdempotencyRecord }
  | { readonly outcome: 'replay'; readonly record: AdminIdempotencyRecord }
  | { readonly outcome: 'conflict'; readonly record: AdminIdempotencyRecord };

export interface AdminIdempotencyRepository {
  claim(input: {
    readonly actorId: string;
    readonly idempotencyKey: string;
    readonly operation: string;
    readonly bodyHash: string;
    readonly requestId: string;
    readonly expiresAt: Date;
  }): Promise<IdempotencyClaim>;

  complete(input: {
    readonly actorId: string;
    readonly idempotencyKey: string;
    readonly statusCode: number;
    readonly responseBody: unknown;
  }): Promise<void>;
}

export interface AdminAuditLogger {
  record(input: {
    readonly actor: AdminActor;
    readonly requestId: string;
    readonly action: string;
    readonly targetType: string;
    readonly targetId: string;
    readonly outcome: 'success' | 'rejected' | 'failed';
    readonly errorCode?: string;
    readonly before?: Record<string, unknown>;
    readonly after?: Record<string, unknown>;
  }): Promise<void>;
}

export interface AdminAuditReader {
  list(input: {
    readonly beforeId: number | null;
    readonly limit: number;
  }): Promise<readonly AdminAuditRecord[]>;
}

export interface AdminAuditRecord {
  readonly id: number;
  readonly actorId: string;
  readonly action: string;
  readonly resourceType: string;
  readonly resourceId: string | null;
  readonly metadata: Record<string, unknown>;
  readonly createdAt: Date;
}

export interface AdminMutationRateLimiter {
  allow(actorId: string, operation: string): boolean;
}

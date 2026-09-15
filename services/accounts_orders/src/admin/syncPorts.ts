export type AdminSyncChannel =
  | 'shopify-products'
  | 'shopify-orders'
  | 'storefront-content'
  | 'external-status';

export type AdminSyncJobStatus = 'pending' | 'running' | 'completed' | 'failed';

export interface AdminSyncJobRecord {
  readonly id: string;
  readonly actorId: string;
  readonly channel: AdminSyncChannel;
  readonly status: AdminSyncJobStatus;
  readonly errorCode: string | null;
  readonly cursor: string | null;
  readonly pagesProcessed: number;
  readonly productsSeen: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface AdminSyncJobRepository {
  create(input: {
    readonly id: string;
    readonly actorId: string;
    readonly channel: AdminSyncChannel;
  }): Promise<AdminSyncJobRecord>;
  find(id: string): Promise<AdminSyncJobRecord | null>;
  update(input: {
    readonly id: string;
    readonly status: AdminSyncJobStatus;
    readonly errorCode?: string | null;
    readonly cursor?: string | null;
    readonly pagesProcessed?: number;
    readonly productsSeen?: number;
  }): Promise<void>;
  /** Jobs that were accepted but not finished — safe to resume after restart. */
  listRecoverable(input?: {
    readonly olderThanMs?: number;
    readonly limit?: number;
  }): Promise<readonly AdminSyncJobRecord[]>;
}

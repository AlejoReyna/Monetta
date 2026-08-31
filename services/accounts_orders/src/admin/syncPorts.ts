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
  }): Promise<void>;
}

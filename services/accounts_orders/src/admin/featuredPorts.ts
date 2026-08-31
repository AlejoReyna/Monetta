import type { AdminFeaturedJobRecord } from './featuredTypes.js';

export interface AdminFeaturedJobRepository {
  create(input: {
    readonly jobId: string;
    readonly actorId: string;
    readonly shopifyJobId: string;
    readonly collectionId: string;
    readonly requestedProductIds: readonly string[];
  }): Promise<AdminFeaturedJobRecord>;

  find(jobId: string): Promise<AdminFeaturedJobRecord | null>;

  update(input: {
    readonly jobId: string;
    readonly status: AdminFeaturedJobRecord['status'];
    readonly errorCode?: string | null;
  }): Promise<void>;
}

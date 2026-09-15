import type { AdminProductProjection } from './shopifyTypes.js';

export interface AdminFeaturedCollectionProjection {
  readonly id: string;
  readonly handle: string;
  readonly title: string;
  readonly updatedAt: string;
  readonly sortOrder: string;
  readonly productIds: readonly string[];
}
export interface AdminFeaturedCatalogProjection {
  readonly collection: AdminFeaturedCollectionProjection | null;
  readonly eligibleProducts: readonly AdminProductProjection[];
  readonly selectedProductIds: readonly string[];
}

export interface AdminFeaturedJobRecord {
  readonly jobId: string;
  readonly actorId: string;
  readonly shopifyJobId: string;
  readonly collectionId: string;
  readonly requestedProductIds: readonly string[];
  readonly status: 'pending' | 'completed' | 'failed' | 'degraded';
  readonly errorCode: string | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

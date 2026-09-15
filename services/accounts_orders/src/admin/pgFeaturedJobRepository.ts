import type pg from 'pg';
import type { AdminFeaturedJobRepository } from './featuredPorts.js';
import type { AdminFeaturedJobRecord } from './featuredTypes.js';

interface JobRow {
  job_id: string;
  actor_id: string;
  shopify_job_id: string;
  collection_id: string;
  requested_product_ids: unknown;
  status: AdminFeaturedJobRecord['status'];
  error_code: string | null;
  created_at: Date;
  updated_at: Date;
}
function fromRow(row: JobRow): AdminFeaturedJobRecord {
  const ids = Array.isArray(row.requested_product_ids)
    ? row.requested_product_ids.filter((id): id is string => typeof id === 'string')
    : [];
  return {
    jobId: row.job_id,
    actorId: row.actor_id,
    shopifyJobId: row.shopify_job_id,
    collectionId: row.collection_id,
    requestedProductIds: ids,
    status: row.status,
    errorCode: row.error_code,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class PgAdminFeaturedJobRepository implements AdminFeaturedJobRepository {
  constructor(private readonly pool: pg.Pool) {}

  async create(input: {
    readonly jobId: string;
    readonly actorId: string;
    readonly shopifyJobId: string;
    readonly collectionId: string;
    readonly requestedProductIds: readonly string[];
  }): Promise<AdminFeaturedJobRecord> {
    const result = await this.pool.query<JobRow>(
      `INSERT INTO admin_featured_jobs
         (job_id, actor_id, shopify_job_id, collection_id, requested_product_ids, status)
       VALUES ($1, $2, $3, $4, $5::jsonb, 'pending')
       RETURNING job_id, actor_id, shopify_job_id, collection_id,
                 requested_product_ids, status, error_code, created_at, updated_at`,
      [
        input.jobId,
        input.actorId,
        input.shopifyJobId,
        input.collectionId,
        JSON.stringify(input.requestedProductIds),
      ],
    );
    const row = result.rows[0];
    if (row === undefined) throw new Error('featured job was not created');
    return fromRow(row);
  }

  async find(jobId: string): Promise<AdminFeaturedJobRecord | null> {
    const result = await this.pool.query<JobRow>(
      `SELECT job_id, actor_id, shopify_job_id, collection_id,
              requested_product_ids, status, error_code, created_at, updated_at
         FROM admin_featured_jobs
        WHERE job_id = $1`,
      [jobId],
    );
    const row = result.rows[0];
    return row === undefined ? null : fromRow(row);
  }

  async update(input: {
    readonly jobId: string;
    readonly status: AdminFeaturedJobRecord['status'];
    readonly errorCode?: string | null;
  }): Promise<void> {
    await this.pool.query(
      `UPDATE admin_featured_jobs
          SET status = $2, error_code = $3, updated_at = now()
        WHERE job_id = $1`,
      [input.jobId, input.status, input.errorCode ?? null],
    );
  }
}

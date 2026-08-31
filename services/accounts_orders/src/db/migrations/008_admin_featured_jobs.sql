CREATE TABLE IF NOT EXISTS admin_featured_jobs (
  job_id UUID PRIMARY KEY,
  actor_id TEXT NOT NULL,
  shopify_job_id TEXT NOT NULL,
  collection_id TEXT NOT NULL,
  requested_product_ids JSONB NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed', 'degraded')),
  error_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_featured_jobs_actor_created_idx
  ON admin_featured_jobs (actor_id, created_at DESC);

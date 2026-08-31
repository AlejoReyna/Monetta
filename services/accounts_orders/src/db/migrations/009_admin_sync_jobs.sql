CREATE TABLE IF NOT EXISTS admin_sync_jobs (
  id UUID PRIMARY KEY,
  actor_id TEXT NOT NULL,
  channel TEXT NOT NULL CHECK (channel IN (
    'shopify-products', 'shopify-orders', 'storefront-content', 'external-status'
  )),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  error_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_sync_jobs_actor_created
  ON admin_sync_jobs (actor_id, created_at DESC);

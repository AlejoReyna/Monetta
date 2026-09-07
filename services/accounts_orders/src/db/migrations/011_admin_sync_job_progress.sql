-- Phase F / F22: durable sync progress so interrupted jobs resume past page 1.
ALTER TABLE admin_sync_jobs
  ADD COLUMN IF NOT EXISTS cursor TEXT,
  ADD COLUMN IF NOT EXISTS pages_processed INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS products_seen INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_admin_sync_jobs_recoverable
  ON admin_sync_jobs (status, updated_at)
  WHERE status IN ('pending', 'running');

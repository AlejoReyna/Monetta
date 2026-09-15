CREATE TABLE IF NOT EXISTS internal_admin_request_replays (
  request_id TEXT PRIMARY KEY,
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_internal_admin_request_replays_expiry
  ON internal_admin_request_replays (expires_at);

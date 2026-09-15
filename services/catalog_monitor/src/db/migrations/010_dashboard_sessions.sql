CREATE TABLE IF NOT EXISTS dashboard_sessions (
  token_sha256 TEXT PRIMARY KEY,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at   TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  label        TEXT
);
CREATE INDEX IF NOT EXISTS idx_dashboard_sessions_expiry
  ON dashboard_sessions (expires_at);

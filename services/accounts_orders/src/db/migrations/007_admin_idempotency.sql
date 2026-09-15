-- Idempotency records for control-plane mutations. The primary key is scoped
-- to an actor, but not to an operation: a key cannot be accidentally reused
-- for a different mutation by the same actor.

CREATE TABLE IF NOT EXISTS admin_idempotency_keys (
  actor_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  operation TEXT NOT NULL,
  body_hash TEXT NOT NULL,
  status_code INTEGER,
  response_body JSONB,
  request_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (actor_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_admin_idempotency_expiry
  ON admin_idempotency_keys (expires_at);

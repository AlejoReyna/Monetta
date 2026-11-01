-- In-app account deletion (Apple 5.1.1(v) / Play). Progress is retryable.
-- The audit row stores internal ids, step codes, and a timestamp only.
-- A check rejects email-shaped values so a regression cannot persist them.

CREATE TABLE IF NOT EXISTS account_deletion_state (
  shopify_customer_id TEXT PRIMARY KEY,
  status TEXT NOT NULL CHECK (status IN ('in_progress', 'completed')),
  firebase_auth TEXT NOT NULL CHECK (firebase_auth IN ('pending', 'done')),
  firestore TEXT NOT NULL CHECK (firestore IN ('pending', 'done')),
  postgres TEXT NOT NULL CHECK (postgres IN ('pending', 'done')),
  shopify_erasure TEXT NOT NULL CHECK (shopify_erasure IN ('pending', 'requested')),
  app_account_id TEXT,
  firebase_uid TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  CONSTRAINT account_deletion_state_ids_check CHECK (
    shopify_customer_id !~ '@'
    AND COALESCE(app_account_id, '') !~ '@'
    AND COALESCE(firebase_uid, '') !~ '@'
  )
);

CREATE TABLE IF NOT EXISTS account_deletion_audit (
  id BIGSERIAL PRIMARY KEY,
  shopify_customer_id TEXT NOT NULL,
  app_account_id TEXT,
  firebase_uid TEXT,
  result TEXT NOT NULL,
  steps JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT account_deletion_audit_redacted_check CHECK (
    shopify_customer_id !~ '@'
    AND COALESCE(app_account_id, '') !~ '@'
    AND COALESCE(firebase_uid, '') !~ '@'
    AND steps::text !~ '@'
    AND steps::text !~ '[0-9]{13,19}'
  )
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_audit_customer
  ON account_deletion_audit (shopify_customer_id, created_at DESC);

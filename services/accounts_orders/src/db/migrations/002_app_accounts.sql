-- First-party Monetta accounts. These deliberately do not overload
-- customers_mirror.shopify_customer_id: Shopify linkage is optional and can
-- be attached later without changing the app account's identity.

CREATE TABLE IF NOT EXISTS app_accounts (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL,
  display_name TEXT,
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  shopify_customer_id TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_accounts_email
  ON app_accounts (lower(email));

CREATE TABLE IF NOT EXISTS app_sessions (
  token_hash TEXT PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES app_accounts(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_sessions_account
  ON app_sessions (account_id);

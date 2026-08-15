-- Password login for first-party Monetta accounts. Email is normalized to
-- lowercase by the API, and uniqueness prevents two credentials from claiming
-- the same address.

ALTER TABLE app_accounts
  ADD COLUMN IF NOT EXISTS password_hash TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_app_accounts_normalized_email
  ON app_accounts (lower(email));

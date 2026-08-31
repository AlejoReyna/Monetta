-- Stable server-side admin subjects. The subject is deliberately independent
-- from an email address so an owner can authenticate through either Monetta
-- or Shopify without implicitly linking identities by matching email.

CREATE TABLE IF NOT EXISTS admin_principals (
  id UUID PRIMARY KEY,
  subject_type TEXT NOT NULL
    CHECK (subject_type IN ('app_account', 'shopify_customer')),
  subject_id TEXT NOT NULL,
  role TEXT NOT NULL
    CHECK (role IN ('owner')),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by TEXT NOT NULL,
  revoked_at TIMESTAMPTZ,
  UNIQUE (subject_type, subject_id, role)
);

CREATE INDEX IF NOT EXISTS idx_admin_principals_active_subject
  ON admin_principals (subject_type, subject_id, active);

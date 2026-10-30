-- Shopify Admin staff users as admin subjects, for the embedded notifications
-- panel. They authenticate with App Bridge session tokens and are provisioned
-- by staff id (the token's `sub`), never by email. The role stays `owner`;
-- the authorizer scopes this subject type to notification capabilities.

ALTER TABLE admin_principals
  DROP CONSTRAINT IF EXISTS admin_principals_subject_type_check;

ALTER TABLE admin_principals
  ADD CONSTRAINT admin_principals_subject_type_check
  CHECK (subject_type IN ('app_account', 'shopify_customer', 'shopify_staff'));

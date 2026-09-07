-- F29: durable export/redaction tracking for privacy_requests
-- Builds on 010_webhook_durable_inbox.sql privacy_requests table.

ALTER TABLE privacy_requests
  DROP CONSTRAINT IF EXISTS privacy_requests_kind_check;

ALTER TABLE privacy_requests
  ADD CONSTRAINT privacy_requests_kind_check
  CHECK (kind IN ('customers/data_request', 'customers/redact'));

ALTER TABLE privacy_requests
  ADD COLUMN IF NOT EXISTS export_artifact_ref TEXT,
  ADD COLUMN IF NOT EXISTS operator TEXT;

COMMENT ON COLUMN privacy_requests.export_artifact_ref IS
  'Operator-supplied reference to the export package location (object path or ticket id). Never store PII payloads here.';
COMMENT ON COLUMN privacy_requests.operator IS
  'Who fulfilled or cancelled the request (principal id or ops handle).';

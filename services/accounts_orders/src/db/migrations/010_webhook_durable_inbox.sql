-- F12: durable webhook inbox with recoverable pending/failed states.
-- Previously INSERT … ON CONFLICT DO NOTHING claimed a delivery before
-- effects ran; a failed upsert left the row claimed forever and Shopify
-- retries were skipped. Status + reclaimable processing fixes that.
--
-- F15: orders_mirror.shopify_updated_at prevents out-of-order webhook
-- deliveries from regressing financial/fulfillment state.
--
-- F29: privacy_requests tracks customers/data_request for durable follow-up
-- (export/close is still an ops workflow; this is the durable open task).

ALTER TABLE webhook_events
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_error TEXT,
  ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS shop_domain TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'webhook_events_status_check'
  ) THEN
    ALTER TABLE webhook_events
      ADD CONSTRAINT webhook_events_status_check
      CHECK (status IN ('pending', 'processing', 'completed', 'failed'));
  END IF;
END $$;

-- Existing rows: processed → completed; claimed-but-unprocessed → failed so
-- the next Shopify retry (or reclaim) can finish the work.
UPDATE webhook_events
SET status = 'completed'
WHERE processed_at IS NOT NULL AND status = 'pending';

UPDATE webhook_events
SET status = 'failed'
WHERE processed_at IS NULL AND status = 'pending';

CREATE INDEX IF NOT EXISTS idx_webhook_events_status_claimed
  ON webhook_events (status, claimed_at);

ALTER TABLE orders_mirror
  ADD COLUMN IF NOT EXISTS shopify_updated_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS privacy_requests (
  id BIGSERIAL PRIMARY KEY,
  webhook_id TEXT NOT NULL UNIQUE REFERENCES webhook_events (webhook_id),
  kind TEXT NOT NULL CHECK (kind IN ('customers/data_request')),
  shopify_customer_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'fulfilled', 'cancelled')),
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  fulfilled_at TIMESTAMPTZ,
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_privacy_requests_open
  ON privacy_requests (status, received_at)
  WHERE status = 'open';

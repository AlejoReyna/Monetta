-- Durable hand-off from catalog reconciliation to accounts_orders. Events are
-- written in the same transaction as product changes and retried separately.

CREATE TABLE IF NOT EXISTS notification_event_outbox (
  id UUID PRIMARY KEY,
  event_id TEXT NOT NULL UNIQUE,
  payload JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sending', 'retry', 'delivered', 'dead')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivered_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notification_event_outbox_queue
  ON notification_event_outbox (status, next_attempt_at)
  WHERE status IN ('pending', 'retry', 'sending');

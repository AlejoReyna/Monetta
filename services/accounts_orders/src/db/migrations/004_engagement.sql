-- Privacy-preserving notification infrastructure. Raw navigation events stay
-- on device; this schema stores only a compact interest snapshot, explicit
-- product alerts, consent, campaigns, and provider outcomes.

CREATE TABLE IF NOT EXISTS device_installations (
  device_id TEXT PRIMARY KEY,
  app_account_id UUID REFERENCES app_accounts(id) ON DELETE SET NULL,
  shopify_customer_id TEXT REFERENCES customers_mirror(shopify_customer_id) ON DELETE SET NULL,
  device_credential_hash TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  locale TEXT NOT NULL DEFAULT 'es-MX',
  timezone TEXT NOT NULL DEFAULT 'UTC',
  app_version TEXT NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  disabled_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_device_installations_account
  ON device_installations (app_account_id)
  WHERE app_account_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_device_installations_customer
  ON device_installations (shopify_customer_id)
  WHERE shopify_customer_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS push_endpoints (
  id UUID PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE REFERENCES device_installations(device_id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'fcm' CHECK (provider = 'fcm'),
  registration_kind TEXT NOT NULL DEFAULT 'token' CHECK (registration_kind IN ('token', 'fid')),
  registration_id_ciphertext TEXT NOT NULL,
  registration_id_hash TEXT NOT NULL UNIQUE,
  permission_state TEXT NOT NULL
    CHECK (permission_state IN ('not_determined', 'provisional', 'granted', 'denied')),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'stale', 'invalid', 'revoked')),
  token_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_success_at TIMESTAMPTZ,
  failure_count INTEGER NOT NULL DEFAULT 0 CHECK (failure_count >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_endpoints_active
  ON push_endpoints (status, token_updated_at DESC);

CREATE TABLE IF NOT EXISTS notification_consents (
  device_id TEXT NOT NULL REFERENCES device_installations(device_id) ON DELETE CASCADE,
  purpose TEXT NOT NULL
    CHECK (purpose IN ('product_alerts', 'personalized_offers', 'announcements')),
  granted BOOLEAN NOT NULL,
  policy_version TEXT NOT NULL,
  source TEXT NOT NULL
    CHECK (source IN ('settings', 'permission_prompt', 'product_alert')),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (device_id, purpose)
);

CREATE TABLE IF NOT EXISTS notification_preferences (
  device_id TEXT PRIMARY KEY REFERENCES device_installations(device_id) ON DELETE CASCADE,
  product_alerts BOOLEAN NOT NULL DEFAULT FALSE,
  personalized_offers BOOLEAN NOT NULL DEFAULT FALSE,
  announcements BOOLEAN NOT NULL DEFAULT FALSE,
  quiet_start SMALLINT NOT NULL DEFAULT 21 CHECK (quiet_start BETWEEN 0 AND 23),
  quiet_end SMALLINT NOT NULL DEFAULT 9 CHECK (quiet_end BETWEEN 0 AND 23),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS device_interest_profiles (
  device_id TEXT PRIMARY KEY REFERENCES device_installations(device_id) ON DELETE CASCADE,
  profile_version BIGINT NOT NULL,
  top_brands JSONB NOT NULL DEFAULT '[]'::jsonb,
  top_categories JSONB NOT NULL DEFAULT '[]'::jsonb,
  price_band TEXT,
  intent_tier TEXT NOT NULL CHECK (intent_tier IN ('low', 'medium', 'high')),
  signal_count_bucket TEXT NOT NULL CHECK (signal_count_bucket IN ('0_4', '5_9', '10_24', '25_plus')),
  generated_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interest_profiles_expiry
  ON device_interest_profiles (expires_at);

CREATE INDEX IF NOT EXISTS idx_interest_profiles_brands
  ON device_interest_profiles USING GIN (top_brands);

CREATE INDEX IF NOT EXISTS idx_interest_profiles_categories
  ON device_interest_profiles USING GIN (top_categories);

CREATE TABLE IF NOT EXISTS product_alerts (
  id UUID PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES device_installations(device_id) ON DELETE CASCADE,
  product_key TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('restock', 'price_drop')),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  last_triggered_cycle TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (device_id, product_key, kind)
);

CREATE INDEX IF NOT EXISTS idx_product_alerts_active
  ON product_alerts (product_key, kind)
  WHERE active = TRUE;

CREATE TABLE IF NOT EXISTS notification_campaigns (
  id UUID PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('manual', 'restock', 'price_drop', 'new_arrival', 'test')),
  purpose TEXT NOT NULL
    CHECK (purpose IN ('product_alerts', 'personalized_offers', 'announcements')),
  status TEXT NOT NULL
    CHECK (status IN ('draft', 'scheduled', 'targeting', 'sending', 'complete', 'cancelled')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  image_url TEXT,
  route JSONB NOT NULL,
  segment_definition JSONB NOT NULL,
  scheduled_at TIMESTAMPTZ,
  created_by TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notification_campaigns_due
  ON notification_campaigns (status, scheduled_at)
  WHERE status = 'scheduled';

CREATE TABLE IF NOT EXISTS notification_deliveries (
  id UUID PRIMARY KEY,
  campaign_id UUID NOT NULL REFERENCES notification_campaigns(id) ON DELETE CASCADE,
  push_endpoint_id UUID NOT NULL REFERENCES push_endpoints(id) ON DELETE CASCADE,
  eligibility_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL
    CHECK (status IN ('queued', 'sending', 'accepted', 'retry', 'failed', 'invalid_token', 'suppressed')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  provider_message_id TEXT,
  provider_error_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, push_endpoint_id)
);

CREATE INDEX IF NOT EXISTS idx_notification_deliveries_queue
  ON notification_deliveries (status, next_attempt_at)
  WHERE status IN ('queued', 'retry');

CREATE TABLE IF NOT EXISTS notification_interactions (
  delivery_id UUID NOT NULL REFERENCES notification_deliveries(id) ON DELETE CASCADE,
  event TEXT NOT NULL
    CHECK (event IN ('opened', 'product_viewed', 'add_to_cart', 'checkout_started', 'purchased')),
  occurred_at TIMESTAMPTZ NOT NULL,
  idempotency_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (delivery_id, event, idempotency_key)
);

CREATE TABLE IF NOT EXISTS automation_rules (
  key TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_by TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO automation_rules (key, enabled, configuration, updated_by)
VALUES
  ('restock', FALSE, '{"ttlHours": 12}'::jsonb, 'migration'),
  ('price_drop', FALSE, '{"minimumPercent": 10, "ttlHours": 24}'::jsonb, 'migration'),
  ('new_arrival', FALSE, '{"minimumScore": 60, "ttlHours": 24}'::jsonb, 'migration'),
  ('local_cart_reminder', FALSE, '{"delayHours": 20}'::jsonb, 'migration')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS catalog_events (
  event_id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  source TEXT NOT NULL,
  product_key TEXT NOT NULL,
  payload JSONB NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS admin_audit_events (
  id BIGSERIAL PRIMARY KEY,
  actor_id TEXT NOT NULL,
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_events_recent
  ON admin_audit_events (created_at DESC);

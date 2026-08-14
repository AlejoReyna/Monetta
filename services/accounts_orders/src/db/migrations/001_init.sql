-- Initial schema. No ORM: explicit SQL, run in order by src/db/migrate.ts,
-- tracked in schema_migrations so re-running `npm run migrate` is a no-op —
-- same convention as services/catalog_monitor.

CREATE TABLE IF NOT EXISTS customers_mirror (
  shopify_customer_id TEXT PRIMARY KEY,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders_mirror (
  id BIGSERIAL PRIMARY KEY,

  -- Null only for a WhatsApp apartado order the owner hasn't yet entered
  -- into Shopify by hand — every checkout-created order has one.
  shopify_order_id TEXT UNIQUE,

  -- ON DELETE SET NULL: customers_mirror.delete() (customers/redact) must
  -- never fail with a foreign-key violation just because the customer has
  -- orders — the order is a business record and survives redaction, only
  -- the PII link drops. This makes that true at the schema level rather
  -- than relying solely on handlers.ts calling detachCustomer() first.
  customer_id TEXT REFERENCES customers_mirror(shopify_customer_id) ON DELETE SET NULL,

  source TEXT NOT NULL
    CHECK (source IN ('shopify_checkout', 'whatsapp_apartado')),

  -- The MN-XXXX code from AttributionCodeGenerator
  -- (lib/data/shopify/cart_attribution.dart) — set only for apartado
  -- orders, where it is the only correlation key available until the owner
  -- manually creates the matching Shopify order.
  attribution_code TEXT,

  tags TEXT[] NOT NULL DEFAULT '{}',
  financial_status TEXT,
  fulfillment_status TEXT,
  total_amount NUMERIC(10, 2),
  currency_code TEXT,

  -- Cart attribution attributes (cart_attribution.dart#CartAttribution),
  -- carried through to the order for the same revenue-share auditability
  -- reason they were stamped on the cart in the first place.
  attribution_device_id TEXT,
  attribution_reco_source TEXT,

  placed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_mirror_customer
  ON orders_mirror (customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_mirror_attribution_code
  ON orders_mirror (attribution_code)
  WHERE attribution_code IS NOT NULL;

-- Idempotency ledger for every webhook delivery this service accepts —
-- including the three mandatory compliance topics (customers/data_request,
-- customers/redact, shop/redact). Keyed by Shopify's own per-delivery
-- `X-Shopify-Webhook-Id`, which stays constant across Shopify's retries of
-- the *same* delivery, so a retried webhook is a harmless duplicate insert
-- attempt rather than double-processing.
CREATE TABLE IF NOT EXISTS webhook_events (
  webhook_id TEXT PRIMARY KEY,
  topic TEXT NOT NULL,
  shopify_resource_id TEXT,
  payload_hash TEXT NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_topic
  ON webhook_events (topic, received_at DESC);

CREATE TABLE IF NOT EXISTS push_tokens (
  device_id TEXT PRIMARY KEY,
  customer_id TEXT REFERENCES customers_mirror(shopify_customer_id) ON DELETE SET NULL,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

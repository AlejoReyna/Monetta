-- Minimal transition state for Shopify product webhooks. This is not a
-- second catalog: it stores only fields needed to detect restock/price events.

CREATE TABLE IF NOT EXISTS shopify_product_notification_snapshots (
  product_key TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  brand TEXT,
  category TEXT,
  image_url TEXT,
  price NUMERIC(12, 2),
  available BOOLEAN NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Correlate a checkout attempt with the Shopify order it created.
-- checkout_token and cart_token come from the orders/create and
-- orders/updated REST webhook payloads. Nullable: a webhook that omits
-- them, and every row mirrored before this migration, stays null.
-- Tokens are bearer-like. Do not log them.
-- npm run backfill:payment-method does not fill these columns. Its
-- candidate set is pending orders missing a payment method, and its
-- stdout would have to print the tokens.

ALTER TABLE orders_mirror
  ADD COLUMN IF NOT EXISTS checkout_token TEXT,
  ADD COLUMN IF NOT EXISTS cart_token TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_mirror_checkout_token
  ON orders_mirror (checkout_token)
  WHERE checkout_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_orders_mirror_cart_token
  ON orders_mirror (cart_token)
  WHERE cart_token IS NOT NULL;

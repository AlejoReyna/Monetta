-- Payment method names for webhook-mirrored orders.
-- Same tokens the app stores from Customer Account `Order.transactions.type`
-- (`bank_deposit`, `manual`, `card`, `shopify_payments`, …).
-- Gateway and method names only: never card numbers, payment_details, or other PII.
-- Null means the webhook (or backfill) has not seen a method yet. The app
-- keeps those rows on "Pago en proceso".

ALTER TABLE orders_mirror
  ADD COLUMN IF NOT EXISTS payment_method TEXT;

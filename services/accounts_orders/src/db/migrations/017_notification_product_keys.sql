-- The app uses Shopify Product GIDs. Older webhooks and API callers used
-- shopify:<number>, which failed subscription matching and app deep links.
LOCK TABLE shopify_product_notification_snapshots, product_alerts,
  notification_campaigns, catalog_events IN SHARE ROW EXCLUSIVE MODE;

-- Preserve the newest stock/price baseline even if both formats exist.
INSERT INTO shopify_product_notification_snapshots
  (product_key, title, brand, category, image_url, price, available, updated_at)
SELECT regexp_replace(product_key, '^shopify:([0-9]+)$', 'shopify:gid://shopify/Product/\1'),
  title, brand, category, image_url, price, available, updated_at
FROM shopify_product_notification_snapshots
WHERE product_key ~ '^shopify:[0-9]+$'
ON CONFLICT (product_key) DO UPDATE SET
  title = EXCLUDED.title,
  brand = EXCLUDED.brand,
  category = EXCLUDED.category,
  image_url = EXCLUDED.image_url,
  price = EXCLUDED.price,
  available = EXCLUDED.available,
  updated_at = EXCLUDED.updated_at
WHERE EXCLUDED.updated_at > shopify_product_notification_snapshots.updated_at;

DELETE FROM shopify_product_notification_snapshots
WHERE product_key ~ '^shopify:[0-9]+$';

-- Avoid the per-device uniqueness conflict. Keep the most recent explicit
-- subscription state, including an opt-out, rather than reactivating it.
WITH ranked AS (
  SELECT id, row_number() OVER (
    PARTITION BY device_id, kind,
      regexp_replace(product_key, '^shopify:([0-9]+)$', 'shopify:gid://shopify/Product/\1')
    ORDER BY updated_at DESC, created_at DESC, product_key DESC, id DESC
  ) AS rank
  FROM product_alerts
  WHERE product_key ~ '^shopify:([0-9]+|gid://shopify/Product/[0-9]+)$'
)
DELETE FROM product_alerts USING ranked
WHERE product_alerts.id = ranked.id AND ranked.rank > 1;

UPDATE product_alerts
SET product_key = regexp_replace(product_key, '^shopify:([0-9]+)$', 'shopify:gid://shopify/Product/\1')
WHERE product_key ~ '^shopify:[0-9]+$';

-- Deliveries read their route from the campaign, so this also repairs queued
-- notifications and inbox entries without creating any new deliveries.
UPDATE notification_campaigns
SET route = jsonb_set(route, '{productKey}',
  to_jsonb(regexp_replace(route->>'productKey', '^shopify:([0-9]+)$', 'shopify:gid://shopify/Product/\1')))
WHERE route->>'type' = 'product' AND route->>'productKey' ~ '^shopify:[0-9]+$';

UPDATE notification_campaigns
SET segment_definition = jsonb_set(segment_definition, '{value}',
  to_jsonb(regexp_replace(segment_definition->>'value', '^shopify:([0-9]+)$', 'shopify:gid://shopify/Product/\1')))
WHERE segment_definition->>'kind' = 'product_alert'
  AND segment_definition->>'value' ~ '^shopify:[0-9]+$';

UPDATE catalog_events
SET product_key = regexp_replace(product_key, '^shopify:([0-9]+)$', 'shopify:gid://shopify/Product/\1')
WHERE product_key ~ '^shopify:[0-9]+$';

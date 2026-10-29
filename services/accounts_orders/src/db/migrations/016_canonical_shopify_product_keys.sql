-- Product keys have one canonical form, shopify:gid://shopify/Product/<id>,
-- which is what the app and the in-app admin send. Shopify product webhooks
-- built shopify:<id> from the numeric REST id, so restock campaigns never
-- matched stored alerts and product routes did not open the product.
-- New keys are canonicalized by src/engagement/domain/productKey.ts; this
-- rewrites the numeric keys already stored. Keys in any other form are left
-- unchanged.

CREATE FUNCTION pg_temp.canonical_product_key(key TEXT) RETURNS TEXT
  LANGUAGE sql IMMUTABLE
  AS $$ SELECT regexp_replace(key, '^shopify:([0-9]+)$', 'shopify:gid://shopify/Product/\1') $$;

-- A device can hold the same alert in both forms. Keep the row updated last.
DELETE FROM product_alerts stale
 USING product_alerts kept
 WHERE kept.device_id = stale.device_id
   AND kept.kind = stale.kind
   AND pg_temp.canonical_product_key(kept.product_key) = pg_temp.canonical_product_key(stale.product_key)
   AND (kept.updated_at, kept.id) > (stale.updated_at, stale.id);

UPDATE product_alerts
   SET product_key = pg_temp.canonical_product_key(product_key)
 WHERE product_key ~ '^shopify:[0-9]+$';

-- Snapshots are keyed by product. Keep the most recent state per product so
-- the next webhook compares against it instead of looking new.
DELETE FROM shopify_product_notification_snapshots stale
 USING shopify_product_notification_snapshots kept
 WHERE pg_temp.canonical_product_key(kept.product_key) = pg_temp.canonical_product_key(stale.product_key)
   AND (kept.updated_at, kept.product_key) > (stale.updated_at, stale.product_key);

UPDATE shopify_product_notification_snapshots
   SET product_key = pg_temp.canonical_product_key(product_key)
 WHERE product_key ~ '^shopify:[0-9]+$';

UPDATE catalog_events
   SET product_key = pg_temp.canonical_product_key(product_key)
 WHERE product_key ~ '^shopify:[0-9]+$';

UPDATE notification_campaigns
   SET route = jsonb_set(route, '{productKey}', to_jsonb(pg_temp.canonical_product_key(route->>'productKey')))
 WHERE route->>'type' = 'product'
   AND route->>'productKey' ~ '^shopify:[0-9]+$';

UPDATE notification_campaigns
   SET segment_definition = jsonb_set(
         segment_definition,
         '{value}',
         to_jsonb(pg_temp.canonical_product_key(segment_definition->>'value'))
       )
 WHERE segment_definition->>'kind' = 'product_alert'
   AND segment_definition->>'value' ~ '^shopify:[0-9]+$';

DROP FUNCTION pg_temp.canonical_product_key(TEXT);

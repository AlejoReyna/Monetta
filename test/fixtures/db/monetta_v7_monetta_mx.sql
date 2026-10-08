-- Fixture for CHAR-03: a monetta.mx installation at schema version 7, already
-- synchronised, with shopper state in every shop-scoped table.
--
-- The CREATE TABLE statements below are the exact `sql` column of
-- `sqlite_master` for a database freshly created by `AppDatabase` at
-- `schemaVersion` 7, in creation order. The test
-- `CHAR-03 ... el fixture es v7` compares them with the schema the current
-- code creates.
--
-- When the schema moves past version 7 (RF-60), this fixture stays frozen and
-- the CHAR-03 test that opens it becomes the v7 -> v8 migration test; that
-- change must be recorded explicitly.
--
-- All values are fictitious: no real emails, tokens or secrets. Timestamps are
-- Unix seconds, which is how Drift stores DateTime without a build.yaml
-- override.

CREATE TABLE "cached_products" ("id" TEXT NOT NULL, "handle" TEXT NOT NULL, "title" TEXT NOT NULL, "vendor" TEXT NOT NULL, "product_type" TEXT NOT NULL, "tags" TEXT NOT NULL DEFAULT '[]', "images" TEXT NOT NULL DEFAULT '[]', "description_html" TEXT NOT NULL DEFAULT '', "collection_handles" TEXT NOT NULL DEFAULT '[]', "brand_override" TEXT NULL, "category_override" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "cached_variants" ("id" TEXT NOT NULL, "product_id" TEXT NOT NULL REFERENCES cached_products (id) ON DELETE CASCADE, "title" TEXT NOT NULL, "price" REAL NOT NULL, "compare_at_price" REAL NULL, "available" INTEGER NOT NULL CHECK ("available" IN (0, 1)), "sku" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "cached_collections" ("id" TEXT NOT NULL, "handle" TEXT NOT NULL, "title" TEXT NOT NULL, "description" TEXT NOT NULL DEFAULT '', "image_url" TEXT NULL, "product_count" INTEGER NULL, PRIMARY KEY ("id"));
CREATE TABLE "sync_cursors" ("id" INTEGER NOT NULL DEFAULT 0, "last_updated_at" INTEGER NULL, "last_full_sync_at" INTEGER NULL, "shop_domain" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "catalog_states" ("id" INTEGER NOT NULL DEFAULT 0, "source" TEXT NOT NULL, "synced_at" INTEGER NULL, "product_count" INTEGER NOT NULL, "fingerprint" TEXT NOT NULL, "status" TEXT NOT NULL, "detail" TEXT NULL, "shop_domain" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "app_preferences" ("id" INTEGER NOT NULL DEFAULT 0, "theme_mode" TEXT NOT NULL DEFAULT 'system', "onboarding_state" TEXT NOT NULL DEFAULT 'pending', PRIMARY KEY ("id"));
CREATE TABLE "wishlist_items" ("product_id" TEXT NOT NULL, "account_id" TEXT NOT NULL DEFAULT '', "added_at" INTEGER NOT NULL, PRIMARY KEY ("product_id", "account_id"));
CREATE TABLE "bag_lines" ("product_id" TEXT NOT NULL, "variant_id" TEXT NOT NULL, "account_id" TEXT NOT NULL DEFAULT '', "quantity" INTEGER NOT NULL, PRIMARY KEY ("variant_id", "account_id"));
CREATE TABLE "interaction_events" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "type" TEXT NOT NULL, "timestamp" INTEGER NOT NULL, "product_id" TEXT NULL, "dwell_ms" INTEGER NULL, "facet_hint" TEXT NULL);
CREATE TABLE "devices" ("device_id" TEXT NOT NULL, "account_id" TEXT NULL, "platform" TEXT NOT NULL, "app_version" TEXT NOT NULL, "push_token" TEXT NULL, "installed_at" INTEGER NOT NULL, "last_seen_at" INTEGER NOT NULL, PRIMARY KEY ("device_id"));
CREATE TABLE "accounts" ("local_account_id" TEXT NOT NULL, "shopify_customer_id" TEXT NULL UNIQUE, "email" TEXT NULL, "display_name" TEXT NULL, "auth_provider" TEXT NULL, "created_at" INTEGER NOT NULL, "last_seen_at" INTEGER NOT NULL, PRIMARY KEY ("local_account_id"));
CREATE TABLE "sessions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "account_id" TEXT NOT NULL REFERENCES accounts (local_account_id) ON DELETE CASCADE, "secure_storage_key_ref" TEXT NOT NULL, "access_token_expires_at" INTEGER NOT NULL, "created_at" INTEGER NOT NULL);
CREATE TABLE "order_summaries" ("id" TEXT NOT NULL, "account_id" TEXT NOT NULL REFERENCES accounts (local_account_id) ON DELETE CASCADE, "display_number" TEXT NULL, "fulfillment_status" TEXT NULL, "shopify_order_id" TEXT NULL, "source" TEXT NOT NULL, "attribution_code" TEXT NULL, "status" TEXT NOT NULL, "total_amount" REAL NOT NULL, "currency_code" TEXT NOT NULL, "placed_at" INTEGER NOT NULL, PRIMARY KEY ("id", "account_id"));
CREATE TABLE "checkout_receipts" ("operation_id" TEXT NOT NULL, "shop_domain" TEXT NOT NULL, "account_id" TEXT NOT NULL, PRIMARY KEY ("operation_id"));

PRAGMA user_version = 7;

-- Catalog: two products (one with collection handles), three variants, one
-- collection.
INSERT INTO cached_products (id, handle, title, vendor, product_type, tags, images, description_html, collection_handles, brand_override, category_override, created_at, updated_at) VALUES
  ('gid://shopify/Product/9001', 'bolso-fixture-uno', 'Bolso fixture uno', 'Monetta', 'Bolsa', '["Coach","Crossbody"]', '["https://cdn.example/fixture-1.jpg"]', '<p>Producto ficticio uno</p>', '["rebajas"]', NULL, NULL, 1782864000, 1785542400),
  ('gid://shopify/Product/9002', 'bolso-fixture-dos', 'Bolso fixture dos', 'Monetta', 'Bolsa', '["Guess"]', '["https://cdn.example/fixture-2.jpg"]', '', '[]', NULL, NULL, 1782864000, 1785542400);

INSERT INTO cached_variants (id, product_id, title, price, compare_at_price, available, sku) VALUES
  ('gid://shopify/ProductVariant/9101', 'gid://shopify/Product/9001', 'Negro', 1500.0, NULL, 1, 'FIX-9101'),
  ('gid://shopify/ProductVariant/9102', 'gid://shopify/Product/9001', 'Cafe', 1600.0, 1900.0, 0, NULL),
  ('gid://shopify/ProductVariant/9201', 'gid://shopify/Product/9002', 'Default Title', 2400.0, NULL, 1, NULL);

INSERT INTO cached_collections (id, handle, title, description, image_url, product_count) VALUES
  ('gid://shopify/Collection/7001', 'rebajas', 'Rebajas', '', NULL, 1);

-- Shop provenance: everything says monetta.mx.
INSERT INTO sync_cursors (id, last_updated_at, last_full_sync_at, shop_domain) VALUES
  (0, 1785542400, 1786363200, 'monetta.mx');

INSERT INTO catalog_states (id, source, synced_at, product_count, fingerprint, status, detail, shop_domain) VALUES
  (0, 'shopify', 1786363200, 2, 'fixture0', 'healthy', NULL, 'monetta.mx');

-- Device-scoped preferences with non-default values.
INSERT INTO app_preferences (id, theme_mode, onboarding_state) VALUES
  (0, 'dark', 'completed');

-- One Shopify account with a session that only references secure storage.
INSERT INTO accounts (local_account_id, shopify_customer_id, email, display_name, auth_provider, created_at, last_seen_at) VALUES
  ('acct-fixture-1', 'gid://shopify/Customer/5001', 'ana@example.com', 'Ana Ejemplo', 'shopify', 1786449600, 1788264000);

INSERT INTO sessions (id, account_id, secure_storage_key_ref, access_token_expires_at, created_at) VALUES
  (1, 'acct-fixture-1', 'customer_auth/refresh_token/acct-fixture-1', 1788264000, 1786449600);

INSERT INTO devices (device_id, account_id, platform, app_version, push_token, installed_at, last_seen_at) VALUES
  ('device-fixture-1', 'acct-fixture-1', 'android', '1.0.0+1', NULL, 1786449600, 1788264000);

INSERT INTO order_summaries (id, account_id, display_number, fulfillment_status, shopify_order_id, source, attribution_code, status, total_amount, currency_code, placed_at) VALUES
  ('gid://shopify/Order/8001', 'acct-fixture-1', '#1001', 'UNFULFILLED', 'gid://shopify/Order/8001', 'shopifyCheckout', NULL, 'paid', 1500.0, 'MXN', 1786536000);

INSERT INTO checkout_receipts (operation_id, shop_domain, account_id) VALUES
  ('op-fixture-1', 'monetta.mx', 'acct-fixture-1');

-- Bag and wishlist: guest scope is the empty string.
INSERT INTO bag_lines (product_id, variant_id, account_id, quantity) VALUES
  ('gid://shopify/Product/9001', 'gid://shopify/ProductVariant/9101', '', 2),
  ('gid://shopify/Product/9001', 'gid://shopify/ProductVariant/9101', 'acct-fixture-1', 1),
  ('gid://shopify/Product/9002', 'gid://shopify/ProductVariant/9201', 'acct-fixture-1', 3);

INSERT INTO wishlist_items (product_id, account_id, added_at) VALUES
  ('gid://shopify/Product/9001', '', 1786788000),
  ('gid://shopify/Product/9002', 'acct-fixture-1', 1786874400);

INSERT INTO interaction_events (id, type, timestamp, product_id, dwell_ms, facet_hint) VALUES
  (1, 'productView', 1787218200, 'gid://shopify/Product/9001', 1200, NULL),
  (2, 'addToCart', 1787218260, 'gid://shopify/Product/9001', NULL, NULL);

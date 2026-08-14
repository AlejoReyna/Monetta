-- Color-level tracking for Coach and Michael Kors (and compatible future
-- sources). JSONB keeps the parent product row stable while each crawl can
-- atomically replace the merchant's current variant set.

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS variants JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE products
  DROP CONSTRAINT IF EXISTS products_variants_is_array;

ALTER TABLE products
  ADD CONSTRAINT products_variants_is_array
  CHECK (jsonb_typeof(variants) = 'array');

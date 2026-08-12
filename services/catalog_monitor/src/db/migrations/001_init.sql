-- Initial schema for the catalog monitor prototype.
--
-- No ORM: explicit SQL, run in order by src/db/migrate.ts, tracked in
-- schema_migrations so re-running `npm run migrate` is a no-op.

CREATE TABLE IF NOT EXISTS schema_migrations (
  filename TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sources (
  id TEXT PRIMARY KEY,
  merchant TEXT NOT NULL,
  brand TEXT NOT NULL,
  base_url TEXT NOT NULL
);

INSERT INTO sources (id, merchant, brand, base_url) VALUES
  ('coach_us', 'Coach', 'Coach', 'https://www.coach.com'),
  ('michael_kors_us', 'Michael Kors', 'Michael Kors', 'https://www.michaelkors.com')
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS products (
  source_id TEXT NOT NULL REFERENCES sources(id),
  external_id TEXT NOT NULL,
  canonical_url TEXT NOT NULL,
  title TEXT NOT NULL,
  brand TEXT NOT NULL,
  category TEXT,
  image_url TEXT,
  price_usd NUMERIC(10, 2),
  availability TEXT NOT NULL DEFAULT 'unknown'
    CHECK (availability IN ('inStock', 'outOfStock', 'unknown')),
  fingerprint TEXT NOT NULL,
  first_seen_at TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL,
  last_changed_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  consecutive_missing_snapshots INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (source_id, external_id)
);

CREATE INDEX IF NOT EXISTS idx_products_active
  ON products (source_id, is_active);

CREATE TABLE IF NOT EXISTS crawl_runs (
  id BIGSERIAL PRIMARY KEY,
  source_id TEXT NOT NULL REFERENCES sources(id),
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'running'
    CHECK (status IN ('running', 'success', 'partial', 'failed', 'blocked')),
  is_full_snapshot BOOLEAN NOT NULL DEFAULT TRUE,
  urls_discovered INTEGER NOT NULL DEFAULT 0,
  pages_fetched INTEGER NOT NULL DEFAULT 0,
  successful_parses INTEGER NOT NULL DEFAULT 0,
  new_items INTEGER NOT NULL DEFAULT 0,
  changed_items INTEGER NOT NULL DEFAULT 0,
  missing_items INTEGER NOT NULL DEFAULT 0,
  inactive_items INTEGER NOT NULL DEFAULT 0,
  errors_by_type JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_crawl_runs_source_started
  ON crawl_runs (source_id, started_at DESC);

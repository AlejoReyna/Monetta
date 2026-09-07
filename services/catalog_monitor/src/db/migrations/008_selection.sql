CREATE TABLE IF NOT EXISTS selection_versions (
  version    BIGSERIAL PRIMARY KEY,
  document   JSONB       NOT NULL,
  hash       TEXT        NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  applied_by TEXT        NOT NULL,
  note       TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_selection_versions_hash
  ON selection_versions (hash);

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS selection_state TEXT NOT NULL DEFAULT 'selected'
    CHECK (selection_state IN ('selected', 'deselected')),
  ADD COLUMN IF NOT EXISTS selection_version BIGINT,
  ADD COLUMN IF NOT EXISTS watch_tier TEXT NOT NULL DEFAULT 'standard'
    CHECK (watch_tier IN ('pinned', 'standard')),
  ADD COLUMN IF NOT EXISTS placements JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS matched_rule_id TEXT;

ALTER TABLE products
  ADD CONSTRAINT products_placements_is_array
  CHECK (jsonb_typeof(placements) = 'array');

CREATE INDEX IF NOT EXISTS idx_products_serveable
  ON products (source_id, selection_state, is_active);

CREATE INDEX IF NOT EXISTS idx_products_watch
  ON products (source_id, watch_tier, last_seen_at)
  WHERE selection_state = 'selected' AND is_active;

ALTER TABLE crawl_runs
  ADD COLUMN IF NOT EXISTS run_kind TEXT NOT NULL DEFAULT 'discovery'
    CHECK (run_kind IN ('discovery', 'watch')),
  ADD COLUMN IF NOT EXISTS selection_version BIGINT,
  ADD COLUMN IF NOT EXISTS urls_selected INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS deselected_items INTEGER NOT NULL DEFAULT 0;

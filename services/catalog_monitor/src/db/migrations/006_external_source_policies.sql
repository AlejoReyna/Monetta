CREATE TABLE IF NOT EXISTS external_source_policies (
  source_id TEXT PRIMARY KEY REFERENCES sources(id),
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  item_limit INTEGER NOT NULL DEFAULT 8 CHECK (item_limit BETWEEN 0 AND 50),
  base_commission_bps INTEGER NOT NULL DEFAULT 2200 CHECK (base_commission_bps BETWEEN 0 AND 10000),
  high_value_commission_bps INTEGER NOT NULL DEFAULT 1400 CHECK (high_value_commission_bps BETWEEN 0 AND 10000),
  high_value_threshold_mxn NUMERIC(12, 2) NOT NULL DEFAULT 4000 CHECK (high_value_threshold_mxn > 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO external_source_policies (source_id, item_limit)
SELECT id, CASE WHEN id = 'gp_mcallen_perfumes' THEN 12 ELSE 8 END
  FROM sources
ON CONFLICT (source_id) DO NOTHING;

-- Paquete F: Monetta Rewards monetario (V1).
-- Autoridad: PostgreSQL para saldos; Shopify para pedidos/pagos/descuentos;
-- eventos logisticos verificables para entregas. Importes en centavos enteros.
-- Estados de negocio: pending, available, used, expired, reversed.
-- Canjes: quoted, reserved, provisioning, applied, order_committed, settled,
-- releasing, released, reconciliation_required (columna state en redemptions).
-- Aditiva y compatible: no toca tablas existentes.

-- 1. Version de programa/reglas (las ediciones crean filas nuevas, nunca UPDATE).
CREATE TABLE IF NOT EXISTS rewards_program_versions (
  version INTEGER PRIMARY KEY,
  currency TEXT NOT NULL DEFAULT 'MXN',
  earn_bps INTEGER NOT NULL DEFAULT 300 CHECK (earn_bps >= 0),
  max_redeem_bps INTEGER NOT NULL DEFAULT 2000 CHECK (max_redeem_bps >= 0 AND max_redeem_bps <= 10000),
  expiry_months INTEGER NOT NULL DEFAULT 12 CHECK (expiry_months > 0),
  wholesale_earns BOOLEAN NOT NULL DEFAULT FALSE,
  -- NULL = decision comercial pendiente (uso de Rewards en mayoreo sin definir).
  wholesale_redeem_allowed BOOLEAN,
  first_purchase_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  first_purchase_amount_cents INTEGER NOT NULL DEFAULT 5000,
  first_purchase_min_cents INTEGER,
  review_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  review_amount_cents INTEGER NOT NULL DEFAULT 2000,
  referral_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  referral_amount_cents INTEGER NOT NULL DEFAULT 5000,
  referral_min_cents INTEGER,
  redemption_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO rewards_program_versions
  (version, currency, earn_bps, max_redeem_bps, expiry_months,
   wholesale_earns, wholesale_redeem_allowed,
   first_purchase_enabled, review_enabled, referral_enabled,
   redemption_enabled, notes)
VALUES
  (1, 'MXN', 300, 2000, 12,
   FALSE, NULL,
   FALSE, FALSE, FALSE,
   FALSE, 'V1 inicial: canje deshabilitado hasta probar adaptador en plan real; bonos con minimo/reglas pendientes deshabilitados.')
ON CONFLICT (version) DO NOTHING;

-- 2. Cuenta canonica: identidad tienda+cliente+moneda. Nunca email.
CREATE TABLE IF NOT EXISTS rewards_accounts (
  shopify_customer_id TEXT PRIMARY KEY,
  shop_domain TEXT,
  currency TEXT NOT NULL DEFAULT 'MXN',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'closed')),
  version INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Lotes de credito (ganancias por origen, con liberacion y vencimiento).
CREATE TABLE IF NOT EXISTS rewards_credit_lots (
  id BIGSERIAL PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES rewards_accounts (shopify_customer_id),
  source_kind TEXT NOT NULL CHECK (source_kind IN ('order_earn', 'first_purchase', 'review', 'referral', 'adjustment')),
  source_ref TEXT NOT NULL,
  rule_version INTEGER NOT NULL DEFAULT 1,
  amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0),
  remaining_cents INTEGER NOT NULL CHECK (remaining_cents >= 0),
  reserved_cents INTEGER NOT NULL DEFAULT 0 CHECK (reserved_cents >= 0),
  state TEXT NOT NULL DEFAULT 'pending'
    CHECK (state IN ('pending', 'available', 'used', 'expired', 'reversed')),
  earned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  released_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT lots_remaining_lte_amount CHECK (remaining_cents <= amount_cents),
  CONSTRAINT lots_reserved_lte_remaining CHECK (reserved_cents <= remaining_cents)
);

-- Una misma compra/bono/regla no concede dos veces aunque llegue por varios webhooks.
CREATE UNIQUE INDEX IF NOT EXISTS uq_rewards_lots_source
  ON rewards_credit_lots (account_id, source_kind, source_ref, rule_version);
CREATE INDEX IF NOT EXISTS idx_rewards_lots_account_state
  ON rewards_credit_lots (account_id, state, expires_at);
CREATE INDEX IF NOT EXISTS idx_rewards_lots_expiry
  ON rewards_credit_lots (expires_at) WHERE state = 'available';

-- 4. Libro mayor inmutable (asientos compensatorios, nunca UPDATE de importes).
CREATE TABLE IF NOT EXISTS rewards_ledger_entries (
  id BIGSERIAL PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES rewards_accounts (shopify_customer_id),
  entry_type TEXT NOT NULL CHECK (entry_type IN (
    'earn_pending', 'earn_released', 'earn_reversed',
    'redeem_reserved', 'redeem_settled', 'redeem_released',
    'expired', 'adjustment', 'bonus_pending', 'bonus_released', 'bonus_reversed'
  )),
  state TEXT NOT NULL CHECK (state IN ('pending', 'available', 'used', 'expired', 'reversed')),
  amount_cents INTEGER NOT NULL,
  lot_id BIGINT REFERENCES rewards_credit_lots (id),
  redemption_id UUID,
  order_shopify_id TEXT,
  bonus_kind TEXT CHECK (bonus_kind IS NULL OR bonus_kind IN ('first_purchase', 'review', 'referral')),
  rule_version INTEGER NOT NULL DEFAULT 1,
  -- Clave idempotente por cuenta para operaciones iniciadas por cliente/API.
  idempotency_key TEXT,
  -- Referencia del evento causante (webhookId + topico) para operaciones por webhook.
  event_ref TEXT,
  reversed_entry_id BIGINT REFERENCES rewards_ledger_entries (id),
  actor TEXT NOT NULL DEFAULT 'system',
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_rewards_ledger_idempotency
  ON rewards_ledger_entries (account_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_rewards_ledger_event
  ON rewards_ledger_entries (account_id, entry_type, order_shopify_id, event_ref)
  WHERE event_ref IS NOT NULL AND order_shopify_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_rewards_ledger_account
  ON rewards_ledger_entries (account_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rewards_ledger_order
  ON rewards_ledger_entries (order_shopify_id) WHERE order_shopify_id IS NOT NULL;

-- 5. Canjes: reserva, instrumento Shopify, pedido final y consumo por lote.
CREATE TABLE IF NOT EXISTS rewards_redemptions (
  id UUID PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES rewards_accounts (shopify_customer_id),
  quote_id UUID NOT NULL,
  cart_revision TEXT NOT NULL,
  subtotal_eligible_cents INTEGER NOT NULL CHECK (subtotal_eligible_cents >= 0),
  requested_cents INTEGER NOT NULL CHECK (requested_cents >= 0),
  max_allowed_cents INTEGER NOT NULL CHECK (max_allowed_cents >= 0),
  provisioned_cents INTEGER NOT NULL DEFAULT 0 CHECK (provisioned_cents >= 0),
  settled_cents INTEGER NOT NULL DEFAULT 0 CHECK (settled_cents >= 0),
  state TEXT NOT NULL DEFAULT 'reserved' CHECK (state IN (
    'quoted', 'reserved', 'provisioning', 'applied', 'order_committed',
    'settled', 'releasing', 'released', 'reconciliation_required'
  )),
  shopify_discount_id TEXT,
  shopify_discount_code TEXT,
  order_shopify_id TEXT,
  idempotency_key TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT redemption_requested_lte_max CHECK (requested_cents <= max_allowed_cents)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_rewards_redemptions_idempotency
  ON rewards_redemptions (account_id, idempotency_key);
CREATE INDEX IF NOT EXISTS idx_rewards_redemptions_state
  ON rewards_redemptions (state, expires_at);
CREATE INDEX IF NOT EXISTS idx_rewards_redemptions_order
  ON rewards_redemptions (order_shopify_id) WHERE order_shopify_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS rewards_lot_allocations (
  redemption_id UUID NOT NULL REFERENCES rewards_redemptions (id) ON DELETE CASCADE,
  lot_id BIGINT NOT NULL REFERENCES rewards_credit_lots (id),
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
  state TEXT NOT NULL DEFAULT 'reserved'
    CHECK (state IN ('reserved', 'settled', 'released')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (redemption_id, lot_id)
);

CREATE INDEX IF NOT EXISTS idx_rewards_allocations_lot
  ON rewards_lot_allocations (lot_id, state);

-- Cotizaciones efimeras (auditoria de lo ofrecido; TTL 10 min).
CREATE TABLE IF NOT EXISTS rewards_quotes (
  id UUID PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES rewards_accounts (shopify_customer_id),
  cart_revision TEXT NOT NULL,
  subtotal_eligible_cents INTEGER NOT NULL CHECK (subtotal_eligible_cents >= 0),
  available_cents INTEGER NOT NULL CHECK (available_cents >= 0),
  max_allowed_cents INTEGER NOT NULL CHECK (max_allowed_cents >= 0),
  estimated_earn_cents INTEGER NOT NULL DEFAULT 0,
  rule_version INTEGER NOT NULL DEFAULT 1,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rewards_quotes_account
  ON rewards_quotes (account_id, created_at DESC);

-- 6. Snapshot por pedido y lineas elegibles (base de calculo auditable).
CREATE TABLE IF NOT EXISTS rewards_order_snapshots (
  shopify_order_id TEXT PRIMARY KEY,
  account_id TEXT REFERENCES rewards_accounts (shopify_customer_id),
  is_wholesale BOOLEAN NOT NULL DEFAULT FALSE,
  wholesale_signals TEXT[] NOT NULL DEFAULT '{}',
  currency TEXT NOT NULL DEFAULT 'MXN',
  subtotal_eligible_cents INTEGER NOT NULL DEFAULT 0,
  discount_cents INTEGER NOT NULL DEFAULT 0,
  shipping_cents INTEGER NOT NULL DEFAULT 0,
  rewards_used_cents INTEGER NOT NULL DEFAULT 0,
  earned_pending_cents INTEGER NOT NULL DEFAULT 0,
  earned_released_cents INTEGER NOT NULL DEFAULT 0,
  earned_reversed_cents INTEGER NOT NULL DEFAULT 0,
  refunded_eligible_cents INTEGER NOT NULL DEFAULT 0,
  rule_version INTEGER NOT NULL DEFAULT 1,
  lines JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Eventos normalizados de entrega/devolucion por linea (evidencia verificable).
CREATE TABLE IF NOT EXISTS rewards_fulfillment_events (
  id BIGSERIAL PRIMARY KEY,
  shopify_order_id TEXT NOT NULL REFERENCES rewards_order_snapshots (shopify_order_id),
  kind TEXT NOT NULL CHECK (kind IN ('paid', 'delivered', 'cancelled', 'refund', 'return_closed', 'fulfilled_unverified')),
  lines JSONB NOT NULL DEFAULT '[]',
  quantity_total INTEGER NOT NULL DEFAULT 0,
  amount_cents INTEGER NOT NULL DEFAULT 0,
  event_ref TEXT NOT NULL,
  occurred_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (shopify_order_id, kind, event_ref)
);

CREATE INDEX IF NOT EXISTS idx_rewards_fulfillment_order
  ON rewards_fulfillment_events (shopify_order_id, kind);

-- 7. Bonos y referidos (tablas listas; emision deshabilitada por programa v1).
CREATE TABLE IF NOT EXISTS rewards_bonus_claims (
  id BIGSERIAL PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES rewards_accounts (shopify_customer_id),
  kind TEXT NOT NULL CHECK (kind IN ('first_purchase', 'review', 'referral')),
  state TEXT NOT NULL DEFAULT 'pending'
    CHECK (state IN ('pending', 'available', 'used', 'expired', 'reversed', 'disabled')),
  amount_cents INTEGER NOT NULL DEFAULT 0,
  order_shopify_id TEXT,
  event_ref TEXT,
  idempotency_key TEXT NOT NULL,
  rule_version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (account_id, kind, idempotency_key)
);

CREATE TABLE IF NOT EXISTS rewards_referrals (
  code TEXT PRIMARY KEY,
  inviter_account_id TEXT NOT NULL REFERENCES rewards_accounts (shopify_customer_id),
  guest_account_id TEXT REFERENCES rewards_accounts (shopify_customer_id),
  state TEXT NOT NULL DEFAULT 'open'
    CHECK (state IN ('open', 'attributed', 'qualified', 'rewarded', 'expired', 'rejected')),
  qualifying_order_id TEXT,
  attributed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  qualified_at TIMESTAMPTZ
);

-- 8. Inbox/outbox recuperables propios de Rewards.
CREATE TABLE IF NOT EXISTS rewards_inbox (
  event_id TEXT PRIMARY KEY,
  topic TEXT NOT NULL,
  shopify_order_id TEXT,
  account_id TEXT,
  payload JSONB NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0,
  next_retry_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_error TEXT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rewards_inbox_status
  ON rewards_inbox (status, next_retry_at);

CREATE TABLE IF NOT EXISTS rewards_outbox (
  id BIGSERIAL PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN (
    'discount_provision', 'discount_invalidate',
    'notify_release', 'notify_expiry', 'notify_adjustment', 'notify_bonus'
  )),
  account_id TEXT,
  payload JSONB NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0,
  next_retry_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rewards_outbox_status
  ON rewards_outbox (status, next_retry_at);

-- 9. Auditoria operativa (ajustes con motivo; sin edicion directa de saldos).
CREATE TABLE IF NOT EXISTS rewards_admin_audit (
  id BIGSERIAL PRIMARY KEY,
  operator TEXT NOT NULL,
  action TEXT NOT NULL,
  account_id TEXT,
  amount_cents INTEGER,
  reason TEXT NOT NULL,
  correlation TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rewards_admin_audit_account
  ON rewards_admin_audit (account_id, created_at DESC);

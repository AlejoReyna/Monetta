import { randomUUID } from 'node:crypto';
import type pg from 'pg';
import { expiryFromRelease } from './rules.js';
import type {
  BalanceView, MovementView, OrderRewardsView,
  QuoteRecord, RedemptionRecord, RewardsRepository,
} from './repository.js';
import type { LedgerEntryType, OrderLineSnapshot, ProgramPolicy, RewardsLotState } from './types.js';
import { DEFAULT_PROGRAM } from './types.js';

/** Autoridad PostgreSQL del saldo. Todas las mutaciones economicas son transaccionales. */
export class PgRewardsRepository implements RewardsRepository {
  constructor(private readonly pool: pg.Pool) {}

  async ensureAccount(customerId: string, shopDomain?: string | null): Promise<void> {
    await this.pool.query(
      `INSERT INTO rewards_accounts (shopify_customer_id, shop_domain)
       VALUES ($1, $2) ON CONFLICT (shopify_customer_id) DO NOTHING`,
      [customerId, shopDomain ?? null],
    );
  }

  async getPolicy(): Promise<ProgramPolicy> {
    const res = await this.pool.query(
      'SELECT * FROM rewards_program_versions ORDER BY version DESC LIMIT 1',
    );
    const row = res.rows[0];
    if (!row) return DEFAULT_PROGRAM;
    return {
      version: row.version as number,
      currency: 'MXN',
      earnBps: row.earn_bps as number,
      maxRedeemBps: row.max_redeem_bps as number,
      expiryMonths: row.expiry_months as number,
      wholesaleEarns: row.wholesale_earns as boolean,
      wholesaleRedeemAllowed: row.wholesale_redeem_allowed as boolean | null,
      redemptionEnabled: row.redemption_enabled as boolean,
      firstPurchaseEnabled: row.first_purchase_enabled as boolean,
      firstPurchaseAmountCents: row.first_purchase_amount_cents as number,
      reviewEnabled: row.review_enabled as boolean,
      reviewAmountCents: row.review_amount_cents as number,
      referralEnabled: row.referral_enabled as boolean,
      referralAmountCents: row.referral_amount_cents as number,
    };
  }

  async balance(accountId: string, now: Date = new Date()): Promise<BalanceView> {
    const [avail, pend, resv, next] = await Promise.all([
      this.pool.query(
        `SELECT COALESCE(SUM(remaining_cents - reserved_cents), 0)::bigint AS c
         FROM rewards_credit_lots WHERE account_id = $1 AND state = 'available'`,
        [accountId],
      ),
      this.pool.query(
        `SELECT COALESCE(SUM(remaining_cents), 0)::bigint AS c
         FROM rewards_credit_lots WHERE account_id = $1 AND state = 'pending'`,
        [accountId],
      ),
      this.pool.query(
        `SELECT COALESCE(SUM(reserved_cents), 0)::bigint AS c
         FROM rewards_credit_lots WHERE account_id = $1 AND state = 'available'`,
        [accountId],
      ),
      this.pool.query(
        `SELECT remaining_cents - reserved_cents AS c, expires_at
         FROM rewards_credit_lots
         WHERE account_id = $1 AND state = 'available' AND expires_at IS NOT NULL
           AND expires_at > $2
         ORDER BY expires_at ASC LIMIT 1`,
        [accountId, now],
      ),
    ]);
    const row = next.rows[0];
    return {
      availableCents: Number(avail.rows[0].c),
      pendingCents: Number(pend.rows[0].c),
      reservedCents: Number(resv.rows[0].c),
      nextExpiry: row ? { cents: Number(row.c), at: new Date(row.expires_at) } : null,
    };
  }

  async activity(accountId: string, limit: number, cursor?: string | null): Promise<{ movements: MovementView[]; nextCursor: string | null }> {
    const n = Math.min(Math.max(limit, 1), 100);
    const afterId = cursor ? Number.parseInt(cursor, 10) : null;
    const res = await this.pool.query(
      `SELECT e.id, e.entry_type, e.state, e.amount_cents, e.order_shopify_id, e.reason, e.created_at,
              l.released_at, l.expires_at
       FROM rewards_ledger_entries e LEFT JOIN rewards_credit_lots l ON l.id = e.lot_id
       WHERE e.account_id = $1 AND ($2::bigint IS NULL OR e.id < $2::bigint)
       ORDER BY e.id DESC LIMIT $3`,
      [accountId, Number.isFinite(afterId) ? afterId : null, n + 1],
    );
    const rows = res.rows.slice(0, n);
    const movements: MovementView[] = rows.map((r) => ({
      id: Number(r.id),
      type: r.entry_type as LedgerEntryType,
      state: r.state as RewardsLotState,
      amountCents: Number(r.amount_cents),
      orderShopifyId: r.order_shopify_id as string | null,
      reason: r.reason as string | null,
      createdAt: new Date(r.created_at),
      releasedAt: r.released_at ? new Date(r.released_at) : null,
      expiresAt: r.expires_at ? new Date(r.expires_at) : null,
    }));
    const nextCursor = res.rows.length > n ? String(rows[rows.length - 1]!.id) : null;
    return { movements, nextCursor };
  }

  async orderRewards(accountId: string, orderShopifyId: string): Promise<OrderRewardsView | null> {
    const res = await this.pool.query(
      `SELECT shopify_order_id, is_wholesale, earned_pending_cents, earned_released_cents,
              earned_reversed_cents, rewards_used_cents, account_id
       FROM rewards_order_snapshots WHERE shopify_order_id = $1`,
      [orderShopifyId],
    );
    const row = res.rows[0];
    if (!row) return null;
    if (row.account_id !== null && row.account_id !== accountId) return null;
    const pending = Number(row.earned_pending_cents);
    const released = Number(row.earned_released_cents);
    const reversed = Number(row.earned_reversed_cents);
    const state = reversed > 0 && pending === 0 && released === 0
      ? 'reversed'
      : pending > 0 ? 'pending' : released > 0 ? 'available' : 'none';
    return {
      orderShopifyId: row.shopify_order_id as string,
      isWholesale: row.is_wholesale as boolean,
      earnedPendingCents: pending,
      earnedReleasedCents: released,
      earnedReversedCents: reversed,
      usedCents: Number(row.rewards_used_cents),
      state,
    };
  }

  async earnPending(args: {
    accountId: string; orderShopifyId: string; amountCents: number;
    lines: readonly OrderLineSnapshot[]; isWholesale: boolean; signals: readonly string[];
    ruleVersion: number; eventRef: string; currency?: string;
  }): Promise<{ created: boolean; lotId: number | null }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO rewards_accounts (shopify_customer_id) VALUES ($1)
         ON CONFLICT (shopify_customer_id) DO NOTHING`,
        [args.accountId],
      );
      await client.query(
        `INSERT INTO rewards_order_snapshots
           (shopify_order_id, account_id, is_wholesale, wholesale_signals, currency,
            subtotal_eligible_cents, rule_version, lines)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
         ON CONFLICT (shopify_order_id) DO UPDATE SET
           account_id = COALESCE(rewards_order_snapshots.account_id, EXCLUDED.account_id),
           is_wholesale = EXCLUDED.is_wholesale,
           wholesale_signals = EXCLUDED.wholesale_signals,
           lines = EXCLUDED.lines,
           updated_at = now()`,
        [
          args.orderShopifyId, args.accountId, args.isWholesale,
          args.signals, args.currency ?? 'MXN',
          args.lines.reduce((s, l) => s + l.lineEligibleCents, 0),
          args.ruleVersion, JSON.stringify(args.lines),
        ],
      );
      if (args.isWholesale || args.amountCents <= 0) {
        // Mayoreo no genera en V1: snapshot queda, sin lote. Idempotente.
        await client.query('COMMIT');
        return { created: false, lotId: null };
      }
      const existing = await client.query(
        `SELECT id FROM rewards_credit_lots
         WHERE account_id = $1 AND source_kind = 'order_earn' AND source_ref = $2 AND rule_version = $3`,
        [args.accountId, args.orderShopifyId, args.ruleVersion],
      );
      if (existing.rowCount !== 0) {
        await client.query('ROLLBACK');
        return { created: false, lotId: Number(existing.rows[0].id) };
      }
      const lot = await client.query(
        `INSERT INTO rewards_credit_lots
           (account_id, source_kind, source_ref, rule_version, amount_cents, remaining_cents, state)
         VALUES ($1, 'order_earn', $2, $3, $4, $4, 'pending') RETURNING id`,
        [args.accountId, args.orderShopifyId, args.ruleVersion, args.amountCents],
      );
      const lotId = Number(lot.rows[0].id);
      await client.query(
        `INSERT INTO rewards_ledger_entries
           (account_id, entry_type, state, amount_cents, lot_id, order_shopify_id,
            rule_version, event_ref, actor, reason)
         VALUES ($1, 'earn_pending', 'pending', $2, $3, $4, $5, $6, 'system', 'earn_pending')`,
        [args.accountId, args.amountCents, lotId, args.orderShopifyId, args.ruleVersion, args.eventRef],
      );
      await client.query(
        `UPDATE rewards_order_snapshots SET earned_pending_cents = $2, updated_at = now()
         WHERE shopify_order_id = $1`,
        [args.orderShopifyId, args.amountCents],
      );
      // Eventos fuera de orden: si la entrega verificada llego antes que el
      // pago, liberar de inmediato en la misma transaccion (idempotente).
      const priorDelivery = await client.query(
        `SELECT event_ref, occurred_at FROM rewards_fulfillment_events
         WHERE shopify_order_id = $1 AND kind = 'delivered' LIMIT 1`,
        [args.orderShopifyId],
      );
      if ((priorDelivery.rowCount ?? 0) > 0) {
        const policy = await this.getPolicyTx(client);
        const occurred = priorDelivery.rows[0].occurred_at as Date | null;
        const releasedAt = occurred ?? new Date();
        const expiresAt = expiryFromRelease(releasedAt, policy.expiryMonths);
        await client.query(
          `UPDATE rewards_credit_lots
           SET state = 'available', released_at = $2, expires_at = $3 WHERE id = $4`,
          [lotId, releasedAt, expiresAt, lotId],
        );
        await client.query(
          `INSERT INTO rewards_ledger_entries
             (account_id, entry_type, state, amount_cents, lot_id, order_shopify_id,
              rule_version, event_ref, actor, reason)
           VALUES ($1, 'earn_released', 'available', $2, $3, $4, $5, $6, 'system', 'delivered_out_of_order')`,
          [args.accountId, args.amountCents, lotId, args.orderShopifyId, args.ruleVersion, `auto:${args.eventRef}`],
        );
        await client.query(
          `UPDATE rewards_order_snapshots
           SET earned_pending_cents = 0, earned_released_cents = earned_released_cents + $2,
               updated_at = now()
           WHERE shopify_order_id = $1`,
          [args.orderShopifyId, args.amountCents],
        );
      }
      await client.query('COMMIT');
      return { created: true, lotId };
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { /* noop */ }
      throw error;
    } finally {
      client.release();
    }
  }

  async releaseForDelivery(args: {
    orderShopifyId: string; eventRef: string; occurredAt?: Date | null;
    lines?: readonly { quantity?: number }[];
  }): Promise<{ releasedCents: number; lots: number }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      // Idempotencia por evento: mismo pedido+kind+ref no libera dos veces.
      const dup = await client.query(
        `SELECT 1 FROM rewards_fulfillment_events
         WHERE shopify_order_id = $1 AND kind = 'delivered' AND event_ref = $2`,
        [args.orderShopifyId, args.eventRef],
      );
      if ((dup.rowCount ?? 0) > 0) {
        await client.query('ROLLBACK');
        return { releasedCents: 0, lots: 0 };
      }
      const lots = await client.query(
        `SELECT id, account_id, remaining_cents, rule_version
         FROM rewards_credit_lots
         WHERE source_kind = 'order_earn' AND source_ref = $1 AND state = 'pending'
         ORDER BY id FOR UPDATE`,
        [args.orderShopifyId],
      );
      if (lots.rowCount === 0) {
        await client.query(
          `INSERT INTO rewards_fulfillment_events
             (shopify_order_id, kind, event_ref, occurred_at) VALUES ($1, 'delivered', $2, $3)
           ON CONFLICT DO NOTHING`,
          [args.orderShopifyId, args.eventRef, args.occurredAt ?? new Date()],
        );
        await client.query('COMMIT');
        return { releasedCents: 0, lots: 0 };
      }
      const policy = await this.getPolicyTx(client);
      const now = new Date();
      let released = 0;
      for (const lot of lots.rows) {
        const lotId = Number(lot.id);
        const amount = Number(lot.remaining_cents);
        const releasedAt = args.occurredAt ?? now;
        const expiresAt = expiryFromRelease(releasedAt, policy.expiryMonths);
        await client.query(
          `UPDATE rewards_credit_lots
           SET state = 'available', released_at = $2, expires_at = $3 WHERE id = $1`,
          [lotId, releasedAt, expiresAt],
        );
        await client.query(
          `INSERT INTO rewards_ledger_entries
             (account_id, entry_type, state, amount_cents, lot_id, order_shopify_id,
              rule_version, event_ref, actor, reason)
           VALUES ($1, 'earn_released', 'available', $2, $3, $4, $5, $6, 'system', 'delivered')`,
          [lot.account_id, amount, lotId, args.orderShopifyId, Number(lot.rule_version), args.eventRef],
        );
        released += amount;
      }
      await client.query(
        `INSERT INTO rewards_fulfillment_events
           (shopify_order_id, kind, event_ref, occurred_at) VALUES ($1, 'delivered', $2, $3)`,
        [args.orderShopifyId, args.eventRef, args.occurredAt ?? now],
      );
      await client.query(
        `UPDATE rewards_order_snapshots
         SET earned_pending_cents = 0, earned_released_cents = earned_released_cents + $2, updated_at = now()
         WHERE shopify_order_id = $1`,
        [args.orderShopifyId, released],
      );
      const accountId = lots.rows[0].account_id as string;
      await client.query(
        `INSERT INTO rewards_outbox (kind, account_id, payload)
         VALUES ('notify_release', $1, $2::jsonb)`,
        [accountId, JSON.stringify({ orderShopifyId: args.orderShopifyId, releasedCents: released })],
      );
      await client.query('COMMIT');
      return { releasedCents: released, lots: lots.rowCount ?? 0 };
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { /* noop */ }
      throw error;
    } finally {
      client.release();
    }
  }

  async reverseEarn(args: {
    orderShopifyId: string; eventRef: string; kind: 'cancelled' | 'refund';
    reverseCents?: number | null; reason: string; operator?: string;
  }): Promise<{ reversedCents: number }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const dup = await client.query(
        `SELECT 1 FROM rewards_fulfillment_events
         WHERE shopify_order_id = $1 AND kind = $2 AND event_ref = $3`,
        [args.orderShopifyId, args.kind, args.eventRef],
      );
      if ((dup.rowCount ?? 0) > 0) {
        await client.query('ROLLBACK');
        return { reversedCents: 0 };
      }
      // Cancelacion+reembolso del mismo efecto economico no revierten dos veces:
      // se calcula sobre el remanente no revertido.
      const lots = await client.query(
        `SELECT id, account_id, remaining_cents, reserved_cents, state, rule_version
         FROM rewards_credit_lots
         WHERE source_kind = 'order_earn' AND source_ref = $1
           AND state IN ('pending', 'available')
         ORDER BY id FOR UPDATE`,
        [args.orderShopifyId],
      );
      let target = args.reverseCents ?? null;
      let reversed = 0;
      for (const lot of lots.rows) {
        const free = Number(lot.remaining_cents) - Number(lot.reserved_cents);
        if (free <= 0) continue;
        const take = target === null ? free : Math.min(free, target - reversed);
        if (take <= 0) break;
        const lotId = Number(lot.id);
        const left = Number(lot.remaining_cents) - take;
        await client.query(
          `UPDATE rewards_credit_lots SET remaining_cents = $2,
             state = CASE WHEN $2 = 0 THEN 'reversed'::text ELSE state END WHERE id = $1`,
          [lotId, left],
        );
        await client.query(
          `INSERT INTO rewards_ledger_entries
             (account_id, entry_type, state, amount_cents, lot_id, order_shopify_id,
              rule_version, event_ref, actor, reason)
           VALUES ($1, 'earn_reversed', 'reversed', $2, $3, $4, $5, $6, $7, $8)`,
          [
            lot.account_id as string, -take, lotId, args.orderShopifyId,
            Number(lot.rule_version), args.eventRef,
            args.operator ?? 'system', args.reason,
          ],
        );
        reversed += take;
        if (target !== null && reversed >= target) break;
      }
      await client.query(
        `INSERT INTO rewards_fulfillment_events (shopify_order_id, kind, event_ref, amount_cents)
         VALUES ($1, $2, $3, $4)`,
        [args.orderShopifyId, args.kind, args.eventRef, reversed],
      );
      await client.query(
        `UPDATE rewards_order_snapshots
         SET earned_reversed_cents = earned_reversed_cents + $2,
             earned_pending_cents = GREATEST(0, earned_pending_cents - $2),
             updated_at = now()
         WHERE shopify_order_id = $1`,
        [args.orderShopifyId, reversed],
      );
      if (reversed > 0) {
        const accountId = lots.rows[0]?.account_id as string | undefined;
        await client.query(
          `INSERT INTO rewards_outbox (kind, account_id, payload)
           VALUES ('notify_adjustment', $1, $2::jsonb)`,
          [accountId ?? null, JSON.stringify({ orderShopifyId: args.orderShopifyId, reversedCents: reversed, kind: args.kind })],
        );
      }
      await client.query('COMMIT');
      return { reversedCents: reversed };
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { /* noop */ }
      throw error;
    } finally {
      client.release();
    }
  }

  async createQuote(args: {
    accountId: string; cartRevision: string; subtotalEligibleCents: number;
    availableCents: number; maxAllowedCents: number; estimatedEarnCents: number;
    ruleVersion: number; ttlMinutes: number;
  }): Promise<QuoteRecord> {
    const id = randomUUID();
    const expiresAt = new Date(Date.now() + args.ttlMinutes * 60_000);
    await this.pool.query(
      `INSERT INTO rewards_accounts (shopify_customer_id) VALUES ($1)
       ON CONFLICT (shopify_customer_id) DO NOTHING`,
      [args.accountId],
    );
    await this.pool.query(
      `INSERT INTO rewards_quotes
         (id, account_id, cart_revision, subtotal_eligible_cents, available_cents,
          max_allowed_cents, estimated_earn_cents, rule_version, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [id, args.accountId, args.cartRevision, args.subtotalEligibleCents, args.availableCents,
        args.maxAllowedCents, args.estimatedEarnCents, args.ruleVersion, expiresAt],
    );
    return {
      id, accountId: args.accountId, cartRevision: args.cartRevision,
      subtotalEligibleCents: args.subtotalEligibleCents, availableCents: args.availableCents,
      maxAllowedCents: args.maxAllowedCents, estimatedEarnCents: args.estimatedEarnCents,
      ruleVersion: args.ruleVersion, expiresAt,
    };
  }

  async findQuote(accountId: string, quoteId: string): Promise<QuoteRecord | null> {
    const res = await this.pool.query(
      `SELECT * FROM rewards_quotes WHERE id = $1 AND account_id = $2`,
      [quoteId, accountId],
    );
    const r = res.rows[0];
    if (!r) return null;
    return {
      id: r.id as string, accountId: r.account_id as string,
      cartRevision: r.cart_revision as string,
      subtotalEligibleCents: Number(r.subtotal_eligible_cents),
      availableCents: Number(r.available_cents),
      maxAllowedCents: Number(r.max_allowed_cents),
      estimatedEarnCents: Number(r.estimated_earn_cents),
      ruleVersion: Number(r.rule_version),
      expiresAt: new Date(r.expires_at),
    };
  }

  async reserve(args: {
    accountId: string; quoteId: string; cartRevision: string;
    subtotalEligibleCents: number; maxAllowedCents: number; requestedCents: number;
    idempotencyKey: string; ttlMinutes: number;
  }): Promise<{ redemption: RedemptionRecord; reused: boolean }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      // Doble toque / reintento: misma clave -> misma reserva, sin doble gasto.
      const prior = await client.query(
        `SELECT * FROM rewards_redemptions WHERE account_id = $1 AND idempotency_key = $2`,
        [args.accountId, args.idempotencyKey],
      );
      if ((prior.rowCount ?? 0) > 0) {
        await client.query('ROLLBACK');
        return { redemption: mapRedemption(prior.rows[0]), reused: true };
      }
      if (args.requestedCents > args.maxAllowedCents) {
        throw Object.assign(new Error('exceeds_limit'), { code: 'exceeds_limit' });
      }
      // Bloqueo por cuenta para serializar reservas concurrentes.
      await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [`rewards:${args.accountId}`]);
      // Lotes vigentes que vencen primero; jamas pendiente/vencido/revertido/reservado.
      const lots = await client.query(
        `SELECT id, remaining_cents, reserved_cents
         FROM rewards_credit_lots
         WHERE account_id = $1 AND state = 'available'
           AND (expires_at IS NULL OR expires_at > now())
         ORDER BY expires_at NULLS LAST, id FOR UPDATE`,
        [args.accountId],
      );
      let need = args.requestedCents;
      const picks: { lotId: number; take: number }[] = [];
      for (const lot of lots.rows) {
        const free = Number(lot.remaining_cents) - Number(lot.reserved_cents);
        if (free <= 0) continue;
        const take = Math.min(free, need);
        picks.push({ lotId: Number(lot.id), take });
        need -= take;
        if (need <= 0) break;
      }
      if (need > 0) {
        throw Object.assign(new Error('insufficient_balance'), { code: 'insufficient_balance' });
      }
      const id = randomUUID();
      const expiresAt = new Date(Date.now() + args.ttlMinutes * 60_000);
      await client.query(
        `INSERT INTO rewards_redemptions
           (id, account_id, quote_id, cart_revision, subtotal_eligible_cents,
            requested_cents, max_allowed_cents, state, idempotency_key, expires_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,'reserved',$8,$9)`,
        [id, args.accountId, args.quoteId, args.cartRevision, args.subtotalEligibleCents,
          args.requestedCents, args.maxAllowedCents, args.idempotencyKey, expiresAt],
      );
      for (const pick of picks) {
        await client.query(
          `UPDATE rewards_credit_lots SET reserved_cents = reserved_cents + $2 WHERE id = $1`,
          [pick.lotId, pick.take],
        );
        await client.query(
          `INSERT INTO rewards_lot_allocations (redemption_id, lot_id, amount_cents, state)
           VALUES ($1, $2, $3, 'reserved')`,
          [id, pick.lotId, pick.take],
        );
      }
      await client.query(
        `INSERT INTO rewards_ledger_entries
           (account_id, entry_type, state, amount_cents, redemption_id,
            rule_version, idempotency_key, actor, reason)
         VALUES ($1, 'redeem_reserved', 'available', $2, $3, 1, $4, 'customer', 'reserve')`,
        [args.accountId, -args.requestedCents, id, `reserve:${args.idempotencyKey}`],
      );
      await client.query('COMMIT');
      const res = await this.pool.query(`SELECT * FROM rewards_redemptions WHERE id = $1`, [id]);
      return { redemption: mapRedemption(res.rows[0]), reused: false };
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { /* noop */ }
      throw error;
    } finally {
      client.release();
    }
  }

  async findRedemption(accountId: string, redemptionId: string): Promise<RedemptionRecord | null> {
    const res = await this.pool.query(
      `SELECT * FROM rewards_redemptions WHERE id = $1 AND account_id = $2`,
      [redemptionId, accountId],
    );
    return res.rows[0] ? mapRedemption(res.rows[0]) : null;
  }

  async markProvisioning(redemptionId: string, discountId: string, discountCode: string): Promise<void> {
    await this.pool.query(
      `UPDATE rewards_redemptions SET state = 'provisioning',
        shopify_discount_id = $2, shopify_discount_code = $3, updated_at = now()
       WHERE id = $1`,
      [redemptionId, discountId, discountCode],
    );
  }

  async markApplied(redemptionId: string): Promise<void> {
    await this.pool.query(
      `UPDATE rewards_redemptions SET state = 'applied', updated_at = now() WHERE id = $1`,
      [redemptionId],
    );
  }

  async attachOrder(redemptionId: string, orderShopifyId: string): Promise<void> {
    await this.pool.query(
      `UPDATE rewards_redemptions
       SET order_shopify_id = $2, state = 'order_committed', updated_at = now()
       WHERE id = $1`,
      [redemptionId, orderShopifyId],
    );
  }

  async settle(args: { redemptionId: string; appliedCents: number; orderShopifyId: string }): Promise<RedemptionRecord> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const cur = await client.query(`SELECT * FROM rewards_redemptions WHERE id = $1 FOR UPDATE`, [args.redemptionId]);
      const row = cur.rows[0];
      if (!row) throw Object.assign(new Error('not_found'), { code: 'not_found' });
      const requested = Number(row.requested_cents);
      const accountId = row.account_id as string;
      if (args.appliedCents > requested) {
        await client.query(
          `UPDATE rewards_redemptions SET state = 'reconciliation_required',
             provisioned_cents = $2, order_shopify_id = $3, updated_at = now() WHERE id = $1`,
          [args.redemptionId, args.appliedCents, args.orderShopifyId],
        );
        await client.query('COMMIT');
        const res = await this.pool.query(`SELECT * FROM rewards_redemptions WHERE id = $1`, [args.redemptionId]);
        return mapRedemption(res.rows[0]);
      }
      // Consume lo real por lote; libera la diferencia tras verificacion.
      const allocs = await client.query(
        `SELECT lot_id, amount_cents FROM rewards_lot_allocations
         WHERE redemption_id = $1 ORDER BY lot_id FOR UPDATE`,
        [args.redemptionId],
      );
      let remaining = args.appliedCents;
      for (const alloc of allocs.rows) {
        const lotId = Number(alloc.lot_id);
        const reserved = Number(alloc.amount_cents);
        const used = Math.min(reserved, remaining);
        const freed = reserved - used;
        remaining -= used;
        await client.query(
          `UPDATE rewards_credit_lots
           SET reserved_cents = reserved_cents - $2,
               remaining_cents = remaining_cents - $3,
               state = CASE WHEN remaining_cents - $3 = 0 THEN 'used' ELSE state END
           WHERE id = $1`,
          [lotId, reserved, used],
        );
        await client.query(
          `UPDATE rewards_lot_allocations SET state = $2
           WHERE redemption_id = $3 AND lot_id = $1`,
          [lotId, used > 0 ? 'settled' : 'released', args.redemptionId],
        );
        void freed;
      }
      await client.query(
        `INSERT INTO rewards_ledger_entries
           (account_id, entry_type, state, amount_cents, redemption_id, order_shopify_id,
            rule_version, event_ref, actor, reason)
         VALUES ($1, 'redeem_settled', 'used', $2, $3, $4, 1, $5, 'system', 'settled')`,
        [accountId, -args.appliedCents, args.redemptionId, args.orderShopifyId, `settle:${args.redemptionId}`],
      );
      await client.query(
        `UPDATE rewards_redemptions SET state = 'settled', settled_cents = $2,
           provisioned_cents = $2, order_shopify_id = $3, updated_at = now() WHERE id = $1`,
        [args.redemptionId, args.appliedCents, args.orderShopifyId],
      );
      await client.query(
        `UPDATE rewards_order_snapshots SET rewards_used_cents = rewards_used_cents + $2,
           updated_at = now() WHERE shopify_order_id = $1`,
        [args.orderShopifyId, args.appliedCents],
      );
      await client.query('COMMIT');
      const res = await this.pool.query(`SELECT * FROM rewards_redemptions WHERE id = $1`, [args.redemptionId]);
      return mapRedemption(res.rows[0]);
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { /* noop */ }
      throw error;
    } finally {
      client.release();
    }
  }

  async releaseReservation(redemptionId: string): Promise<RedemptionRecord> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const cur = await client.query(`SELECT * FROM rewards_redemptions WHERE id = $1 FOR UPDATE`, [redemptionId]);
      const row = cur.rows[0];
      if (!row) throw Object.assign(new Error('not_found'), { code: 'not_found' });
      if (row.state === 'settled') throw Object.assign(new Error('already_settled'), { code: 'already_settled' });
      const allocs = await client.query(
        `SELECT lot_id, amount_cents FROM rewards_lot_allocations
         WHERE redemption_id = $1 AND state = 'reserved' FOR UPDATE`,
        [redemptionId],
      );
      for (const alloc of allocs.rows) {
        await client.query(
          `UPDATE rewards_credit_lots SET reserved_cents = reserved_cents - $2 WHERE id = $1`,
          [Number(alloc.lot_id), Number(alloc.amount_cents)],
        );
      }
      await client.query(
        `UPDATE rewards_lot_allocations SET state = 'released' WHERE redemption_id = $1 AND state = 'reserved'`,
        [redemptionId],
      );
      await client.query(
        `INSERT INTO rewards_ledger_entries
           (account_id, entry_type, state, amount_cents, redemption_id,
            rule_version, event_ref, actor, reason)
         VALUES ($1, 'redeem_released', 'available', $2, $3, 1, $4, 'system', 'released')`,
        [row.account_id, Number(row.requested_cents), redemptionId, `release:${redemptionId}`],
      );
      await client.query(
        `UPDATE rewards_redemptions SET state = 'released', updated_at = now() WHERE id = $1`,
        [redemptionId],
      );
      await client.query('COMMIT');
      const res = await this.pool.query(`SELECT * FROM rewards_redemptions WHERE id = $1`, [redemptionId]);
      return mapRedemption(res.rows[0]);
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { /* noop */ }
      throw error;
    } finally {
      client.release();
    }
  }

  async markReconciliation(redemptionId: string, reason: string): Promise<void> {
    await this.pool.query(
      `UPDATE rewards_redemptions SET state = 'reconciliation_required', updated_at = now() WHERE id = $1`,
      [redemptionId],
    );
    await this.pool.query(
      `INSERT INTO rewards_outbox (kind, payload) VALUES ('notify_adjustment', $1::jsonb)`,
      [JSON.stringify({ redemptionId, reason })],
    );
  }

  async expireDue(now: Date, limit = 500): Promise<{ expiredLots: number; expiredCents: number }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const lots = await client.query(
        `SELECT id, account_id, remaining_cents, reserved_cents, rule_version
         FROM rewards_credit_lots
         WHERE state = 'available' AND expires_at IS NOT NULL AND expires_at <= $1
         ORDER BY id LIMIT $2 FOR UPDATE SKIP LOCKED`,
        [now, limit],
      );
      let cents = 0;
      for (const lot of lots.rows) {
        const free = Number(lot.remaining_cents) - Number(lot.reserved_cents);
        if (free <= 0) continue;
        const lotId = Number(lot.id);
        await client.query(
          `UPDATE rewards_credit_lots SET remaining_cents = reserved_cents,
             state = CASE WHEN reserved_cents = 0 THEN 'expired' ELSE state END WHERE id = $1`,
          [lotId],
        );
        await client.query(
          `INSERT INTO rewards_ledger_entries
             (account_id, entry_type, state, amount_cents, lot_id, rule_version, actor, reason)
           VALUES ($1, 'expired', 'expired', $2, $3, $4, 'system', 'expiry_12m')`,
          [lot.account_id, -free, lotId, Number(lot.rule_version)],
        );
        cents += free;
      }
      await client.query('COMMIT');
      return { expiredLots: lots.rowCount ?? 0, expiredCents: cents };
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { /* noop */ }
      throw error;
    } finally {
      client.release();
    }
  }

  async abandonedReservations(now: Date, limit = 100): Promise<RedemptionRecord[]> {
    const res = await this.pool.query(
      `SELECT * FROM rewards_redemptions
       WHERE state IN ('reserved', 'provisioning', 'applied') AND expires_at <= $1
       ORDER BY expires_at LIMIT $2`,
      [now, limit],
    );
    return res.rows.map(mapRedemption);
  }

  async inboxClaim(eventId: string, topic: string, payload: unknown, orderId?: string | null, accountId?: string | null): Promise<boolean> {
    const res = await this.pool.query(
      `INSERT INTO rewards_inbox (event_id, topic, shopify_order_id, account_id, payload, status, attempts, next_retry_at)
       VALUES ($1, $2, $3, $4, $5::jsonb, 'processing', 1, now())
       ON CONFLICT (event_id) DO NOTHING`,
      [eventId, topic, orderId ?? null, accountId ?? null, JSON.stringify(payload ?? {})],
    );
    return (res.rowCount ?? 0) > 0;
  }

  async inboxDone(eventId: string, ok: boolean, error?: string): Promise<void> {
    await this.pool.query(
      `UPDATE rewards_inbox SET status = $2, last_error = $3,
         attempts = attempts + 1,
         next_retry_at = CASE WHEN $2 = 'failed' THEN now() + interval '5 minutes' ELSE next_retry_at END
       WHERE event_id = $1`,
      [eventId, ok ? 'completed' : 'failed', error?.slice(0, 2000) ?? null],
    );
  }

  async pendingInbox(limit = 50): Promise<{ eventId: string; topic: string; payload: unknown; orderShopifyId: string | null }[]> {
    const res = await this.pool.query(
      `SELECT event_id, topic, payload, shopify_order_id FROM rewards_inbox
       WHERE status IN ('pending', 'failed') AND next_retry_at <= now()
       ORDER BY received_at LIMIT $1`,
      [limit],
    );
    return res.rows.map((r) => ({
      eventId: r.event_id as string,
      topic: r.topic as string,
      payload: r.payload as unknown,
      orderShopifyId: r.shopify_order_id as string | null,
    }));
  }

  async outboxEnqueue(kind: string, payload: unknown, accountId?: string | null): Promise<void> {
    await this.pool.query(
      `INSERT INTO rewards_outbox (kind, account_id, payload) VALUES ($1, $2, $3::jsonb)`,
      [kind, accountId ?? null, JSON.stringify(payload ?? {})],
    );
  }

  private async getPolicyTx(client: pg.PoolClient): Promise<ProgramPolicy> {
    const res = await client.query('SELECT expiry_months FROM rewards_program_versions ORDER BY version DESC LIMIT 1');
    const months = res.rows[0]?.expiry_months as number | undefined;
    return { ...DEFAULT_PROGRAM, expiryMonths: months ?? 12 };
  }
}

function mapRedemption(r: Record<string, unknown>): RedemptionRecord {
  return {
    id: r['id'] as string,
    accountId: r['account_id'] as string,
    quoteId: r['quote_id'] as string,
    cartRevision: r['cart_revision'] as string,
    subtotalEligibleCents: Number(r['subtotal_eligible_cents']),
    requestedCents: Number(r['requested_cents']),
    maxAllowedCents: Number(r['max_allowed_cents']),
    provisionedCents: Number(r['provisioned_cents'] ?? 0),
    settledCents: Number(r['settled_cents'] ?? 0),
    state: r['state'] as RedemptionRecord['state'],
    shopifyDiscountId: (r['shopify_discount_id'] as string | null) ?? null,
    shopifyDiscountCode: (r['shopify_discount_code'] as string | null) ?? null,
    orderShopifyId: (r['order_shopify_id'] as string | null) ?? null,
    idempotencyKey: r['idempotency_key'] as string,
    expiresAt: new Date(r['expires_at'] as string),
  };
}

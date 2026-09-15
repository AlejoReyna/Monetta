import { randomUUID } from 'node:crypto';
import { eligibleSubtotal, estimatedEarnCents, maxRedeemableCents, redemptionEligibility } from './rules.js';
import type { RewardsRepository } from './repository.js';
import type { RewardsEnv } from './rewardsConfig.js';
import { effectivePolicy } from './rewardsConfig.js';
import type { ShopifyDiscountAdapter } from './shopifyDiscountAdapter.js';
import { DisabledDiscountAdapter } from './shopifyDiscountAdapter.js';
import type { ProgramPolicy, QuoteInput } from './types.js';

export interface ServiceDeps {
  readonly rewards: RewardsRepository;
  readonly env: RewardsEnv;
  readonly discounts?: ShopifyDiscountAdapter;
  readonly shopDomain?: string | null;
  readonly now?: () => Date;
}

function asIdemKey(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const t = value.trim();
  return t.length >= 8 && t.length <= 128 ? t : null;
}

export class RewardsService {
  private readonly now: () => Date;
  private readonly discounts: ShopifyDiscountAdapter;
  constructor(private readonly deps: ServiceDeps) {
    this.now = deps.now ?? (() => new Date());
    this.discounts = deps.discounts ?? new DisabledDiscountAdapter();
  }

  policy(): ProgramPolicy {
    return effectivePolicy(this.deps.env);
  }

  async summary(accountId: string) {
    const policy = this.policy();
    await this.deps.rewards.ensureAccount(accountId, this.deps.shopDomain ?? null);
    const [balance, dbPolicy] = await Promise.all([
      this.deps.rewards.balance(accountId, this.now()),
      this.deps.rewards.getPolicy(),
    ]);
    const merged: ProgramPolicy = { ...policy, version: dbPolicy.version };
    return {
      program: {
        enabled: this.deps.env.rewardsEnabled,
        redemptionEnabled: merged.redemptionEnabled,
        currency: merged.currency,
        earnBps: merged.earnBps,
        maxRedeemBps: merged.maxRedeemBps,
        expiryMonths: merged.expiryMonths,
        wholesaleEarns: merged.wholesaleEarns,
        ruleVersion: merged.version,
      },
      balance: {
        availableCents: balance.availableCents,
        pendingCents: balance.pendingCents,
        reservedCents: balance.reservedCents,
        nextExpiry: balance.nextExpiry
          ? { cents: balance.nextExpiry.cents, at: balance.nextExpiry.at.toISOString() }
          : null,
        asOf: this.now().toISOString(),
      },
      incentives: {
        // Minimos/reglas pendientes -> deshabilitados, sin importes asignables.
        firstPurchase: { enabled: false, amountCents: 5000, reason: 'minimum_undecided' },
        review: { enabled: false, amountCents: 2000, reason: 'verification_integration_pending' },
        referral: { enabled: false, amountCents: 5000, reason: 'minimum_undecided' },
      },
    };
  }

  async quote(accountId: string, input: QuoteInput) {
    const policy = this.policy();
    if (input.cartRevision.trim() === '' || input.lines.length === 0 || input.lines.length > 200) {
      throw Object.assign(new Error('invalid_cart'), { code: 'invalid_cart' });
    }
    const breakdown = eligibleSubtotal(input.lines);
    await this.deps.rewards.ensureAccount(accountId, this.deps.shopDomain ?? null);
    const balance = await this.deps.rewards.balance(accountId, this.now());
    const maxAllowed = maxRedeemableCents({
      subtotalEligibleCents: breakdown.subtotalEligibleCents,
      availableCents: balance.availableCents,
      maxRedeemBps: policy.maxRedeemBps,
    });
    // Estimacion claramente identificada (no liberada): base neta propuesta sin canje aun.
    const estimated = breakdown.subtotalEligibleCents > 0
      ? estimatedEarnCents({ subtotalEligibleCents: breakdown.subtotalEligibleCents, redeemCents: 0, earnBps: policy.earnBps })
      : 0;
    const record = await this.deps.rewards.createQuote({
      accountId,
      cartRevision: input.cartRevision,
      subtotalEligibleCents: breakdown.subtotalEligibleCents,
      availableCents: balance.availableCents,
      maxAllowedCents: maxAllowed,
      estimatedEarnCents: estimated,
      ruleVersion: policy.version,
      ttlMinutes: this.deps.env.quoteTtlMinutes,
    });
    return {
      quoteId: record.id,
      cartRevision: record.cartRevision,
      subtotalEligibleCents: record.subtotalEligibleCents,
      availableCents: record.availableCents,
      maxAllowedCents: record.maxAllowedCents,
      estimatedEarnCents: record.estimatedEarnCents,
      isWholesaleCart: input.isWholesaleCart ?? false,
      redemptionEnabled: policy.redemptionEnabled,
      expiresAt: record.expiresAt.toISOString(),
      estimateDisclaimer: 'Estimación pendiente de entrega; no es saldo liberado.',
    };
  }

  async redeem(args: {
    accountId: string; quoteId: string; amountCents: number;
    isWholesaleCart: boolean; idempotencyKey: unknown;
  }) {
    const policy = this.policy();
    const key = asIdemKey(args.idempotencyKey);
    if (key === null) throw Object.assign(new Error('invalid_idempotency_key'), { code: 'invalid_idempotency_key' });
    const q = await this.deps.rewards.findQuote(args.accountId, args.quoteId);
    if (!q) throw Object.assign(new Error('quote_not_found'), { code: 'quote_not_found' });
    if (q.expiresAt <= this.now()) throw Object.assign(new Error('quote_expired'), { code: 'quote_expired' });
    const eligibility = redemptionEligibility({
      policy,
      isWholesaleCart: args.isWholesaleCart,
      requestedCents: args.amountCents,
      maxAllowedCents: q.maxAllowedCents,
    });
    if (!eligibility.ok) {
      throw Object.assign(new Error(eligibility.code), { code: eligibility.code, message: eligibility.message });
    }
    if (!Number.isInteger(args.amountCents) || args.amountCents <= 0 || args.amountCents > q.maxAllowedCents) {
      throw Object.assign(new Error('exceeds_limit'), { code: 'exceeds_limit' });
    }
    const { redemption, reused } = await this.deps.rewards.reserve({
      accountId: args.accountId,
      quoteId: q.id,
      cartRevision: q.cartRevision,
      subtotalEligibleCents: q.subtotalEligibleCents,
      maxAllowedCents: q.maxAllowedCents,
      requestedCents: args.amountCents,
      idempotencyKey: key,
      ttlMinutes: this.deps.env.reservationTtlMinutes,
    });
    if (reused) return { redemption: toApi(redemption), reused: true, discount: null };
    // Provision fuera de la transaccion SQL (operacion recuperable via outbox).
    if (!this.discounts.available) {
      await this.deps.rewards.outboxEnqueue('discount_provision', {
        redemptionId: redemption.id, accountId: args.accountId,
        amountCents: args.amountCents, reason: 'adapter_unavailable',
      }, args.accountId);
      return { redemption: toApi(redemption), reused: false, discount: null, pendingProvision: true };
    }
    try {
      const provisioned = await this.discounts.provision({
        redemptionId: redemption.id,
        accountId: args.accountId,
        amountCents: args.amountCents,
        subtotalEligibleCents: q.subtotalEligibleCents,
        currency: 'MXN',
        expiresAt: redemption.expiresAt,
      });
      await this.deps.rewards.markProvisioning(redemption.id, provisioned.discountId, provisioned.code);
      await this.deps.rewards.markApplied(redemption.id);
      const updated = await this.deps.rewards.findRedemption(args.accountId, redemption.id);
      return {
        redemption: toApi(updated ?? redemption),
        reused: false,
        discount: { code: provisioned.code },
      };
    } catch (error) {
      await this.deps.rewards.markReconciliation(redemption.id, error instanceof Error ? error.message : String(error));
      throw error;
    }
  }

  async releaseRedemption(accountId: string, redemptionId: string) {
    const current = await this.deps.rewards.findRedemption(accountId, redemptionId);
    if (!current) throw Object.assign(new Error('not_found'), { code: 'not_found' });
    if (current.state === 'settled') throw Object.assign(new Error('already_settled'), { code: 'already_settled' });
    // No liberar por declaracion del cliente sin verificar uso en Shopify.
    if (current.shopifyDiscountId && this.discounts.available) {
      const unused = await this.discounts.isUnused(current.shopifyDiscountId);
      if (unused === false) {
        throw Object.assign(new Error('discount_already_used'), { code: 'discount_already_used' });
      }
      if (unused === null) {
        await this.deps.rewards.markReconciliation(redemptionId, 'usage_unknown');
        throw Object.assign(new Error('reconciliation_required'), { code: 'reconciliation_required' });
      }
      await this.discounts.invalidate(current.shopifyDiscountId).catch(() => {});
    }
    const released = await this.deps.rewards.releaseReservation(redemptionId);
    return { redemption: toApi(released) };
  }

  // ---- Eventos verificados (inbox + idempotencia de negocio) ----

  /** Pago confirmado (fuente verificable). Crea pendiente; mayoreo no genera. */
  async onOrderPaid(args: {
    eventId: string; orderShopifyId: string; accountId: string | null;
    subtotalEligibleCents: number; lines: QuoteInput['lines'];
    isWholesale: boolean; signals: readonly string[]; currency?: string;
  }): Promise<{ earned: boolean }> {
    const claimed = await this.deps.rewards.inboxClaim(
      args.eventId, 'order_paid', args, args.orderShopifyId, args.accountId,
    );
    if (!claimed) return { earned: false };
    try {
      if (args.accountId === null) {
        await this.deps.rewards.inboxDone(args.eventId, true);
        return { earned: false };
      }
      const policy = this.policy();
      const breakdown = eligibleSubtotal(args.lines);
      const base = Math.min(args.subtotalEligibleCents, breakdown.subtotalEligibleCents);
      // G sobre base elegible (sin canje conocido aqui; el settle ajusta si hubo canje).
      const earn = args.isWholesale
        ? 0
        : estimatedEarnCents({ subtotalEligibleCents: base, redeemCents: 0, earnBps: policy.earnBps });
      const res = await this.deps.rewards.earnPending({
        accountId: args.accountId,
        orderShopifyId: args.orderShopifyId,
        amountCents: earn,
        lines: breakdown.lines,
        isWholesale: args.isWholesale,
        signals: args.signals,
        ruleVersion: policy.version,
        eventRef: args.eventId,
        currency: args.currency ?? 'MXN',
      });
      await this.deps.rewards.inboxDone(args.eventId, true);
      return { earned: res.created };
    } catch (error) {
      await this.deps.rewards.inboxDone(args.eventId, false, error instanceof Error ? error.message : String(error));
      throw error;
    }
  }

  /** Entrega de fuente verificable (fulfillment event DELIVERED o confirmacion operativa auditada). */
  async onOrderDelivered(args: { eventId: string; orderShopifyId: string; occurredAt?: Date | null }) {
    const claimed = await this.deps.rewards.inboxClaim(args.eventId, 'order_delivered', args, args.orderShopifyId);
    if (!claimed) return { releasedCents: 0 };
    try {
      const res = await this.deps.rewards.releaseForDelivery({
        orderShopifyId: args.orderShopifyId, eventRef: args.eventId, occurredAt: args.occurredAt ?? null,
      });
      await this.deps.rewards.inboxDone(args.eventId, true);
      return res;
    } catch (error) {
      await this.deps.rewards.inboxDone(args.eventId, false, error instanceof Error ? error.message : String(error));
      throw error;
    }
  }

  async onOrderCancelled(args: { eventId: string; orderShopifyId: string; reason?: string }) {
    const claimed = await this.deps.rewards.inboxClaim(args.eventId, 'order_cancelled', args, args.orderShopifyId);
    if (!claimed) return { reversedCents: 0 };
    try {
      const res = await this.deps.rewards.reverseEarn({
        orderShopifyId: args.orderShopifyId, eventRef: args.eventId,
        kind: 'cancelled', reason: args.reason ?? 'order_cancelled',
      });
      await this.deps.rewards.inboxDone(args.eventId, true);
      return res;
    } catch (error) {
      await this.deps.rewards.inboxDone(args.eventId, false, error instanceof Error ? error.message : String(error));
      throw error;
    }
  }

  async onRefund(args: {
    eventId: string; orderShopifyId: string; reverseCents?: number | null; reason?: string;
  }) {
    const claimed = await this.deps.rewards.inboxClaim(args.eventId, 'order_refund', args, args.orderShopifyId);
    if (!claimed) return { reversedCents: 0 };
    try {
      const res = await this.deps.rewards.reverseEarn({
        orderShopifyId: args.orderShopifyId, eventRef: args.eventId, kind: 'refund',
        reverseCents: args.reverseCents ?? null, reason: args.reason ?? 'refund',
      });
      await this.deps.rewards.inboxDone(args.eventId, true);
      return res;
    } catch (error) {
      await this.deps.rewards.inboxDone(args.eventId, false, error instanceof Error ? error.message : String(error));
      throw error;
    }
  }

  /** Mantenimiento: expiracion + reservas abandonadas (verifica no-uso antes de liberar). */
  async runMaintenance(): Promise<{
    expiredLots: number; expiredCents: number;
    releasedReservations: number; needReconciliation: string[];
  }> {
    const now = this.now();
    const expired = await this.deps.rewards.expireDue(now);
    const abandoned = await this.deps.rewards.abandonedReservations(now);
    let released = 0;
    const needReconciliation: string[] = [];
    for (const r of abandoned) {
      if (r.shopifyDiscountId && this.discounts.available) {
        const unused = await this.discounts.isUnused(r.shopifyDiscountId).catch(() => null);
        if (unused === false) {
          await this.deps.rewards.markReconciliation(r.id, 'discount_used_after_expiry');
          needReconciliation.push(r.id);
          continue;
        }
        if (unused === null) {
          await this.deps.rewards.markReconciliation(r.id, 'usage_unknown_at_expiry');
          needReconciliation.push(r.id);
          continue;
        }
        await this.discounts.invalidate(r.shopifyDiscountId).catch(() => {});
      }
      await this.deps.rewards.releaseReservation(r.id).catch(() => {});
      released += 1;
    }
    return {
      expiredLots: expired.expiredLots, expiredCents: expired.expiredCents,
      releasedReservations: released, needReconciliation,
    };
  }

  newIdemKey(): string {
    return randomUUID();
  }
}

function toApi(r: { id: string; state: unknown; requestedCents: number; maxAllowedCents: number; subtotalEligibleCents: number; cartRevision: string; quoteId: string; expiresAt: Date; orderShopifyId: string | null }) {
  return {
    redemptionId: r.id,
    state: r.state,
    requestedCents: r.requestedCents,
    maxAllowedCents: r.maxAllowedCents,
    subtotalEligibleCents: r.subtotalEligibleCents,
    cartRevision: r.cartRevision,
    quoteId: r.quoteId,
    expiresAt: r.expiresAt.toISOString(),
    orderShopifyId: r.orderShopifyId,
  };
}

import { randomUUID } from 'node:crypto';
import { expiryFromRelease } from '../../src/rewards/rules.js';
import type {
  BalanceView, MovementView, OrderRewardsView, QuoteRecord,
  RedemptionRecord, RewardsRepository,
} from '../../src/rewards/repository.js';
import type { LedgerEntryType, OrderLineSnapshot, ProgramPolicy, RewardsLotState } from '../../src/rewards/types.js';
import { DEFAULT_PROGRAM } from '../../src/rewards/types.js';

interface Lot {
  id: number; accountId: string; sourceKind: string; sourceRef: string; ruleVersion: number;
  amountCents: number; remainingCents: number; reservedCents: number;
  state: RewardsLotState; releasedAt: Date | null; expiresAt: Date | null;
}

interface Movement extends MovementView { accountId: string; redemptionId: string | null; lotId: number | null }

/** Misma semantica que el pg (FIFO, idempotencia, sin sobregiro), solo memoria. */
export class InMemoryRewardsRepository implements RewardsRepository {
  private lots: Lot[] = [];
  private movements: Movement[] = [];
  private redemptions = new Map<string, RedemptionRecord & { allocations: { lotId: number; amountCents: number; state: string }[] }>();
  private quotes = new Map<string, QuoteRecord>();
  private snapshots = new Map<string, {
    accountId: string | null; isWholesale: boolean;
    pending: number; released: number; reversed: number; used: number;
  }>();
  private deliveryEvents = new Set<string>();
  private fulfillmentKinds = new Map<string, { kind: string; ref: string; at: Date | null }[]>();
  private inbox = new Set<string>();
  private seq = 1;
  policy: ProgramPolicy = { ...DEFAULT_PROGRAM };
  now: () => Date = () => new Date();

  async ensureAccount(): Promise<void> {}
  async getPolicy(): Promise<ProgramPolicy> { return this.policy; }

  async balance(accountId: string, now: Date = this.now()): Promise<BalanceView> {
    let avail = 0; let pend = 0; let resv = 0;
    let next: { cents: number; at: Date } | null = null;
    for (const l of this.lots) {
      if (l.accountId !== accountId) continue;
      if (l.state === 'pending') pend += l.remainingCents;
      if (l.state === 'available') {
        avail += l.remainingCents - l.reservedCents;
        resv += l.reservedCents;
        if (l.expiresAt && l.expiresAt > now && (next === null || l.expiresAt < next.at)) {
          next = { cents: l.remainingCents - l.reservedCents, at: l.expiresAt };
        }
      }
    }
    return { availableCents: avail, pendingCents: pend, reservedCents: resv, nextExpiry: next };
  }

  async activity(accountId: string, limit: number, cursor?: string | null): Promise<{ movements: MovementView[]; nextCursor: string | null }> {
    const after = cursor ? Number.parseInt(cursor, 10) : null;
    const rows = this.movements
      .filter((m) => m.accountId === accountId && (after === null || !Number.isFinite(after) || m.id < after))
      .sort((a, b) => b.id - afterNaN(a.id))
      .slice(0, Math.min(Math.max(limit, 1), 100) + 1);
    const page = rows.slice(0, Math.min(Math.max(limit, 1), 100));
    return {
      movements: page.map(stripAccount),
      nextCursor: rows.length > page.length ? String(page[page.length - 1]!.id) : null,
    };
    function afterNaN(_x: number): number { return 0; }
  }

  async orderRewards(accountId: string, orderShopifyId: string): Promise<OrderRewardsView | null> {
    const s = this.snapshots.get(orderShopifyId);
    if (!s || (s.accountId !== null && s.accountId !== accountId)) return null;
    const state = s.reversed > 0 && s.pending === 0 && s.released === 0
      ? 'reversed' : s.pending > 0 ? 'pending' : s.released > 0 ? 'available' : 'none';
    return {
      orderShopifyId, isWholesale: s.isWholesale,
      earnedPendingCents: s.pending, earnedReleasedCents: s.released,
      earnedReversedCents: s.reversed, usedCents: s.used, state,
    };
  }

  async earnPending(args: {
    accountId: string; orderShopifyId: string; amountCents: number;
    lines: readonly OrderLineSnapshot[]; isWholesale: boolean; signals: readonly string[];
    ruleVersion: number; eventRef: string; currency?: string;
  }): Promise<{ created: boolean; lotId: number | null }> {
    const snap = this.snapshots.get(args.orderShopifyId) ?? {
      accountId: null, isWholesale: false, pending: 0, released: 0, reversed: 0, used: 0,
    };
    snap.accountId = args.accountId;
    snap.isWholesale = args.isWholesale;
    this.snapshots.set(args.orderShopifyId, snap);
    if (args.isWholesale || args.amountCents <= 0) return { created: false, lotId: null };
    const dup = this.lots.find((l) =>
      l.accountId === args.accountId && l.sourceKind === 'order_earn' &&
      l.sourceRef === args.orderShopifyId && l.ruleVersion === args.ruleVersion);
    if (dup) return { created: false, lotId: dup.id };
    const lot: Lot = {
      id: this.seq++, accountId: args.accountId, sourceKind: 'order_earn',
      sourceRef: args.orderShopifyId, ruleVersion: args.ruleVersion,
      amountCents: args.amountCents, remainingCents: args.amountCents, reservedCents: 0,
      state: 'pending', releasedAt: null, expiresAt: null,
    };
    this.lots.push(lot);
    this.pushMovement({
      accountId: args.accountId, type: 'earn_pending', state: 'pending',
      amountCents: args.amountCents, orderShopifyId: args.orderShopifyId,
      reason: 'earn_pending', lotId: lot.id, redemptionId: null,
    });
    snap.pending += args.amountCents;
    // Fuera de orden: entrega previa libera de inmediato.
    const kinds = this.fulfillmentKinds.get(args.orderShopifyId) ?? [];
    const delivered = kinds.find((k) => k.kind === 'delivered');
    if (delivered) {
      const at = delivered.at ?? this.now();
      lot.state = 'available';
      lot.releasedAt = at;
      lot.expiresAt = expiryFromRelease(at, this.policy.expiryMonths);
      this.pushMovement({
        accountId: args.accountId, type: 'earn_released', state: 'available',
        amountCents: args.amountCents, orderShopifyId: args.orderShopifyId,
        reason: 'delivered_out_of_order', lotId: lot.id, redemptionId: null,
      });
      snap.pending -= args.amountCents;
      snap.released += args.amountCents;
    }
    return { created: true, lotId: lot.id };
  }

  async releaseForDelivery(args: {
    orderShopifyId: string; eventRef: string; occurredAt?: Date | null;
  }): Promise<{ releasedCents: number; lots: number }> {
    const key = `delivered:${args.orderShopifyId}:${args.eventRef}`;
    if (this.deliveryEvents.has(key)) return { releasedCents: 0, lots: 0 };
    this.deliveryEvents.add(key);
    const kinds = this.fulfillmentKinds.get(args.orderShopifyId) ?? [];
    kinds.push({ kind: 'delivered', ref: args.eventRef, at: args.occurredAt ?? this.now() });
    this.fulfillmentKinds.set(args.orderShopifyId, kinds);
    let released = 0; let n = 0;
    for (const lot of this.lots) {
      if (lot.sourceKind !== 'order_earn' || lot.sourceRef !== args.orderShopifyId || lot.state !== 'pending') continue;
      const at = args.occurredAt ?? this.now();
      lot.state = 'available';
      lot.releasedAt = at;
      lot.expiresAt = expiryFromRelease(at, this.policy.expiryMonths);
      this.pushMovement({
        accountId: lot.accountId, type: 'earn_released', state: 'available',
        amountCents: lot.remainingCents, orderShopifyId: args.orderShopifyId,
        reason: 'delivered', lotId: lot.id, redemptionId: null,
      });
      const snap = this.snapshots.get(args.orderShopifyId);
      if (snap) { snap.pending -= lot.remainingCents; snap.released += lot.remainingCents; }
      released += lot.remainingCents;
      n += 1;
    }
    return { releasedCents: released, lots: n };
  }

  async reverseEarn(args: {
    orderShopifyId: string; eventRef: string; kind: 'cancelled' | 'refund';
    reverseCents?: number | null; reason: string;
  }): Promise<{ reversedCents: number }> {
    const key = `${args.kind}:${args.orderShopifyId}:${args.eventRef}`;
    if (this.deliveryEvents.has(key)) return { reversedCents: 0 };
    this.deliveryEvents.add(key);
    let target = args.reverseCents ?? null;
    let reversed = 0;
    for (const lot of this.lots) {
      if (lot.sourceKind !== 'order_earn' || lot.sourceRef !== args.orderShopifyId) continue;
      if (lot.state !== 'pending' && lot.state !== 'available') continue;
      const free = lot.remainingCents - lot.reservedCents;
      if (free <= 0) continue;
      const take = target === null ? free : Math.min(free, target - reversed);
      if (take <= 0) break;
      lot.remainingCents -= take;
      if (lot.remainingCents === 0) lot.state = 'reversed';
      this.pushMovement({
        accountId: lot.accountId, type: 'earn_reversed', state: 'reversed',
        amountCents: -take, orderShopifyId: args.orderShopifyId,
        reason: args.reason, lotId: lot.id, redemptionId: null,
      });
      reversed += take;
      if (target !== null && reversed >= target) break;
    }
    const snap = this.snapshots.get(args.orderShopifyId);
    if (snap) {
      snap.reversed += reversed;
      snap.pending = Math.max(0, snap.pending - reversed);
    }
    return { reversedCents: reversed };
  }

  async createQuote(args: {
    accountId: string; cartRevision: string; subtotalEligibleCents: number;
    availableCents: number; maxAllowedCents: number; estimatedEarnCents: number;
    ruleVersion: number; ttlMinutes: number;
  }): Promise<QuoteRecord> {
    const record: QuoteRecord = {
      id: randomUUID(), accountId: args.accountId, cartRevision: args.cartRevision,
      subtotalEligibleCents: args.subtotalEligibleCents, availableCents: args.availableCents,
      maxAllowedCents: args.maxAllowedCents, estimatedEarnCents: args.estimatedEarnCents,
      ruleVersion: args.ruleVersion,
      expiresAt: new Date(this.now().getTime() + args.ttlMinutes * 60_000),
    };
    this.quotes.set(`${args.accountId}:${record.id}`, record);
    return record;
  }

  async findQuote(accountId: string, quoteId: string): Promise<QuoteRecord | null> {
    return this.quotes.get(`${accountId}:${quoteId}`) ?? null;
  }

  async reserve(args: {
    accountId: string; quoteId: string; cartRevision: string;
    subtotalEligibleCents: number; maxAllowedCents: number; requestedCents: number;
    idempotencyKey: string; ttlMinutes: number;
  }): Promise<{ redemption: RedemptionRecord; reused: boolean }> {
    for (const r of this.redemptions.values()) {
      if (r.accountId === args.accountId && r.idempotencyKey === args.idempotencyKey) {
        return { redemption: stripAlloc(r), reused: true };
      }
    }
    if (args.requestedCents > args.maxAllowedCents) {
      throw Object.assign(new Error('exceeds_limit'), { code: 'exceeds_limit' });
    }
    const now = this.now();
    const cands = this.lots
      .filter((l) => l.accountId === args.accountId && l.state === 'available' &&
        (!l.expiresAt || l.expiresAt > now))
      .sort((a, b) => {
        if (!a.expiresAt && !b.expiresAt) return a.id - b.id;
        if (!a.expiresAt) return 1;
        if (!b.expiresAt) return -1;
        return a.expiresAt.getTime() - b.expiresAt.getTime() || a.id - b.id;
      });
    let need = args.requestedCents;
    const picks: { lotId: number; take: number }[] = [];
    for (const lot of cands) {
      const free = lot.remainingCents - lot.reservedCents;
      if (free <= 0) continue;
      const take = Math.min(free, need);
      picks.push({ lotId: lot.id, take });
      need -= take;
      if (need <= 0) break;
    }
    if (need > 0) throw Object.assign(new Error('insufficient_balance'), { code: 'insufficient_balance' });
    const id = randomUUID();
    for (const p of picks) {
      this.lots.find((l) => l.id === p.lotId)!.reservedCents += p.take;
    }
    const record = {
      id, accountId: args.accountId, quoteId: args.quoteId, cartRevision: args.cartRevision,
      subtotalEligibleCents: args.subtotalEligibleCents, requestedCents: args.requestedCents,
      maxAllowedCents: args.maxAllowedCents, provisionedCents: 0, settledCents: 0,
      state: 'reserved' as const, shopifyDiscountId: null, shopifyDiscountCode: null,
      orderShopifyId: null, idempotencyKey: args.idempotencyKey,
      expiresAt: new Date(now.getTime() + args.ttlMinutes * 60_000),
      allocations: picks.map((p) => ({ lotId: p.lotId, amountCents: p.take, state: 'reserved' })),
    };
    this.redemptions.set(id, record);
    this.pushMovement({
      accountId: args.accountId, type: 'redeem_reserved', state: 'available',
      amountCents: -args.requestedCents, orderShopifyId: null,
      reason: 'reserve', lotId: null, redemptionId: id,
    });
    return { redemption: stripAlloc(record), reused: false };
  }

  async findRedemption(accountId: string, redemptionId: string): Promise<RedemptionRecord | null> {
    const r = this.redemptions.get(redemptionId);
    return r && r.accountId === accountId ? stripAlloc(r) : null;
  }

  async markProvisioning(redemptionId: string, discountId: string, discountCode: string): Promise<void> {
    const r = this.redemptions.get(redemptionId);
    if (r) {
      r.state = 'provisioning';
      (r as { shopifyDiscountId: string | null }).shopifyDiscountId = discountId;
      (r as { shopifyDiscountCode: string | null }).shopifyDiscountCode = discountCode;
    }
  }

  async markApplied(redemptionId: string): Promise<void> {
    const r = this.redemptions.get(redemptionId);
    if (r) r.state = 'applied';
  }

  async attachOrder(redemptionId: string, orderShopifyId: string): Promise<void> {
    const r = this.redemptions.get(redemptionId);
    if (r) {
      r.state = 'order_committed';
      (r as { orderShopifyId: string | null }).orderShopifyId = orderShopifyId;
    }
  }

  async settle(args: { redemptionId: string; appliedCents: number; orderShopifyId: string }): Promise<RedemptionRecord> {
    const r = this.redemptions.get(args.redemptionId);
    if (!r) throw Object.assign(new Error('not_found'), { code: 'not_found' });
    if (args.appliedCents > r.requestedCents) {
      r.state = 'reconciliation_required';
      return stripAlloc(r);
    }
    let remaining = args.appliedCents;
    for (const a of r.allocations) {
      const lot = this.lots.find((l) => l.id === a.lotId)!;
      const used = Math.min(a.amountCents, remaining);
      remaining -= used;
      lot.reservedCents -= a.amountCents;
      lot.remainingCents -= used;
      if (lot.remainingCents === 0) lot.state = 'used';
      a.state = used > 0 ? 'settled' : 'released';
    }
    r.state = 'settled';
    (r as { settledCents: number }).settledCents = args.appliedCents;
    (r as { provisionedCents: number }).provisionedCents = args.appliedCents;
    (r as { orderShopifyId: string | null }).orderShopifyId = args.orderShopifyId;
    this.pushMovement({
      accountId: r.accountId, type: 'redeem_settled', state: 'used',
      amountCents: -args.appliedCents, orderShopifyId: args.orderShopifyId,
      reason: 'settled', lotId: null, redemptionId: r.id,
    });
    const snap = this.snapshots.get(args.orderShopifyId);
    if (snap) snap.used += args.appliedCents;
    return stripAlloc(r);
  }

  async releaseReservation(redemptionId: string): Promise<RedemptionRecord> {
    const r = this.redemptions.get(redemptionId);
    if (!r) throw Object.assign(new Error('not_found'), { code: 'not_found' });
    if (r.state === 'settled') throw Object.assign(new Error('already_settled'), { code: 'already_settled' });
    for (const a of r.allocations) {
      if (a.state !== 'reserved') continue;
      this.lots.find((l) => l.id === a.lotId)!.reservedCents -= a.amountCents;
      a.state = 'released';
    }
    r.state = 'released';
    this.pushMovement({
      accountId: r.accountId, type: 'redeem_released', state: 'available',
      amountCents: r.requestedCents, orderShopifyId: null,
      reason: 'released', lotId: null, redemptionId: r.id,
    });
    return stripAlloc(r);
  }

  async markReconciliation(redemptionId: string): Promise<void> {
    const r = this.redemptions.get(redemptionId);
    if (r) r.state = 'reconciliation_required';
  }

  async expireDue(now: Date, limit = 500): Promise<{ expiredLots: number; expiredCents: number }> {
    let n = 0; let cents = 0;
    for (const lot of this.lots) {
      if (n >= limit) break;
      if (lot.state !== 'available' || !lot.expiresAt || lot.expiresAt > now) continue;
      const free = lot.remainingCents - lot.reservedCents;
      if (free <= 0) continue;
      lot.remainingCents = lot.reservedCents;
      if (lot.reservedCents === 0) lot.state = 'expired';
      this.pushMovement({
        accountId: lot.accountId, type: 'expired', state: 'expired',
        amountCents: -free, orderShopifyId: null, reason: 'expiry_12m',
        lotId: lot.id, redemptionId: null,
      });
      cents += free;
      n += 1;
    }
    return { expiredLots: n, expiredCents: cents };
  }

  async abandonedReservations(now: Date): Promise<RedemptionRecord[]> {
    return [...this.redemptions.values()]
      .filter((r) => ['reserved', 'provisioning', 'applied'].includes(r.state) && r.expiresAt <= now)
      .map(stripAlloc);
  }

  async inboxClaim(eventId: string): Promise<boolean> {
    if (this.inbox.has(eventId)) return false;
    this.inbox.add(eventId);
    return true;
  }

  async inboxDone(): Promise<void> {}
  async pendingInbox(): Promise<{ eventId: string; topic: string; payload: unknown; orderShopifyId: string | null }[]> {
    return [];
  }
  async outboxEnqueue(): Promise<void> {}

  // --- helpers de prueba ---
  lotCount(): number { return this.lots.length; }

  private pushMovement(m: Omit<Movement, 'id' | 'createdAt'>): void {
    const id = this.seq++;
    this.movements.push({ ...m, id, createdAt: this.now() });
  }
}

function stripAccount(m: Movement): MovementView {
  return {
    id: m.id, type: m.type as LedgerEntryType, state: m.state,
    amountCents: m.amountCents, orderShopifyId: m.orderShopifyId,
    reason: m.reason, createdAt: m.createdAt,
  };
}

function stripAlloc(r: RedemptionRecord & { allocations: unknown }): RedemptionRecord {
  const { allocations: _ignored, ...rest } = r;
  void _ignored;
  return rest;
}

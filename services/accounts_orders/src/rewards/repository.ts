import type {
  LedgerEntryType, OrderLineSnapshot, ProgramPolicy, RedemptionState, RewardsLotState,
} from './types.js';

/** Puertos del ledger. La implementacion pg es la autoridad; la memoria es solo tests. */

export interface LotRecord {
  readonly id: number;
  readonly accountId: string;
  readonly sourceKind: string;
  readonly sourceRef: string;
  readonly ruleVersion: number;
  readonly amountCents: number;
  readonly remainingCents: number;
  readonly reservedCents: number;
  readonly state: RewardsLotState;
  readonly releasedAt: Date | null;
  readonly expiresAt: Date | null;
}

export interface RedemptionRecord {
  readonly id: string;
  readonly accountId: string;
  readonly quoteId: string;
  readonly cartRevision: string;
  readonly subtotalEligibleCents: number;
  readonly requestedCents: number;
  readonly maxAllowedCents: number;
  readonly provisionedCents: number;
  readonly settledCents: number;
  readonly state: RedemptionState;
  readonly shopifyDiscountId: string | null;
  readonly shopifyDiscountCode: string | null;
  readonly orderShopifyId: string | null;
  readonly idempotencyKey: string;
  readonly expiresAt: Date;
}

export interface BalanceView {
  readonly availableCents: number;
  readonly pendingCents: number;
  readonly reservedCents: number;
  readonly nextExpiry: { readonly cents: number; readonly at: Date } | null;
}

export interface MovementView {
  readonly id: number;
  readonly type: LedgerEntryType;
  readonly state: RewardsLotState;
  readonly amountCents: number;
  readonly orderShopifyId: string | null;
  readonly reason: string | null;
  readonly createdAt: Date;
  readonly releasedAt?: Date | null;
  readonly expiresAt?: Date | null;
}

export interface OrderRewardsView {
  readonly orderShopifyId: string;
  readonly isWholesale: boolean;
  readonly earnedPendingCents: number;
  readonly earnedReleasedCents: number;
  readonly earnedReversedCents: number;
  readonly usedCents: number;
  readonly state: 'pending' | 'available' | 'reversed' | 'none' | 'partial';
}

export interface QuoteRecord {
  readonly id: string;
  readonly accountId: string;
  readonly cartRevision: string;
  readonly subtotalEligibleCents: number;
  readonly availableCents: number;
  readonly maxAllowedCents: number;
  readonly estimatedEarnCents: number;
  readonly ruleVersion: number;
  readonly expiresAt: Date;
}

export interface RewardsRepository {
  ensureAccount(customerId: string, shopDomain?: string | null): Promise<void>;
  getPolicy(): Promise<ProgramPolicy>;
  balance(accountId: string, now?: Date): Promise<BalanceView>;
  activity(accountId: string, limit: number, cursor?: string | null): Promise<{ movements: MovementView[]; nextCursor: string | null }>;
  orderRewards(accountId: string, orderShopifyId: string): Promise<OrderRewardsView | null>;

  /** Emision de ganancia pendiente (idempotente por cuenta+origen+regla). Retorna false si ya existia. */
  earnPending(args: {
    accountId: string; orderShopifyId: string; amountCents: number;
    lines: readonly OrderLineSnapshot[]; isWholesale: boolean; signals: readonly string[];
    ruleVersion: number; eventRef: string; currency?: string;
  }): Promise<{ created: boolean; lotId: number | null }>;

  /** Liberacion tras entrega verificada (idempotente por evento). */
  releaseForDelivery(args: {
    orderShopifyId: string; eventRef: string; occurredAt?: Date | null;
    lines?: readonly { quantity?: number }[];
  }): Promise<{ releasedCents: number; lots: number }>;

  /** Reversion (cancelacion/devolucion). Aplica diferencia, no recalcula sobre bruto. */
  reverseEarn(args: {
    orderShopifyId: string; eventRef: string; kind: 'cancelled' | 'refund';
    reverseCents?: number | null; reason: string; operator?: string;
  }): Promise<{ reversedCents: number }>;

  createQuote(args: {
    accountId: string; cartRevision: string; subtotalEligibleCents: number;
    availableCents: number; maxAllowedCents: number; estimatedEarnCents: number;
    ruleVersion: number; ttlMinutes: number;
  }): Promise<QuoteRecord>;
  findQuote(accountId: string, quoteId: string): Promise<QuoteRecord | null>;

  /** Reserva transaccional FIFO (lotes que vencen primero). Idempotente por (cuenta, clave). */
  reserve(args: {
    accountId: string; quoteId: string; cartRevision: string;
    subtotalEligibleCents: number; maxAllowedCents: number; requestedCents: number;
    idempotencyKey: string; ttlMinutes: number;
  }): Promise<{ redemption: RedemptionRecord; reused: boolean }>;
  findRedemption(accountId: string, redemptionId: string): Promise<RedemptionRecord | null>;
  markProvisioning(redemptionId: string, discountId: string, discountCode: string): Promise<void>;
  markApplied(redemptionId: string): Promise<void>;
  attachOrder(redemptionId: string, orderShopifyId: string): Promise<void>;
  /** Confirma lo realmente aplicado en Shopify; exceso -> reconciliation_required. */
  settle(args: { redemptionId: string; appliedCents: number; orderShopifyId: string }): Promise<RedemptionRecord>;
  releaseReservation(redemptionId: string): Promise<RedemptionRecord>;
  markReconciliation(redemptionId: string, reason: string): Promise<void>;

  /** Expiracion + reservas abandonadas para el worker. */
  expireDue(now: Date, limit?: number): Promise<{ expiredLots: number; expiredCents: number }>;
  abandonedReservations(now: Date, limit?: number): Promise<RedemptionRecord[]>;

  // Inbox/outbox duraderos.
  inboxClaim(eventId: string, topic: string, payload: unknown, orderId?: string | null, accountId?: string | null): Promise<boolean>;
  inboxDone(eventId: string, ok: boolean, error?: string): Promise<void>;
  pendingInbox(limit?: number): Promise<{ eventId: string; topic: string; payload: unknown; orderShopifyId: string | null }[]>;
  outboxEnqueue(kind: string, payload: unknown, accountId?: string | null): Promise<void>;
}

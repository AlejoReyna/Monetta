/** Contrato interno Rewards V1. El contrato HTTP versionado vive en docs/redesign/REWARDS_CONTRACT_V1.md. */

export type RewardsLotState = 'pending' | 'available' | 'used' | 'expired' | 'reversed';

export type RedemptionState =
  | 'quoted' | 'reserved' | 'provisioning' | 'applied' | 'order_committed'
  | 'settled' | 'releasing' | 'released' | 'reconciliation_required';

export type LedgerEntryType =
  | 'earn_pending' | 'earn_released' | 'earn_reversed'
  | 'redeem_reserved' | 'redeem_settled' | 'redeem_released'
  | 'expired' | 'adjustment'
  | 'bonus_pending' | 'bonus_released' | 'bonus_reversed';

export interface ProgramPolicy {
  readonly version: number;
  readonly currency: 'MXN';
  /** 300 = 3%. */
  readonly earnBps: number;
  /** 2000 = 20%. */
  readonly maxRedeemBps: number;
  readonly expiryMonths: number;
  readonly wholesaleEarns: boolean;
  /** null = decision pendiente (uso en mayoreo sin definir) -> canje bloqueado en mayoreo. */
  readonly wholesaleRedeemAllowed: boolean | null;
  readonly redemptionEnabled: boolean;
  readonly firstPurchaseEnabled: boolean;
  readonly firstPurchaseAmountCents: number;
  readonly reviewEnabled: boolean;
  readonly reviewAmountCents: number;
  readonly referralEnabled: boolean;
  readonly referralAmountCents: number;
}

export const DEFAULT_PROGRAM: ProgramPolicy = {
  version: 1,
  currency: 'MXN',
  earnBps: 300,
  maxRedeemBps: 2000,
  expiryMonths: 12,
  wholesaleEarns: false,
  wholesaleRedeemAllowed: null,
  redemptionEnabled: false,
  firstPurchaseEnabled: false,
  firstPurchaseAmountCents: 5000,
  reviewEnabled: false,
  reviewAmountCents: 2000,
  referralEnabled: false,
  referralAmountCents: 5000,
};

export interface CartLineInput {
  readonly variantId?: string;
  readonly productId?: string;
  readonly quantity: number;
  /** Precio unitario en centavos (lista o con descuento comercial ya aplicado segun politica). */
  readonly unitPriceCents: number;
  /** Descuento comercial de la linea en centavos (promos, sin incluir Rewards). */
  readonly discountCents?: number;
  /** Elegibilidad por linea; por defecto elegible. */
  readonly eligible?: boolean;
}

export interface QuoteInput {
  readonly cartRevision: string;
  readonly lines: readonly CartLineInput[];
  /** Subtotal declarado por el cliente (solo auditoria; el servidor recalcula). */
  readonly declaredSubtotalCents?: number;
  /** true cuando el carrito es de mayoreo (el servidor tambien lo deriva de señales). */
  readonly isWholesaleCart?: boolean;
}

export interface OrderLineSnapshot {
  readonly variantId?: string | null;
  readonly productId?: string | null;
  readonly quantity: number;
  readonly unitPriceCents: number;
  readonly discountCents: number;
  readonly eligible: boolean;
  readonly lineEligibleCents: number;
}

import type { SourceId } from '../domain/types.js';

export interface RetailPricingPolicy {
  readonly usdToMxnRate: number | null;
  readonly defaultCommissionBps: number;
  readonly highValueThresholdMxn: number;
  readonly highValueCommissionBps: number;
  readonly sourceCommissionBps: Readonly<Partial<Record<SourceId, number>>>;
  /** Keys use the API identity, for example `coach_us:CU068`. */
  readonly productCommissionBps: Readonly<Record<string, number>>;
}

export const DEFAULT_RETAIL_PRICING_POLICY: RetailPricingPolicy = {
  // Intentionally absent: deployments must provide a current rate instead
  // of silently shipping a stale exchange rate in source control.
  usdToMxnRate: null,
  defaultCommissionBps: 2200,
  highValueThresholdMxn: 4000,
  highValueCommissionBps: 1400,
  sourceCommissionBps: {},
  productCommissionBps: {},
};

export type CommissionRule =
  | 'product_override'
  | 'high_value'
  | 'source_override'
  | 'default';

export interface RetailPriceQuote {
  readonly sourceCostMxn: number;
  readonly commissionRate: number;
  readonly commissionAmountMxn: number;
  readonly suggestedRetailPriceMxn: number;
  readonly usdToMxnRate: number;
  readonly rule: CommissionRule;
}

function money(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export function quoteRetailPrice(
  sourceId: SourceId,
  externalId: string,
  sourcePriceUsd: number | null,
  policy: RetailPricingPolicy,
): RetailPriceQuote | null {
  if (
    sourcePriceUsd === null ||
    sourcePriceUsd <= 0 ||
    policy.usdToMxnRate === null ||
    policy.usdToMxnRate <= 0
  ) {
    return null;
  }

  const sourceCostMxn = money(sourcePriceUsd * policy.usdToMxnRate);
  const scopedId = `${sourceId}:${externalId}`;
  const productOverride = policy.productCommissionBps[scopedId];
  const sourceOverride = policy.sourceCommissionBps[sourceId];

  let commissionBps: number;
  let rule: CommissionRule;
  if (productOverride !== undefined) {
    commissionBps = productOverride;
    rule = 'product_override';
  } else if (sourceCostMxn > policy.highValueThresholdMxn) {
    commissionBps = policy.highValueCommissionBps;
    rule = 'high_value';
  } else if (sourceOverride !== undefined) {
    commissionBps = sourceOverride;
    rule = 'source_override';
  } else {
    commissionBps = policy.defaultCommissionBps;
    rule = 'default';
  }

  const commissionRate = commissionBps / 10_000;
  const commissionAmountMxn = money(sourceCostMxn * commissionRate);
  return {
    sourceCostMxn,
    commissionRate,
    commissionAmountMxn,
    suggestedRetailPriceMxn: money(sourceCostMxn + commissionAmountMxn),
    usdToMxnRate: policy.usdToMxnRate,
    rule,
  };
}

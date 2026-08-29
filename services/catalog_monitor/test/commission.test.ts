import { describe, expect, it } from 'vitest';
import { quoteRetailPrice, type RetailPricingPolicy } from '../src/pricing/commission.js';

const policy: RetailPricingPolicy = {
  usdToMxnRate: 20,
  defaultCommissionBps: 2200,
  highValueThresholdMxn: 4000,
  highValueCommissionBps: 1400,
  sourceCommissionBps: { kate_spade_us: 1800 },
  productCommissionBps: { 'coach_us:SPECIAL': 900 },
};

describe('quoteRetailPrice', () => {
  it('uses the default rate below the high-value threshold', () => {
    expect(quoteRetailPrice('coach_us', 'A1', 100, policy)).toEqual({
      sourceCostMxn: 2000,
      commissionRate: 0.22,
      commissionAmountMxn: 440,
      suggestedRetailPriceMxn: 2440,
      usdToMxnRate: 20,
      rule: 'default',
    });
  });

  it('uses the lower rate only when the base cost exceeds MXN 4,000', () => {
    expect(quoteRetailPrice('coach_us', 'AT-THRESHOLD', 200, policy)?.rule).toBe('default');
    expect(quoteRetailPrice('coach_us', 'OVER', 200.01, policy)).toMatchObject({
      commissionRate: 0.14,
      rule: 'high_value',
    });
  });

  it('supports source and product-specific overrides', () => {
    expect(quoteRetailPrice('kate_spade_us', 'A1', 100, policy)?.commissionRate).toBe(0.18);
    expect(quoteRetailPrice('coach_us', 'SPECIAL', 300, policy)).toMatchObject({
      commissionRate: 0.09,
      rule: 'product_override',
    });
  });

  it('returns null without a configured exchange rate or source price', () => {
    expect(quoteRetailPrice('coach_us', 'A1', null, policy)).toBeNull();
    expect(
      quoteRetailPrice('coach_us', 'A1', 100, { ...policy, usdToMxnRate: null }),
    ).toBeNull();
  });
});

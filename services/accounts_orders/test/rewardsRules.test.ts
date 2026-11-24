import { describe, expect, it } from 'vitest';
import { formatMonettaShort } from '../src/rewards/money.js';
import {
  detectWholesale, eligibleSubtotal, estimatedEarnCents, expiryFromRelease,
  maxRedeemableCents, redemptionEligibility, resolveTier, tierBonusesUnlocked,
} from '../src/rewards/rules.js';
import { DEFAULT_PROGRAM } from '../src/rewards/types.js';

describe('rewards rules (paquete F)', () => {
  it('3% sobre base elegible neta, en centavos enteros', () => {
    // Compra $1,800 elegible -> $54 pendientes.
    expect(estimatedEarnCents({ subtotalEligibleCents: 180000, redeemCents: 0, earnBps: 300 })).toBe(5400);
    // Con saldo $184 y subtotal $900: maximo $180, quedan $4; nueva compra genera sobre base neta.
    expect(maxRedeemableCents({ subtotalEligibleCents: 90000, availableCents: 18400, maxRedeemBps: 2000 })).toBe(18000);
    expect(estimatedEarnCents({ subtotalEligibleCents: 90000, redeemCents: 18000, earnBps: 300 })).toBe(2160);
  });

  it('excluye descuentos comerciales y lineas no elegibles del subtotal', () => {
    const b = eligibleSubtotal([
      { quantity: 1, unitPriceCents: 100000, discountCents: 20000, eligible: true },
      { quantity: 1, unitPriceCents: 50000, eligible: false },
    ]);
    expect(b.subtotalEligibleCents).toBe(80000);
    expect(b.ineligibleCents).toBe(50000);
  });

  it('tope 20%: min(disponible, floor(S*20%))', () => {
    expect(maxRedeemableCents({ subtotalEligibleCents: 901, availableCents: 100000, maxRedeemBps: 2000 })).toBe(180);
    expect(maxRedeemableCents({ subtotalEligibleCents: 90000, availableCents: 400, maxRedeemBps: 2000 })).toBe(400);
    expect(maxRedeemableCents({ subtotalEligibleCents: 0, availableCents: 5000, maxRedeemBps: 2000 })).toBe(0);
  });

  it('vigencia 12 meses calendario con fin de mes recortado', () => {
    const release = new Date(Date.UTC(2026, 0, 31, 12, 0, 0));
    const expiry = expiryFromRelease(release, 12);
    expect(expiry.toISOString()).toBe('2027-01-31T12:00:00.000Z');
    const feb = expiryFromRelease(new Date(Date.UTC(2025, 7, 31)), 6);
    expect(feb.toISOString().slice(0, 10)).toBe('2026-02-28');
  });

  it('mayoreo se detecta por señales comerciales verificables, no por el telefono', () => {
    expect(detectWholesale({ tags: ['Mayoreo'] }).isWholesale).toBe(true);
    expect(detectWholesale({ discountCodes: ['WHOLESALE10'] }).isWholesale).toBe(true);
    expect(detectWholesale({ tags: ['nuevo', 'bolsas'] }).isWholesale).toBe(false);
    expect(detectWholesale({}).isWholesale).toBe(false);
  });

  it('canje en mayoreo permitido con programa confirmado y bloqueado si sigue pendiente', () => {
    const allowed = redemptionEligibility({
      policy: { ...DEFAULT_PROGRAM, redemptionEnabled: true },
      isWholesaleCart: true, requestedCents: 1000, maxAllowedCents: 5000,
    });
    expect(allowed.ok).toBe(true);

    const pending = redemptionEligibility({
      policy: { ...DEFAULT_PROGRAM, redemptionEnabled: true, wholesaleRedeemAllowed: null },
      isWholesaleCart: true, requestedCents: 1000, maxAllowedCents: 5000,
    });
    expect(pending.ok).toBe(false);
  });

  it('canje deshabilitado tras bandera apagada', () => {
    const r = redemptionEligibility({
      policy: { ...DEFAULT_PROGRAM, redemptionEnabled: false },
      isWholesaleCart: false, requestedCents: 100, maxAllowedCents: 5000,
    });
    expect(r).toEqual(expect.objectContaining({ ok: false }));
  });

  it('presentacion en pesos: "Tienes $184 Monetta disponibles"', () => {
    expect(formatMonettaShort(18400)).toBe('$184 Monetta');
  });

  it('resuelve niveles PRO (1%), VIP (2%) y ÉLITE (3%) sobre 10 compras y bonos', () => {
    expect(resolveTier(0)).toMatchObject({
      level: 'PRO', nextLevel: 'VIP', isFinalLevel: false,
      progressPercent: 0, purchaseCountLabel: '0 de 10 compras', cashbackBps: 100, bonusCents: 10000,
    });
    expect(resolveTier(4)).toMatchObject({
      level: 'PRO', nextLevel: 'VIP', isFinalLevel: false,
      progressPercent: 40, purchaseCountLabel: '4 de 10 compras', cashbackBps: 100,
    });
    expect(resolveTier(5)).toMatchObject({
      level: 'VIP', nextLevel: 'ÉLITE', isFinalLevel: false,
      progressPercent: 50, purchaseCountLabel: '5 de 10 compras', cashbackBps: 200, bonusCents: 10000,
    });
    expect(resolveTier(9)).toMatchObject({
      level: 'VIP', nextLevel: 'ÉLITE', isFinalLevel: false,
      progressPercent: 90, purchaseCountLabel: '9 de 10 compras', cashbackBps: 200,
    });
    expect(resolveTier(10)).toMatchObject({
      level: 'ÉLITE', nextLevel: null, isFinalLevel: true,
      progressPercent: 100, cashbackBps: 300, bonusCents: 20000,
    });
    expect(resolveTier(12).progressFraction).toBe(1);
    expect(tierBonusesUnlocked(0)).toEqual([]);
    expect(tierBonusesUnlocked(1)).toEqual([{ tierKey: 'PRO', amountCents: 10000 }]);
    expect(tierBonusesUnlocked(5)).toEqual([
      { tierKey: 'PRO', amountCents: 10000 },
      { tierKey: 'VIP', amountCents: 10000 },
    ]);
    expect(tierBonusesUnlocked(10)).toEqual([
      { tierKey: 'PRO', amountCents: 10000 },
      { tierKey: 'VIP', amountCents: 10000 },
      { tierKey: 'ÉLITE', amountCents: 20000 },
    ]);
  });
});

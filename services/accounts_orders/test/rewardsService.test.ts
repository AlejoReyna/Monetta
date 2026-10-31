import { beforeEach, describe, expect, it } from 'vitest';
import { loadRewardsEnv } from '../src/rewards/rewardsConfig.js';
import type { RewardsEnv } from '../src/rewards/rewardsConfig.js';
import { RewardsService } from '../src/rewards/service.js';
import { DisabledDiscountAdapter } from '../src/rewards/shopifyDiscountAdapter.js';
import { InMemoryRewardsRepository } from './support/inMemoryRewardsRepository.js';

const CUSTOMER = '1001';
const ORDER = '9001';

function serviceWith(repo?: InMemoryRewardsRepository, env?: RewardsEnv): { service: RewardsService; repo: InMemoryRewardsRepository } {
  const r = repo ?? new InMemoryRewardsRepository();
  const e = env ?? { ...loadRewardsEnv({} as NodeJS.ProcessEnv), rewardsEnabled: true, redemptionEnabled: true };
  return { service: new RewardsService({ rewards: r, env: e, discounts: new DisabledDiscountAdapter() }), repo: r };
}

const LINES = [{ quantity: 1, unitPriceCents: 180000, discountCents: 0, eligible: true }];

describe('rewards service (paquete F)', () => {
  let service: RewardsService;
  let repo: InMemoryRewardsRepository;

  beforeEach(() => {
    ({ service, repo } = serviceWith());
  });

  async function paid(orderId = ORDER, eventId = `ev:paid:${orderId}`, customerId = CUSTOMER) {
    return service.onOrderPaid({
      eventId, orderShopifyId: orderId, accountId: customerId,
      subtotalEligibleCents: 180000, lines: LINES, isWholesale: false, signals: [],
    });
  }

  it('emision unica frente a eventos duplicados', async () => {
    await paid();
    const again = await paid(ORDER, `ev:paid:${ORDER}`);
    expect(again.earned).toBe(false);
    expect(repo.lotCount()).toBe(1);
    const summary = await service.summary(CUSTOMER);
    expect(summary.balance.pendingCents).toBe(5400);
  });

  it('pendiente hasta entrega verificada; preparado/enviado no libera', async () => {
    await paid();
    // Sin evento DELIVERED no hay liberacion: el resumen sigue pendiente.
    let summary = await service.summary(CUSTOMER);
    expect(summary.balance.pendingCents).toBe(5400);
    expect(summary.balance.availableCents).toBe(0);
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    summary = await service.summary(CUSTOMER);
    expect(summary.balance.pendingCents).toBe(0);
    expect(summary.balance.availableCents).toBe(5400);
  });

  it('entrega duplicada no duplica saldo', async () => {
    await paid();
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    const again = await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    expect(again.releasedCents).toBe(0);
    expect((await service.summary(CUSTOMER)).balance.availableCents).toBe(5400);
  });

  it('eventos fuera de orden: entrega antes que pago libera al llegar el pago', async () => {
    await service.onOrderDelivered({ eventId: 'ev:del:early', orderShopifyId: '555' });
    await service.onOrderPaid({
      eventId: 'ev:paid:555', orderShopifyId: '555', accountId: CUSTOMER,
      subtotalEligibleCents: 180000, lines: LINES, isWholesale: false, signals: [],
    });
    const summary = await service.summary(CUSTOMER);
    expect(summary.balance.availableCents).toBe(5400);
    expect(summary.balance.pendingCents).toBe(0);
  });

  it('cancelacion y reembolso del mismo pedido no revierten dos veces', async () => {
    await paid();
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    const c = await service.onOrderCancelled({ eventId: 'ev:cancel:1', orderShopifyId: ORDER });
    expect(c.reversedCents).toBe(5400);
    const r = await service.onRefund({ eventId: 'ev:refund:1', orderShopifyId: ORDER, reverseCents: 5400 });
    expect(r.reversedCents).toBe(0);
    expect((await service.summary(CUSTOMER)).balance.availableCents).toBe(0);
  });

  it('devolucion parcial revierte solo la diferencia (3% de lo reembolsado)', async () => {
    await paid();
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    // Devuelven $600 de $1,800 -> reversa $18.
    const r = await service.onRefund({ eventId: 'ev:refund:p', orderShopifyId: ORDER, reverseCents: 1800 });
    expect(r.reversedCents).toBe(1800);
    expect((await service.summary(CUSTOMER)).balance.availableCents).toBe(3600);
  });

  it('mayoreo no genera Rewards', async () => {
    await service.onOrderPaid({
      eventId: 'ev:paid:ws', orderShopifyId: 'WS1', accountId: CUSTOMER,
      subtotalEligibleCents: 500000, lines: [{ quantity: 5, unitPriceCents: 100000, eligible: true }],
      isWholesale: true, signals: ['tag:mayoreo'],
    });
    expect((await service.summary(CUSTOMER)).balance.pendingCents).toBe(0);
    expect((await service.summary(CUSTOMER)).balance.availableCents).toBe(0);
  });

  it('limite 20% y cambios de carrito: cotizacion menor invalida el monto anterior', async () => {
    await paid();
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    const q = await service.quote(CUSTOMER, {
      cartRevision: 'rev-1',
      lines: [{ quantity: 1, unitPriceCents: 90000, eligible: true }],
    });
    expect(q.maxAllowedCents).toBe(5400); // min(5400 disp, 18000)
    await expect(service.redeem({
      accountId: CUSTOMER, quoteId: q.quoteId, amountCents: 5401, isWholesaleCart: false, idempotencyKey: 'k-1-ok-12',
    })).rejects.toMatchObject({ code: 'exceeds_limit' });
  });

  it('canjes concurrentes (doble toque) no sobregiran: misma clave reutiliza', async () => {
    await paid();
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    const q = await service.quote(CUSTOMER, {
      cartRevision: 'rev-1',
      lines: [{ quantity: 2, unitPriceCents: 90000, eligible: true }],
    });
    const first = await service.redeem({
      accountId: CUSTOMER, quoteId: q.quoteId, amountCents: 5400, isWholesaleCart: false, idempotencyKey: 'same-key-1',
    });
    const second = await service.redeem({
      accountId: CUSTOMER, quoteId: q.quoteId, amountCents: 5400, isWholesaleCart: false, idempotencyKey: 'same-key-1',
    });
    expect(second.reused).toBe(true);
    expect(second.redemption.redemptionId).toBe(first.redemption.redemptionId);
    await expect(service.redeem({
      accountId: CUSTOMER, quoteId: q.quoteId, amountCents: 1, isWholesaleCart: false, idempotencyKey: 'other-key-2',
    })).rejects.toMatchObject({ code: 'insufficient_balance' });
  });

  it('expiracion a 12 meses: saldo vencido no se ofrece', async () => {
    await paid();
    const deliveredAt = new Date('2025-01-15T12:00:00Z');
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER, occurredAt: deliveredAt });
    // 12 meses despues + 1 dia: expira.
    const expired = await repo.expireDue(new Date('2026-01-16T12:00:00Z'));
    expect(expired.expiredCents).toBe(5400);
    expect((await service.summary(CUSTOMER)).balance.availableCents).toBe(0);
  });

  it('reservas abandonadas se liberan y quedan disponibles de nuevo', async () => {
    await paid();
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    const q = await service.quote(CUSTOMER, {
      cartRevision: 'rev-1',
      lines: [{ quantity: 2, unitPriceCents: 90000, eligible: true }],
    });
    const { redemption } = await service.redeem({
      accountId: CUSTOMER, quoteId: q.quoteId, amountCents: 5000, isWholesaleCart: false, idempotencyKey: 'abandon-12',
    });
    // Reserva viva: disponible neto 400.
    expect((await service.summary(CUSTOMER)).balance.availableCents).toBe(400);
    await service.releaseRedemption(CUSTOMER, redemption.redemptionId);
    expect((await service.summary(CUSTOMER)).balance.availableCents).toBe(5400);
  });

  it('separacion entre cuentas: el saldo de una no financia a otra', async () => {
    await paid(ORDER, 'ev:paid:1', 'AAA');
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: ORDER });
    const q = await service.quote('BBB', {
      cartRevision: 'rev-b', lines: [{ quantity: 1, unitPriceCents: 90000, eligible: true }],
    });
    expect(q.maxAllowedCents).toBe(0);
    await expect(service.redeem({
      accountId: 'BBB', quoteId: q.quoteId, amountCents: 100, isWholesaleCart: false, idempotencyKey: 'bbb-key-12',
    })).rejects.toMatchObject({ code: 'exceeds_limit' });
  });

  it('incentivos sin definicion permanecen deshabilitados', async () => {
    const summary = await service.summary(CUSTOMER);
    expect(summary.incentives.firstPurchase.enabled).toBe(false);
    expect(summary.incentives.review.enabled).toBe(false);
    expect(summary.incentives.referral.enabled).toBe(false);
  });

  it('canje deshabilitado tras bandera: quotes informan, redemptions bloquean', async () => {
    const off = serviceWith(undefined, {
      ...loadRewardsEnv({} as NodeJS.ProcessEnv), rewardsEnabled: true, redemptionEnabled: false,
    });
    const q = await off.service.quote(CUSTOMER, {
      cartRevision: 'rev-1', lines: [{ quantity: 1, unitPriceCents: 90000, eligible: true }],
    });
    expect(q.redemptionEnabled).toBe(false);
    await expect(off.service.redeem({
      accountId: CUSTOMER, quoteId: q.quoteId, amountCents: 100, isWholesaleCart: false, idempotencyKey: 'off-key-12',
    })).rejects.toMatchObject({ code: 'redemption_disabled' });
  });
});

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { randomUUID } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import pg from 'pg';
import { PgRewardsRepository } from '../src/rewards/pgRewardsRepository.js';
import { RewardsService } from '../src/rewards/service.js';
import { DisabledDiscountAdapter } from '../src/rewards/shopifyDiscountAdapter.js';

const adminUrl = process.env.WP01_PG_ADMIN_URL ?? `postgres://${process.env.USER}@localhost:5432/postgres`;
const admin = new pg.Client({ connectionString: adminUrl });
let available = false;
try { await admin.connect(); available = true; } catch { /* optional local run */ }
if (!available && (process.env.CI || process.env.REQUIRE_POSTGRES_TESTS === '1')) throw new Error('PostgreSQL required');
const name = `monetta_rewards_${randomUUID().replaceAll('-', '')}`;

describe.skipIf(!available)('rewards ledger on PostgreSQL (paquete F)', () => {
  let pool: pg.Pool;
  let repo: PgRewardsRepository;
  let service: RewardsService;

  beforeAll(async () => {
    await admin.query(`CREATE DATABASE ${name}`);
    const url = new URL(adminUrl); url.pathname = `/${name}`;
    pool = new pg.Pool({ connectionString: url.toString() });
    const migrations = new URL('../src/db/migrations/', import.meta.url);
    for (const file of readdirSync(migrations).filter((f) => f.endsWith('.sql')).sort()) {
      await pool.query(readFileSync(new URL(file, migrations), 'utf8'));
    }
    repo = new PgRewardsRepository(pool);
    service = new RewardsService({
      rewards: repo,
      env: { rewardsEnabled: true, redemptionEnabled: true, reservationTtlMinutes: 30, quoteTtlMinutes: 10 },
      discounts: new DisabledDiscountAdapter(),
    });
  }, 60_000);

  afterAll(async () => {
    if (pool) await pool.end();
    await admin.query(`DROP DATABASE IF EXISTS ${name}`);
    await admin.end();
  });

  it('earn pendiente -> liberacion DELIVERED -> reserva -> settle parcial verificado', async () => {
    const customer = 'pg-cust-1';
    const order = `pg-order-${randomUUID().slice(0, 8)}`;
    const earned = await service.onOrderPaid({
      eventId: `ev:${order}:paid`, orderShopifyId: order, accountId: customer,
      subtotalEligibleCents: 180000,
      lines: [{ quantity: 1, unitPriceCents: 180000, eligible: true }],
      isWholesale: false, signals: [],
    });
    expect(earned.earned).toBe(true);
    // Duplicado no emite dos veces.
    expect((await service.onOrderPaid({
      eventId: `ev:${order}:paid`, orderShopifyId: order, accountId: customer,
      subtotalEligibleCents: 180000,
      lines: [{ quantity: 1, unitPriceCents: 180000, eligible: true }],
      isWholesale: false, signals: [],
    })).earned).toBe(false);

    const rel = await service.onOrderDelivered({ eventId: `ev:${order}:del`, orderShopifyId: order });
    expect(rel.releasedCents).toBe(5400);

    const q = await service.quote(customer, {
      cartRevision: 'rev-pg-1',
      lines: [{ quantity: 1, unitPriceCents: 90000, eligible: true }],
    });
    expect(q.maxAllowedCents).toBe(5400);

    const { redemption } = await service.redeem({
      accountId: customer, quoteId: q.quoteId, amountCents: 5400,
      isWholesaleCart: false, idempotencyKey: `pg-key-${order}`,
    });
    expect(redemption.state).toBe('reserved');

    // Shopify aplico menos (carrito editado): se consume lo real.
    const settled = await repo.settle({ redemptionId: redemption.redemptionId, appliedCents: 5000, orderShopifyId: `pg-new-${order}` });
    expect(settled.state).toBe('settled');
    expect(settled.settledCents).toBe(5000);
    const balance = await repo.balance(customer);
    expect(balance.availableCents).toBe(400);
  });

  it('exceso sobre la reserva marca reconciliacion, no saldo negativo sorpresa', async () => {
    const customer = 'pg-cust-2';
    const order = `pg-order-${randomUUID().slice(0, 8)}`;
    await service.onOrderPaid({
      eventId: `ev:${order}:paid`, orderShopifyId: order, accountId: customer,
      subtotalEligibleCents: 100000,
      lines: [{ quantity: 1, unitPriceCents: 100000, eligible: true }],
      isWholesale: false, signals: [],
    });
    await service.onOrderDelivered({ eventId: `ev:${order}:del`, orderShopifyId: order });
    const q = await service.quote(customer, {
      cartRevision: 'rev-pg-2', lines: [{ quantity: 1, unitPriceCents: 100000, eligible: true }],
    });
    const { redemption } = await service.redeem({
      accountId: customer, quoteId: q.quoteId, amountCents: q.maxAllowedCents,
      isWholesaleCart: false, idempotencyKey: `pg-key2-${order}`,
    });
    const over = await repo.settle({
      redemptionId: redemption.redemptionId,
      appliedCents: redemption.requestedCents + 1,
      orderShopifyId: `pg-new-${order}`,
    });
    expect(over.state).toBe('reconciliation_required');
  });

  it('mayoreo no genera lote aunque el pago este verificado', async () => {
    const order = `pg-ws-${randomUUID().slice(0, 8)}`;
    await service.onOrderPaid({
      eventId: `ev:${order}:paid`, orderShopifyId: order, accountId: 'pg-cust-3',
      subtotalEligibleCents: 500000,
      lines: [{ quantity: 5, unitPriceCents: 100000, eligible: true }],
      isWholesale: true, signals: ['tag:mayoreo'],
    });
    await service.onOrderDelivered({ eventId: `ev:${order}:del`, orderShopifyId: order });
    expect((await repo.balance('pg-cust-3')).availableCents).toBe(0);
  });
});

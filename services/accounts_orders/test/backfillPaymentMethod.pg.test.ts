import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { randomUUID } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import pg from 'pg';
import { normalizePaymentMethod } from '../src/orders/paymentMethod.js';
import {
  PgPaymentMethodBackfillStore,
  runPaymentMethodBackfill,
  type OrderPaymentReader,
} from '../src/scripts/backfillPaymentMethod.js';

const adminUrl = process.env.WP01_PG_ADMIN_URL
  ?? `postgres://${process.env.USER}@localhost:5432/postgres`;
const admin = new pg.Client({ connectionString: adminUrl });
let available = false;
try {
  await admin.connect();
  available = true;
} catch {
  /* optional local run */
}
if (!available && (process.env.CI || process.env.REQUIRE_POSTGRES_TESTS === '1')) {
  throw new Error('PostgreSQL required');
}

const name = `monetta_paymethod_${randomUUID().replaceAll('-', '')}`;
const SEEDED_AT = '2020-01-15T12:00:00.000Z';

interface MirrorRow {
  shopify_order_id: string;
  financial_status: string;
  payment_method: string;
  updated_at: string;
}

describe.skipIf(!available)('payment method backfill on PostgreSQL', () => {
  let pool: pg.Pool;

  beforeAll(async () => {
    await admin.query(`CREATE DATABASE ${name}`);
    const url = new URL(adminUrl);
    url.pathname = `/${name}`;
    pool = new pg.Pool({ connectionString: url.toString() });
    const migrations = new URL('../src/db/migrations/', import.meta.url);
    for (const file of readdirSync(migrations).filter((entry) => entry.endsWith('.sql')).sort()) {
      await pool.query(readFileSync(new URL(file, migrations), 'utf8'));
    }
  }, 60_000);

  afterAll(async () => {
    if (pool) await pool.end();
    await admin.query(`DROP DATABASE IF EXISTS ${name}`);
    await admin.end();
  });

  async function snapshot(): Promise<MirrorRow[]> {
    const result = await pool.query<MirrorRow>(
      `SELECT shopify_order_id, financial_status, payment_method,
              to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') AS updated_at
       FROM orders_mirror
       ORDER BY id`,
    );
    return result.rows;
  }

  it('rewrites pending transfer aliases, including padded pending status, and leaves the rest', async () => {
    await pool.query(
      `INSERT INTO orders_mirror
         (shopify_order_id, source, financial_status, payment_method, updated_at)
       VALUES
         ('1001', 'shopify_checkout', 'pending', 'other:transferencia_bancaria', $1),
         ('1002', 'shopify_checkout', ' PENDING ', 'other:transferencia_bancaria', $1),
         ('1003', 'shopify_checkout', 'paid', 'other:transferencia_bancaria', $1),
         ('1004', 'shopify_checkout', 'pending', 'other:paypal', $1),
         ('1005', 'shopify_checkout', 'pending', 'other:deposito_bancario', $1),
         ('1006', 'shopify_checkout', 'paid', 'other:deposito_bancario', $1),
         ('1007', 'shopify_checkout', ' PENDING ', 'other:deposito_bancario', $1)`,
      [SEEDED_AT],
    );

    const transfer = normalizePaymentMethod({
      payment_gateway_names: ['Transferencia bancaria'],
    });
    const transferSpaced = normalizePaymentMethod({
      payment_gateway_names: ['  TRANSFERENCIA   BANCARIA  '],
    });
    const deposit = normalizePaymentMethod({ gateway: 'Depósito bancario' });
    const depositUpper = normalizePaymentMethod({ gateway: 'DEPÓSITO BANCARIO' });
    expect(transfer).toBe('bank_deposit');
    expect(transferSpaced).toBe('bank_deposit');
    expect(deposit).toBe('bank_deposit');
    expect(depositUpper).toBe('bank_deposit');

    const proposed = new Map<string, string>([
      ['1001', transfer!],
      ['1002', transferSpaced!],
      ['1005', deposit!],
      ['1007', depositUpper!],
    ]);
    const reads: string[][] = [];
    const reader: OrderPaymentReader = {
      async read(ids) {
        reads.push([...ids]);
        return new Map(ids.map((id) => {
          const paymentMethod = proposed.get(id);
          if (paymentMethod === undefined) throw new Error(`unexpected candidate ${id}`);
          return [id, { ok: true as const, name: `#${id}`, paymentMethod }];
        }));
      },
    };
    const store = new PgPaymentMethodBackfillStore(pool);
    const seeded = await snapshot();

    const dryRun = await runPaymentMethodBackfill(store, reader, { apply: false });
    expect(dryRun.applied).toBe(false);
    expect(dryRun.mode).toBe('dry-run');
    expect(dryRun.entries.map((entry) => entry.shopifyOrderId)).toEqual(['1001', '1002', '1005', '1007']);
    expect(dryRun.entries.every((entry) => entry.action === 'would_write' && entry.paymentMethod === 'bank_deposit')).toBe(true);
    expect(await snapshot()).toEqual(seeded);

    const applied = await runPaymentMethodBackfill(store, reader, { apply: true });
    expect(applied.applied).toBe(true);
    expect(applied.entries.map((entry) => ({
      shopifyOrderId: entry.shopifyOrderId,
      paymentMethod: entry.paymentMethod,
      action: entry.action,
    }))).toEqual([
      { shopifyOrderId: '1001', paymentMethod: 'bank_deposit', action: 'written' },
      { shopifyOrderId: '1002', paymentMethod: 'bank_deposit', action: 'written' },
      { shopifyOrderId: '1005', paymentMethod: 'bank_deposit', action: 'written' },
      { shopifyOrderId: '1007', paymentMethod: 'bank_deposit', action: 'written' },
    ]);

    const rewritten = new Set(['1001', '1002', '1005', '1007']);
    const afterApply = await snapshot();
    expect(afterApply.map((row) => row.shopify_order_id)).toEqual([
      '1001', '1002', '1003', '1004', '1005', '1006', '1007',
    ]);
    for (const row of afterApply) {
      const before = seeded.find((candidate) => candidate.shopify_order_id === row.shopify_order_id);
      expect(before).toBeDefined();
      expect(row.financial_status).toBe(before!.financial_status);
      if (rewritten.has(row.shopify_order_id)) {
        expect(row.payment_method).toBe('bank_deposit');
        expect(row.updated_at > before!.updated_at).toBe(true);
      } else {
        expect(row.payment_method).toBe(before!.payment_method);
        expect(row.updated_at).toBe(before!.updated_at);
      }
    }
    expect(afterApply.find((row) => row.shopify_order_id === '1003')?.payment_method).toBe('other:transferencia_bancaria');
    expect(afterApply.find((row) => row.shopify_order_id === '1004')?.payment_method).toBe('other:paypal');
    expect(afterApply.find((row) => row.shopify_order_id === '1006')?.payment_method).toBe('other:deposito_bancario');
    expect(afterApply.find((row) => row.shopify_order_id === '1002')?.financial_status).toBe(' PENDING ');
    expect(afterApply.find((row) => row.shopify_order_id === '1007')?.financial_status).toBe(' PENDING ');

    await new Promise((resolve) => setTimeout(resolve, 20));
    const second = await runPaymentMethodBackfill(store, reader, { apply: true });
    expect(second.candidates).toBe(0);
    expect(second.entries).toEqual([]);
    expect(await snapshot()).toEqual(afterApply);

    const dryAgain = await runPaymentMethodBackfill(store, reader, { apply: false });
    expect(dryAgain.candidates).toBe(0);
    expect(dryAgain.entries).toEqual([]);
    expect(dryAgain.applied).toBe(false);
    expect(await snapshot()).toEqual(afterApply);
    expect(reads).toEqual([
      ['1001', '1002', '1005', '1007'],
      ['1001', '1002', '1005', '1007'],
    ]);
  });
});

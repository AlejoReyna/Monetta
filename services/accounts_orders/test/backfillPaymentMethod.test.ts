import { describe, expect, it } from 'vitest';
import { TRANSFER_METHOD_ALIASES } from '../src/orders/paymentMethod.js';
import {
  ORDER_PAYMENT_QUERY,
  backfillLine,
  backfillSummary,
  parseBackfillArgs,
  readShopifyOrderPayments,
  runPaymentMethodBackfill,
  type OrderPaymentReader,
  type PaymentMethodBackfillStore,
  type PendingPaymentOrder,
} from '../src/scripts/backfillPaymentMethod.js';

class MemoryStore implements PaymentMethodBackfillStore {
  readonly writes: Array<{ shopifyOrderId: string; paymentMethod: string }> = [];

  constructor(readonly rows: Array<{
    shopifyOrderId: string;
    financialStatus: string;
    paymentMethod: string | null;
  }>) {}

  async listPendingWithoutPaymentMethod(): Promise<readonly PendingPaymentOrder[]> {
    return this.rows
      .filter((row) => row.paymentMethod === null && row.financialStatus.toLowerCase() === 'pending')
      .map((row) => ({ shopifyOrderId: row.shopifyOrderId }));
  }

  async setPaymentMethodIfNull(shopifyOrderId: string, paymentMethod: string): Promise<boolean> {
    const row = this.rows.find((candidate) => candidate.shopifyOrderId === shopifyOrderId);
    if (!row || row.paymentMethod !== null || row.financialStatus.toLowerCase() !== 'pending') {
      return false;
    }
    row.paymentMethod = paymentMethod;
    this.writes.push({ shopifyOrderId, paymentMethod });
    return true;
  }
}

describe('payment method backfill', () => {
  it('rejects a token passed as an argument and defaults to dry-run', () => {
    expect(parseBackfillArgs([])).toEqual({ apply: false, help: false });
    expect(parseBackfillArgs(['--apply'])).toEqual({ apply: true, help: false });
    expect(() => parseBackfillArgs(['--token', 'shpat_secret'])).toThrow(/SHOPIFY_ADMIN_ACCESS_TOKEN/);
    expect(() => parseBackfillArgs(['--apply', '--force'])).toThrow(/--apply/);
  });

  it('does not request card or payment detail fields', () => {
    expect(ORDER_PAYMENT_QUERY).toContain('paymentGatewayNames');
    expect(ORDER_PAYMENT_QUERY).toContain('transactions');
    expect(ORDER_PAYMENT_QUERY).not.toMatch(/paymentDetails|accountNumber|receiptJson|creditCard|email|phone/i);
  });

  it('dry-run lists ids, names, and proposed methods without writing', async () => {
    const store = new MemoryStore([
      { shopifyOrderId: '555', financialStatus: 'pending', paymentMethod: null },
      { shopifyOrderId: '556', financialStatus: 'pending', paymentMethod: null },
      { shopifyOrderId: '557', financialStatus: 'paid', paymentMethod: null },
      { shopifyOrderId: '558', financialStatus: 'pending', paymentMethod: 'manual' },
    ]);
    const reader: OrderPaymentReader = {
      async read(ids) {
        expect(ids).toEqual(['555', '556']);
        return new Map([
          ['555', { ok: true, name: '#1002', paymentMethod: 'bank_deposit' }],
          ['556', { ok: true, name: '#1003', paymentMethod: null }],
        ]);
      },
    };

    const report = await runPaymentMethodBackfill(store, reader, { apply: false });

    expect(store.writes).toEqual([]);
    expect(report.applied).toBe(false);
    expect(report.mode).toBe('dry-run');
    expect(report.entries).toEqual([
      {
        shopifyOrderId: '555',
        name: '#1002',
        paymentMethod: 'bank_deposit',
        action: 'would_write',
      },
      {
        shopifyOrderId: '556',
        name: '#1003',
        paymentMethod: null,
        action: 'skip_no_method',
      },
    ]);
    const printed = report.entries.map(backfillLine).join('\n');
    expect(printed).toContain('#1002');
    expect(printed).toContain('bank_deposit');
    expect(printed).not.toMatch(/@|shpat_|credit_card|4242/);
    expect(backfillSummary(report)).not.toMatch(/shpat_|@/);
  });

  it('apply writes only null pending rows and is idempotent', async () => {
    const store = new MemoryStore([
      { shopifyOrderId: '555', financialStatus: 'pending', paymentMethod: null },
      { shopifyOrderId: '559', financialStatus: 'pending', paymentMethod: null },
    ]);
    const reader: OrderPaymentReader = {
      async read() {
        return new Map([
          ['555', { ok: true, name: '#1002', paymentMethod: 'bank_deposit' }],
          ['559', { ok: true, name: '#1004', paymentMethod: 'card' }],
        ]);
      },
    };

    const first = await runPaymentMethodBackfill(store, reader, { apply: true });
    expect(first.applied).toBe(true);
    expect(first.entries.map((entry) => entry.action)).toEqual(['written', 'written']);
    expect(store.writes).toEqual([
      { shopifyOrderId: '555', paymentMethod: 'bank_deposit' },
      { shopifyOrderId: '559', paymentMethod: 'card' },
    ]);

    const second = await runPaymentMethodBackfill(store, reader, { apply: true });
    expect(second.candidates).toBe(0);
    expect(second.entries).toEqual([]);
    expect(store.writes).toHaveLength(2);
    expect(store.rows.find((row) => row.shopifyOrderId === '555')?.paymentMethod).toBe('bank_deposit');
  });

  it('does not write when a Shopify read fails', async () => {
    const store = new MemoryStore([
      { shopifyOrderId: '555', financialStatus: 'pending', paymentMethod: null },
      { shopifyOrderId: '560', financialStatus: 'pending', paymentMethod: null },
    ]);
    const reader: OrderPaymentReader = {
      async read() {
        return new Map([
          ['555', { ok: true, name: '#1002', paymentMethod: 'manual' }],
          ['560', { ok: false, error: 'shopify_http_401' }],
        ]);
      },
    };

    const report = await runPaymentMethodBackfill(store, reader, { apply: true });

    expect(report.applied).toBe(false);
    expect(report.reason).toBe('incomplete_shopify_read');
    expect(store.writes).toEqual([]);
    expect(report.entries[1]?.error).toBe('shopify_http_401');
    expect(JSON.stringify(report)).not.toContain('shpat_secret');
  });

  it('reads gateway names from the Admin API without echoing the token', async () => {
    const token = 'shpat_secretvalue';
    let sawToken = false;
    const fetchFn = (async (_url: string | URL | Request, init?: RequestInit) => {
      const headers = new Headers(init?.headers);
      sawToken = headers.get('X-Shopify-Access-Token') === token;
      const body = JSON.parse(String(init?.body)) as { query: string };
      expect(body.query).not.toMatch(/paymentDetails|accountNumber|receiptJson|creditCard/i);
      return new Response(JSON.stringify({
        data: {
          nodes: [
            {
              __typename: 'Order',
              id: 'gid://shopify/Order/555',
              name: '#1002',
              paymentGatewayNames: ['Bank Deposit'],
              transactions: [{ kind: 'SALE', gateway: 'Bank Deposit', formattedGateway: 'Bank Deposit' }],
            },
          ],
        },
      }), { status: 200 });
    }) as typeof fetch;

    const lookups = await readShopifyOrderPayments({
      shopDomain: 'monetta-staging.myshopify.com',
      apiVersion: '2026-07',
      accessToken: token,
      shopifyOrderIds: ['555'],
      fetchFn,
    });

    expect(sawToken).toBe(true);
    expect(lookups.get('555')).toEqual({
      ok: true,
      name: '#1002',
      paymentMethod: 'bank_deposit',
    });
    expect(JSON.stringify([...lookups.values()])).not.toContain(token);
  });

  it('leaves an unlisted transfer-like name as other: via the shared alias list', async () => {
    expect(Object.keys(TRANSFER_METHOD_ALIASES)).toEqual([]);
    const fetchFn = (async () => new Response(JSON.stringify({
      data: {
        nodes: [
          {
            __typename: 'Order',
            id: 'gid://shopify/Order/901',
            name: '#1901',
            paymentGatewayNames: ['ZZ Fake Transfer Rail'],
            transactions: [],
          },
        ],
      },
    }), { status: 200 })) as typeof fetch;

    const lookups = await readShopifyOrderPayments({
      shopDomain: 'monetta-staging.myshopify.com',
      apiVersion: '2026-07',
      accessToken: 'shpat_secretvalue',
      shopifyOrderIds: ['901'],
      fetchFn,
    });

    expect(lookups.get('901')).toMatchObject({
      ok: true,
      paymentMethod: 'other:zz_fake_transfer_rail',
    });
  });

  it('normalizes PayPal, Mercado Pago, and unknown Admin gateways the same way as webhooks', async () => {
    const fetchFn = (async () => new Response(JSON.stringify({
      data: {
        nodes: [
          {
            __typename: 'Order',
            id: 'gid://shopify/Order/801',
            name: '#1801',
            paymentGatewayNames: ['PayPal Express Checkout'],
            transactions: [{ kind: 'SALE', gateway: 'paypal', formattedGateway: 'PayPal Express Checkout' }],
          },
          {
            __typename: 'Order',
            id: 'gid://shopify/Order/802',
            name: '#1802',
            paymentGatewayNames: ['Mercado Pago'],
            transactions: [{ kind: 'SALE', gateway: 'MercadoPago', formattedGateway: 'Mercado Pago' }],
          },
          {
            __typename: 'Order',
            id: 'gid://shopify/Order/803',
            name: '#1803',
            paymentGatewayNames: ['Kueski Pay'],
            transactions: [],
          },
          {
            __typename: 'Order',
            id: 'gid://shopify/Order/804',
            name: '#1804',
            paymentGatewayNames: [],
            transactions: [{ kind: 'SALE' }],
          },
          {
            __typename: 'Order',
            id: 'gid://shopify/Order/805',
            name: '#1805',
            paymentGatewayNames: ['Shopify Payments'],
            transactions: [{
              kind: 'AUTHORIZATION',
              gateway: 'shopify_payments',
              formattedGateway: 'Shopify Payments',
            }],
          },
          {
            __typename: 'Order',
            id: 'gid://shopify/Order/806',
            name: '#1806',
            paymentGatewayNames: ['4242424242424242'],
            transactions: [],
          },
        ],
      },
    }), { status: 200 })) as typeof fetch;

    const lookups = await readShopifyOrderPayments({
      shopDomain: 'monetta-staging.myshopify.com',
      apiVersion: '2026-07',
      accessToken: 'shpat_secretvalue',
      shopifyOrderIds: ['801', '802', '803', '804', '805', '806'],
      fetchFn,
    });

    expect(lookups.get('801')).toMatchObject({ ok: true, paymentMethod: 'paypal' });
    expect(lookups.get('802')).toMatchObject({ ok: true, paymentMethod: 'mercadopago' });
    expect(lookups.get('803')).toMatchObject({ ok: true, paymentMethod: 'other:kueski_pay' });
    expect(lookups.get('804')).toMatchObject({ ok: true, paymentMethod: null });
    expect(lookups.get('805')).toMatchObject({ ok: true, paymentMethod: 'card' });
    expect(lookups.get('806')).toMatchObject({ ok: true, paymentMethod: null });
  });

  it('apply writes an other: method and leaves a missing method null', async () => {
    const store = new MemoryStore([
      { shopifyOrderId: '803', financialStatus: 'pending', paymentMethod: null },
      { shopifyOrderId: '804', financialStatus: 'pending', paymentMethod: null },
    ]);
    const reader: OrderPaymentReader = {
      async read() {
        return new Map([
          ['803', { ok: true, name: '#1803', paymentMethod: 'other:kueski_pay' }],
          ['804', { ok: true, name: '#1804', paymentMethod: null }],
        ]);
      },
    };

    const report = await runPaymentMethodBackfill(store, reader, { apply: true });

    expect(report.entries.map((entry) => entry.action)).toEqual(['written', 'skip_no_method']);
    expect(store.writes).toEqual([
      { shopifyOrderId: '803', paymentMethod: 'other:kueski_pay' },
    ]);
    expect(store.rows.find((row) => row.shopifyOrderId === '804')?.paymentMethod).toBeNull();
  });

  it('reports an HTTP failure without the response body or token', async () => {
    const token = 'shpat_secretvalue';
    const fetchFn = (async () => new Response(JSON.stringify({
      email: 'shopper@example.com',
      token,
    }), { status: 401 })) as typeof fetch;

    const lookups = await readShopifyOrderPayments({
      shopDomain: 'monetta-staging.myshopify.com',
      apiVersion: '2026-07',
      accessToken: token,
      shopifyOrderIds: ['555'],
      fetchFn,
    });

    expect(lookups.get('555')).toEqual({ ok: false, error: 'shopify_http_401' });
    expect(JSON.stringify([...lookups.values()])).not.toContain('shopper@example.com');
    expect(JSON.stringify([...lookups.values()])).not.toContain(token);
  });
});

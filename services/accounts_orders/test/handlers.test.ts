import { beforeEach, describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import {
  handleCustomersDataRequest,
  handleCustomersRedact,
  handleOrdersWebhook,
  handleShopRedact,
} from '../src/webhooks/handlers.js';
import {
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPrivacyRequestsRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import type { ShopifyOrderWebhookPayload } from '../src/webhooks/payloads.js';
import type { OrderRecord } from '../src/domain/types.js';

function orderPayload(overrides: Partial<ShopifyOrderWebhookPayload> = {}): ShopifyOrderWebhookPayload {
  return {
    id: 555,
    tags: 'VIP',
    financial_status: 'paid',
    fulfillment_status: null,
    current_total_price: '1749.00',
    currency: 'MXN',
    created_at: '2026-08-01T10:00:00-06:00',
    updated_at: '2026-08-01T10:00:00-06:00',
    customer: {
      id: 42,
      email: 'shopper@example.com',
      first_name: 'Ana',
      last_name: 'Ramirez',
      phone: '+528261066868',
    },
    note_attributes: [
      { name: '_device_id', value: 'device-abc' },
      { name: '_rec_source', value: 'profile' },
    ],
    ...overrides,
  };
}

async function captureLogs(run: () => Promise<void>): Promise<string[]> {
  const lines: string[] = [];
  const original = {
    log: console.log,
    warn: console.warn,
    error: console.error,
  };
  const push = (line?: unknown) => {
    lines.push(String(line));
  };
  console.log = push;
  console.warn = push;
  console.error = push;
  try {
    await run();
  } finally {
    console.log = original.log;
    console.warn = original.warn;
    console.error = original.error;
  }
  return lines;
}

function missingTokenWarnings(lines: readonly string[]): Array<Record<string, unknown>> {
  return lines.flatMap((line) => {
    try {
      const parsed = JSON.parse(line) as Record<string, unknown>;
      return parsed.message === 'order_webhook_missing_checkout_tokens' ? [parsed] : [];
    } catch {
      return [];
    }
  });
}

describe('webhook handlers', () => {
  let customers: InMemoryCustomersRepository;
  let orders: InMemoryOrdersRepository;
  let webhookEvents: InMemoryWebhookEventsRepository;
  let pushTokens: InMemoryPushTokensRepository;
  let privacyRequests: InMemoryPrivacyRequestsRepository;
  let deps: {
    customers: InMemoryCustomersRepository;
    orders: InMemoryOrdersRepository;
    webhookEvents: InMemoryWebhookEventsRepository;
    pushTokens: InMemoryPushTokensRepository;
    privacyRequests: InMemoryPrivacyRequestsRepository;
  };

  beforeEach(() => {
    customers = new InMemoryCustomersRepository();
    orders = new InMemoryOrdersRepository();
    webhookEvents = new InMemoryWebhookEventsRepository();
    pushTokens = new InMemoryPushTokensRepository();
    privacyRequests = new InMemoryPrivacyRequestsRepository();
    deps = { customers, orders, webhookEvents, pushTokens, privacyRequests };
  });

  describe('handleOrdersWebhook', () => {
    it.each(['orders/create', 'orders/updated'] as const)(
      'mirrors the exact staging transfer gateway on %s for the Flutter contract',
      async (topic) => {
        const fixture = JSON.parse(readFileSync(new URL(
          '../../../test/fixtures/contracts/staging_transfer_payment.json', import.meta.url,
        ), 'utf8')) as { gateway: string; paymentMethod: string };
        expect(fixture.gateway).toBe('Transferencia bancaria');

        await handleOrdersWebhook(
          deps,
          `wh-staging-transfer-${topic}`,
          topic,
          orderPayload({
            financial_status: 'pending',
            payment_gateway_names: [fixture.gateway],
          }),
          Buffer.from('raw-staging-transfer'),
        );

        expect(orders.rows).toHaveLength(1);
        expect(orders.rows[0]!.financialStatus).toBe('pending');
        expect(orders.rows[0]!.paymentMethod).toBe(fixture.paymentMethod);
      },
    );

    it('mirrors a real checkout order and its customer', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-1',
        'orders/create',
        orderPayload(),
        Buffer.from('raw'),
      );

      expect(orders.rows).toHaveLength(1);
      const order = orders.rows[0]!;
      expect(order.shopifyOrderId).toBe('555');
      expect(order.source).toBe('shopify_checkout');
      expect(order.attributionCode).toBeNull();
      expect(order.totalAmount).toBe(1749);
      expect(order.attributionDeviceId).toBe('device-abc');
      expect(order.attributionRecoSource).toBe('profile');
      expect(customers.byId.get('42')?.email).toBe('shopper@example.com');
      expect(webhookEvents.byWebhookId.get('wh-1')?.status).toBe('completed');
    });

    it('classifies an order carrying a valid MN- apartado tag as whatsapp_apartado', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-2',
        'orders/create',
        orderPayload({ tags: 'VIP, MN-7K3Q' }),
        Buffer.from('raw'),
      );

      const order = orders.rows[0]!;
      expect(order.source).toBe('whatsapp_apartado');
      expect(order.attributionCode).toBe('MN-7K3Q');
    });

    it('does not mistake an unrelated "MN-" tag for an apartado code', async () => {
      // Not from AttributionCodeGenerator's alphabet (no vowels, no 0/O/1/I) —
      // must not match.
      await handleOrdersWebhook(
        deps,
        'wh-3',
        'orders/create',
        orderPayload({ tags: 'MN-0001' }),
        Buffer.from('raw'),
      );

      expect(orders.rows[0]!.source).toBe('shopify_checkout');
      expect(orders.rows[0]!.attributionCode).toBeNull();
    });

    it('is idempotent for a retried delivery of the same webhook id', async () => {
      const payload = orderPayload();
      await handleOrdersWebhook(deps, 'wh-4', 'orders/create', payload, Buffer.from('raw'));
      await handleOrdersWebhook(deps, 'wh-4', 'orders/create', payload, Buffer.from('raw'));

      expect(orders.rows).toHaveLength(1);
      expect(webhookEvents.byWebhookId.get('wh-4')?.attemptCount).toBe(1);
    });

    it('F12: claim-then-fail leaves delivery failed so Shopify retry reprocesses', async () => {
      let failNext = true;
      const failingOrders = {
        ...orders,
        rows: orders.rows,
        async upsertByShopifyOrderId(order: OrderRecord): Promise<void> {
          if (failNext) {
            failNext = false;
            throw new Error('simulated upsert failure');
          }
          return orders.upsertByShopifyOrderId(order);
        },
        linkApartadoByAttributionCode: orders.linkApartadoByAttributionCode.bind(orders),
        detachCustomer: orders.detachCustomer.bind(orders),
        listForCustomer: orders.listForCustomer.bind(orders),
        deleteAll: orders.deleteAll.bind(orders),
      };

      const failingDeps = { ...deps, orders: failingOrders };
      const payload = orderPayload();

      await expect(
        handleOrdersWebhook(failingDeps, 'wh-fail', 'orders/create', payload, Buffer.from('raw-a')),
      ).rejects.toThrow('simulated upsert failure');

      expect(orders.rows).toHaveLength(0);
      expect(webhookEvents.byWebhookId.get('wh-fail')?.status).toBe('failed');

      await handleOrdersWebhook(failingDeps, 'wh-fail', 'orders/create', payload, Buffer.from('raw-a'));

      expect(orders.rows).toHaveLength(1);
      expect(orders.rows[0]!.shopifyOrderId).toBe('555');
      expect(webhookEvents.byWebhookId.get('wh-fail')?.status).toBe('completed');
      expect(webhookEvents.byWebhookId.get('wh-fail')?.attemptCount).toBe(2);
    });

    it('F12: completed delivery is not double-applied on duplicate', async () => {
      let upsertCalls = 0;
      const countingOrders = {
        rows: orders.rows,
        async upsertByShopifyOrderId(order: OrderRecord): Promise<void> {
          upsertCalls += 1;
          return orders.upsertByShopifyOrderId(order);
        },
        linkApartadoByAttributionCode: orders.linkApartadoByAttributionCode.bind(orders),
        detachCustomer: orders.detachCustomer.bind(orders),
        listForCustomer: orders.listForCustomer.bind(orders),
        deleteAll: orders.deleteAll.bind(orders),
      };
      const countingDeps = { ...deps, orders: countingOrders };
      const payload = orderPayload();

      await handleOrdersWebhook(countingDeps, 'wh-dup', 'orders/create', payload, Buffer.from('raw'));
      await handleOrdersWebhook(countingDeps, 'wh-dup', 'orders/create', payload, Buffer.from('raw'));

      expect(upsertCalls).toBe(1);
      expect(orders.rows).toHaveLength(1);
    });

    it('an orders/updated delivery updates the same mirrored row rather than duplicating it', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-5',
        'orders/create',
        orderPayload({
          financial_status: 'pending',
          updated_at: '2026-08-01T10:00:00-06:00',
        }),
        Buffer.from('raw'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-6',
        'orders/updated',
        orderPayload({
          financial_status: 'paid',
          updated_at: '2026-08-01T11:00:00-06:00',
        }),
        Buffer.from('raw'),
      );

      expect(orders.rows).toHaveLength(1);
      expect(orders.rows[0]!.financialStatus).toBe('paid');
    });

    it('F15: stale out-of-order delivery does not regress financial status', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-paid',
        'orders/updated',
        orderPayload({
          financial_status: 'paid',
          updated_at: '2026-08-01T10:00:00-06:00',
        }),
        Buffer.from('raw-paid'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-refund',
        'orders/updated',
        orderPayload({
          financial_status: 'refunded',
          updated_at: '2026-08-01T12:00:00-06:00',
        }),
        Buffer.from('raw-refund'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-stale-paid',
        'orders/updated',
        orderPayload({
          financial_status: 'paid',
          updated_at: '2026-08-01T10:00:00-06:00',
        }),
        Buffer.from('raw-stale'),
      );

      expect(orders.rows).toHaveLength(1);
      expect(orders.rows[0]!.financialStatus).toBe('refunded');
    });

    it('unifies real checkout and apartado orders for the same customer in one list', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-checkout',
        'orders/create',
        orderPayload({ id: 100, tags: '' }),
        Buffer.from('r'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-apartado',
        'orders/create',
        orderPayload({ id: 101, tags: 'MN-7K3Q' }),
        Buffer.from('r'),
      );

      const forCustomer = await orders.listForCustomer('42');
      expect(forCustomer).toHaveLength(2);
      expect(forCustomer.map((o) => o.source).sort()).toEqual([
        'shopify_checkout',
        'whatsapp_apartado',
      ]);
    });

    it('stores a pending bank deposit from payment_gateway_names as bank_deposit', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-transfer',
        'orders/create',
        orderPayload({
          financial_status: 'pending',
          payment_gateway_names: ['Bank Deposit'],
        }),
        Buffer.from('raw-transfer'),
      );

      expect(orders.rows[0]!.paymentMethod).toBe('bank_deposit');
      expect(orders.rows[0]!.financialStatus).toBe('pending');
    });

    it('stores a manual transaction gateway on orders/updated and drops the sale kind', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-manual-create',
        'orders/create',
        orderPayload({ financial_status: 'pending', updated_at: '2026-08-01T10:00:00-06:00' }),
        Buffer.from('raw-manual-create'),
      );
      expect(orders.rows[0]!.paymentMethod).toBeNull();

      await handleOrdersWebhook(
        deps,
        'wh-manual-update',
        'orders/updated',
        orderPayload({
          financial_status: 'pending',
          updated_at: '2026-08-01T11:00:00-06:00',
          transactions: [{ kind: 'sale', gateway: 'manual', type: 'MANUAL' }],
        }),
        Buffer.from('raw-manual-update'),
      );

      expect(orders.rows).toHaveLength(1);
      expect(orders.rows[0]!.paymentMethod).toBe('manual');
    });

    it('stores a card gateway without card numbers or payment_details', async () => {
      const pan = '4242424242424242';
      await handleOrdersWebhook(
        deps,
        'wh-card',
        'orders/create',
        orderPayload({
          financial_status: 'pending',
          payment_gateway_names: ['shopify_payments'],
          transactions: [
            {
              kind: 'authorization',
              gateway: 'shopify_payments',
              payment_details: {
                credit_card_number: pan,
                credit_card_company: 'Visa',
              },
            } as never,
          ],
        }),
        Buffer.from('raw-card'),
      );

      const stored = JSON.stringify(orders.rows[0]);
      expect(orders.rows[0]!.paymentMethod).toBe('card');
      expect(stored).not.toContain(pan);
      expect(stored).not.toContain('credit_card');
      expect(stored).not.toContain('Visa');
    });

    it('leaves payment_method null when the webhook has no method', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-missing',
        'orders/create',
        orderPayload({ financial_status: 'pending', payment_gateway_names: [] }),
        Buffer.from('raw-missing'),
      );

      expect(orders.rows[0]!.paymentMethod).toBeNull();
    });

    it('does not clear a known method when a later webhook omits gateways', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-keep-create',
        'orders/create',
        orderPayload({
          financial_status: 'pending',
          updated_at: '2026-08-01T10:00:00-06:00',
          payment_gateway_names: ['Transferencia bancaria'],
        }),
        Buffer.from('raw-keep-create'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-keep-update',
        'orders/updated',
        orderPayload({
          financial_status: 'pending',
          updated_at: '2026-08-01T12:00:00-06:00',
        }),
        Buffer.from('raw-keep-update'),
      );

      expect(orders.rows[0]!.paymentMethod).toBe('bank_deposit');
    });

    it('stores paypal, mercadopago, and an unrecognized gateway as non-null methods', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-paypal',
        'orders/create',
        orderPayload({
          id: 701,
          financial_status: 'pending',
          payment_gateway_names: ['PayPal Express Checkout'],
        }),
        Buffer.from('raw-paypal'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-mp',
        'orders/create',
        orderPayload({
          id: 702,
          financial_status: 'pending',
          payment_gateway_names: ['Mercado Pago'],
        }),
        Buffer.from('raw-mp'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-kueski',
        'orders/create',
        orderPayload({
          id: 703,
          financial_status: 'pending',
          payment_gateway_names: ['Kueski Pay'],
        }),
        Buffer.from('raw-kueski'),
      );

      const byId = new Map(orders.rows.map((row) => [row.shopifyOrderId, row.paymentMethod]));
      expect(byId.get('701')).toBe('paypal');
      expect(byId.get('702')).toBe('mercadopago');
      expect(byId.get('703')).toBe('other:kueski_pay');
    });

    it('drops a digits-only gateway so a card number is not stored as the method', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-pan-name',
        'orders/create',
        orderPayload({
          financial_status: 'pending',
          payment_gateway_names: ['4242424242424242'],
        }),
        Buffer.from('raw-pan-name'),
      );

      expect(orders.rows[0]!.paymentMethod).toBeNull();
      expect(JSON.stringify(orders.rows[0])).not.toContain('4242424242424242');
    });

    it('stores checkout_token and cart_token and does not log them', async () => {
      const checkoutToken = 'chk_a1b2c3d4e5';
      const cartToken = 'crt_f6e5d4c3b2';
      const lines: string[] = [];
      const original = {
        log: console.log,
        warn: console.warn,
        error: console.error,
      };
      console.log = (line?: unknown) => {
        lines.push(String(line));
      };
      console.warn = (line?: unknown) => {
        lines.push(String(line));
      };
      console.error = (line?: unknown) => {
        lines.push(String(line));
      };
      try {
        await handleOrdersWebhook(
          deps,
          'wh-tokens',
          'orders/create',
          orderPayload({
            checkout_token: `  ${checkoutToken}?key=not-a-stored-key`,
            cart_token: cartToken,
          }),
          Buffer.from('raw-tokens'),
        );
      } finally {
        console.log = original.log;
        console.warn = original.warn;
        console.error = original.error;
      }

      expect(orders.rows[0]!.checkoutToken).toBe(checkoutToken);
      expect(orders.rows[0]!.cartToken).toBe(cartToken);
      const logged = lines.join('\n');
      expect(logged).not.toContain('order_webhook_missing_checkout_tokens');
      expect(logged).not.toContain(checkoutToken);
      expect(logged).not.toContain(cartToken);
      expect(logged).not.toContain('not-a-stored-key');
    });

    it('leaves both tokens null when the webhook omits them or sends a non-string', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-no-tokens',
        'orders/create',
        orderPayload({
          checkout_token: null,
          cart_token: 4242 as never,
        }),
        Buffer.from('raw-no-tokens'),
      );

      expect(orders.rows[0]!.checkoutToken).toBeNull();
      expect(orders.rows[0]!.cartToken).toBeNull();
      expect(JSON.stringify(orders.rows[0])).not.toContain('4242');
    });

    it('does not clear stored tokens when a later webhook omits them', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-token-create',
        'orders/create',
        orderPayload({
          updated_at: '2026-08-01T10:00:00-06:00',
          checkout_token: 'chk_a1b2c3d4e5',
          cart_token: 'crt_f6e5d4c3b2',
        }),
        Buffer.from('raw-token-create'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-token-update',
        'orders/updated',
        orderPayload({
          updated_at: '2026-08-01T12:00:00-06:00',
          financial_status: 'paid',
        }),
        Buffer.from('raw-token-update'),
      );

      expect(orders.rows).toHaveLength(1);
      expect(orders.rows[0]!.checkoutToken).toBe('chk_a1b2c3d4e5');
      expect(orders.rows[0]!.cartToken).toBe('crt_f6e5d4c3b2');
      expect(orders.rows[0]!.financialStatus).toBe('paid');
    });

    it('fills tokens that were missing when a later webhook carries them', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-token-fill-create',
        'orders/create',
        orderPayload({ updated_at: '2026-08-01T10:00:00-06:00' }),
        Buffer.from('raw-token-fill-create'),
      );
      expect(orders.rows[0]!.checkoutToken).toBeNull();

      await handleOrdersWebhook(
        deps,
        'wh-token-fill-update',
        'orders/updated',
        orderPayload({
          updated_at: '2026-08-01T12:00:00-06:00',
          checkout_token: 'chk_filledlater',
          cart_token: 'crt_filledlater',
        }),
        Buffer.from('raw-token-fill-update'),
      );

      expect(orders.rows[0]!.checkoutToken).toBe('chk_filledlater');
      expect(orders.rows[0]!.cartToken).toBe('crt_filledlater');
    });

    it('warns when orders/create has no usable checkout or cart token, without logging token values', async () => {
      const rawToken = 'raw token should not log';
      const lines = await captureLogs(() => handleOrdersWebhook(
        deps,
        'wh-missing-tokens',
        'orders/create',
        orderPayload({
          id: 555,
          name: '#1002',
          checkout_token: '',
          cart_token: rawToken,
        }),
        Buffer.from('raw-missing-tokens'),
      ));

      const warns = missingTokenWarnings(lines);
      expect(warns).toEqual([
        expect.objectContaining({
          level: 'warn',
          message: 'order_webhook_missing_checkout_tokens',
          shopifyOrderId: '555',
          orderName: '#1002',
          missingFields: ['checkout_token', 'cart_token'],
          topic: 'orders/create',
        }),
      ]);
      expect(lines.join('\n')).not.toContain(rawToken);
      expect(orders.rows[0]!.checkoutToken).toBeNull();
      expect(orders.rows[0]!.cartToken).toBeNull();
    });

    it('warns on orders/create when the fields are omitted, and does not repeat a completed delivery', async () => {
      const payload = orderPayload({ name: '#1004' });
      const first = await captureLogs(() => handleOrdersWebhook(
        deps,
        'wh-omitted-tokens',
        'orders/create',
        payload,
        Buffer.from('raw-omitted-tokens'),
      ));
      const second = await captureLogs(() => handleOrdersWebhook(
        deps,
        'wh-omitted-tokens',
        'orders/create',
        payload,
        Buffer.from('raw-omitted-tokens'),
      ));

      expect(missingTokenWarnings(first)).toHaveLength(1);
      expect(missingTokenWarnings(first)[0]).toMatchObject({
        shopifyOrderId: '555',
        orderName: '#1004',
        missingFields: ['checkout_token', 'cart_token'],
      });
      expect(missingTokenWarnings(second)).toHaveLength(0);
    });

    it('does not warn when either correlation token is present, and does not log the values', async () => {
      const checkoutToken = 'chk_only_checkout';
      const cartToken = 'crt_only_cart';
      const both = await captureLogs(() => handleOrdersWebhook(
        deps,
        'wh-both-tokens',
        'orders/create',
        orderPayload({
          id: 601,
          name: '#1005',
          checkout_token: checkoutToken,
          cart_token: cartToken,
        }),
        Buffer.from('raw-both-tokens'),
      ));
      const checkoutOnly = await captureLogs(() => handleOrdersWebhook(
        deps,
        'wh-checkout-only',
        'orders/create',
        orderPayload({
          id: 602,
          name: '#1006',
          checkout_token: checkoutToken,
          cart_token: '',
        }),
        Buffer.from('raw-checkout-only'),
      ));
      const cartOnly = await captureLogs(() => handleOrdersWebhook(
        deps,
        'wh-cart-only',
        'orders/create',
        orderPayload({
          id: 603,
          checkout_token: null,
          cart_token: cartToken,
        }),
        Buffer.from('raw-cart-only'),
      ));

      expect(missingTokenWarnings(both)).toHaveLength(0);
      expect(missingTokenWarnings(checkoutOnly)).toHaveLength(0);
      expect(missingTokenWarnings(cartOnly)).toHaveLength(0);
      const logged = [...both, ...checkoutOnly, ...cartOnly].join('\n');
      expect(logged).not.toContain(checkoutToken);
      expect(logged).not.toContain(cartToken);
    });

    it('warns on orders/updated only for orders created after deploy', async () => {
      const deployedAt = new Date('2026-08-01T00:00:00Z');
      const rawToken = 'updated raw token should not log';
      const gated = { ...deps, checkoutTokensDeployedAt: deployedAt };

      const beforeDeploy = await captureLogs(() => handleOrdersWebhook(
        gated,
        'wh-update-before',
        'orders/updated',
        orderPayload({
          id: 611,
          name: '#1011',
          created_at: '2026-07-01T00:00:00Z',
          updated_at: '2026-09-01T00:00:00Z',
          checkout_token: rawToken,
          cart_token: '',
        }),
        Buffer.from('raw-update-before'),
      ));
      const afterDeploy = await captureLogs(() => handleOrdersWebhook(
        gated,
        'wh-update-after',
        'orders/updated',
        orderPayload({
          id: 612,
          name: '#1012',
          created_at: '2026-08-02T00:00:00Z',
          updated_at: '2026-09-01T00:00:00Z',
          checkout_token: '',
          cart_token: rawToken,
        }),
        Buffer.from('raw-update-after'),
      ));
      const afterDeployWithTokens = await captureLogs(() => handleOrdersWebhook(
        gated,
        'wh-update-after-tokens',
        'orders/updated',
        orderPayload({
          id: 613,
          name: '#1013',
          created_at: '2026-08-02T00:00:00Z',
          updated_at: '2026-09-01T00:00:00Z',
          checkout_token: 'chk_update_kept',
          cart_token: 'crt_update_kept',
        }),
        Buffer.from('raw-update-after-tokens'),
      ));
      const updateWithoutCreatedAt = await captureLogs(() => handleOrdersWebhook(
        gated,
        'wh-update-no-created',
        'orders/updated',
        orderPayload({
          id: 615,
          name: '#1015',
          created_at: null,
          updated_at: '2026-09-01T00:00:00Z',
          checkout_token: null,
          cart_token: null,
        }),
        Buffer.from('raw-update-no-created'),
      ));
      const createBeforeDeploy = await captureLogs(() => handleOrdersWebhook(
        gated,
        'wh-create-old',
        'orders/create',
        orderPayload({
          id: 614,
          name: rawToken,
          created_at: '2026-01-01T00:00:00Z',
          checkout_token: null,
          cart_token: null,
        }),
        Buffer.from('raw-create-old'),
      ));

      expect(missingTokenWarnings(beforeDeploy)).toHaveLength(0);
      expect(missingTokenWarnings(updateWithoutCreatedAt)).toHaveLength(0);
      expect(missingTokenWarnings(afterDeploy)).toEqual([
        expect.objectContaining({
          level: 'warn',
          message: 'order_webhook_missing_checkout_tokens',
          shopifyOrderId: '612',
          orderName: '#1012',
          missingFields: ['checkout_token', 'cart_token'],
          topic: 'orders/updated',
        }),
      ]);
      expect(missingTokenWarnings(afterDeployWithTokens)).toHaveLength(0);
      expect(missingTokenWarnings(createBeforeDeploy)).toEqual([
        expect.objectContaining({
          shopifyOrderId: '614',
          orderName: null,
          topic: 'orders/create',
        }),
      ]);
      const logged = [
        ...beforeDeploy,
        ...afterDeploy,
        ...afterDeployWithTokens,
        ...updateWithoutCreatedAt,
        ...createBeforeDeploy,
      ].join('\n');
      expect(logged).not.toContain(rawToken);
      expect(logged).not.toContain('chk_update_kept');
      expect(logged).not.toContain('crt_update_kept');
    });
  });

  describe('handleCustomersRedact', () => {
    it('deletes the customer, detaches their orders, and deletes their push tokens', async () => {
      await handleOrdersWebhook(deps, 'wh-1', 'orders/create', orderPayload(), Buffer.from('r'));
      await pushTokens.upsert({
        deviceId: 'dev-1',
        customerId: '42',
        fcmToken: 'tok',
        platform: 'ios',
      });

      await handleCustomersRedact(
        deps,
        'wh-redact-1',
        { customer: { id: 42 } },
        Buffer.from('raw'),
      );

      expect(customers.byId.has('42')).toBe(false);
      expect(orders.rows[0]!.customerId).toBeNull();
      expect(pushTokens.byDeviceId.has('dev-1')).toBe(false);
      // The order itself is a business record and survives redaction.
      expect(orders.rows).toHaveLength(1);
      const privacy = privacyRequests.byWebhookId.get('wh-redact-1');
      expect(privacy?.kind).toBe('customers/redact');
      expect(privacy?.status).toBe('fulfilled');
      expect(privacy?.shopifyCustomerId).toBe('42');
    });

    it('is idempotent for a retried delivery', async () => {
      await handleOrdersWebhook(deps, 'wh-1', 'orders/create', orderPayload(), Buffer.from('r'));
      await handleCustomersRedact(deps, 'wh-r', { customer: { id: 42 } }, Buffer.from('raw'));
      // A second delivery of the same webhook id must not throw even
      // though the customer is already gone.
      await expect(
        handleCustomersRedact(deps, 'wh-r', { customer: { id: 42 } }, Buffer.from('raw')),
      ).resolves.toBeUndefined();
    });
  });

  describe('handleCustomersDataRequest', () => {
    it('records a durable open privacy task without throwing', async () => {
      await expect(
        handleCustomersDataRequest(deps, 'wh-dr', { customer: { id: 42 } }, Buffer.from('raw')),
      ).resolves.toBeUndefined();
      expect(webhookEvents.byWebhookId.get('wh-dr')?.status).toBe('completed');
      expect(privacyRequests.byWebhookId.get('wh-dr')?.status).toBe('open');
      expect(privacyRequests.byWebhookId.get('wh-dr')?.shopifyCustomerId).toBe('42');
    });

    it('fulfills an open data_request with operator evidence', async () => {
      await privacyRequests.openDataRequest({ webhookId: 'wh-dr-2', shopifyCustomerId: '7' });
      const ok = await privacyRequests.markFulfilled({
        webhookId: 'wh-dr-2',
        operator: 'owner-1',
        notes: 'exported to ticket T-1',
        exportArtifactRef: 'tickets/T-1',
      });
      expect(ok).toBe(true);
      expect(privacyRequests.byWebhookId.get('wh-dr-2')?.status).toBe('fulfilled');
      expect(privacyRequests.byWebhookId.get('wh-dr-2')?.exportArtifactRef).toBe('tickets/T-1');
      expect(await privacyRequests.listOpen()).toHaveLength(0);
    });
  });

  describe('handleShopRedact', () => {
    it('wipes every customer, order and push token', async () => {
      await handleOrdersWebhook(deps, 'wh-1', 'orders/create', orderPayload(), Buffer.from('r'));
      await pushTokens.upsert({
        deviceId: 'dev-1',
        customerId: '42',
        fcmToken: 'tok',
        platform: 'ios',
      });

      await handleShopRedact(
        deps,
        'wh-shop-redact',
        { shop_id: 1, shop_domain: 'monetta.myshopify.com' },
        Buffer.from('raw'),
      );

      expect(customers.byId.size).toBe(0);
      expect(orders.rows).toHaveLength(0);
      expect(pushTokens.byDeviceId.size).toBe(0);
    });
  });
});

import { beforeEach, describe, expect, it } from 'vitest';
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
      expect(orders.rows[0]!.paymentMethod).toBe('shopify_payments');
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

      expect(orders.rows[0]!.paymentMethod).toBe('transferencia_bancaria');
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

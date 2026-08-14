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
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import type { ShopifyOrderWebhookPayload } from '../src/webhooks/payloads.js';

function orderPayload(overrides: Partial<ShopifyOrderWebhookPayload> = {}): ShopifyOrderWebhookPayload {
  return {
    id: 555,
    tags: 'VIP',
    financial_status: 'paid',
    fulfillment_status: null,
    current_total_price: '1749.00',
    currency: 'MXN',
    created_at: '2026-08-01T10:00:00-06:00',
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
  let deps: {
    customers: InMemoryCustomersRepository;
    orders: InMemoryOrdersRepository;
    webhookEvents: InMemoryWebhookEventsRepository;
    pushTokens: InMemoryPushTokensRepository;
  };

  beforeEach(() => {
    customers = new InMemoryCustomersRepository();
    orders = new InMemoryOrdersRepository();
    webhookEvents = new InMemoryWebhookEventsRepository();
    pushTokens = new InMemoryPushTokensRepository();
    deps = { customers, orders, webhookEvents, pushTokens };
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
    });

    it('an orders/updated delivery updates the same mirrored row rather than duplicating it', async () => {
      await handleOrdersWebhook(
        deps,
        'wh-5',
        'orders/create',
        orderPayload({ financial_status: 'pending' }),
        Buffer.from('raw'),
      );
      await handleOrdersWebhook(
        deps,
        'wh-6',
        'orders/updated',
        orderPayload({ financial_status: 'paid' }),
        Buffer.from('raw'),
      );

      expect(orders.rows).toHaveLength(1);
      expect(orders.rows[0]!.financialStatus).toBe('paid');
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
    it('records the request for manual follow-up without throwing', async () => {
      await expect(
        handleCustomersDataRequest(deps, 'wh-dr', { customer: { id: 42 } }, Buffer.from('raw')),
      ).resolves.toBeUndefined();
      expect(webhookEvents.byWebhookId.get('wh-dr')?.processedAt).not.toBeNull();
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

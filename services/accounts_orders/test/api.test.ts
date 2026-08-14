import { createHmac, randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
import {
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

const secret = 'shpss_test_secret';

function sign(body: string): string {
  return createHmac('sha256', secret).update(body).digest('base64');
}

describe('accounts_orders API', () => {
  let server: Server;
  let baseUrl: string;
  let customers: InMemoryCustomersRepository;
  let orders: InMemoryOrdersRepository;
  let webhookEvents: InMemoryWebhookEventsRepository;
  let pushTokens: InMemoryPushTokensRepository;

  beforeEach(async () => {
    customers = new InMemoryCustomersRepository();
    orders = new InMemoryOrdersRepository();
    webhookEvents = new InMemoryWebhookEventsRepository();
    pushTokens = new InMemoryPushTokensRepository();
    const deps: ServerDeps = { customers, orders, webhookEvents, pushTokens, webhookSecret: secret };
    const app = createApp(deps);
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;
  });

  afterEach(async () => {
    await new Promise<void>((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
  });

  it('/livez and /healthz report ok', async () => {
    expect((await fetch(`${baseUrl}/livez`)).status).toBe(200);
    expect((await fetch(`${baseUrl}/healthz`)).status).toBe(200);
  });

  it('accepts a correctly signed orders/create webhook and mirrors the order', async () => {
    const body = JSON.stringify({ id: 1, customer: { id: 9, email: 'a@b.com' } });
    const response = await fetch(`${baseUrl}/webhooks/orders/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Hmac-Sha256': sign(body),
        'X-Shopify-Webhook-Id': randomUUID(),
      },
      body,
    });

    expect(response.status).toBe(200);
    expect(orders.rows).toHaveLength(1);
    expect(orders.rows[0]!.shopifyOrderId).toBe('1');
  });

  it('rejects a webhook with an incorrect signature and mirrors nothing', async () => {
    const body = JSON.stringify({ id: 2 });
    const response = await fetch(`${baseUrl}/webhooks/orders/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Hmac-Sha256': 'not-a-real-signature',
        'X-Shopify-Webhook-Id': randomUUID(),
      },
      body,
    });

    expect(response.status).toBe(401);
    expect(orders.rows).toHaveLength(0);
  });

  it('rejects a webhook missing the X-Shopify-Webhook-Id header', async () => {
    const body = JSON.stringify({ id: 3 });
    const response = await fetch(`${baseUrl}/webhooks/orders/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Hmac-Sha256': sign(body),
      },
      body,
    });

    expect(response.status).toBe(400);
  });

  it('processes the three mandatory compliance webhook topics', async () => {
    for (const [path, payload] of [
      ['/webhooks/customers/data_request', { customer: { id: 42 } }],
      ['/webhooks/customers/redact', { customer: { id: 42 } }],
      ['/webhooks/shop/redact', { shop_id: 1 }],
    ] as const) {
      const body = JSON.stringify(payload);
      const response = await fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Hmac-Sha256': sign(body),
          'X-Shopify-Webhook-Id': randomUUID(),
        },
        body,
      });
      expect(response.status, `${path} should return 200`).toBe(200);
    }
  });

  it('registers a push token', async () => {
    const response = await fetch(`${baseUrl}/push-tokens`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        deviceId: 'dev-1',
        customerId: null,
        fcmToken: 'tok-abc',
        platform: 'ios',
      }),
    });

    expect(response.status).toBe(200);
    expect(pushTokens.byDeviceId.get('dev-1')?.fcmToken).toBe('tok-abc');
  });

  it('lists a customer\'s mirrored orders, newest first', async () => {
    for (const [id, placedAt] of [[10, '2026-01-01T00:00:00Z'], [11, '2026-06-01T00:00:00Z']] as const) {
      const body = JSON.stringify({
        id,
        created_at: placedAt,
        customer: { id: 77, email: 'c@example.com' },
      });
      await fetch(`${baseUrl}/webhooks/orders/create`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Hmac-Sha256': sign(body),
          'X-Shopify-Webhook-Id': randomUUID(),
        },
        body,
      });
    }

    const response = await fetch(`${baseUrl}/customers/77/orders`);
    expect(response.status).toBe(200);
    const json = (await response.json()) as { orders: Array<{ shopifyOrderId: string }> };
    expect(json.orders.map((o) => o.shopifyOrderId)).toEqual(['11', '10']);
  });

  it('rejects an invalid push-token request', async () => {
    const response = await fetch(`${baseUrl}/push-tokens`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: 'dev-1' }),
    });
    expect(response.status).toBe(400);
  });
});

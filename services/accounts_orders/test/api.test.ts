import { createHmac, randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

const secret = 'shpss_test_secret';

class InMemoryCustomerTokenVerifier implements CustomerTokenVerifier {
  readonly customerIdsByToken = new Map<string, string>();
  unavailable = false;

  async resolveCustomerId(accessToken: string): Promise<string | null> {
    if (this.unavailable) throw new Error('shopify unavailable');
    return this.customerIdsByToken.get(accessToken) ?? null;
  }
}

function sign(body: string): string {
  return createHmac('sha256', secret).update(body).digest('base64');
}

describe('accounts_orders API', () => {
  let server: Server;
  let baseUrl: string;
  let customers: InMemoryCustomersRepository;
  let appAccounts: InMemoryAppAccountsRepository;
  let orders: InMemoryOrdersRepository;
  let webhookEvents: InMemoryWebhookEventsRepository;
  let pushTokens: InMemoryPushTokensRepository;
  let customerTokenVerifier: InMemoryCustomerTokenVerifier;

  beforeEach(async () => {
    customers = new InMemoryCustomersRepository();
    appAccounts = new InMemoryAppAccountsRepository();
    orders = new InMemoryOrdersRepository();
    webhookEvents = new InMemoryWebhookEventsRepository();
    pushTokens = new InMemoryPushTokensRepository();
    customerTokenVerifier = new InMemoryCustomerTokenVerifier();
    customerTokenVerifier.customerIdsByToken.set(
      'shopify-token-77',
      'gid://shopify/Customer/77',
    );
    customerTokenVerifier.customerIdsByToken.set(
      'shopify-token-88',
      'gid://shopify/Customer/88',
    );
    const deps: ServerDeps = {
      appAccounts,
      customers,
      orders,
      webhookEvents,
      pushTokens,
      webhookSecret: secret,
      customerTokenVerifier,
    };
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

  it('registers a first-party account and authenticates its opaque session', async () => {
    const registration = await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: ' Shopper@Example.com ',
        password: 'correct horse battery staple',
        displayName: 'Ana',
        deviceId: 'dev-account-1',
      }),
    });
    expect(registration.status).toBe(201);
    const body = (await registration.json()) as {
      account: { id: string; email: string; emailVerified: boolean };
      session: { token: string };
    };
    expect(body.account.email).toBe('shopper@example.com');
    expect(body.account.emailVerified).toBe(false);
    expect(appAccounts.byId.get(body.account.id)?.email).toBe('shopper@example.com');

    const me = await fetch(`${baseUrl}/accounts/me`, {
      headers: { Authorization: `Bearer ${body.session.token}` },
    });
    expect(me.status).toBe(200);

    const logout = await fetch(`${baseUrl}/accounts/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${body.session.token}` },
    });
    expect(logout.status).toBe(200);
    expect((await fetch(`${baseUrl}/accounts/me`, {
      headers: { Authorization: `Bearer ${body.session.token}` },
    })).status).toBe(401);

    const badLogin = await fetch(`${baseUrl}/accounts/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'shopper@example.com',
        password: 'wrong-password',
        deviceId: 'dev-account-2',
      }),
    });
    expect(badLogin.status).toBe(401);

    const login = await fetch(`${baseUrl}/accounts/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'SHOPPER@EXAMPLE.COM',
        password: 'correct horse battery staple',
        deviceId: 'dev-account-2',
      }),
    });
    expect(login.status).toBe(200);
    const loginBody = (await login.json()) as {
      account: { id: string; email: string };
      session: { token: string };
    };
    expect(loginBody.account.id).toBe(body.account.id);
    expect(loginBody.session.token).not.toBe(body.session.token);
    expect((await fetch(`${baseUrl}/accounts/me`, {
      headers: { Authorization: `Bearer ${loginBody.session.token}` },
    })).status).toBe(200);
  });

  it('rejects malformed first-party registration data', async () => {
    const response = await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'not-an-email', password: 'password', deviceId: 'dev-1' }),
    });
    expect(response.status).toBe(400);
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

  it('rejects push-token registration without a valid customer bearer', async () => {
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

    expect(response.status).toBe(401);
    expect(pushTokens.byDeviceId.size).toBe(0);
  });

  it('binds a push token to the verified customer and ignores a spoofed body id', async () => {
    const response = await fetch(`${baseUrl}/push-tokens`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer shopify-token-77',
      },
      body: JSON.stringify({
        deviceId: 'dev-1',
        customerId: '88',
        fcmToken: 'tok-abc',
        platform: 'ios',
      }),
    });

    expect(response.status).toBe(200);
    expect(pushTokens.byDeviceId.get('dev-1')).toMatchObject({
      customerId: '77',
      fcmToken: 'tok-abc',
    });
  });

  it('does not let another authenticated customer take over a device token', async () => {
    await pushTokens.upsert({
      deviceId: 'dev-1',
      customerId: '77',
      fcmToken: 'tok-original',
      platform: 'ios',
    });

    const response = await fetch(`${baseUrl}/push-tokens`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer shopify-token-88',
      },
      body: JSON.stringify({
        deviceId: 'dev-1',
        fcmToken: 'tok-attacker',
        platform: 'android',
      }),
    });

    expect(response.status).toBe(409);
    expect(pushTokens.byDeviceId.get('dev-1')).toMatchObject({
      customerId: '77',
      fcmToken: 'tok-original',
      platform: 'ios',
    });
  });

  it('lists only the authenticated customer\'s mirrored orders, newest first', async () => {
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

    const otherCustomerBody = JSON.stringify({
      id: 12,
      created_at: '2026-08-01T00:00:00Z',
      customer: { id: 88, email: 'other@example.com' },
    });
    await fetch(`${baseUrl}/webhooks/orders/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Hmac-Sha256': sign(otherCustomerBody),
        'X-Shopify-Webhook-Id': randomUUID(),
      },
      body: otherCustomerBody,
    });

    const unauthenticated = await fetch(`${baseUrl}/customers/me/orders`);
    expect(unauthenticated.status).toBe(401);

    const response = await fetch(`${baseUrl}/customers/me/orders`, {
      headers: { Authorization: 'Bearer shopify-token-77' },
    });
    expect(response.status).toBe(200);
    const json = (await response.json()) as { orders: Array<{ shopifyOrderId: string }> };
    expect(json.orders.map((o) => o.shopifyOrderId)).toEqual(['11', '10']);

    expect((await fetch(`${baseUrl}/customers/77/orders`, {
      headers: { Authorization: 'Bearer shopify-token-77' },
    })).status).toBe(404);
  });

  it('requires an explicit Shopify link before a Monetta session can read orders', async () => {
    const orderBody = JSON.stringify({
      id: 21,
      created_at: '2026-08-01T00:00:00Z',
      customer: { id: 77, email: 'linked@example.com' },
    });
    await fetch(`${baseUrl}/webhooks/orders/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Hmac-Sha256': sign(orderBody),
        'X-Shopify-Webhook-Id': randomUUID(),
      },
      body: orderBody,
    });

    const registration = await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'linked@example.com',
        password: 'correct horse battery staple',
        deviceId: 'dev-linked',
      }),
    });
    const registrationBody = (await registration.json()) as {
      account: { id: string };
      session: { token: string };
    };
    const authorization = `Bearer ${registrationBody.session.token}`;

    expect((await fetch(`${baseUrl}/customers/me/orders`, {
      headers: { Authorization: authorization },
    })).status).toBe(403);

    const account = appAccounts.byId.get(registrationBody.account.id);
    expect(account).toBeDefined();
    appAccounts.byId.set(registrationBody.account.id, {
      ...account!,
      shopifyCustomerId: 'gid://shopify/Customer/77',
    });

    const response = await fetch(`${baseUrl}/customers/me/orders`, {
      headers: { Authorization: authorization },
    });
    expect(response.status).toBe(200);
    const json = (await response.json()) as { orders: Array<{ shopifyOrderId: string }> };
    expect(json.orders.map((order) => order.shopifyOrderId)).toEqual(['21']);
  });

  it('rejects an invalid customer bearer', async () => {
    const response = await fetch(`${baseUrl}/customers/me/orders`, {
      headers: { Authorization: 'Bearer invalid-token' },
    });

    expect(response.status).toBe(401);
  });

  it('returns 503 instead of leaking data when Shopify token verification is unavailable', async () => {
    customerTokenVerifier.unavailable = true;

    const response = await fetch(`${baseUrl}/customers/me/orders`, {
      headers: { Authorization: 'Bearer any-token' },
    });

    expect(response.status).toBe(503);
  });

  it('rejects an invalid push-token request', async () => {
    const response = await fetch(`${baseUrl}/push-tokens`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer shopify-token-77',
      },
      body: JSON.stringify({ deviceId: 'dev-1' }),
    });
    expect(response.status).toBe(400);
  });
});

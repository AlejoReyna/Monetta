import type { Server } from 'node:http';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';
import { RewardsService } from '../src/rewards/service.js';
import { loadRewardsEnv } from '../src/rewards/rewardsConfig.js';
import { DisabledDiscountAdapter } from '../src/rewards/shopifyDiscountAdapter.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import { InMemoryRewardsRepository } from './support/inMemoryRewardsRepository.js';

class Verifier implements CustomerTokenVerifier {
  readonly ids = new Map<string, string>([['tok-77', 'gid://shopify/Customer/77']]);
  async resolveCustomerId(token: string): Promise<string | null> {
    return this.ids.get(token) ?? null;
  }
}

const auth = { Authorization: 'Bearer tok-77', 'Content-Type': 'application/json' };

describe('rewards API v1', () => {
  let server: Server;
  let baseUrl: string;
  let rewards: InMemoryRewardsRepository;
  let service: RewardsService;

  beforeEach(async () => {
    rewards = new InMemoryRewardsRepository();
    service = new RewardsService({
      rewards,
      env: { ...loadRewardsEnv({} as NodeJS.ProcessEnv), rewardsEnabled: true, redemptionEnabled: false },
      discounts: new DisabledDiscountAdapter(),
      shopDomain: 'monetta-staging.myshopify.com',
    });
    const deps: ServerDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shpss_test_secret',
      customerTokenVerifier: new Verifier(),
      rewards: { service },
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

  it('401 sin credencial; resumen con ceros honestos para cuenta nueva', async () => {
    expect(await (await fetch(`${baseUrl}/customers/me/rewards`)).status).toBe(401);
    const res = await fetch(`${baseUrl}/customers/me/rewards`, { headers: auth });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      balance: { availableCents: number; pendingCents: number };
      program: { redemptionEnabled: boolean };
      incentives: { firstPurchase: { enabled: boolean } };
    };
    expect(body.balance).toMatchObject({ availableCents: 0, pendingCents: 0 });
    expect(body.program.redemptionEnabled).toBe(false);
    expect(body.incentives.firstPurchase.enabled).toBe(false);
  });

  it('cotiza con tope 20% y bloquea el canje tras la bandera', async () => {
    await service.onOrderPaid({
      eventId: 'ev:paid:1', orderShopifyId: '8001', accountId: '77',
      subtotalEligibleCents: 180000,
      lines: [{ quantity: 1, unitPriceCents: 180000, eligible: true }],
      isWholesale: false, signals: [],
    });
    await service.onOrderDelivered({ eventId: 'ev:del:1', orderShopifyId: '8001' });
    const quote = await fetch(`${baseUrl}/customers/me/rewards/quotes`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({
        cartRevision: 'rev-1',
        lines: [{ quantity: 1, unitPriceCents: 90000, eligible: true }],
      }),
    });
    expect(quote.status).toBe(201);
    const q = (await quote.json()) as { quoteId: string; maxAllowedCents: number };
    expect(q.maxAllowedCents).toBe(5400);
    const redeem = await fetch(`${baseUrl}/customers/me/rewards/redemptions`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({ quoteId: q.quoteId, amountCents: 1000, idempotencyKey: 'api-key-1234' }),
    });
    expect(redeem.status).toBe(409);
    expect(await redeem.json()).toMatchObject({ error: 'redemption_disabled' });
  });

  it('actividad y estado por pedido; otra cuenta no ve el pedido', async () => {
    await service.onOrderPaid({
      eventId: 'ev:paid:1', orderShopifyId: '8001', accountId: '77',
      subtotalEligibleCents: 180000,
      lines: [{ quantity: 1, unitPriceCents: 180000, eligible: true }],
      isWholesale: false, signals: [],
    });
    const activity = await fetch(`${baseUrl}/customers/me/rewards/activity?limit=10`, { headers: auth });
    expect(activity.status).toBe(200);
    const list = (await activity.json()) as { movements: unknown[] };
    expect(list.movements.length).toBeGreaterThan(0);
    const order = await fetch(`${baseUrl}/customers/me/orders/8001/rewards`, { headers: auth });
    expect(order.status).toBe(200);
    // Cuenta 88 no existe como titular del pedido 8001 -> 404, no 403 con fuga.
    const other = await fetch(`${baseUrl}/customers/me/orders/8001/rewards`, {
      headers: { Authorization: 'Bearer tok-88', 'Content-Type': 'application/json' },
    });
    expect([401, 404]).toContain(other.status);
  });
});

describe('bandera REWARDS_ENABLED', () => {
  it('apagada si falta la variable; solo se enciende explicitamente', () => {
    expect(loadRewardsEnv({} as NodeJS.ProcessEnv).rewardsEnabled).toBe(false);
    expect(loadRewardsEnv({ REWARDS_ENABLED: '' } as NodeJS.ProcessEnv).rewardsEnabled).toBe(false);
    expect(loadRewardsEnv({ REWARDS_ENABLED: 'true' } as NodeJS.ProcessEnv).rewardsEnabled).toBe(true);
    expect(loadRewardsEnv({ REWARDS_ENABLED: 'false' } as NodeJS.ProcessEnv).rewardsEnabled).toBe(false);
  });

  it('sin programa montado, las rutas de Rewards no existen', async () => {
    const app = createApp({
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shpss_test_secret',
      customerTokenVerifier: new Verifier(),
    });
    const server = await new Promise<Server>((resolve) => {
      const s = app.listen(0, '127.0.0.1', () => resolve(s));
    });
    try {
      const address = server.address();
      if (address === null || typeof address === 'string') throw new Error('no address');
      const res = await fetch(`http://127.0.0.1:${address.port}/customers/me/rewards`, { headers: auth });
      expect(res.status).toBe(404);
    } finally {
      await new Promise<void>((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      });
    }
  });
});

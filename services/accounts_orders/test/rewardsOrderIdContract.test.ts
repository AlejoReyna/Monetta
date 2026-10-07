import { readFileSync } from 'node:fs';
import type { Server } from 'node:http';
import { fileURLToPath } from 'node:url';
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

// CONTRACT-01: shared fixture with test/features/rewards/rewards_order_id_contract_test.dart.
const fixture = JSON.parse(
  readFileSync(
    fileURLToPath(new URL('../../../test/fixtures/contracts/rewards_order_id.json', import.meta.url)),
    'utf8',
  ),
) as {
  storedOrderId: string;
  acceptedIds: string[];
  rejectedIds: string[];
};

class Verifier implements CustomerTokenVerifier {
  readonly ids = new Map<string, string>([['tok-77', 'gid://shopify/Customer/77']]);
  async resolveCustomerId(token: string): Promise<string | null> {
    return this.ids.get(token) ?? null;
  }
}

const auth = { Authorization: 'Bearer tok-77', 'Content-Type': 'application/json' };

describe('CONTRACT-01 rewards order id', () => {
  let server: Server;
  let baseUrl: string;

  const getOrderRewards = (id: string) =>
    fetch(`${baseUrl}/customers/me/orders/${encodeURIComponent(id)}/rewards`, { headers: auth });

  beforeEach(async () => {
    const rewards = new InMemoryRewardsRepository();
    const service = new RewardsService({
      rewards,
      env: { ...loadRewardsEnv({} as NodeJS.ProcessEnv), rewardsEnabled: true, redemptionEnabled: false },
      discounts: new DisabledDiscountAdapter(),
      shopDomain: 'monetta-staging.myshopify.com',
    });
    await service.onOrderPaid({
      eventId: 'ev:paid:1', orderShopifyId: fixture.storedOrderId, accountId: '77',
      subtotalEligibleCents: 180000,
      lines: [{ quantity: 1, unitPriceCents: 180000, eligible: true }],
      isWholesale: false, signals: [],
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

  for (const id of fixture.acceptedIds) {
    it(`CONTRACT-01 accepts "${id}" and normalizes to the stored numeric id`, async () => {
      const baseline = await getOrderRewards(fixture.storedOrderId);
      expect(baseline.status).toBe(200);
      const expected = (await baseline.json()) as { orderShopifyId: string };

      const res = await getOrderRewards(id);
      expect(res.status).toBe(200);
      const body = (await res.json()) as { orderShopifyId: string };
      expect(body).toEqual(expected);
      expect(body.orderShopifyId).toBe(fixture.storedOrderId);
    });
  }

  for (const id of fixture.rejectedIds) {
    it(`CONTRACT-01 rejects "${id}" with 400 invalid_request`, async () => {
      const res = await getOrderRewards(id);
      expect(res.status).toBe(400);
      expect(await res.json()).toEqual({ error: 'invalid_request' });
    });
  }
});

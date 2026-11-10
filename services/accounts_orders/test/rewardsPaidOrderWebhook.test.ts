import { createHmac, randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';
import { loadRewardsEnv } from '../src/rewards/rewardsConfig.js';
import { RewardsService } from '../src/rewards/service.js';
import { DisabledDiscountAdapter } from '../src/rewards/shopifyDiscountAdapter.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import { InMemoryRewardsRepository } from './support/inMemoryRewardsRepository.js';

const secret = 'shpss_test_secret';

/** $1,999.00 → 199900 cents; 3% half-up = 5997. */
const orderPrice = '1999.00';
const expectedPendingCents = 5997;

class Verifier implements CustomerTokenVerifier {
  async resolveCustomerId(): Promise<string | null> {
    return null;
  }
}

function sign(body: string): string {
  return createHmac('sha256', secret).update(body).digest('base64');
}

describe('paid order webhook → rewards', () => {
  let server: Server;
  let baseUrl: string;
  let rewards: InMemoryRewardsRepository;

  beforeEach(async () => {
    rewards = new InMemoryRewardsRepository();
    const service = new RewardsService({
      rewards,
      env: { ...loadRewardsEnv({} as NodeJS.ProcessEnv), redemptionEnabled: false },
      discounts: new DisabledDiscountAdapter(),
      shopDomain: 'monetta-staging.myshopify.com',
    });
    const deps: ServerDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: secret,
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

  it('creates a pending 3% lot from a signed paid order with line items', async () => {
    // orders/paid is not its own route. A paid order arrives on
    // orders/create or orders/updated with financial_status paid, and both
    // call bridgePaidIfApplicable.
    const body = JSON.stringify({
      id: 9001,
      financial_status: 'paid',
      currency: 'MXN',
      customer: { id: 77 },
      discount_codes: [{ code: 'LANZAMIENTO' }],
      line_items: [
        {
          variant_id: 11,
          product_id: 22,
          quantity: 1,
          price: orderPrice,
          total_discount: '0.00',
        },
      ],
    });
    const response = await fetch(`${baseUrl}/webhooks/orders/updated`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Hmac-Sha256': sign(body),
        'X-Shopify-Webhook-Id': randomUUID(),
      },
      body,
    });

    expect(response.status).toBe(200);
    expect(rewards.lotCount()).toBe(1);
    expect(await rewards.orderRewards('77', '9001')).toMatchObject({
      state: 'pending',
      earnedPendingCents: expectedPendingCents,
      isWholesale: false,
    });
    expect((await rewards.balance('77')).pendingCents).toBe(expectedPendingCents);
  });
});

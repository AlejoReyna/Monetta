import { createHmac, randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
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

function sign(body: string): string {
  return createHmac('sha256', secret).update(body).digest('base64');
}

describe('paid order webhook feeds Rewards', () => {
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
      server.close((error) => (error ? reject(error) : resolve()));
    });
  });

  async function post(topic: string, payload: Record<string, unknown>): Promise<number> {
    const body = JSON.stringify(payload);
    const response = await fetch(`${baseUrl}/webhooks/${topic}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Hmac-Sha256': sign(body),
        'X-Shopify-Webhook-Id': randomUUID(),
        'X-Shopify-Shop-Domain': 'monetta-staging.myshopify.com',
      },
      body,
    });
    return response.status;
  }

  const paidOrder = {
    id: 9001,
    financial_status: 'paid',
    currency: 'MXN',
    customer: { id: 77, email: 'a@example.com' },
    line_items: [
      { variant_id: 1, product_id: 2, quantity: 1, price: '1000.00', total_discount: '0.00' },
      { variant_id: 3, product_id: 4, quantity: 2, price: '500.00', total_discount: '100.00' },
    ],
  };

  it('creates pending earn on the eligible subtotal (3% of $1,900.00)', async () => {
    expect(await post('orders/create', paidOrder)).toBe(200);

    const balance = await rewards.balance('77');
    expect(balance.pendingCents).toBe(5700);
    expect(balance.availableCents).toBe(0);
  });

  it('does not double-earn when orders/updated repeats the same paid order', async () => {
    expect(await post('orders/create', paidOrder)).toBe(200);
    expect(await post('orders/updated', paidOrder)).toBe(200);

    expect((await rewards.balance('77')).pendingCents).toBe(5700);
  });

  it('earns nothing for an order that is not paid yet', async () => {
    expect(
      await post('orders/create', { ...paidOrder, id: 9002, financial_status: 'pending' }),
    ).toBe(200);

    expect((await rewards.balance('77')).pendingCents).toBe(0);
  });

  it('earns nothing for a wholesale order detected from its tags', async () => {
    expect(
      await post('orders/create', {
        ...paidOrder,
        id: 9003,
        tags: 'mayoreo',
      }),
    ).toBe(200);

    expect((await rewards.balance('77')).pendingCents).toBe(0);
  });
});

import { createHmac, randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';
import { loadRewardsEnv } from '../src/rewards/rewardsConfig.js';
import { RewardsService } from '../src/rewards/service.js';
import {
  BasicSingleUseCouponAdapter,
  type BasicCouponProvisioner,
} from '../src/rewards/shopifyDiscountAdapter.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import { InMemoryRewardsRepository } from './support/inMemoryRewardsRepository.js';

const secret = 'shpss_test_secret';

/** $1,999.00 → 199900 cents; PRO 1% half-up = 1999. */
const orderPrice = '1999.00';
const expectedPendingCents = 1999;

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
  let service: RewardsService;

  beforeEach(async () => {
    rewards = new InMemoryRewardsRepository();
    const provisioner: BasicCouponProvisioner = {
      async createSingleUseFixedCode({ redemptionId }) {
        return {
          discountId: `gid://shopify/DiscountCodeNode/${redemptionId}`,
          code: `MRW-${redemptionId.replace(/-/g, '').slice(0, 10).toUpperCase()}`,
        };
      },
      async deleteCode() {},
      async usageCount() { return 0; },
    };
    service = new RewardsService({
      rewards,
      env: { ...loadRewardsEnv({} as NodeJS.ProcessEnv), redemptionEnabled: true },
      discounts: new BasicSingleUseCouponAdapter(provisioner),
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

  it('creates a pending PRO 1% lot from a signed paid order with line items', async () => {
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

  it('settles a redeemed Rewards coupon and credits new pending cashback on a paid order webhook', async () => {
    // 1. Seed delivered order ($2,000 * 1% PRO = $20 + $100 PRO bonus = $120 available).
    await service.onOrderPaid({
      eventId: 'seed:paid:8001',
      orderShopifyId: '8001',
      accountId: '77',
      subtotalEligibleCents: 200000,
      lines: [{ quantity: 1, unitPriceCents: 200000, discountCents: 0, eligible: true }],
      isWholesale: false,
      signals: [],
    });
    await service.onOrderDelivered({ eventId: 'seed:deliv:8001', orderShopifyId: '8001' });

    // 2. Quote and redeem $60.00 against a $1,000.00 second cart ($120 avail <= $200 20% cap -> max 12000).
    const quote = await service.quote('77', {
      cartRevision: 'rev-2',
      lines: [{ quantity: 1, unitPriceCents: 100000, discountCents: 0, eligible: true }],
    });
    expect(quote.maxAllowedCents).toBe(12000);
    const redeemed = await service.redeem({
      accountId: '77',
      quoteId: quote.quoteId,
      amountCents: 6000,
      isWholesaleCart: false,
      idempotencyKey: 'idem-second-order-1',
    });
    const code = redeemed.discount?.code;
    expect(code).toMatch(/^MRW-/);

    // 3. Deliver the paid order webhook carrying that code and $60.00 discount.
    const body = JSON.stringify({
      id: 9002,
      financial_status: 'paid',
      currency: 'MXN',
      customer: { id: 77 },
      discount_codes: [{ code, amount: '60.00' }],
      line_items: [
        {
          variant_id: 12,
          product_id: 23,
          quantity: 1,
          price: '1000.00',
          total_discount: '60.00',
        },
      ],
    });
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

    // Available balance is now $60 (12000 - 6000), reserved is 0, and new net cashback ($940 * 1% PRO = $9.40 = 940c) is pending.
    const bal = await rewards.balance('77');
    expect(bal.availableCents).toBe(6000);
    expect(bal.reservedCents).toBe(0);
    expect(bal.pendingCents).toBe(940);

    // Order snapshot records both usedCents and earnedPendingCents.
    expect(await rewards.orderRewards('77', '9002')).toMatchObject({
      state: 'pending',
      usedCents: 6000,
      earnedPendingCents: 940,
    });

    // Redemption record moved to settled and ledger contains redeem_settled in state 'used'.
    const updatedRedemption = await rewards.findRedemption('77', redeemed.redemption.redemptionId);
    expect(updatedRedemption?.state).toBe('settled');
    expect(updatedRedemption?.settledCents).toBe(6000);
    const { movements } = await rewards.activity('77', 10);
    expect(movements.some((m) => m.type === 'redeem_settled' && m.state === 'used' && m.amountCents === -6000)).toBe(true);
  });
});

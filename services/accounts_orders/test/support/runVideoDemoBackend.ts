import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../../src/api/server.js';
import type { CustomerTokenVerifier } from '../../src/auth/customerTokenVerifier.js';
import { loadRewardsEnv } from '../../src/rewards/rewardsConfig.js';
import { RewardsService } from '../../src/rewards/service.js';
import {
  BasicSingleUseCouponAdapter,
  type BasicCouponProvisioner,
} from '../../src/rewards/shopifyDiscountAdapter.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './inMemoryRepositories.js';
import { InMemoryRewardsRepository } from './inMemoryRewardsRepository.js';

const PORT = Number.parseInt(process.env.DEMO_PORT ?? '8099', 10);
const WEBHOOK_SECRET = process.env.DEMO_WEBHOOK_SECRET ?? 'demo_webhook_secret_12345';
const DEMO_TOKEN = 'demo-shopify-token';
const DEMO_CUSTOMER_ID = '77001';

class DemoTokenVerifier implements CustomerTokenVerifier {
  async resolveCustomerId(token: string): Promise<string | null> {
    return token === DEMO_TOKEN ? DEMO_CUSTOMER_ID : null;
  }
}

async function main(): Promise<void> {
  const rewardsRepo = new InMemoryRewardsRepository();
  const issuedCoupons = new Map<string, { discountId: string; amountCents: number; used: number }>();

  const provisioner: BasicCouponProvisioner = {
    async createSingleUseFixedCode({ redemptionId, amountCents }) {
      const code = `MRW-${redemptionId.replace(/-/g, '').slice(0, 10).toUpperCase()}`;
      const discountId = `gid://shopify/DiscountCodeNode/${redemptionId}`;
      issuedCoupons.set(code, { discountId, amountCents, used: 0 });
      return { discountId, code };
    },
    async deleteCode(discountId) {
      for (const [code, entry] of issuedCoupons.entries()) {
        if (entry.discountId === discountId) issuedCoupons.delete(code);
      }
    },
    async usageCount(discountId) {
      for (const entry of issuedCoupons.values()) {
        if (entry.discountId === discountId) return entry.used;
      }
      return 0;
    },
  };

  const rewardsService = new RewardsService({
    rewards: rewardsRepo,
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
    webhookSecret: WEBHOOK_SECRET,
    customerTokenVerifier: new DemoTokenVerifier(),
    rewards: { service: rewardsService },
  };

  const app = createApp(deps);

  // Demo-only helper endpoint so the simulator cart reconciler reads the exact
  // provisioned fixed discount amount returned by RewardsService.
  app.get('/demo/coupons/:code', (req, res) => {
    const code = String(req.params.code ?? '').trim().toUpperCase();
    const entry = issuedCoupons.get(code);
    if (!entry) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    res.status(200).json({ code, amountCents: entry.amountCents });
  });

  let server: Server;
  await new Promise<void>((resolve) => {
    server = app.listen(PORT, '127.0.0.1', resolve);
  });
  console.log(`DEMO_BACKEND_READY http://127.0.0.1:${PORT}`);

  const shutdown = () => {
    server.close(() => process.exit(0));
  };
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

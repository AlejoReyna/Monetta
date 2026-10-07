import { readFileSync } from 'node:fs';
import type { Server } from 'node:http';
import { fileURLToPath } from 'node:url';
import { afterEach, describe, expect, it } from 'vitest';
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

// CONTRACT-02: the same fixture is read by test/features/rewards/rewards_disabled_contract_test.dart.
interface Route {
  method: string;
  path: string;
}
interface Fixture {
  disabled: { status: number; error: string; routes: Route[] };
  unknownRoute: Route & { status: number; error: string };
}

const fixture = JSON.parse(
  readFileSync(
    fileURLToPath(new URL('../../../test/fixtures/contracts/rewards_disabled.json', import.meta.url)),
    'utf8',
  ),
) as Fixture;

class Verifier implements CustomerTokenVerifier {
  readonly ids = new Map<string, string>([['tok-77', 'gid://shopify/Customer/77']]);
  async resolveCustomerId(token: string): Promise<string | null> {
    return this.ids.get(token) ?? null;
  }
}

const auth = { Authorization: 'Bearer tok-77', 'Content-Type': 'application/json' };

let server: Server | undefined;

async function start(withRewards: boolean): Promise<string> {
  const deps: ServerDeps = {
    appAccounts: new InMemoryAppAccountsRepository(),
    customers: new InMemoryCustomersRepository(),
    orders: new InMemoryOrdersRepository(),
    webhookEvents: new InMemoryWebhookEventsRepository(),
    pushTokens: new InMemoryPushTokensRepository(),
    webhookSecret: 'shpss_test_secret',
    customerTokenVerifier: new Verifier(),
  };
  if (withRewards) {
    const service = new RewardsService({
      rewards: new InMemoryRewardsRepository(),
      env: { ...loadRewardsEnv({} as NodeJS.ProcessEnv), rewardsEnabled: true, redemptionEnabled: false },
      discounts: new DisabledDiscountAdapter(),
      shopDomain: 'monetta-staging.myshopify.com',
    });
    deps.rewards = { service };
  }
  const app = createApp(deps);
  const s = await new Promise<Server>((resolve) => {
    const listening = app.listen(0, '127.0.0.1', () => resolve(listening));
  });
  server = s;
  const address = s.address();
  if (address === null || typeof address === 'string') throw new Error('no address');
  return `http://127.0.0.1:${address.port}`;
}

async function call(baseUrl: string, route: Route): Promise<Response> {
  return fetch(`${baseUrl}${route.path}`, {
    method: route.method,
    headers: auth,
    ...(route.method === 'POST' ? { body: '{}' } : {}),
  });
}

async function expectJsonError(res: Response, status: number, error: string): Promise<void> {
  expect(res.status).toBe(status);
  expect(res.headers.get('content-type') ?? '').toContain('application/json');
  const headerId = res.headers.get('x-request-id');
  expect(headerId).toBeTruthy();
  const body = (await res.json()) as { error?: string; requestId?: string };
  expect(body.error).toBe(error);
  expect(body.requestId).toBe(headerId);
}

describe('CONTRACT-02 rewards disabled contract', () => {
  afterEach(async () => {
    const s = server;
    server = undefined;
    if (s === undefined) return;
    await new Promise<void>((resolve, reject) => {
      s.close((err) => (err ? reject(err) : resolve()));
    });
  });

  it('CONTRACT-02 without rewards every rewards route answers JSON feature_disabled with requestId', async () => {
    const baseUrl = await start(false);
    expect(fixture.disabled.routes.length).toBeGreaterThan(0);
    for (const route of fixture.disabled.routes) {
      const res = await call(baseUrl, route);
      await expectJsonError(res, fixture.disabled.status, fixture.disabled.error);
    }
  });

  it('CONTRACT-02 without rewards an unknown route answers JSON not_found with requestId', async () => {
    const baseUrl = await start(false);
    const res = await call(baseUrl, fixture.unknownRoute);
    await expectJsonError(res, fixture.unknownRoute.status, fixture.unknownRoute.error);
  });

  it('CONTRACT-02 with rewards mounted an unknown route answers JSON not_found with requestId', async () => {
    const baseUrl = await start(true);
    const res = await call(baseUrl, fixture.unknownRoute);
    await expectJsonError(res, fixture.unknownRoute.status, fixture.unknownRoute.error);
  });
});

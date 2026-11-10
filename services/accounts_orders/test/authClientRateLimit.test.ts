import { afterEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { SlidingWindowAdminRateLimiter } from '../src/admin/rateLimiter.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

const productionAuthLimit = 20;

class RejectingCustomerTokenVerifier implements CustomerTokenVerifier {
  async resolveCustomerId(): Promise<string | null> {
    return null;
  }
}

function attemptsOf(limiter: SlidingWindowAdminRateLimiter): Map<string, number[]> {
  return (limiter as unknown as { readonly attempts: Map<string, number[]> }).attempts;
}

describe('legacy auth client rate limit', () => {
  let server: Server | undefined;

  afterEach(async () => {
    if (server === undefined) return;
    const closing = server;
    server = undefined;
    await new Promise<void>((resolve, reject) => {
      closing.close((error) => error ? reject(error) : resolve());
    });
  });

  async function listen(authRateLimiter: SlidingWindowAdminRateLimiter): Promise<string> {
    const deps: ServerDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier: new RejectingCustomerTokenVerifier(),
      authRateLimiter,
    };
    const app = createApp(deps);
    const listening = await new Promise<Server>((resolve) => {
      const started = app.listen(0, '127.0.0.1', () => resolve(started));
    });
    server = listening;
    const address = listening.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    return `http://127.0.0.1:${address.port}`;
  }

  async function login(
    baseUrl: string,
    headers: Record<string, string>,
  ): Promise<{ status: number; body: unknown }> {
    const response = await fetch(`${baseUrl}/accounts/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify({
        email: 'nobody@example.com',
        password: 'wrong-password',
        deviceId: 's1-rate',
      }),
    });
    return { status: response.status, body: await response.json() };
  }

  it('rate-limits logins that share Fly-Client-IP even when X-Forwarded-For changes', async () => {
    const baseUrl = await listen(new SlidingWindowAdminRateLimiter(productionAuthLimit, 60_000));

    for (let attempt = 1; attempt <= productionAuthLimit; attempt += 1) {
      const response = await login(baseUrl, {
        'X-Forwarded-For': `203.0.113.${attempt}`,
        'Fly-Client-IP': '198.51.100.10',
      });
      expect(response.status, `attempt ${attempt}`).toBe(401);
      expect(response.body).toEqual({ error: 'invalid_credentials' });
    }

    for (let attempt = productionAuthLimit + 1; attempt <= 25; attempt += 1) {
      const response = await login(baseUrl, {
        'X-Forwarded-For': `203.0.113.${attempt}`,
        'Fly-Client-IP': '198.51.100.10',
      });
      expect(response.status, `attempt ${attempt}`).toBe(429);
      expect(response.body).toEqual({ error: 'rate_limited' });
    }
  });

  it('uses the socket address when Fly-Client-IP is absent and ignores X-Forwarded-For', async () => {
    const baseUrl = await listen(new SlidingWindowAdminRateLimiter(2, 60_000));

    for (let attempt = 1; attempt <= 2; attempt += 1) {
      const response = await login(baseUrl, { 'X-Forwarded-For': `198.51.100.${attempt}` });
      expect(response.status).toBe(401);
    }
    const limited = await login(baseUrl, { 'X-Forwarded-For': '198.51.100.99' });
    expect(limited.status).toBe(429);
    expect(limited.body).toEqual({ error: 'rate_limited' });
  });
});

describe('SlidingWindowAdminRateLimiter expiry', () => {
  it('deletes a key that no longer has attempts inside the window', () => {
    let now = 1_000_000;
    const limiter = new SlidingWindowAdminRateLimiter(1, 60_000, () => now);
    expect(limiter.allow('203.0.113.8', 'accounts.login')).toBe(true);
    expect(limiter.allow('203.0.113.8', 'accounts.login')).toBe(false);

    now += 60_001;
    expect(limiter.allow('203.0.113.9', 'accounts.login')).toBe(true);

    const attempts = attemptsOf(limiter);
    expect(attempts.has('203.0.113.8:accounts.login')).toBe(false);
    expect(attempts.get('203.0.113.9:accounts.login')).toEqual([now]);

    expect(limiter.allow('203.0.113.8', 'accounts.login')).toBe(true);
  });
});

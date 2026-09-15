import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { randomUUID } from 'node:crypto';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { ServerAdminAuthorizer } from '../src/admin/authorizer.js';
import { SlidingWindowAdminRateLimiter } from '../src/admin/rateLimiter.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import { InMemoryAdminPrincipalsRepository } from './support/inMemoryAdminPrincipalsRepository.js';

class FakeCustomerTokenVerifier implements CustomerTokenVerifier {
  readonly customerIdsByToken = new Map<string, string>();

  async resolveCustomerId(token: string): Promise<string | null> {
    return this.customerIdsByToken.get(token) ?? null;
  }
}

describe('WP-01 security remediation (F01, F02, F19)', () => {
  let server: Server;
  let baseUrl: string;
  let appAccounts: InMemoryAppAccountsRepository;
  let principals: InMemoryAdminPrincipalsRepository;
  let customerTokenVerifier: FakeCustomerTokenVerifier;
  let authRateLimiter: SlidingWindowAdminRateLimiter;
  let legacyAccountRegistrationEnabled: boolean;

  beforeEach(async () => {
    appAccounts = new InMemoryAppAccountsRepository();
    principals = new InMemoryAdminPrincipalsRepository();
    customerTokenVerifier = new FakeCustomerTokenVerifier();
    authRateLimiter = new SlidingWindowAdminRateLimiter(50, 60_000);
    legacyAccountRegistrationEnabled = true;
    await startServer();
  });

  afterEach(async () => {
    await stopServer();
  });

  async function startServer(): Promise<void> {
    const adminAuthorizer = new ServerAdminAuthorizer({
      appAccounts,
      customerTokenVerifier,
      principals,
      ownerShopifyCustomerIds: new Set(['9001']),
    });
    const deps: ServerDeps = {
      appAccounts,
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier,
      adminAuthorizer,
      adminEnvironment: 'staging',
      authRateLimiter,
      legacyAccountRegistrationEnabled,
    };
    const app = createApp(deps);
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;
  }

  async function stopServer(): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }

  async function register(email: string, deviceId: string, password = 'correct horse battery staple') {
    return fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, deviceId }),
    });
  }

  it('F01 persona E: unverified email matching owner address gets no admin capabilities', async () => {
    const reg = await register('owner@monetta.mx', 'persona-e');
    expect(reg.status).toBe(201);
    const { session } = await reg.json() as { session: { token: string } };

    const me = await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${session.token}` },
    });
    expect(me.status).toBe(200);
    expect(await me.json()).toMatchObject({
      roles: [],
      capabilities: { openAdmin: false, manageProducts: false },
    });
    expect(principals.rows.size).toBe(0);

    const privileged = await fetch(`${baseUrl}/admin/control-plane`, {
      headers: { Authorization: `Bearer ${session.token}` },
    });
    expect(privileged.status).toBe(403);
  });

  it('F01 personas U/O/R: ordinary denied, provisioned owner succeeds, revoked cannot regain', async () => {
    const userReg = await register('user@example.com', 'persona-u');
    const userToken = ((await userReg.json()) as { session: { token: string } }).session.token;
    expect((await fetch(`${baseUrl}/admin/control-plane`, {
      headers: { Authorization: `Bearer ${userToken}` },
    })).status).toBe(403);

    const ownerReg = await register('legit-owner@example.com', 'persona-o');
    const ownerBody = await ownerReg.json() as {
      account: { id: string };
      session: { token: string };
    };
    await principals.createIfAbsent({
      id: randomUUID(),
      subject: { type: 'app_account', id: ownerBody.account.id },
      role: 'owner',
      createdBy: 'test:provision',
    });
    expect((await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${ownerBody.session.token}` },
    })).status).toBe(200);
    expect(await (await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${ownerBody.session.token}` },
    })).json()).toMatchObject({ roles: ['owner'], capabilities: { openAdmin: true } });

    const revokedReg = await register('revoked@example.com', 'persona-r');
    const revokedBody = await revokedReg.json() as {
      account: { id: string };
      session: { token: string };
    };
    const principal = await principals.createIfAbsent({
      id: randomUUID(),
      subject: { type: 'app_account', id: revokedBody.account.id },
      role: 'owner',
      createdBy: 'test:provision',
    });
    principals.rows.set(`${principal.type}:${principal.id}`, {
      ...principal,
      active: false,
      revokedAt: new Date(),
    });

    const login = await fetch(`${baseUrl}/accounts/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'revoked@example.com',
        password: 'correct horse battery staple',
        deviceId: 'persona-r-relogin',
      }),
    });
    expect(login.status).toBe(200);
    const loginToken = ((await login.json()) as { session: { token: string } }).session.token;
    expect(await (await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${loginToken}` },
    })).json()).toMatchObject({ roles: [], capabilities: { openAdmin: false } });
    expect((await fetch(`${baseUrl}/admin/control-plane`, {
      headers: { Authorization: `Bearer ${loginToken}` },
    })).status).toBe(403);
  });

  it('F02: reusing legacy deviceId cannot alter the existing account', async () => {
    const legacy = await register('legacy@example.com', 'shared-device');
    expect(legacy.status).toBe(201);
    const legacyBody = await legacy.json() as {
      account: { id: string; email: string };
      session: { token: string };
    };
    const before = appAccounts.byId.get(legacyBody.account.id)!;
    const beforePassword = (await appAccounts.findCredentialsByEmail('legacy@example.com'))!.passwordHash;

    const attacker = await register('attacker@example.com', 'shared-device', 'attacker-password-1');
    expect(attacker.status).toBe(409);
    expect(await attacker.json()).toEqual({ error: 'registration_conflict' });

    const after = appAccounts.byId.get(legacyBody.account.id)!;
    expect(after.email).toBe(before.email);
    expect(after.displayName).toBe(before.displayName);
    expect(after.shopifyCustomerId).toBe(before.shopifyCustomerId);
    expect(after.emailVerified).toBe(before.emailVerified);
    expect((await appAccounts.findCredentialsByEmail('legacy@example.com'))!.passwordHash)
      .toBe(beforePassword);
    expect(appAccounts.byId.size).toBe(1);

    expect((await fetch(`${baseUrl}/accounts/me`, {
      headers: { Authorization: `Bearer ${legacyBody.session.token}` },
    })).status).toBe(200);
  });

  it('F19: rejects invalid types/lengths, rate-limits auth, and can disable new registrations', async () => {
    expect((await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 42, password: 'password', deviceId: 'd1' }),
    })).status).toBe(400);

    expect((await fetch(`${baseUrl}/accounts/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'a@b.com', password: 'x'.repeat(129), deviceId: 'd1' }),
    })).status).toBe(400);

    // Fresh limiter so prior suite traffic cannot exhaust the window.
    await stopServer();
    authRateLimiter = new SlidingWindowAdminRateLimiter(3, 60_000);
    await startServer();

    for (let i = 0; i < 3; i += 1) {
      const response = await fetch(`${baseUrl}/accounts/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: `missing${i}@example.com`,
          password: 'wrong-password',
          deviceId: `rate-${i}`,
        }),
      });
      expect(response.status).toBe(401);
      expect(await response.json()).toEqual({ error: 'invalid_credentials' });
    }
    const limited = await fetch(`${baseUrl}/accounts/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'missing@example.com',
        password: 'wrong-password',
        deviceId: 'rate-overflow',
      }),
    });
    expect(limited.status).toBe(429);
    expect(await limited.json()).toEqual({ error: 'rate_limited' });

    await stopServer();
    legacyAccountRegistrationEnabled = false;
    authRateLimiter = new SlidingWindowAdminRateLimiter(20, 60_000);
    await startServer();
    const disabled = await register('new@example.com', 'new-device');
    expect(disabled.status).toBe(403);
    expect(await disabled.json()).toEqual({ error: 'registration_disabled' });
  });
});

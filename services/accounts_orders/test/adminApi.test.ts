import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { ServerAdminAuthorizer } from '../src/admin/authorizer.js';
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

describe('native admin capability API', () => {
  let server: Server;
  let baseUrl: string;
  let appAccounts: InMemoryAppAccountsRepository;
  let principals: InMemoryAdminPrincipalsRepository;
  let customerTokenVerifier: FakeCustomerTokenVerifier;

  beforeEach(async () => {
    appAccounts = new InMemoryAppAccountsRepository();
    principals = new InMemoryAdminPrincipalsRepository();
    customerTokenVerifier = new FakeCustomerTokenVerifier();
    const adminAuthorizer = new ServerAdminAuthorizer({
      appAccounts,
      customerTokenVerifier,
      principals,
      ownerEmails: new Set(['owner@monetta.mx']),
      ownerShopifyCustomerIds: new Set(['77']),
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
      server.close((error) => error ? reject(error) : resolve());
    });
  });

  it('returns structured 401 errors with a request id for missing and invalid sessions', async () => {
    const missing = await fetch(`${baseUrl}/admin/me`);
    expect(missing.status).toBe(401);
    expect(missing.headers.get('x-request-id')).toMatch(/^req_/);
    expect(await missing.json()).toMatchObject({
      error: { code: 'UNAUTHORIZED', fields: {} },
    });

    const invalid = await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: 'Bearer revoked-token' },
    });
    expect(invalid.status).toBe(401);
    expect(await invalid.json()).toMatchObject({
      error: { code: 'UNAUTHORIZED', message: 'The session is invalid or expired.' },
    });
  });

  it('returns authenticated non-owner capabilities without granting admin access', async () => {
    const token = await registerAccount('shopper@example.com', 'shopper-device');
    const response = await fetch(`${baseUrl}/admin/me`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Admin-Email': 'owner@monetta.mx',
        'X-Admin-Role': 'owner',
      },
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      actor: { provider: 'monetta' },
      roles: [],
      capabilities: {
        openAdmin: false,
        manageProducts: false,
        manageExternalSources: false,
      },
      environment: 'staging',
    });
    expect(principals.rows.size).toBe(0);
  });

  it('bootstraps an owner by stable first-party account subject, not client claims', async () => {
    const token = await registerAccount('owner@monetta.mx', 'owner-device');
    const response = await fetch(`${baseUrl}/admin/me`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Admin-Email': 'attacker@example.com',
        'X-Admin-Role': 'shopper',
      },
    });

    expect(response.status).toBe(200);
    const body = await response.json() as {
      actor: { id: string; provider: string };
      roles: string[];
      capabilities: { openAdmin: boolean; manageNotifications: boolean };
    };
    expect(body.actor.provider).toBe('monetta');
    expect(body.actor.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(body.roles).toEqual(['owner']);
    expect(body.capabilities).toMatchObject({
      openAdmin: true,
      manageNotifications: true,
    });
    expect(principals.rows.size).toBe(1);

    const principal = [...principals.rows.values()][0]!;
    principals.rows.set(`${principal.type}:${principal.id}`, {
      ...principal,
      active: false,
      revokedAt: new Date(),
    });
    const revoked = await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(revoked.status).toBe(200);
    expect(await revoked.json()).toMatchObject({ roles: [], capabilities: { openAdmin: false } });
  });

  it('accepts a Shopify Customer token and bootstraps by customer id', async () => {
    customerTokenVerifier.customerIdsByToken.set(
      'shopify-owner-token',
      'gid://shopify/Customer/77',
    );
    const response = await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: 'Bearer shopify-owner-token' },
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      actor: { provider: 'shopify' },
      roles: ['owner'],
      capabilities: { openAdmin: true },
      environment: 'staging',
    });
    expect([...principals.rows.values()][0]).toMatchObject({
      type: 'shopify_customer',
      id: '77',
      active: true,
    });
  });

  it('revoked first-party sessions stop authenticating immediately', async () => {
    const token = await registerAccount('owner@monetta.mx', 'revoked-device');
    const logout = await fetch(`${baseUrl}/accounts/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(logout.status).toBe(200);

    const response = await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.status).toBe(401);
  });

  async function registerAccount(email: string, deviceId: string): Promise<string> {
    const response = await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'correct horse battery staple',
        deviceId,
      }),
    });
    expect(response.status).toBe(201);
    const body = await response.json() as { session: { token: string } };
    return body.session.token;
  }
});

import { afterEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { loadConfig } from '../src/config.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

class RejectingCustomerTokenVerifier implements CustomerTokenVerifier {
  async resolveCustomerId(): Promise<string | null> {
    return null;
  }
}

describe('LEGACY_ACCOUNT_REGISTRATION_ENABLED default', () => {
  let server: Server | undefined;

  afterEach(async () => {
    if (server === undefined) return;
    const closing = server;
    server = undefined;
    await new Promise<void>((resolve, reject) => {
      closing.close((error) => error ? reject(error) : resolve());
    });
  });

  async function register(enabled: boolean): Promise<{ status: number; body: unknown }> {
    const deps: ServerDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier: new RejectingCustomerTokenVerifier(),
      legacyAccountRegistrationEnabled: enabled,
    };
    const app = createApp(deps);
    server = await new Promise<Server>((resolve) => {
      const started = app.listen(0, '127.0.0.1', () => resolve(started));
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    const response = await fetch(`http://127.0.0.1:${address.port}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'legacy@example.com',
        password: 'correct horse battery staple',
        deviceId: 'legacy-default',
      }),
    });
    return { status: response.status, body: await response.json() };
  }

  it('disables /accounts/register when the variable is unset', async () => {
    const config = loadConfig({});
    expect(config.legacyAccountRegistrationEnabled).toBe(false);

    const response = await register(config.legacyAccountRegistrationEnabled);
    expect(response.status).toBe(403);
    expect(response.body).toEqual({ error: 'registration_disabled' });
  });

  it('keeps /accounts/register open when LEGACY_ACCOUNT_REGISTRATION_ENABLED=true', async () => {
    const config = loadConfig({ LEGACY_ACCOUNT_REGISTRATION_ENABLED: 'true' });
    expect(config.legacyAccountRegistrationEnabled).toBe(true);

    const response = await register(config.legacyAccountRegistrationEnabled);
    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({
      account: { email: 'legacy@example.com' },
    });
  });
});

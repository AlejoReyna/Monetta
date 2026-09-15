import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../src/api/server.js';
import type {
  ExternalCatalogAdminClient,
  ExternalSourcePolicyInput,
  ExternalSourceProjection,
} from '../src/admin/externalCatalogClient.js';
import { ownerAdminCapabilities } from '../src/admin/authorizer.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import {
  AllowingAdminRateLimiter,
  InMemoryAdminAuditLogger,
  InMemoryAdminIdempotencyRepository,
} from './support/inMemoryMutationRepositories.js';

describe('admin external catalog adapter', () => {
  let server: Server;
  let baseUrl: string;
  let externalCatalog: FakeExternalCatalogClient;
  let serverDeps: ServerDeps;

  beforeEach(async () => {
    externalCatalog = new FakeExternalCatalogClient();
    serverDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier: { resolveCustomerId: async () => null },
      adminAuthorizer: {
        resolve: async () => ({
          actor: {
            id: 'principal-1',
            provider: 'monetta' as const,
            subject: { type: 'app_account' as const, id: 'account-1' },
            role: 'owner' as const,
          },
          capabilities: ownerAdminCapabilities,
        }),
        authenticate: async (token: string) => token === 'owner-token'
          ? {
              id: 'principal-1',
              provider: 'monetta' as const,
              subject: { type: 'app_account' as const, id: 'account-1' },
              role: 'owner' as const,
            }
          : null,
      },
      adminEnvironment: 'staging',
      externalCatalog,
      idempotency: new InMemoryAdminIdempotencyRepository(),
      audit: new InMemoryAdminAuditLogger(),
      rateLimiter: new AllowingAdminRateLimiter(),
      mutationsEnabled: true,
      externalWritesEnabled: false,
    };
    const app = createApp(serverDeps);
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

  it('projects source health into the owner control plane without exposing service credentials', async () => {
    const response = await fetch(`${baseUrl}/admin/control-plane`, {
      headers: { Authorization: 'Bearer owner-token' },
    });
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body).toMatchObject({
      health: { sources: { status: 'ready', errorCode: null } },
      sources: [{ id: 'coach_us', merchant: 'Coach', itemCount: 4 }],
    });
    expect(JSON.stringify(body)).not.toContain('service-secret');
    expect(externalCatalog.fetchCalls).toBe(1);
  });

  it('keeps policy writes off until the external-write switch is deliberately enabled', async () => {
    const path = '/admin/external-policy/coach_us';
    const body = {
      enabled: false,
      itemLimit: 3,
      baseCommissionRate: 0.18,
      highValueCommissionRate: 0.12,
      highValueThreshold: 5000,
    };
    const disabled = await fetch(`${baseUrl}${path}`, {
      method: 'PUT',
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        'Idempotency-Key': 'external-disabled',
      },
      body: JSON.stringify(body),
    });
    expect(disabled.status).toBe(503);
    expect(externalCatalog.updateCalls).toBe(0);

    await closeServer();
    serverDeps = { ...serverDeps, externalWritesEnabled: true };
    const app = createApp(serverDeps);
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;

    const enabled = await fetch(`${baseUrl}${path}`, {
      method: 'PUT',
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        'Idempotency-Key': 'external-enabled',
      },
      body: JSON.stringify(body),
    });
    expect(enabled.status).toBe(200);
    expect(externalCatalog.updateCalls).toBe(1);
    expect(await enabled.json()).toMatchObject({ source: { enabled: false, itemLimit: 3 } });
  });

  async function closeServer(): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
});

class FakeExternalCatalogClient implements ExternalCatalogAdminClient {
  readonly source: ExternalSourceProjection = {
    id: 'coach_us',
    merchant: 'Coach',
    enabled: true,
    itemLimit: 8,
    baseCommissionRate: 0.22,
    highValueCommissionRate: 0.14,
    highValueThreshold: 4000,
    itemCount: 4,
    lastSuccessfulRunAt: '2026-08-30T12:00:00.000Z',
    health: { status: 'ready', reasons: [], freshnessHours: 1 },
    updatedAt: '2026-08-30T12:00:00.000Z',
  };
  fetchCalls = 0;
  updateCalls = 0;

  async fetchSources(): Promise<ExternalSourceProjection[]> {
    this.fetchCalls += 1;
    return [this.source];
  }

  async fetchSource(): Promise<ExternalSourceProjection> {
    return this.source;
  }

  async updateSource(input: {
    readonly sourceId: string;
    readonly source: ExternalSourcePolicyInput;
  }): Promise<ExternalSourceProjection> {
    this.updateCalls += 1;
    return { ...this.source, id: input.sourceId, ...input.source };
  }
}

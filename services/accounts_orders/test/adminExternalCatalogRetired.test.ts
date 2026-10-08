import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { ownerAdminCapabilities } from '../src/admin/authorizer.js';
import { loadConfig } from '../src/config.js';
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
  InMemoryAdminSyncJobRepository,
} from './support/inMemoryMutationRepositories.js';

// CONTRACT-06: the backend no longer exposes anything of the retired external
// (US) catalog. No external catalog client is configured, which is the real
// situation in staging and production.

const owner = {
  id: 'principal-1',
  provider: 'monetta' as const,
  subject: { type: 'app_account' as const, id: 'account-1' },
  role: 'owner' as const,
};

const ownerHeaders = { Authorization: 'Bearer owner-token' };

describe('CONTRACT-06 external catalog retired from the admin backend', () => {
  let server: Server;
  let baseUrl: string;

  beforeEach(async () => {
    const deps: ServerDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier: { resolveCustomerId: async () => null },
      adminAuthorizer: {
        resolve: async (token: string) => token === 'owner-token'
          ? { actor: owner, capabilities: ownerAdminCapabilities }
          : null,
        authenticate: async (token: string) => token === 'owner-token' ? owner : null,
      },
      adminEnvironment: 'staging',
      syncJobs: new InMemoryAdminSyncJobRepository(),
      idempotency: new InMemoryAdminIdempotencyRepository(),
      audit: new InMemoryAdminAuditLogger(),
      rateLimiter: new AllowingAdminRateLimiter(),
      mutationsEnabled: true,
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

  async function expectCatchAllNotFound(res: Response): Promise<void> {
    expect(res.status).toBe(404);
    const headerId = res.headers.get('x-request-id');
    expect(headerId).toBeTruthy();
    const body = (await res.json()) as Record<string, unknown>;
    expect(body).toEqual({ error: 'not_found', requestId: headerId });
  }

  it('CONTRACT-06 GET /admin/external-policy/:id falls through to the JSON not_found catch-all', async () => {
    const res = await fetch(`${baseUrl}/admin/external-policy/coach_us`, {
      headers: ownerHeaders,
    });
    await expectCatchAllNotFound(res);
  });

  it('CONTRACT-06 PUT /admin/external-policy/:id falls through to the JSON not_found catch-all', async () => {
    const res = await fetch(`${baseUrl}/admin/external-policy/coach_us`, {
      method: 'PUT',
      headers: {
        ...ownerHeaders,
        'Content-Type': 'application/json',
        'Idempotency-Key': 'external-policy-retired',
      },
      body: JSON.stringify({
        enabled: false,
        itemLimit: 3,
        baseCommissionRate: 0.18,
        highValueCommissionRate: 0.12,
        highValueThreshold: 5000,
      }),
    });
    await expectCatchAllNotFound(res);
  });

  it('CONTRACT-06 POST /admin/sync rejects the external-status channel as INVALID_SYNC_CHANNEL', async () => {
    const res = await fetch(`${baseUrl}/admin/sync`, {
      method: 'POST',
      headers: {
        ...ownerHeaders,
        'Content-Type': 'application/json',
        'Idempotency-Key': 'sync-external-retired',
      },
      body: JSON.stringify({ channel: 'external-status' }),
    });
    expect(res.status).toBe(422);
    const body = (await res.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('INVALID_SYNC_CHANNEL');
  });

  it('CONTRACT-06 GET /admin/control-plane has neither root sources nor health.sources', async () => {
    const res = await fetch(`${baseUrl}/admin/control-plane`, { headers: ownerHeaders });
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown> & {
      health: Record<string, unknown>;
    };
    expect(Object.keys(body)).not.toContain('sources');
    expect(Object.keys(body.health)).not.toContain('sources');
  });

  it('CONTRACT-06 GET /admin/me capabilities have no manageExternalSources', async () => {
    const res = await fetch(`${baseUrl}/admin/me`, { headers: ownerHeaders });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { capabilities: Record<string, unknown> };
    expect(Object.keys(body.capabilities)).not.toContain('manageExternalSources');
  });

  it('CONTRACT-06 loadConfig ignores CATALOG_MONITOR_* instead of validating them', () => {
    expect(() =>
      loadConfig({
        NODE_ENV: 'test',
        CATALOG_MONITOR_BASE_URL: 'ftp://x',
        CATALOG_MONITOR_SERVICE_SECRET: 'short',
      } as NodeJS.ProcessEnv)).not.toThrow();
  });
});

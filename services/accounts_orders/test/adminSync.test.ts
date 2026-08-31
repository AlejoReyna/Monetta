import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp } from '../src/api/server.js';
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
  InMemoryAdminAuditLogger,
  InMemoryAdminIdempotencyRepository,
  InMemoryAdminSyncJobRepository,
} from './support/inMemoryMutationRepositories.js';

describe('admin sync jobs', () => {
  let server: Server;
  let baseUrl: string;
  let externalCatalog: FakeExternalCatalogClient;

  beforeEach(async () => {
    externalCatalog = new FakeExternalCatalogClient();
    const app = createApp({
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier: { resolveCustomerId: async () => null },
      adminAuthorizer: {
        resolve: async () => null,
        authenticate: async (token: string) => token === 'owner-token'
          ? {
              id: 'principal-1',
              provider: 'monetta' as const,
              subject: { type: 'app_account' as const, id: 'account-1' },
              role: 'owner' as const,
            }
          : null,
      },
      externalCatalog,
      syncJobs: new InMemoryAdminSyncJobRepository(),
      idempotency: new InMemoryAdminIdempotencyRepository(),
      audit: new InMemoryAdminAuditLogger(),
      mutationsEnabled: false,
    });
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

  it('accepts an enum-scoped job, polls it, and replays the request without duplicating work', async () => {
    const payload = JSON.stringify({ channel: 'external-status' });
    const first = await fetch(`${baseUrl}/admin/sync`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        'Idempotency-Key': 'sync-external-1',
      },
      body: payload,
    });
    expect(first.status).toBe(202);
    const firstBody = await first.json();
    expect(firstBody.job).toMatchObject({ channel: 'external-status', status: 'pending' });

    let statusBody: any;
    for (let attempt = 0; attempt < 20; attempt += 1) {
      const status = await fetch(`${baseUrl}/admin/sync/jobs/${firstBody.job.id}`, {
        headers: { Authorization: 'Bearer owner-token' },
      });
      statusBody = await status.json();
      if (statusBody.job.status !== 'pending' && statusBody.job.status !== 'running') break;
      await new Promise((resolve) => setTimeout(resolve, 2));
    }
    expect(statusBody.job).toMatchObject({ status: 'completed', errorCode: null });
    expect(externalCatalog.fetchCalls).toBe(1);

    const replay = await fetch(`${baseUrl}/admin/sync`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        'Idempotency-Key': 'sync-external-1',
      },
      body: payload,
    });
    expect(replay.status).toBe(202);
    expect(await replay.json()).toEqual(firstBody);
    expect(externalCatalog.fetchCalls).toBe(1);
  });

  it('rejects unsupported sync channels before creating a job', async () => {
    const response = await fetch(`${baseUrl}/admin/sync`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        'Idempotency-Key': 'sync-invalid',
      },
      body: JSON.stringify({ channel: 'force-crawl' }),
    });
    expect(response.status).toBe(422);
    expect(externalCatalog.fetchCalls).toBe(0);
  });
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
    itemCount: 0,
    lastSuccessfulRunAt: null,
    updatedAt: '2026-08-30T12:00:00.000Z',
  };
  fetchCalls = 0;

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
    return { ...this.source, id: input.sourceId, ...input.source };
  }
}

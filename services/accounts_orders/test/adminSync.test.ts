import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp } from '../src/api/server.js';
import type { ShopifyAdminReadClient } from '../src/admin/shopifyAdminClient.js';
import type { AdminProductsPage } from '../src/admin/shopifyTypes.js';
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
  let shopify: FakeShopifyProductsClient;
  let syncJobs: InMemoryAdminSyncJobRepository;

  beforeEach(async () => {
    shopify = new FakeShopifyProductsClient();
    syncJobs = new InMemoryAdminSyncJobRepository();
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
      shopifyAdmin: shopify,
      syncJobs,
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

  async function pollJob(jobId: string): Promise<any> {
    let statusBody: any;
    for (let attempt = 0; attempt < 40; attempt += 1) {
      const status = await fetch(`${baseUrl}/admin/sync/jobs/${jobId}`, {
        headers: { Authorization: 'Bearer owner-token' },
      });
      statusBody = await status.json();
      if (statusBody.job.status !== 'pending' && statusBody.job.status !== 'running') {
        return statusBody;
      }
      await new Promise((resolve) => setTimeout(resolve, 5));
    }
    return statusBody;
  }

  it('accepts an enum-scoped job, polls it, and replays the request without duplicating work', async () => {
    const payload = JSON.stringify({ channel: 'shopify-products' });
    const first = await fetch(`${baseUrl}/admin/sync`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        'Idempotency-Key': 'sync-products-1',
      },
      body: payload,
    });
    expect(first.status).toBe(202);
    const firstBody = await first.json();
    expect(firstBody.job).toMatchObject({ channel: 'shopify-products', status: 'pending' });

    const statusBody = await pollJob(firstBody.job.id);
    expect(statusBody.job).toMatchObject({ status: 'completed', errorCode: null });
    expect(shopify.listCalls).toBe(1);

    const replay = await fetch(`${baseUrl}/admin/sync`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        'Idempotency-Key': 'sync-products-1',
      },
      body: payload,
    });
    expect(replay.status).toBe(202);
    expect(await replay.json()).toEqual(firstBody);
    expect(shopify.listCalls).toBe(1);
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
    expect(shopify.listCalls).toBe(0);
    expect(syncJobs.rows.size).toBe(0);
  });

  it('keeps jobs stored with the retired external-status channel readable', async () => {
    const completedId = '22222222-2222-4222-8222-222222222222';
    const now = new Date();
    syncJobs.rows.set(completedId, {
      id: completedId,
      actorId: 'principal-1',
      channel: 'external-status',
      status: 'completed',
      errorCode: null,
      cursor: null,
      pagesProcessed: 1,
      productsSeen: 0,
      createdAt: now,
      updatedAt: now,
    });
    const completed = await fetch(`${baseUrl}/admin/sync/jobs/${completedId}`, {
      headers: { Authorization: 'Bearer owner-token' },
    });
    expect(completed.status).toBe(200);
    expect((await completed.json()).job).toMatchObject({
      id: completedId,
      channel: 'external-status',
      status: 'completed',
      errorCode: null,
    });

    // A job left pending by an older client cannot run any more; it must end in
    // a stable failure instead of staying pending forever.
    const pendingId = '33333333-3333-4333-8333-333333333333';
    syncJobs.rows.set(pendingId, {
      ...syncJobs.rows.get(completedId)!,
      id: pendingId,
      status: 'pending',
      pagesProcessed: 0,
    });
    const settled = await pollJob(pendingId);
    expect(settled.job).toMatchObject({
      id: pendingId,
      channel: 'external-status',
      status: 'failed',
      errorCode: 'SYNC_CHANNEL_RETIRED',
    });
    expect(shopify.listCalls).toBe(0);
  });

  it('completes shopify-products only after reading every page (F22)', async () => {
    shopify.pages = [
      pageWith('cursor-1', true, 100, 1),
      pageWith('cursor-2', true, 100, 101),
      pageWith(null, false, 5, 201),
    ];
    const response = await fetch(`${baseUrl}/admin/sync`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        'Idempotency-Key': 'sync-products-full',
      },
      body: JSON.stringify({ channel: 'shopify-products' }),
    });
    expect(response.status).toBe(202);
    const body = await response.json();
    // HTTP 202 alone is not completion — poll until terminal.
    expect(body.job.status).toBe('pending');

    const done = await pollJob(body.job.id);
    expect(done.job).toMatchObject({
      status: 'completed',
      errorCode: null,
      pagesProcessed: 3,
      productsSeen: 205,
    });
    expect(shopify.listCalls).toBe(3);
  });

  it('resumes an interrupted shopify-products job from the durable cursor (F22)', async () => {
    shopify.pages = [
      pageWith('cursor-1', true, 100, 1),
      pageWith(null, false, 20, 101),
    ];
    // Seed a job as if the process died after page 1.
    const seeded = await syncJobs.create({
      id: '11111111-1111-4111-8111-111111111111',
      actorId: 'principal-1',
      channel: 'shopify-products',
    });
    await syncJobs.update({
      id: seeded.id,
      status: 'running',
      cursor: 'cursor-1',
      pagesProcessed: 1,
      productsSeen: 100,
    });
    // Make it look stale so resume is meaningful.
    const row = syncJobs.rows.get(seeded.id)!;
    syncJobs.rows.set(seeded.id, {
      ...row,
      updatedAt: new Date(Date.now() - 60_000),
    });

    const done = await pollJob(seeded.id);
    expect(done.job).toMatchObject({
      status: 'completed',
      pagesProcessed: 2,
      productsSeen: 120,
    });
    // Only the remaining page after the durable cursor should be fetched.
    expect(shopify.listCalls).toBe(1);
    expect(shopify.lastAfter).toBe('cursor-1');
  });
});

function pageWith(
  endCursor: string | null,
  hasNextPage: boolean,
  count: number,
  startId: number,
): AdminProductsPage {
  return {
    currencyCode: 'MXN',
    products: Array.from({ length: count }, (_, i) => ({
      id: `gid://shopify/Product/${startId + i}`,
      title: `P${startId + i}`,
      updatedAt: '2026-09-07T00:00:00Z',
      status: 'ACTIVE',
      publishedOnPublication: true,
      variants: [],
    })),
    pageInfo: { hasNextPage, endCursor },
  };
}

class FakeShopifyProductsClient implements ShopifyAdminReadClient {
  pages: AdminProductsPage[] = [pageWith(null, false, 1, 1)];
  listCalls = 0;
  lastAfter: string | null = null;

  async listProducts(input: {
    readonly first: number;
    readonly after: string | null;
    readonly query?: string | null;
  }): Promise<AdminProductsPage> {
    this.listCalls += 1;
    this.lastAfter = input.after;
    if (input.after === null) return this.pages[0]!;
    // Map after cursor to the next page: pages[i].pageInfo.endCursor -> pages[i+1]
    for (let i = 0; i < this.pages.length - 1; i += 1) {
      if (this.pages[i]?.pageInfo.endCursor === input.after) {
        return this.pages[i + 1]!;
      }
    }
    return { currencyCode: 'MXN', products: [], pageInfo: { hasNextPage: false, endCursor: null } };
  }

  async countProducts(): Promise<number | null> {
    return this.pages.reduce((sum, page) => sum + page.products.length, 0);
  }
}

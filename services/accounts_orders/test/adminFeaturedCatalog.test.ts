import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { ownerAdminCapabilities } from '../src/admin/authorizer.js';
import type { AdminActor } from '../src/admin/types.js';
import type { AdminFeaturedJobRepository } from '../src/admin/featuredPorts.js';
import type { AdminFeaturedJobRecord } from '../src/admin/featuredTypes.js';
import type { ShopifyAdminWriteClient } from '../src/admin/shopifyAdminClient.js';
import type { AdminProductProjection, AdminProductsPage } from '../src/admin/shopifyTypes.js';
import {
  InMemoryAdminAuditLogger,
  InMemoryAdminIdempotencyRepository,
  AllowingAdminRateLimiter,
} from './support/inMemoryMutationRepositories.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

describe('admin featured catalog', () => {
  let server: Server;
  let baseUrl: string;
  let shopify: FakeFeaturedShopify;
  let audit: InMemoryAdminAuditLogger;

  beforeEach(async () => {
    shopify = new FakeFeaturedShopify();
    audit = new InMemoryAdminAuditLogger();
    const actor: AdminActor = {
      id: 'principal-1',
      provider: 'monetta',
      subject: { type: 'app_account', id: 'account-1' },
      role: 'owner',
    };
    const authorizer = {
      resolve: async () => ({ actor, capabilities: ownerAdminCapabilities }),
      authenticate: async () => actor,
    };
    const deps: ServerDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier: { resolveCustomerId: async () => null },
      adminAuthorizer: authorizer,
      adminEnvironment: 'staging',
      shopifyAdmin: shopify,
      idempotency: new InMemoryAdminIdempotencyRepository(),
      audit,
      rateLimiter: new AllowingAdminRateLimiter(),
      mutationsEnabled: true,
      shopifyWritesEnabled: true,
      featuredJobs: new InMemoryFeaturedJobs(),
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

  it('reads eligible products and confirms one-click add canonically', async () => {
    const read = await request('/admin/featured-catalog');
    expect(read.status).toBe(200);
    expect((await read.json()).featuredCatalog).toMatchObject({
      selectedProductIds: ['gid://shopify/Product/1'],
      eligibleProducts: [{ id: 'gid://shopify/Product/1' }, { id: 'gid://shopify/Product/2' }],
    });

    const response = await request('/admin/featured-catalog/products/gid%3A%2F%2Fshopify%2FProduct%2F2', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Idempotency-Key': 'add-product-2',
      },
      body: JSON.stringify({
        featured: true,
        expectedCollectionUpdatedAt: shopify.collection.updatedAt,
      }),
    });
    expect(response.status).toBe(200);
    expect((await response.json()).featuredCatalog.selectedProductIds).toEqual([
      'gid://shopify/Product/1',
      'gid://shopify/Product/2',
    ]);
    expect(audit.events.at(-1)?.action).toBe('featured-catalog.add');
  });

  it('rejects a stale collection and does not mutate Shopify', async () => {
    const before = [...shopify.collection.productIds];
    const response = await request('/admin/featured-catalog/products/gid%3A%2F%2Fshopify%2FProduct%2F2', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Idempotency-Key': 'stale-remove' },
      body: JSON.stringify({ featured: true, expectedCollectionUpdatedAt: '2026-08-29T12:00:00.000Z' }),
    });
    expect(response.status).toBe(409);
    expect((await response.json()).error.code).toBe('STALE_RESOURCE');
    expect(shopify.collection.productIds).toEqual(before);
  });

  it('returns a durable job for reorder and reconciles it canonically', async () => {
    const response = await request('/admin/featured-catalog', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Idempotency-Key': 'reorder-1' },
      body: JSON.stringify({
        productIds: ['gid://shopify/Product/2', 'gid://shopify/Product/1'],
        expectedCollectionUpdatedAt: shopify.collection.updatedAt,
      }),
    });
    expect(response.status).toBe(202);
    const body = await response.json();
    expect(body.status).toBe('ordering');
    const job = await request(`/admin/featured-catalog/jobs/${body.jobId}`);
    expect(job.status).toBe(200);
    expect((await job.json()).job).toMatchObject({ id: body.jobId, status: 'completed' });
    expect(shopify.collection.productIds).toEqual([
      'gid://shopify/Product/2',
      'gid://shopify/Product/1',
    ]);
  });

  it('version-checks and canonically confirms storefront configuration', async () => {
    const response = await request('/admin/storefront-config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Idempotency-Key': 'storefront-1' },
      body: JSON.stringify({
        announcement: 'Envío gratis',
        showHero: true,
        showNewest: true,
        showTodaysPicks: true,
        showExternalPicks: false,
        expectedVersion: 0,
      }),
    });
    expect(response.status).toBe(200);
    expect((await response.json()).storefront).toMatchObject({ version: 1, showExternalPicks: false });
    expect(shopify.storefront.version).toBe(1);

    const stale = await request('/admin/storefront-config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Idempotency-Key': 'storefront-stale' },
      body: JSON.stringify({
        announcement: 'Viejo',
        showHero: true,
        showNewest: true,
        showTodaysPicks: true,
        showExternalPicks: true,
        expectedVersion: 0,
      }),
    });
    expect(stale.status).toBe(409);
  });

  async function request(path: string, init: RequestInit = {}): Promise<Response> {
    return fetch(`${baseUrl}${path}`, {
      ...init,
      headers: { Authorization: 'Bearer owner-token', ...(init.headers ?? {}) },
    });
  }
});

class InMemoryFeaturedJobs implements AdminFeaturedJobRepository {
  readonly rows = new Map<string, AdminFeaturedJobRecord>();

  async create(input: {
    readonly jobId: string;
    readonly actorId: string;
    readonly shopifyJobId: string;
    readonly collectionId: string;
    readonly requestedProductIds: readonly string[];
  }): Promise<AdminFeaturedJobRecord> {
    const now = new Date();
    const job: AdminFeaturedJobRecord = {
      ...input,
      requestedProductIds: [...input.requestedProductIds],
      status: 'pending',
      errorCode: null,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(input.jobId, job);
    return job;
  }

  async find(jobId: string): Promise<AdminFeaturedJobRecord | null> {
    return this.rows.get(jobId) ?? null;
  }

  async update(input: {
    readonly jobId: string;
    readonly status: AdminFeaturedJobRecord['status'];
    readonly errorCode?: string | null;
  }): Promise<void> {
    const current = this.rows.get(input.jobId);
    if (current === undefined) throw new Error('job missing');
    this.rows.set(input.jobId, {
      ...current,
      status: input.status,
      errorCode: input.errorCode ?? null,
      updatedAt: new Date(),
    });
  }
}

class FakeFeaturedShopify implements ShopifyAdminWriteClient {
  readonly products: AdminProductProjection[] = [
    product('gid://shopify/Product/1', true, 'Bolsa uno'),
    product('gid://shopify/Product/2', true, 'Bolsa dos'),
    product('gid://shopify/Product/3', false, 'Borrador'),
  ];
  collection = {
    id: 'gid://shopify/Collection/1',
    handle: 'monetta-todays-picks',
    title: 'Today\'s Picks',
    updatedAt: '2026-08-30T12:00:00.000Z',
    sortOrder: 'MANUAL',
    productIds: ['gid://shopify/Product/1'],
  };
  private jobDone = true;
  storefront = {
    id: 'gid://shopify/Metaobject/1',
    version: 0,
    announcement: 'Inicial',
    showHero: true,
    showNewest: true,
    showTodaysPicks: true,
    showExternalPicks: true,
  };

  async listProducts(input: { readonly first: number; readonly after: string | null }): Promise<AdminProductsPage> {
    return {
      currencyCode: 'MXN',
      products: this.products.slice(0, input.first),
      pageInfo: { hasNextPage: false, endCursor: null },
    };
  }

  async getProduct(productGid: string): Promise<AdminProductProjection | null> {
    return this.products.find((product) => product.id === productGid) ?? null;
  }

  async updateProductTitle(): Promise<void> {}
  async updateVariantPrice(): Promise<void> {}
  async setPublication(): Promise<void> {}

  async getFeaturedCollection() {
    return { ...this.collection, productIds: [...this.collection.productIds] };
  }

  async addFeaturedProducts(productGids: readonly string[]): Promise<void> {
    this.collection = {
      ...this.collection,
      updatedAt: '2026-08-30T12:00:01.000Z',
      productIds: [...this.collection.productIds, ...productGids],
    };
  }

  async removeFeaturedProducts(productGids: readonly string[]): Promise<void> {
    this.collection = {
      ...this.collection,
      updatedAt: '2026-08-30T12:00:02.000Z',
      productIds: this.collection.productIds.filter((id) => !productGids.includes(id)),
    };
  }

  async reorderFeaturedProducts(moves: readonly { readonly id: string; readonly newPosition: number }[]): Promise<string> {
    const ids = [...this.collection.productIds];
    for (const move of moves) {
      const index = ids.indexOf(move.id);
      if (index === -1) continue;
      ids.splice(index, 1);
      ids.splice(move.newPosition, 0, move.id);
    }
    this.collection = { ...this.collection, productIds: ids, updatedAt: '2026-08-30T12:00:03.000Z' };
    this.jobDone = true;
    return 'gid://shopify/Job/1';
  }

  async getJob() {
    return { done: this.jobDone };
  }

  async getStorefrontConfig() {
    return { ...this.storefront };
  }

  async updateStorefrontConfig(input: typeof this.storefront): Promise<void> {
    this.storefront = { ...input, id: this.storefront.id };
  }
}

function product(id: string, published: boolean, title: string): AdminProductProjection {
  return {
    id,
    title,
    descriptionHtml: '<p>Descripción Shopify</p>',
    updatedAt: '2026-08-30T12:00:00.000Z',
    status: published ? 'ACTIVE' : 'DRAFT',
    publishedOnPublication: published,
    imageUrl: null,
    currencyCode: 'MXN',
    variants: [{
      id: `${id.replace('Product', 'ProductVariant')}`,
      title: 'Default',
      price: '1299.00',
      compareAtPrice: null,
      currencyCode: 'MXN',
      availableForSale: true,
      inventoryPolicy: 'DENY',
    }],
  };
}

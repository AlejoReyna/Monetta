import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../src/api/server.js';
import {
  ShopifyAdminUserError,
} from '../src/admin/shopifyAdminClient.js';
import type { ShopifyAdminWriteClient } from '../src/admin/shopifyAdminClient.js';
import type { AdminProductProjection, AdminProductsPage } from '../src/admin/shopifyTypes.js';
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

const productGid = 'gid://shopify/Product/1';
const firstVariantGid = 'gid://shopify/ProductVariant/11';
const secondVariantGid = 'gid://shopify/ProductVariant/12';
const initialUpdatedAt = '2026-08-30T12:00:00.000Z';

describe('admin product mutations', () => {
  let server: Server;
  let baseUrl: string;
  let shopify: FakeShopifyAdminWriteClient;
  let idempotency: InMemoryAdminIdempotencyRepository;
  let audit: InMemoryAdminAuditLogger;
  let rateLimiter: AllowingAdminRateLimiter;
  let serverDeps: ServerDeps;

  beforeEach(async () => {
    shopify = new FakeShopifyAdminWriteClient();
    idempotency = new InMemoryAdminIdempotencyRepository();
    audit = new InMemoryAdminAuditLogger();
    rateLimiter = new AllowingAdminRateLimiter();
    const authorizer = {
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
    };
    serverDeps = {
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
      idempotency,
      audit,
      rateLimiter,
      mutationsEnabled: true,
      shopifyWritesEnabled: true,
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
    await closeServer();
  });

  async function closeServer(): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }

  it('requires an idempotency key before attempting an upstream write', async () => {
    const missingKey = await mutate('PATCH', `/admin/products/${encodeURIComponent(productGid)}`, {
      title: 'Nuevo título',
      expectedUpdatedAt: initialUpdatedAt,
    });
    expect(missingKey.status).toBe(400);
    expect(shopify.calls).toEqual([]);

    await closeServer();
    const disabledApp = createApp({ ...serverDeps, mutationsEnabled: false });
    await new Promise<void>((resolve) => {
      server = disabledApp.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;
    const disabled = await mutate(
      'PATCH',
      `/admin/products/${encodeURIComponent(productGid)}`,
      { title: 'Nuevo título', expectedUpdatedAt: initialUpdatedAt },
      'disabled-key',
    );
    expect(disabled.status).toBe(503);
    expect(shopify.calls).toEqual([]);
  });

  it('updates the title, re-reads Shopify, audits it, and replays idempotently', async () => {
    const path = `/admin/products/${encodeURIComponent(productGid)}`;
    const body = { title: 'Título canónico', expectedUpdatedAt: initialUpdatedAt };
    const first = await mutate('PATCH', path, body, 'title-key');
    expect(first.status).toBe(200);
    const firstBody = await first.json() as { requestId: string; product: AdminProductProjection };
    expect(firstBody.product.title).toBe('Título canónico');
    expect(shopify.calls).toEqual(['getProduct', 'updateProductTitle', 'getProduct']);
    expect(audit.events).toHaveLength(1);
    expect(audit.events[0]).toMatchObject({
      action: 'product.title.update',
      outcome: 'success',
      requestId: firstBody.requestId,
    });

    const replay = await mutate('PATCH', path, body, 'title-key');
    expect(replay.status).toBe(200);
    expect(await replay.json()).toEqual(firstBody);
    expect(shopify.calls).toHaveLength(3);
    expect(audit.events).toHaveLength(1);
  });

  it('rejects stale writes before Shopify mutation and preserves the conflict response', async () => {
    const response = await mutate(
      'PATCH',
      `/admin/products/${encodeURIComponent(productGid)}`,
      { title: 'Stale title', expectedUpdatedAt: '2026-08-29T12:00:00Z' },
      'stale-key',
    );
    expect(response.status).toBe(409);
    expect(await response.json()).toMatchObject({
      error: {
        code: 'STALE_RESOURCE',
        fields: { actualUpdatedAt: initialUpdatedAt },
      },
    });
    expect(shopify.calls).toEqual(['getProduct']);

    const replay = await mutate(
      'PATCH',
      `/admin/products/${encodeURIComponent(productGid)}`,
      { title: 'Stale title', expectedUpdatedAt: '2026-08-29T12:00:00Z' },
      'stale-key',
    );
    expect(replay.status).toBe(409);
    expect(shopify.calls).toHaveLength(1);
  });

  it('changes only the explicitly selected variant and rejects malformed money', async () => {
    const path = `/admin/products/${encodeURIComponent(productGid)}/variants/${encodeURIComponent(secondVariantGid)}`;
    const response = await mutate('PATCH', path, {
      price: '1399.50',
      expectedProductUpdatedAt: initialUpdatedAt,
    }, 'variant-key');
    expect(response.status).toBe(200);
    const product = (await response.json() as { product: AdminProductProjection }).product;
    expect(product.variants.find((variant) => variant.id === firstVariantGid)?.price).toBe('1299.00');
    expect(product.variants.find((variant) => variant.id === secondVariantGid)?.price).toBe('1399.50');
    expect(shopify.lastVariantMutation).toEqual({ productGid, variantGid: secondVariantGid, price: '1399.50' });

    const invalid = await mutate('PATCH', path, {
      price: '1,399.50',
      expectedProductUpdatedAt: initialUpdatedAt,
    }, 'invalid-money');
    expect(invalid.status).toBe(422);
    expect(shopify.lastVariantMutation?.price).toBe('1399.50');
  });

  it('maps Shopify user errors to a safe structured failure and rate limits attempts', async () => {
    shopify.userError = true;
    const response = await mutate(
      'PUT',
      `/admin/products/${encodeURIComponent(productGid)}/publication`,
      { published: true, expectedUpdatedAt: initialUpdatedAt },
      'publication-key',
    );
    expect(response.status).toBe(422);
    const body = await response.json() as { error: { code: string; message: string } };
    expect(body.error).toMatchObject({
      code: 'SHOPIFY_VALIDATION_ERROR',
      message: 'Shopify rejected the requested change.',
    });
    expect(JSON.stringify(body)).not.toContain('secret Shopify detail');
    expect(audit.events[0]).toMatchObject({
      outcome: 'failed',
      errorCode: 'SHOPIFY_VALIDATION_ERROR',
    });

    rateLimiter.allow = () => false;
    const limited = await mutate(
      'PUT',
      `/admin/products/${encodeURIComponent(productGid)}/publication`,
      { published: true, expectedUpdatedAt: initialUpdatedAt },
      'publication-key-2',
    );
    expect(limited.status).toBe(429);
  });

  async function mutate(
    method: 'PATCH' | 'PUT',
    path: string,
    body: Record<string, unknown>,
    key?: string,
  ) {
    return fetch(`${baseUrl}${path}`, {
      method,
      headers: {
        Authorization: 'Bearer owner-token',
        'Content-Type': 'application/json',
        ...(key === undefined ? {} : { 'Idempotency-Key': key }),
      },
      body: JSON.stringify(body),
    });
  }
});

class FakeShopifyAdminWriteClient implements ShopifyAdminWriteClient {
  product: AdminProductProjection = {
    id: productGid,
    title: 'Título original',
    descriptionHtml: '',
    updatedAt: initialUpdatedAt,
    status: 'ACTIVE',
    publishedOnPublication: false,
    imageUrl: null,
    currencyCode: 'MXN',
    variants: [
      {
        id: firstVariantGid,
        title: 'Negro',
        price: '1299.00',
        compareAtPrice: null,
        currencyCode: 'MXN',
        availableForSale: true,
        inventoryPolicy: 'DENY',
      },
      {
        id: secondVariantGid,
        title: 'Café',
        price: '1399.00',
        compareAtPrice: null,
        currencyCode: 'MXN',
        availableForSale: true,
        inventoryPolicy: 'DENY',
      },
    ],
  };
  calls: string[] = [];
  lastVariantMutation: { productGid: string; variantGid: string; price: string } | null = null;
  userError = false;

  async countProducts(): Promise<number | null> { return null; }

  async listProducts(_input: { readonly first: number; readonly after: string | null; readonly query?: string | null }): Promise<AdminProductsPage> {
    return { currencyCode: 'MXN', products: [this.product], pageInfo: { hasNextPage: false, endCursor: null } };
  }

  async getProduct(_productGid: string): Promise<AdminProductProjection> {
    this.calls.push('getProduct');
    return structuredClone(this.product);
  }

  async updateProductTitle(_productGid: string, title: string): Promise<void> {
    this.calls.push('updateProductTitle');
    if (this.userError) throw new ShopifyAdminUserError([{ message: 'secret Shopify detail' }]);
    this.product = { ...this.product, title, updatedAt: initialUpdatedAt };
  }

  async updateVariantPrice(_productGid: string, variantGid: string, price: string): Promise<void> {
    this.calls.push('updateVariantPrice');
    if (this.userError) throw new ShopifyAdminUserError([{ message: 'secret Shopify detail' }]);
    this.lastVariantMutation = { productGid, variantGid, price };
    this.product = {
      ...this.product,
      variants: this.product.variants.map((variant) => variant.id === variantGid ? { ...variant, price } : variant),
      updatedAt: initialUpdatedAt,
    };
  }

  async setPublication(_productGid: string, published: boolean): Promise<void> {
    this.calls.push('setPublication');
    if (this.userError) throw new ShopifyAdminUserError([{ message: 'secret Shopify detail' }]);
    this.product = { ...this.product, publishedOnPublication: published, updatedAt: initialUpdatedAt };
  }
}

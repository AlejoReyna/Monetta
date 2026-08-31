import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { ownerAdminCapabilities } from '../src/admin/authorizer.js';
import type { ShopifyAdminReadClient } from '../src/admin/shopifyAdminClient.js';
import type { AdminProductsPage } from '../src/admin/shopifyTypes.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

describe('admin control-plane read projection', () => {
  let server: Server;
  let baseUrl: string;
  let shopify: FakeShopifyAdminClient;

  beforeEach(async () => {
    shopify = new FakeShopifyAdminClient();
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

  it('returns a bounded Shopify projection only to owners', async () => {
    const denied = await fetch(`${baseUrl}/admin/control-plane`, {
      headers: { Authorization: 'Bearer shopper-token' },
    });
    expect(denied.status).toBe(403);

    const response = await fetch(`${baseUrl}/admin/control-plane?limit=1000`, {
      headers: { Authorization: 'Bearer owner-token' },
    });
    expect(response.status).toBe(200);
    expect(shopify.lastInput).toEqual({ first: 100, after: null });
    expect(await response.json()).toMatchObject({
      health: { shopify: { status: 'ready', errorCode: null } },
      products: [{
        id: 'gid://shopify/Product/1',
        title: 'Bolsa Shopify',
        descriptionHtml: '',
        publishedToMonetta: true,
        variants: [
          { id: 'gid://shopify/ProductVariant/1', price: '1299.00' },
          { id: 'gid://shopify/ProductVariant/2', price: '1399.00' },
        ],
      }],
      storefront: null,
      sources: [],
    });
  });

  it('keeps the panel usable when Shopify is unavailable', async () => {
    shopify.failure = true;
    const response = await fetch(`${baseUrl}/admin/control-plane`, {
      headers: { Authorization: 'Bearer owner-token' },
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      health: {
        shopify: { status: 'degraded', errorCode: 'SHOPIFY_UPSTREAM_ERROR' },
        storefront: { status: 'unavailable' },
      },
      products: [],
    });
  });
});

class FakeShopifyAdminClient implements ShopifyAdminReadClient {
  lastInput: { first: number; after: string | null } | null = null;
  failure = false;

  async listProducts(input: { readonly first: number; readonly after: string | null }): Promise<AdminProductsPage> {
    this.lastInput = { ...input };
    if (this.failure) throw new Error('upstream is down');
    return {
      currencyCode: 'MXN',
      products: [{
        id: 'gid://shopify/Product/1',
        title: 'Bolsa Shopify',
        descriptionHtml: '',
        updatedAt: '2026-08-30T12:00:00Z',
        status: 'ACTIVE',
        publishedOnPublication: true,
        imageUrl: null,
        currencyCode: 'MXN',
        variants: [
          {
            id: 'gid://shopify/ProductVariant/1',
            title: 'Negro',
            price: '1299.00',
            compareAtPrice: null,
            currencyCode: 'MXN',
            availableForSale: true,
            inventoryPolicy: 'DENY',
          },
          {
            id: 'gid://shopify/ProductVariant/2',
            title: 'Café',
            price: '1399.00',
            compareAtPrice: null,
            currencyCode: 'MXN',
            availableForSale: false,
            inventoryPolicy: 'DENY',
          },
        ],
      }],
      pageInfo: { hasNextPage: false, endCursor: null },
    };
  }
}

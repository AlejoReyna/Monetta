import { describe, expect, it } from 'vitest';
import {
  ShopifyAdminClient,
  ShopifyAdminError,
} from '../src/admin/shopifyAdminClient.js';

const clientOptions = {
  shopDomain: 'monetta-staging.myshopify.com',
  clientId: '4a29ba522a35bd476f3d1f467749234f',
  clientSecret: 'shpss_test_secret_at_least_32_characters',
  apiVersion: '2026-07',
  headlessPublicationId: 'gid://shopify/Publication/123',
};

describe('ShopifyAdminClient', () => {
  it('exchanges a server-only token and maps all variants without collapsing them', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const client = new ShopifyAdminClient({
      ...clientOptions,
      fetchFn: async (url, init) => {
        calls.push({ url: String(url), init });
        if (String(url).endsWith('/access_token')) {
          return jsonResponse({
            access_token: 'admin-token-000001',
            scope: 'read_products',
            expires_in: 86_400,
          });
        }
        return jsonResponse({
          data: {
            shop: { currencyCode: 'MXN' },
            products: {
              nodes: [{
                id: 'gid://shopify/Product/1',
                title: 'Bolsa de prueba',
                descriptionHtml: '<p>Descripción Shopify</p>',
                updatedAt: '2026-08-30T12:00:00Z',
                status: 'ACTIVE',
                publishedOnPublication: true,
                images: { nodes: [{ url: 'https://cdn.shopify.com/image.jpg' }] },
                variants: {
                  nodes: [
                    {
                      id: 'gid://shopify/ProductVariant/11',
                      title: 'Negro',
                      price: '1299.00',
                      compareAtPrice: '1499.00',
                      availableForSale: true,
                      inventoryPolicy: 'DENY',
                    },
                    {
                      id: 'gid://shopify/ProductVariant/12',
                      title: 'Café',
                      price: '1399.00',
                      compareAtPrice: null,
                      availableForSale: false,
                      inventoryPolicy: 'CONTINUE',
                    },
                  ],
                },
              }],
              pageInfo: { hasNextPage: false, endCursor: 'cursor-1' },
            },
          },
        });
      },
    });

    const page = await client.listProducts({ first: 50, after: null });
    expect(page.currencyCode).toBe('MXN');
    expect(page.products[0]).toMatchObject({
      id: 'gid://shopify/Product/1',
      title: 'Bolsa de prueba',
      descriptionHtml: '<p>Descripción Shopify</p>',
      imageUrl: 'https://cdn.shopify.com/image.jpg',
      publishedOnPublication: true,
    });
    expect(page.products[0]?.variants).toHaveLength(2);
    expect(page.products[0]?.variants[1]).toMatchObject({
      id: 'gid://shopify/ProductVariant/12',
      price: '1399.00',
      availableForSale: false,
      currencyCode: 'MXN',
    });
    expect(calls).toHaveLength(2);
    expect(String(calls[1]?.init.body)).toContain('gid://shopify/Publication/123');
    expect(String(calls[1]?.init.body)).toContain('publishedOnPublication');
  });

  it('caches the 24-hour token and refreshes it before expiry', async () => {
    let now = 1_000_000;
    let tokenCalls = 0;
    const client = new ShopifyAdminClient({
      ...clientOptions,
      now: () => now,
      fetchFn: async (url) => {
        if (String(url).endsWith('/access_token')) {
          tokenCalls += 1;
          return jsonResponse({
            access_token: `admin-token-00000${tokenCalls}`,
            scope: 'read_products',
            expires_in: 600,
          });
        }
        return jsonResponse({
          data: {
            shop: { currencyCode: 'MXN' },
            products: { nodes: [], pageInfo: { hasNextPage: false, endCursor: null } },
          },
        });
      },
    });

    await client.listProducts({ first: 1, after: null });
    await client.listProducts({ first: 1, after: null });
    expect(tokenCalls).toBe(1);
    now += 301_000;
    await client.listProducts({ first: 1, after: null });
    expect(tokenCalls).toBe(2);
  });

  it('refreshes once after an Admin 401 and never returns upstream payloads', async () => {
    let tokenCalls = 0;
    let graphCalls = 0;
    const client = new ShopifyAdminClient({
      ...clientOptions,
      fetchFn: async (url) => {
        if (String(url).endsWith('/access_token')) {
          tokenCalls += 1;
          return jsonResponse({
            access_token: `admin-token-00000${tokenCalls}`,
            scope: 'read_products',
            expires_in: 86_400,
          });
        }
        graphCalls += 1;
        if (graphCalls === 1) return jsonResponse({ secret: 'do-not-leak' }, 401);
        return jsonResponse({
          data: {
            shop: { currencyCode: 'MXN' },
            products: { nodes: [], pageInfo: { hasNextPage: false, endCursor: null } },
          },
        });
      },
    });

    await client.listProducts({ first: 1, after: null });
    expect(tokenCalls).toBe(2);
    expect(graphCalls).toBe(2);
  });

  it('classifies GraphQL errors, throttling, and missing scopes', async () => {
    const makeClient = (payload: unknown) => new ShopifyAdminClient({
      ...clientOptions,
      fetchFn: async (url) => String(url).endsWith('/access_token')
        ? jsonResponse({ access_token: 'admin-token-000001', scope: 'read_products', expires_in: 86_400 })
        : jsonResponse(payload),
    });

    await expect(makeClient({ errors: [{ message: 'bad query' }] }).listProducts({ first: 1, after: null }))
      .rejects.toMatchObject<Partial<ShopifyAdminError>>({ code: 'graphql' });
    await expect(makeClient({ errors: [{ message: 'throttled', extensions: { code: 'THROTTLED' } }] }).listProducts({ first: 1, after: null }))
      .rejects.toMatchObject<Partial<ShopifyAdminError>>({ code: 'throttled', retryable: true });

    const missingScope = new ShopifyAdminClient({
      ...clientOptions,
      fetchFn: async () => jsonResponse({
        access_token: 'admin-token-000001',
        scope: 'read_orders',
        expires_in: 86_400,
      }),
    });
    await expect(missingScope.listProducts({ first: 1, after: null }))
      .rejects.toMatchObject<Partial<ShopifyAdminError>>({ code: 'authentication' });
  });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

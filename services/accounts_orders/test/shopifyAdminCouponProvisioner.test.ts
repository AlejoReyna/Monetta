import { describe, expect, it, vi } from 'vitest';
import { loadConfig } from '../src/config.js';
import { loadRewardsEnv } from '../src/rewards/rewardsConfig.js';
import {
  ShopifyAdminCouponProvisioner,
  createRewardsDiscountAdapter,
  normalizeCustomerGid,
} from '../src/rewards/shopifyAdminCouponProvisioner.js';

describe('ShopifyAdminCouponProvisioner', () => {
  it('normalizes numeric and GID customer ids and rejects invalid values', () => {
    expect(normalizeCustomerGid('123456')).toBe('gid://shopify/Customer/123456');
    expect(normalizeCustomerGid('gid://shopify/Customer/789')).toBe('gid://shopify/Customer/789');
    expect(() => normalizeCustomerGid('abc')).toThrow('invalid_customer_id');
  });

  it('exchanges client_credentials, creates a single-use customer-scoped coupon, queries usage and deletes', async () => {
    const calls: { url: string; body: string; token?: string }[] = [];
    const fetchMock = vi.fn(async (input: string | URL, init?: RequestInit) => {
      const url = String(input);
      const body = typeof init?.body === 'string' ? init.body : '';
      const headers = (init?.headers ?? {}) as Record<string, string>;
      calls.push({ url, body, token: headers['X-Shopify-Access-Token'] });

      if (url.endsWith('/admin/oauth/access_token')) {
        return new Response(JSON.stringify({ access_token: 'shpat_minted_token_12345', expires_in: 3600 }), { status: 200 });
      }
      const parsed = JSON.parse(body) as { query: string; variables: Record<string, unknown> };
      if (parsed.query.includes('discountCodeBasicCreate')) {
        expect(headers['X-Shopify-Access-Token']).toBe('shpat_minted_token_12345');
        const inputVars = parsed.variables.basicCodeDiscount as Record<string, unknown>;
        expect(inputVars.usageLimit).toBe(1);
        expect(inputVars.appliesOncePerCustomer).toBe(true);
        expect(inputVars.customerSelection).toEqual({ customers: { add: ['gid://shopify/Customer/42'] } });
        expect(inputVars.customerGets).toEqual({
          value: { discountAmount: { amount: '60.00', appliesOnEachItem: false } },
          items: { all: true },
        });
        expect(inputVars.minimumRequirement).toEqual({
          subtotal: { greaterThanOrEqualToSubtotal: '300.00' },
        });
        return new Response(
          JSON.stringify({
            data: {
              discountCodeBasicCreate: {
                codeDiscountNode: {
                  id: 'gid://shopify/DiscountCodeNode/999',
                  codeDiscount: { codes: { nodes: [{ code: inputVars.code }] } },
                },
                userErrors: [],
              },
            },
          }),
          { status: 200 },
        );
      }
      if (parsed.query.includes('MonettaRewardsDiscountUsage')) {
        return new Response(
          JSON.stringify({
            data: {
              codeDiscountNode: {
                id: 'gid://shopify/DiscountCodeNode/999',
                codeDiscount: { asyncUsageCount: 0 },
              },
            },
          }),
          { status: 200 },
        );
      }
      if (parsed.query.includes('discountCodeDelete')) {
        return new Response(
          JSON.stringify({
            data: {
              discountCodeDelete: {
                deletedCodeDiscountId: 'gid://shopify/DiscountCodeNode/999',
                userErrors: [],
              },
            },
          }),
          { status: 200 },
        );
      }
      return new Response('unexpected', { status: 500 });
    });

    const provisioner = new ShopifyAdminCouponProvisioner({
      shopDomain: 'monetta-staging.myshopify.com',
      apiVersion: '2026-07',
      clientId: 'client-123',
      clientSecret: 'shpss_secret_1234567890',
      fetchFn: fetchMock as unknown as typeof fetch,
      now: () => Date.UTC(2026, 10, 23, 12, 0, 0),
    });

    const created = await provisioner.createSingleUseFixedCode({
      amountCents: 6000,
      currency: 'MXN',
      expiresAt: new Date(Date.UTC(2026, 10, 23, 12, 30, 0)),
      customerId: '42',
      redemptionId: 'abcdef12-3456-7890-abcd-ef1234567890',
      minimumSubtotalCents: 30000,
    });
    expect(created.discountId).toBe('gid://shopify/DiscountCodeNode/999');
    expect(created.code).toBe('MRW-ABCDEF1234');

    const count = await provisioner.usageCount(created.discountId);
    expect(count).toBe(0);

    await provisioner.deleteCode(created.discountId);
    // Token was cached across all 3 GraphQL calls -> 1 oauth + 3 graphql = 4 calls.
    expect(calls).toHaveLength(4);
  });

  it('throws on userErrors during creation and returns null on usageCount error', async () => {
    const fetchMock = vi.fn(async (_input: string | URL, init?: RequestInit) => {
      const parsed = JSON.parse(String(init?.body)) as { query: string };
      if (parsed.query.includes('discountCodeBasicCreate')) {
        return new Response(
          JSON.stringify({
            data: {
              discountCodeBasicCreate: {
                codeDiscountNode: null,
                userErrors: [{ field: ['code'], message: 'Code has already been taken' }],
              },
            },
          }),
          { status: 200 },
        );
      }
      return new Response('boom', { status: 500 });
    });

    const provisioner = new ShopifyAdminCouponProvisioner({
      shopDomain: 'monetta-staging.myshopify.com',
      apiVersion: '2026-07',
      adminAccessToken: 'shpat_static_token_12345',
      fetchFn: fetchMock as unknown as typeof fetch,
    });

    await expect(
      provisioner.createSingleUseFixedCode({
        amountCents: 5000,
        currency: 'MXN',
        expiresAt: new Date(Date.UTC(2026, 10, 23, 12, 30, 0)),
        customerId: '42',
        redemptionId: '11111111-2222-3333-4444-555555555555',
        minimumSubtotalCents: null,
      }),
    ).rejects.toThrow('shopify_discount_rejected');

    expect(await provisioner.usageCount('gid://shopify/DiscountCodeNode/1')).toBeNull();
  });

  it('gates createRewardsDiscountAdapter on flag and credentials', () => {
    const disabled = createRewardsDiscountAdapter(
      loadConfig({
        SHOPIFY_STORE_DOMAIN: 'monetta-staging.myshopify.com',
        SHOPIFY_ADMIN_ACCESS_TOKEN: 'shpat_static_token_12345',
      } as NodeJS.ProcessEnv),
      loadRewardsEnv({ REWARDS_ENABLED: 'true', REWARDS_REDEMPTION_ENABLED: 'false' } as NodeJS.ProcessEnv),
    );
    expect(disabled.available).toBe(false);

    const enabled = createRewardsDiscountAdapter(
      loadConfig({
        SHOPIFY_STORE_DOMAIN: 'monetta-staging.myshopify.com',
        SHOPIFY_APP_CLIENT_ID: 'client-123',
        SHOPIFY_APP_CLIENT_SECRET: 'shpss_secret_1234567890',
      } as NodeJS.ProcessEnv),
      loadRewardsEnv({ REWARDS_ENABLED: 'true', REWARDS_REDEMPTION_ENABLED: 'true' } as NodeJS.ProcessEnv),
    );
    expect(enabled.available).toBe(true);
    expect(enabled.name).toBe('basic_single_use_coupon');
  });
});

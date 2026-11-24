import type { AccountsOrdersConfig } from '../config.js';
import type { RewardsEnv } from './rewardsConfig.js';
import {
  BasicSingleUseCouponAdapter,
  DisabledDiscountAdapter,
  type BasicCouponProvisioner,
  type ProvisionedDiscount,
  type ShopifyDiscountAdapter,
} from './shopifyDiscountAdapter.js';

const DISCOUNT_CODE_BASIC_CREATE = `mutation MonettaRewardsDiscountCreate($basicCodeDiscount: DiscountCodeBasicInput!) {
  discountCodeBasicCreate(basicCodeDiscount: $basicCodeDiscount) {
    codeDiscountNode {
      id
      codeDiscount {
        ... on DiscountCodeBasic {
          codes(first: 1) {
            nodes {
              code
            }
          }
        }
      }
    }
    userErrors {
      field
      code
      message
    }
  }
}`;

const DISCOUNT_CODE_DELETE = `mutation MonettaRewardsDiscountDelete($id: ID!) {
  discountCodeDelete(id: $id) {
    deletedCodeDiscountId
    userErrors {
      field
      code
      message
    }
  }
}`;

const DISCOUNT_USAGE_QUERY = `query MonettaRewardsDiscountUsage($id: ID!) {
  codeDiscountNode(id: $id) {
    id
    codeDiscount {
      ... on DiscountCodeBasic {
        asyncUsageCount
      }
    }
  }
}`;

export interface ShopifyAdminCouponProvisionerOptions {
  readonly shopDomain: string;
  readonly apiVersion: string;
  readonly adminAccessToken?: string;
  readonly clientId?: string;
  readonly clientSecret?: string;
  readonly fetchFn?: typeof fetch;
  readonly now?: () => number;
  readonly timeoutMs?: number;
}

interface GraphqlEnvelope<T> {
  readonly data?: T;
  readonly errors?: ReadonlyArray<{ readonly message?: unknown }>;
}

interface GraphqlUserError {
  readonly field?: readonly unknown[];
  readonly code?: unknown;
  readonly message?: unknown;
}

export class ShopifyAdminCouponProvisioner implements BasicCouponProvisioner {
  private cached: { readonly token: string; readonly refreshAt: number } | null = null;

  constructor(private readonly options: ShopifyAdminCouponProvisionerOptions) {}

  async createSingleUseFixedCode(args: {
    amountCents: number;
    currency: 'MXN';
    expiresAt: Date;
    customerId: string;
    redemptionId: string;
    minimumSubtotalCents: number | null;
  }): Promise<ProvisionedDiscount> {
    if (!Number.isInteger(args.amountCents) || args.amountCents <= 0) {
      throw new Error('invalid_amount');
    }
    const customerGid = normalizeCustomerGid(args.customerId);
    const code = `MRW-${args.redemptionId.replace(/-/g, '').slice(0, 10).toUpperCase()}`;
    const nowMs = (this.options.now ?? Date.now)();
    const basicCodeDiscount: Record<string, unknown> = {
      title: `Monetta Rewards ${args.redemptionId.slice(0, 8)}`,
      code,
      startsAt: new Date(nowMs).toISOString(),
      endsAt: args.expiresAt.toISOString(),
      usageLimit: 1,
      appliesOncePerCustomer: true,
      customerSelection: {
        customers: {
          add: [customerGid],
        },
      },
      customerGets: {
        value: {
          discountAmount: {
            amount: (args.amountCents / 100).toFixed(2),
            appliesOnEachItem: false,
          },
        },
        items: {
          all: true,
        },
      },
      combinesWith: {
        orderDiscounts: false,
        productDiscounts: false,
        shippingDiscounts: true,
      },
    };
    if (args.minimumSubtotalCents !== null && args.minimumSubtotalCents > 0) {
      basicCodeDiscount.minimumRequirement = {
        subtotal: {
          greaterThanOrEqualToSubtotal: (args.minimumSubtotalCents / 100).toFixed(2),
        },
      };
    }

    const data = await this.graphql<{
      readonly discountCodeBasicCreate?: {
        readonly codeDiscountNode?: {
          readonly id?: unknown;
          readonly codeDiscount?: {
            readonly codes?: { readonly nodes?: ReadonlyArray<{ readonly code?: unknown }> };
          } | null;
        } | null;
        readonly userErrors?: readonly GraphqlUserError[];
      } | null;
    }>(DISCOUNT_CODE_BASIC_CREATE, { basicCodeDiscount });

    const payload = data.discountCodeBasicCreate;
    if (payload == null) throw new Error('shopify_discount_create_empty');
    const userErrors = payload.userErrors ?? [];
    if (userErrors.length > 0) {
      const msg = userErrors
        .map((e) => (typeof e.message === 'string' ? e.message : 'user_error'))
        .join('; ');
      throw new Error(`shopify_discount_rejected: ${msg}`);
    }
    const discountId = payload.codeDiscountNode?.id;
    if (typeof discountId !== 'string' || discountId === '') {
      throw new Error('shopify_discount_missing_id');
    }
    const returnedCode = payload.codeDiscountNode?.codeDiscount?.codes?.nodes?.[0]?.code;
    return {
      discountId,
      code: typeof returnedCode === 'string' && returnedCode !== '' ? returnedCode : code,
    };
  }

  async deleteCode(discountId: string): Promise<void> {
    const data = await this.graphql<{
      readonly discountCodeDelete?: {
        readonly deletedCodeDiscountId?: unknown;
        readonly userErrors?: readonly GraphqlUserError[];
      } | null;
    }>(DISCOUNT_CODE_DELETE, { id: discountId });
    const userErrors = data.discountCodeDelete?.userErrors ?? [];
    if (userErrors.length > 0) {
      const msg = userErrors
        .map((e) => (typeof e.message === 'string' ? e.message : 'user_error'))
        .join('; ');
      throw new Error(`shopify_discount_delete_rejected: ${msg}`);
    }
  }

  async usageCount(discountId: string): Promise<number | null> {
    try {
      const data = await this.graphql<{
        readonly codeDiscountNode?: {
          readonly codeDiscount?: { readonly asyncUsageCount?: unknown } | null;
        } | null;
      }>(DISCOUNT_USAGE_QUERY, { id: discountId });
      const count = data.codeDiscountNode?.codeDiscount?.asyncUsageCount;
      return typeof count === 'number' && Number.isInteger(count) && count >= 0 ? count : null;
    } catch {
      return null;
    }
  }

  private async graphql<T>(query: string, variables: Record<string, unknown>): Promise<T> {
    const token = await this.adminToken();
    const response = await this.fetch(
      `https://${this.shopDomain()}/admin/api/${this.apiVersion()}/graphql.json`,
      {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': token,
        },
        body: JSON.stringify({ query, variables }),
      },
    );
    if (!response.ok) throw new Error(`shopify_discount_http_${response.status}`);
    const body = (await response.json()) as GraphqlEnvelope<T>;
    if (body.errors !== undefined && body.errors.length > 0) {
      throw new Error('shopify_discount_graphql_failed');
    }
    if (body.data === undefined) {
      throw new Error('shopify_discount_empty_data');
    }
    return body.data;
  }

  private async adminToken(): Promise<string> {
    const staticToken = this.options.adminAccessToken?.trim() ?? '';
    if (staticToken.length >= 16) return staticToken;

    const now = (this.options.now ?? Date.now)();
    if (this.cached !== null && this.cached.refreshAt > now) return this.cached.token;
    const clientId = this.options.clientId?.trim() ?? '';
    const clientSecret = this.options.clientSecret ?? '';
    if (clientId === '' || clientSecret.length < 16) {
      throw new Error('shopify_admin_not_configured');
    }

    const response = await this.fetch(
      `https://${this.shopDomain()}/admin/oauth/access_token`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'client_credentials',
          client_id: clientId,
          client_secret: clientSecret,
        }).toString(),
      },
    );
    if (!response.ok) throw new Error('shopify_admin_token_failed');
    const envelope = (await response.json()) as {
      readonly access_token?: unknown;
      readonly expires_in?: unknown;
    };
    if (typeof envelope.access_token !== 'string' || envelope.access_token.length < 16) {
      throw new Error('shopify_admin_token_invalid');
    }
    const expiresIn = typeof envelope.expires_in === 'number' ? envelope.expires_in : 3600;
    this.cached = {
      token: envelope.access_token,
      refreshAt: now + Math.max(60, expiresIn - 300) * 1000,
    };
    return envelope.access_token;
  }

  private shopDomain(): string {
    const domain = this.options.shopDomain.trim().toLowerCase();
    if (!/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/.test(domain)) {
      throw new Error('shopify_domain_invalid');
    }
    return domain;
  }

  private apiVersion(): string {
    const version = this.options.apiVersion.trim();
    if (!/^20\d{2}-(01|04|07|10)$/.test(version)) {
      throw new Error('shopify_api_version_invalid');
    }
    return version;
  }

  private async fetch(url: string, init: RequestInit): Promise<Response> {
    const fetchFn = this.options.fetchFn ?? fetch;
    try {
      return await fetchFn(url, {
        ...init,
        signal: AbortSignal.timeout(this.options.timeoutMs ?? 10_000),
      });
    } catch {
      throw new Error('shopify_discount_request_failed');
    }
  }
}

export function normalizeCustomerGid(customerId: string): string {
  const trimmed = customerId.trim();
  if (/^[0-9]+$/.test(trimmed)) {
    return `gid://shopify/Customer/${trimmed}`;
  }
  if (/^gid:\/\/shopify\/Customer\/[0-9]+$/.test(trimmed)) {
    return trimmed;
  }
  throw new Error('invalid_customer_id');
}

export function createRewardsDiscountAdapter(
  config: Pick<
    AccountsOrdersConfig,
    'shopDomain' | 'shopifyAdminApiVersion' | 'shopifyAdminAccessToken' | 'shopifyAppClientId' | 'webhookSecret'
  >,
  rewardsEnv: Pick<RewardsEnv, 'rewardsEnabled' | 'redemptionEnabled'>,
): ShopifyDiscountAdapter {
  const hasAdminCreds =
    config.shopifyAdminAccessToken.length >= 16 ||
    (config.shopifyAppClientId !== '' && config.webhookSecret.length >= 16);
  if (!rewardsEnv.rewardsEnabled || !rewardsEnv.redemptionEnabled || config.shopDomain === '' || !hasAdminCreds) {
    return new DisabledDiscountAdapter();
  }
  return new BasicSingleUseCouponAdapter(
    new ShopifyAdminCouponProvisioner({
      shopDomain: config.shopDomain,
      apiVersion: config.shopifyAdminApiVersion,
      adminAccessToken: config.shopifyAdminAccessToken,
      clientId: config.shopifyAppClientId,
      clientSecret: config.webhookSecret,
    }),
  );
}

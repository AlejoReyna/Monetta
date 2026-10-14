import type { ShopifyCustomerErasureClient } from './ports.js';

const erasureMutation = `mutation MonettaCustomerRequestDataErasure($customerId: ID!) {
  customerRequestDataErasure(customerId: $customerId) {
    customerId
    userErrors { field message }
  }
}`;

const alreadyRequested = /already|previously requested|erasure request/i;

/**
 * Calls Shopify Admin `customerRequestDataErasure`. The Admin token is read
 * from the backend environment (static token, or client-credentials exchange).
 * It is never returned to the app. Erasure itself stays asynchronous.
 */
export class ShopifyCustomerDataErasureClient implements ShopifyCustomerErasureClient {
  private cached: { readonly token: string; readonly refreshAt: number } | null = null;

  constructor(private readonly options: {
    readonly shopDomain: string;
    readonly apiVersion: string;
    readonly adminAccessToken?: string;
    readonly clientId?: string;
    readonly clientSecret?: string;
    readonly fetchFn?: typeof fetch;
    readonly now?: () => number;
    readonly timeoutMs?: number;
  }) {}

  async request(shopifyCustomerId: string): Promise<'requested'> {
    if (!/^[0-9]+$/.test(shopifyCustomerId)) throw new Error('invalid_customer_id');
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
        body: JSON.stringify({
          query: erasureMutation,
          variables: { customerId: `gid://shopify/Customer/${shopifyCustomerId}` },
        }),
      },
    );
    if (!response.ok) throw new Error('shopify_erasure_http_failed');
    const body = await response.json() as {
      readonly errors?: readonly { readonly message?: unknown; readonly extensions?: { readonly code?: unknown } }[];
      readonly data?: {
        readonly customerRequestDataErasure?: {
          readonly customerId?: unknown;
          readonly userErrors?: readonly { readonly message?: unknown }[];
        } | null;
      };
    };
    const extensionsCode = body.errors?.find((error) => error.extensions?.code === 'ACCESS_DENIED');
    if (extensionsCode !== undefined) throw new Error('shopify_erasure_access_denied');
    if (body.errors !== undefined && body.errors.length > 0) {
      throw new Error('shopify_erasure_graphql_failed');
    }
    const payload = body.data?.customerRequestDataErasure;
    if (payload == null) throw new Error('shopify_erasure_empty');
    const userErrors = payload.userErrors ?? [];
    if (userErrors.length === 0) return 'requested';
    const messages = userErrors.map((error) => (typeof error.message === 'string' ? error.message : ''));
    if (messages.every((message) => message !== '' && alreadyRequested.test(message))) {
      return 'requested';
    }
    throw new Error('shopify_erasure_rejected');
  }

  private async adminToken(): Promise<string> {
    const staticToken = this.options.adminAccessToken?.trim() ?? '';
    if (staticToken.length >= 16) return staticToken;

    const now = (this.options.now ?? Date.now)();
    if (this.cached !== null && this.cached.refreshAt > now) return this.cached.token;
    const clientId = this.options.clientId?.trim() ?? '';
    const clientSecret = this.options.clientSecret ?? '';
    if (clientId === '' || clientSecret.length < 16) throw new Error('shopify_admin_not_configured');

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
    const envelope = await response.json() as {
      readonly access_token?: unknown;
      readonly scope?: unknown;
      readonly expires_in?: unknown;
    };
    if (typeof envelope.access_token !== 'string' || envelope.access_token.length < 16) {
      throw new Error('shopify_admin_token_invalid');
    }
    const scopes = typeof envelope.scope === 'string'
      ? envelope.scope.split(/[ ,]+/).map((scope) => scope.trim())
      : [];
    if (!scopes.includes('write_customer_data_erasure')) {
      throw new Error('shopify_erasure_scope_missing');
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
    if (!/^20\d{2}-(01|04|07|10)$/.test(version)) throw new Error('shopify_api_version_invalid');
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
      throw new Error('shopify_erasure_request_failed');
    }
  }
}

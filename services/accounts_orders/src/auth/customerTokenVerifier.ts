import { Buffer } from 'node:buffer';
import { isIP } from 'node:net';

/**
 * Resolves the customer represented by a bearer credential. A null result
 * means the credential is invalid; operational failures throw so callers can
 * answer 503 instead of misreporting a Shopify outage as an authentication
 * failure.
 */
export interface CustomerTokenVerifier {
  resolveCustomerId(accessToken: string): Promise<string | null>;
}

export class CustomerTokenVerificationUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CustomerTokenVerificationUnavailableError';
  }
}

const identityQuery = `query MonettaAuthenticatedCustomer {
  customer { id }
}`;

const maxResponseBytes = 256 * 1024;

export class ShopifyCustomerTokenVerifier implements CustomerTokenVerifier {
  constructor({
    shopDomain,
    fetchFn = fetch,
    timeoutMs = 10_000,
  }: {
    shopDomain: string;
    fetchFn?: typeof fetch;
    timeoutMs?: number;
  }) {
    this.shopDomain = shopDomain.trim();
    this.fetchFn = fetchFn;
    this.timeoutMs = timeoutMs;
  }

  private readonly shopDomain: string;
  private readonly fetchFn: typeof fetch;
  private readonly timeoutMs: number;
  private graphQlEndpoint: URL | null = null;
  private discoveryInFlight: Promise<URL> | null = null;

  async resolveCustomerId(accessToken: string): Promise<string | null> {
    if (accessToken.length === 0 || accessToken.length > 8192) return null;

    const endpoint = await this.resolveGraphQlEndpoint();
    let response: Response;
    try {
      response = await this.fetchFn(endpoint, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          // Shopify Customer Account API expects the raw token here, without
          // the standard Bearer prefix used by Monetta's public HTTP API.
          Authorization: accessToken,
          'User-Agent': 'MonettaAccountsOrders/0.1 (+https://monetta.mx)',
        },
        body: JSON.stringify({ query: identityQuery }),
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      throw unavailable('Customer Account API request failed', error);
    }

    if (response.status === 401 || response.status === 403) return null;
    if (!response.ok) {
      throw new CustomerTokenVerificationUnavailableError(
        `Customer Account API returned HTTP ${response.status}`,
      );
    }

    const payload = await readJson(response, 'Customer Account API');
    const errors = isRecord(payload) ? payload.errors : null;
    if (Array.isArray(errors) && errors.length > 0) {
      const text = JSON.stringify(errors).toUpperCase();
      if (
        text.includes('UNAUTHENTICATED') ||
        text.includes('UNAUTHORIZED') ||
        text.includes('ACCESS_DENIED') ||
        text.includes('INVALID_TOKEN')
      ) {
        return null;
      }
      throw new CustomerTokenVerificationUnavailableError(
        'Customer Account API returned GraphQL errors',
      );
    }

    const data = isRecord(payload) ? payload.data : null;
    const customer = isRecord(data) ? data.customer : null;
    const id = isRecord(customer) ? customer.id : null;
    return typeof id === 'string' && id.length > 0 ? id : null;
  }

  private resolveGraphQlEndpoint(): Promise<URL> {
    if (this.graphQlEndpoint !== null) {
      return Promise.resolve(this.graphQlEndpoint);
    }
    if (this.discoveryInFlight !== null) return this.discoveryInFlight;

    const pending = this.discoverGraphQlEndpoint();
    this.discoveryInFlight = pending;
    return pending.finally(() => {
      if (this.discoveryInFlight === pending) this.discoveryInFlight = null;
    });
  }

  private async discoverGraphQlEndpoint(): Promise<URL> {
    if (!looksLikeHost(this.shopDomain)) {
      throw new CustomerTokenVerificationUnavailableError(
        'SHOPIFY_STORE_DOMAIN is not configured',
      );
    }

    let response: Response;
    try {
      response = await this.fetchFn(
        new URL(`https://${this.shopDomain}/.well-known/customer-account-api`),
        {
          headers: {
            Accept: 'application/json',
            'User-Agent': 'MonettaAccountsOrders/0.1 (+https://monetta.mx)',
          },
          signal: AbortSignal.timeout(this.timeoutMs),
        },
      );
    } catch (error) {
      throw unavailable('Customer Account API discovery failed', error);
    }

    if (!response.ok) {
      throw new CustomerTokenVerificationUnavailableError(
        `Customer Account API discovery returned HTTP ${response.status}`,
      );
    }

    const payload = await readJson(response, 'Customer Account API discovery');
    const rawEndpoint = isRecord(payload) ? payload.graphql_api : null;
    if (typeof rawEndpoint !== 'string') {
      throw new CustomerTokenVerificationUnavailableError(
        'Customer Account API discovery returned no graphql_api',
      );
    }

    let endpoint: URL;
    try {
      endpoint = new URL(rawEndpoint);
    } catch {
      throw new CustomerTokenVerificationUnavailableError(
        'Customer Account API discovery returned an invalid graphql_api',
      );
    }
    if (
      endpoint.protocol !== 'https:' ||
      endpoint.username !== '' ||
      endpoint.password !== '' ||
      endpoint.hash !== '' ||
      !looksLikeHost(endpoint.hostname)
    ) {
      throw new CustomerTokenVerificationUnavailableError(
        'Customer Account API discovery returned an unsafe graphql_api',
      );
    }

    this.graphQlEndpoint = endpoint;
    return endpoint;
  }
}

async function readJson(response: Response, source: string): Promise<unknown> {
  const declaredLength = Number.parseInt(response.headers.get('content-length') ?? '', 10);
  if (Number.isFinite(declaredLength) && declaredLength > maxResponseBytes) {
    throw new CustomerTokenVerificationUnavailableError(`${source} response was too large`);
  }

  const body = await response.text();
  if (Buffer.byteLength(body, 'utf8') > maxResponseBytes) {
    throw new CustomerTokenVerificationUnavailableError(`${source} response was too large`);
  }
  try {
    return JSON.parse(body) as unknown;
  } catch {
    throw new CustomerTokenVerificationUnavailableError(`${source} returned non-JSON`);
  }
}

function unavailable(message: string, error: unknown): CustomerTokenVerificationUnavailableError {
  const suffix = error instanceof Error ? `: ${error.name}` : '';
  return new CustomerTokenVerificationUnavailableError(`${message}${suffix}`);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function looksLikeHost(value: string): boolean {
  return (
    value.length > 0 &&
    value.length <= 253 &&
    value.includes('.') &&
    !value.includes('://') &&
    !value.includes('/') &&
    !value.includes(' ') &&
    isIP(value) === 0 &&
    value !== 'localhost' &&
    !value.endsWith('.local')
  );
}

import { Buffer } from 'node:buffer';
import { isIP } from 'node:net';
import type { ShopifyCustomerOrderLookup, ShopifyListedOrder } from './ports.js';

/**
 * The live order check could not be completed. Callers must not treat that
 * as "no open orders".
 */
export class OrderCheckUnavailableError extends Error {
  constructor() {
    super('order_check_unavailable');
    this.name = 'OrderCheckUnavailableError';
  }
}

/** The shopper has more orders than this check will page through. */
export class TooManyOrdersError extends Error {
  constructor() {
    super('too_many_orders');
    this.name = 'TooManyOrdersError';
  }
}

const ordersQuery = `query MonettaDeletionOrderCheck($first: Int!, $after: String) {
  customer {
    orders(first: $first, after: $after, sortKey: PROCESSED_AT, reverse: true) {
      pageInfo { hasNextPage endCursor }
      nodes {
        id
        financialStatus
        fulfillmentStatus
        cancelledAt
        cancelReason
      }
    }
  }
}`;

const pageSize = 50;
const maxPages = 40;
const maxResponseBytes = 512 * 1024;

/**
 * Lists the shopper's orders from the Customer Account API — the same
 * `customer.orders` source the app uses for Mis pedidos. The Admin token is
 * not involved. Any transport, auth, or pagination failure throws
 * {@link OrderCheckUnavailableError} so deletion fails closed.
 */
export class CustomerAccountOrderLookup implements ShopifyCustomerOrderLookup {
  constructor(private readonly options: {
    readonly shopDomain: string;
    readonly fetchFn?: typeof fetch;
    readonly timeoutMs?: number;
    /** Test seam. Production discovers the endpoint from the shop domain. */
    readonly graphQlEndpoint?: string;
  }) {}

  async listOrders(accessToken: string): Promise<readonly ShopifyListedOrder[]> {
    if (accessToken.trim() === '' || accessToken.length > 8192 || /\s/.test(accessToken)) {
      throw new OrderCheckUnavailableError();
    }
    const endpoint = await this.endpoint();
    const orders: ShopifyListedOrder[] = [];
    const seenCursors = new Set<string>();
    let after: string | null = null;

    for (let page = 0; page < maxPages; page += 1) {
      const body = await this.post(endpoint, accessToken, after);
      const connection = readConnection(body);
      for (const node of connection.nodes) orders.push(node);
      if (!connection.hasNextPage) return orders;
      const cursor = connection.endCursor;
      if (cursor === null || seenCursors.has(cursor)) throw new OrderCheckUnavailableError();
      seenCursors.add(cursor);
      after = cursor;
    }
    throw new TooManyOrdersError();
  }

  private async endpoint(): Promise<URL> {
    const configured = this.options.graphQlEndpoint?.trim() ?? '';
    if (configured !== '') return requireHttpsUrl(configured);
    return discoverGraphQlEndpoint(
      this.options.shopDomain,
      this.options.fetchFn ?? fetch,
      this.options.timeoutMs ?? 10_000,
    );
  }

  private async post(endpoint: URL, accessToken: string, after: string | null): Promise<unknown> {
    let response: Response;
    try {
      response = await (this.options.fetchFn ?? fetch)(endpoint, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          // Customer Account API uses the raw token, not a Bearer prefix.
          Authorization: accessToken,
          'User-Agent': 'MonettaAccountsOrders/0.1 (+https://monetta.mx)',
        },
        body: JSON.stringify({
          query: ordersQuery,
          variables: { first: pageSize, after },
        }),
        signal: AbortSignal.timeout(this.options.timeoutMs ?? 10_000),
      });
    } catch {
      throw new OrderCheckUnavailableError();
    }
    if (!response.ok) throw new OrderCheckUnavailableError();
    const text = await response.text();
    if (Buffer.byteLength(text, 'utf8') > maxResponseBytes) throw new OrderCheckUnavailableError();
    try {
      return JSON.parse(text) as unknown;
    } catch {
      throw new OrderCheckUnavailableError();
    }
  }
}

function readConnection(payload: unknown): {
  readonly nodes: readonly ShopifyListedOrder[];
  readonly hasNextPage: boolean;
  readonly endCursor: string | null;
} {
  if (!isRecord(payload)) throw new OrderCheckUnavailableError();
  const errors = payload.errors;
  if (Array.isArray(errors) && errors.length > 0) throw new OrderCheckUnavailableError();
  const data = isRecord(payload.data) ? payload.data : null;
  const customer = isRecord(data?.customer) ? data.customer : null;
  const orders = isRecord(customer?.orders) ? customer.orders : null;
  const pageInfo = isRecord(orders?.pageInfo) ? orders.pageInfo : null;
  const nodes = orders?.nodes;
  if (!Array.isArray(nodes) || pageInfo === null || typeof pageInfo.hasNextPage !== 'boolean') {
    throw new OrderCheckUnavailableError();
  }
  const endCursor = pageInfo.endCursor;
  if (endCursor !== null && typeof endCursor !== 'string') throw new OrderCheckUnavailableError();
  return {
    nodes: nodes.map(readOrder),
    hasNextPage: pageInfo.hasNextPage,
    endCursor: typeof endCursor === 'string' && endCursor !== '' ? endCursor : null,
  };
}

function readOrder(node: unknown): ShopifyListedOrder {
  if (!isRecord(node) || typeof node.id !== 'string' || node.id.trim() === '') {
    throw new OrderCheckUnavailableError();
  }
  return {
    id: node.id,
    financialStatus: optionalString(node.financialStatus),
    fulfillmentStatus: optionalString(node.fulfillmentStatus),
    cancelledAt: optionalString(node.cancelledAt),
    cancelReason: optionalString(node.cancelReason),
    tags: [],
  };
}

function optionalString(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string') throw new OrderCheckUnavailableError();
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

async function discoverGraphQlEndpoint(
  shopDomain: string,
  fetchFn: typeof fetch,
  timeoutMs: number,
): Promise<URL> {
  if (!looksLikeHost(shopDomain.trim())) throw new OrderCheckUnavailableError();
  let response: Response;
  try {
    response = await fetchFn(
      new URL(`https://${shopDomain.trim()}/.well-known/customer-account-api`),
      {
        headers: {
          Accept: 'application/json',
          'User-Agent': 'MonettaAccountsOrders/0.1 (+https://monetta.mx)',
        },
        signal: AbortSignal.timeout(timeoutMs),
      },
    );
  } catch {
    throw new OrderCheckUnavailableError();
  }
  if (!response.ok) throw new OrderCheckUnavailableError();
  const text = await response.text();
  let payload: unknown;
  try {
    payload = JSON.parse(text) as unknown;
  } catch {
    throw new OrderCheckUnavailableError();
  }
  const raw = isRecord(payload) ? payload.graphql_api : null;
  if (typeof raw !== 'string') throw new OrderCheckUnavailableError();
  return requireHttpsUrl(raw);
}

function requireHttpsUrl(raw: string): URL {
  let endpoint: URL;
  try {
    endpoint = new URL(raw);
  } catch {
    throw new OrderCheckUnavailableError();
  }
  if (
    endpoint.protocol !== 'https:' ||
    endpoint.username !== '' ||
    endpoint.password !== '' ||
    endpoint.hash !== '' ||
    !looksLikeHost(endpoint.hostname)
  ) {
    throw new OrderCheckUnavailableError();
  }
  return endpoint;
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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

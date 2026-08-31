import type {
  AdminFeaturedCollectionProjection,
} from './featuredTypes.js';
import type { AdminStorefrontConfigProjection } from './storefrontTypes.js';
import type { AdminProductProjection, AdminProductsPage } from './shopifyTypes.js';

export interface ShopifyAdminClientOptions {
  readonly shopDomain: string;
  readonly clientId: string;
  readonly clientSecret: string;
  readonly apiVersion: string;
  readonly headlessPublicationId: string;
  readonly featuredCollectionId?: string;
  readonly fetchFn?: typeof fetch;
  readonly timeoutMs?: number;
  readonly now?: () => number;
}

interface GraphqlEnvelope<T> {
  readonly data?: T;
  readonly errors?: ReadonlyArray<{ readonly message?: string; readonly extensions?: Record<string, unknown> }>;
  readonly extensions?: Record<string, unknown>;
}

interface AccessTokenEnvelope {
  readonly access_token?: unknown;
  readonly scope?: unknown;
  readonly expires_in?: unknown;
}

interface AdminProductsData {
  readonly shop: { readonly currencyCode: string };
  readonly products: {
    readonly nodes: readonly AdminProductNode[];
    readonly pageInfo: { readonly hasNextPage: boolean; readonly endCursor: string | null };
  };
}

interface AdminProductNode {
  readonly id: string;
  readonly title: string;
  readonly descriptionHtml?: string | null;
  readonly updatedAt: string;
  readonly status: string;
  readonly publishedOnPublication: boolean;
  readonly images: { readonly nodes: readonly { readonly url: string }[] };
  readonly variants: { readonly nodes: readonly AdminProductVariantNode[] };
}

interface AdminProductVariantNode {
  readonly id: string;
  readonly title: string;
  readonly price: string;
  readonly compareAtPrice: string | null;
  readonly availableForSale: boolean;
  readonly inventoryPolicy: string;
}

interface AdminCollectionNode {
  readonly id: string;
  readonly handle: string;
  readonly title: string;
  readonly updatedAt: string;
  readonly sortOrder: string;
  readonly products: { readonly nodes: readonly { readonly id: string }[] };
}

interface AdminMetaobjectNode {
  readonly id: string;
  readonly handle: string;
  readonly fields: readonly { readonly key: string; readonly value: string | null }[];
}

interface GraphqlUserError {
  readonly field?: readonly (string | number)[];
  readonly message?: string;
  readonly code?: string;
}

interface CachedAccessToken {
  readonly value: string;
  readonly refreshAt: number;
}

export type ShopifyAdminErrorCode =
  | 'not_configured'
  | 'http'
  | 'graphql'
  | 'throttled'
  | 'invalid_response'
  | 'authentication';

export class ShopifyAdminError extends Error {
  constructor(
    readonly code: ShopifyAdminErrorCode,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
    this.name = 'ShopifyAdminError';
  }
}

export class ShopifyAdminUserError extends ShopifyAdminError {
  constructor(readonly userErrors: readonly GraphqlUserError[]) {
    super('graphql', 'Shopify Admin rejected the requested change.');
    this.name = 'ShopifyAdminUserError';
  }
}

const adminProductFields = `
fragment AdminProductFields on Product {
  id
  title
  descriptionHtml
  updatedAt
  status
  publishedOnPublication(publicationId: $publicationId)
  images(first: 1) { nodes { url } }
  variants(first: 100) {
    nodes {
      id
      title
      price
      compareAtPrice
      availableForSale
      inventoryPolicy
    }
  }
}`;

const adminProductsQuery = `${adminProductFields}
query AdminProducts($first: Int!, $after: String, $publicationId: ID!) {
  shop { currencyCode }
  products(first: $first, after: $after, sortKey: ID) {
    nodes { ...AdminProductFields }
    pageInfo { hasNextPage endCursor }
  }
}
`;

const adminProductQuery = `${adminProductFields}
query AdminProduct($id: ID!, $publicationId: ID!) {
  shop { currencyCode }
  product(id: $id) { ...AdminProductFields }
}
`;

export interface ShopifyAdminReadClient {
  listProducts(input: { readonly first: number; readonly after: string | null }): Promise<AdminProductsPage>;
}

export interface ShopifyAdminWriteClient extends ShopifyAdminReadClient {
  getProduct(productGid: string): Promise<AdminProductProjection | null>;
  updateProductTitle(productGid: string, title: string): Promise<void>;
  updateVariantPrice(productGid: string, variantGid: string, price: string): Promise<void>;
  setPublication(productGid: string, published: boolean): Promise<void>;
  getFeaturedCollection(): Promise<AdminFeaturedCollectionProjection | null>;
  addFeaturedProducts(productGids: readonly string[]): Promise<void>;
  removeFeaturedProducts(productGids: readonly string[]): Promise<void>;
  reorderFeaturedProducts(moves: readonly { readonly id: string; readonly newPosition: number }[]): Promise<string | null>;
  getJob(jobId: string): Promise<{ readonly done: boolean }>;
  getStorefrontConfig(): Promise<AdminStorefrontConfigProjection | null>;
  updateStorefrontConfig(input: {
    readonly announcement: string;
    readonly showHero: boolean;
    readonly showNewest: boolean;
    readonly showTodaysPicks: boolean;
    readonly showExternalPicks: boolean;
    readonly version: number;
  }): Promise<void>;
}

export class ShopifyAdminClient implements ShopifyAdminWriteClient {
  private cachedAccessToken: CachedAccessToken | null = null;

  constructor(private readonly options: ShopifyAdminClientOptions) {
    if (!/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/.test(options.shopDomain)) {
      throw new ShopifyAdminError('not_configured', 'Shopify store domain is invalid.');
    }
    if (!/^20\d{2}-(01|04|07|10)$/.test(options.apiVersion)) {
      throw new ShopifyAdminError('not_configured', 'Shopify Admin API version is invalid.');
    }
    if (!/^[a-f0-9]{32}$/.test(options.clientId)) {
      throw new ShopifyAdminError('not_configured', 'Shopify app client id is invalid.');
    }
    if (options.clientSecret.length < 32) {
      throw new ShopifyAdminError('not_configured', 'Shopify app client secret is missing.');
    }
    if (!/^gid:\/\/shopify\/Publication\/\d+$/.test(options.headlessPublicationId)) {
      throw new ShopifyAdminError('not_configured', 'Shopify Headless publication id is invalid.');
    }
    this.fetchFn = options.fetchFn ?? fetch;
    this.timeoutMs = options.timeoutMs ?? 10_000;
    this.now = options.now ?? (() => Date.now());
  }

  private readonly fetchFn: typeof fetch;
  private readonly timeoutMs: number;
  private readonly now: () => number;

  async listProducts(input: {
    readonly first: number;
    readonly after: string | null;
  }): Promise<AdminProductsPage> {
    const first = Math.max(1, Math.min(100, Math.trunc(input.first)));
    const data = await this.query<AdminProductsData>(adminProductsQuery, {
      first,
      after: input.after,
      publicationId: this.options.headlessPublicationId,
    });
    const currencyCode = data.shop.currencyCode;
    return {
      currencyCode,
      products: data.products.nodes.map((product) => normalizeProduct(product, currencyCode)),
      pageInfo: data.products.pageInfo,
    };
  }

  async getProduct(productGid: string): Promise<AdminProductProjection | null> {
    const data = await this.query<{
      readonly shop: { readonly currencyCode: string };
      readonly product: AdminProductNode | null;
    }>(
      adminProductQuery,
      { id: productGid, publicationId: this.options.headlessPublicationId },
    );
    return data.product === null
      ? null
      : normalizeProduct(data.product, data.shop.currencyCode);
  }

  async updateProductTitle(productGid: string, title: string): Promise<void> {
    const data = await this.mutate<{
      readonly productUpdate: { readonly userErrors: readonly GraphqlUserError[] };
    }>(
      `mutation ProductUpdate($product: ProductUpdateInput!) {
        productUpdate(product: $product) { userErrors { field message code } }
      }`,
      { product: { id: productGid, title } },
    );
    throwMutationUserErrors(data.productUpdate.userErrors);
  }

  async updateVariantPrice(
    productGid: string,
    variantGid: string,
    price: string,
  ): Promise<void> {
    const data = await this.mutate<{
      readonly productVariantsBulkUpdate: { readonly userErrors: readonly GraphqlUserError[] };
    }>(
      `mutation ProductVariantsBulkUpdate(
        $productId: ID!
        $variants: [ProductVariantsBulkInput!]!
      ) {
        productVariantsBulkUpdate(productId: $productId, variants: $variants) {
          userErrors { field message code }
        }
      }`,
      { productId: productGid, variants: [{ id: variantGid, price }] },
    );
    throwMutationUserErrors(data.productVariantsBulkUpdate.userErrors);
  }

  async setPublication(productGid: string, published: boolean): Promise<void> {
    const mutation = published ? 'publishablePublish' : 'publishableUnpublish';
    const data = await this.mutate<Record<string, { readonly userErrors: readonly GraphqlUserError[] }>>(
      `mutation PublicationChange($id: ID!, $publicationId: ID!) {
        ${mutation}(id: $id, input: { publicationId: $publicationId }) {
          userErrors { field message code }
        }
      }`,
      { id: productGid, publicationId: this.options.headlessPublicationId },
    );
    throwMutationUserErrors(data[mutation]!.userErrors);
  }

  async getFeaturedCollection(): Promise<AdminFeaturedCollectionProjection | null> {
    const collectionId = this.options.featuredCollectionId?.trim();
    if (!collectionId) {
      throw new ShopifyAdminError('not_configured', 'Featured collection is not configured.');
    }
    const data = await this.query<{
      readonly collection: AdminCollectionNode | null;
    }>(
      `query FeaturedCollection($id: ID!) {
        collection(id: $id) {
          id
          handle
          title
          updatedAt
          sortOrder
          products(first: 100) { nodes { id } }
        }
      }`,
      { id: collectionId },
    );
    if (data.collection === null) return null;
    return normalizeCollection(data.collection);
  }

  async addFeaturedProducts(productGids: readonly string[]): Promise<void> {
    await this.collectionMembershipMutation('collectionAddProducts', productGids);
  }

  async removeFeaturedProducts(productGids: readonly string[]): Promise<void> {
    await this.collectionMembershipMutation('collectionRemoveProducts', productGids);
  }

  async reorderFeaturedProducts(
    moves: readonly { readonly id: string; readonly newPosition: number }[],
  ): Promise<string | null> {
    const collectionId = this.requireFeaturedCollectionId();
    const data = await this.mutate<{
      readonly collectionReorderProducts: {
        readonly job: { readonly id: string } | null;
        readonly userErrors: readonly GraphqlUserError[];
      };
    }>(
      `mutation FeaturedCollectionReorder($id: ID!, $moves: [MoveInput!]!) {
        collectionReorderProducts(id: $id, moves: $moves) {
          job { id }
          userErrors { field message code }
        }
      }`,
      { id: collectionId, moves },
    );
    const result = data.collectionReorderProducts;
    throwMutationUserErrors(result.userErrors);
    return result.job?.id ?? null;
  }

  async getJob(jobId: string): Promise<{ readonly done: boolean }> {
    const data = await this.query<{
      readonly job: { readonly done: boolean } | null;
    }>(
      `query AdminJob($id: ID!) { job(id: $id) { done } }`,
      { id: jobId },
    );
    if (data.job === null) {
      throw new ShopifyAdminError('invalid_response', 'Shopify Admin job was not found.');
    }
    return data.job;
  }

  async getStorefrontConfig(): Promise<AdminStorefrontConfigProjection | null> {
    const data = await this.query<{
      readonly metaobjectByHandle: AdminMetaobjectNode | null;
    }>(
      `query StorefrontConfig($handle: MetaobjectHandleInput!) {
        metaobjectByHandle(handle: $handle) {
          id
          handle
          fields { key value }
        }
      }`,
      { handle: { type: '$app:storefront_config', handle: 'monetta' } },
    );
    return data.metaobjectByHandle === null
      ? null
      : storefrontFromMetaobject(data.metaobjectByHandle);
  }

  async updateStorefrontConfig(input: {
    readonly announcement: string;
    readonly showHero: boolean;
    readonly showNewest: boolean;
    readonly showTodaysPicks: boolean;
    readonly showExternalPicks: boolean;
    readonly version: number;
  }): Promise<void> {
    const data = await this.mutate<{
      readonly metaobjectUpsert: { readonly userErrors: readonly GraphqlUserError[] };
    }>(
      `mutation StorefrontConfigUpsert(
        $handle: MetaobjectHandleInput!
        $metaobject: MetaobjectUpsertInput!
      ) {
        metaobjectUpsert(handle: $handle, metaobject: $metaobject) {
          userErrors { field message code }
        }
      }`,
      {
        handle: { type: '$app:storefront_config', handle: 'monetta' },
        metaobject: {
          fields: [
            { key: 'announcement', value: input.announcement },
            { key: 'show_hero', value: String(input.showHero) },
            { key: 'show_newest', value: String(input.showNewest) },
            { key: 'show_todays_picks', value: String(input.showTodaysPicks) },
            { key: 'show_external_picks', value: String(input.showExternalPicks) },
            { key: 'version', value: String(input.version) },
          ],
        },
      },
    );
    throwMutationUserErrors(data.metaobjectUpsert.userErrors);
  }

  private requireFeaturedCollectionId(): string {
    const collectionId = this.options.featuredCollectionId?.trim();
    if (!collectionId) {
      throw new ShopifyAdminError('not_configured', 'Featured collection is not configured.');
    }
    return collectionId;
  }

  private async collectionMembershipMutation(
    mutation: 'collectionAddProducts' | 'collectionRemoveProducts',
    productGids: readonly string[],
  ): Promise<void> {
    const collectionId = this.requireFeaturedCollectionId();
    if (productGids.length === 0) return;
    const data = await this.mutate<Record<string, {
      readonly userErrors: readonly GraphqlUserError[];
    }>>(
      `mutation FeaturedCollectionMembership($id: ID!, $productIds: [ID!]!) {
        ${mutation}(id: $id, productIds: $productIds) {
          userErrors { field message code }
        }
      }`,
      { id: collectionId, productIds: productGids },
    );
    const result = data[mutation];
    if (result === undefined) {
      throw new ShopifyAdminError('invalid_response', 'Shopify Admin returned no collection result.');
    }
    throwMutationUserErrors(result.userErrors);
  }

  private async query<T>(
    query: string,
    variables: Readonly<Record<string, unknown>>,
  ): Promise<T> {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      const accessToken = await this.accessToken(attempt > 0);
      const response = await this.fetchGraphql(accessToken, query, variables);
      if (response.status === 401 || response.status === 403) {
        this.cachedAccessToken = null;
        if (attempt === 0) continue;
        throw new ShopifyAdminError('authentication', 'Shopify Admin authentication failed.');
      }
      if (response.status === 429) {
        throw new ShopifyAdminError('throttled', 'Shopify Admin API is throttled.', true);
      }
      if (!response.ok) {
        throw new ShopifyAdminError('http', 'Shopify Admin API returned an upstream error.', true);
      }

      const envelope = await readJson<GraphqlEnvelope<T>>(response);
      if (envelope.errors !== undefined && envelope.errors.length > 0) {
        const throttled = envelope.errors.some((error) =>
          JSON.stringify(error.extensions ?? {}).toUpperCase().includes('THROTTL'),
        );
        throw new ShopifyAdminError(
          throttled ? 'throttled' : 'graphql',
          throttled
            ? 'Shopify Admin API is throttled.'
            : 'Shopify Admin GraphQL returned an error.',
          throttled,
        );
      }
      if (envelope.data === undefined) {
        throw new ShopifyAdminError('invalid_response', 'Shopify Admin returned no data.');
      }
      return envelope.data;
    }
    throw new ShopifyAdminError('authentication', 'Shopify Admin authentication failed.');
  }

  /** Mutations deliberately make one upstream attempt; an ambiguous response
   * must be reconciled by a canonical read instead of being repeated. */
  private async mutate<T>(
    mutation: string,
    variables: Readonly<Record<string, unknown>>,
  ): Promise<T> {
    const accessToken = await this.accessToken(false);
    const response = await this.fetchGraphql(accessToken, mutation, variables);
    if (response.status === 401 || response.status === 403) {
      this.cachedAccessToken = null;
      throw new ShopifyAdminError('authentication', 'Shopify Admin authentication failed.');
    }
    if (response.status === 429) {
      throw new ShopifyAdminError('throttled', 'Shopify Admin API is throttled.', true);
    }
    if (!response.ok) {
      throw new ShopifyAdminError('http', 'Shopify Admin API returned an upstream error.', true);
    }
    const envelope = await readJson<GraphqlEnvelope<T>>(response);
    if (envelope.errors !== undefined && envelope.errors.length > 0) {
      throw new ShopifyAdminError('graphql', 'Shopify Admin GraphQL returned an error.');
    }
    if (envelope.data === undefined) {
      throw new ShopifyAdminError('invalid_response', 'Shopify Admin returned no data.');
    }
    return envelope.data;
  }

  private async fetchGraphql(
    accessToken: string,
    query: string,
    variables: Readonly<Record<string, unknown>>,
  ): Promise<Response> {
    return this.request(
      `https://${this.options.shopDomain}/admin/api/${this.options.apiVersion}/graphql.json`,
      {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': accessToken,
        },
        body: JSON.stringify({ query, variables }),
      },
    );
  }

  private async accessToken(forceRefresh: boolean): Promise<string> {
    const now = this.now();
    if (!forceRefresh && this.cachedAccessToken !== null && this.cachedAccessToken.refreshAt > now) {
      return this.cachedAccessToken.value;
    }

    const response = await this.request(
      `https://${this.options.shopDomain}/admin/oauth/access_token`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'client_credentials',
          client_id: this.options.clientId,
          client_secret: this.options.clientSecret,
        }).toString(),
      },
    );
    if (response.status === 401 || response.status === 403) {
      throw new ShopifyAdminError('authentication', 'Shopify Admin token exchange failed.');
    }
    if (!response.ok) {
      throw new ShopifyAdminError('http', 'Shopify Admin token exchange failed.', true);
    }

    const envelope = await readJson<AccessTokenEnvelope>(response);
    if (
      typeof envelope.access_token !== 'string' || envelope.access_token.length < 16 ||
      typeof envelope.scope !== 'string' ||
      typeof envelope.expires_in !== 'number' || !Number.isFinite(envelope.expires_in) ||
      envelope.expires_in < 600
    ) {
      throw new ShopifyAdminError('invalid_response', 'Shopify Admin token response is invalid.');
    }
    const scopes = new Set(envelope.scope.split(/[ ,]+/).map((scope) => scope.trim()));
    if (!scopes.has('read_products')) {
      throw new ShopifyAdminError('authentication', 'Shopify Admin token lacks read_products.');
    }

    this.cachedAccessToken = {
      value: envelope.access_token,
      refreshAt: now + (envelope.expires_in - 300) * 1_000,
    };
    return envelope.access_token;
  }

  private async request(url: string, init: RequestInit): Promise<Response> {
    try {
      return await this.fetchFn(url, {
        ...init,
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch {
      throw new ShopifyAdminError('http', 'Shopify Admin request failed.', true);
    }
  }
}

async function readJson<T>(response: Response): Promise<T> {
  try {
    return await response.json() as T;
  } catch {
    throw new ShopifyAdminError('invalid_response', 'Shopify Admin returned invalid JSON.');
  }
}

function normalizeProduct(
  product: AdminProductNode,
  currencyCode: string,
): AdminProductProjection {
  return {
    id: product.id,
    title: product.title,
    updatedAt: product.updatedAt,
    status: product.status,
    publishedOnPublication: product.publishedOnPublication,
    currencyCode,
    imageUrl: product.images.nodes[0]?.url ?? null,
    descriptionHtml: product.descriptionHtml ?? '',
    variants: product.variants.nodes.map((variant) => ({
      id: variant.id,
      title: variant.title,
      price: variant.price,
      compareAtPrice: variant.compareAtPrice,
      availableForSale: variant.availableForSale,
      inventoryPolicy: variant.inventoryPolicy,
      currencyCode,
    })),
  };
}

function normalizeCollection(collection: AdminCollectionNode): AdminFeaturedCollectionProjection {
  return {
    id: collection.id,
    handle: collection.handle,
    title: collection.title,
    updatedAt: collection.updatedAt,
    sortOrder: collection.sortOrder,
    productIds: collection.products.nodes.map((product) => product.id),
  };
}

function storefrontFromMetaobject(metaobject: AdminMetaobjectNode): AdminStorefrontConfigProjection {
  const values = new Map(metaobject.fields.map((field) => [field.key, field.value ?? '']));
  const integer = Number.parseInt(values.get('version') ?? '0', 10);
  return {
    id: metaobject.id,
    version: Number.isFinite(integer) && integer >= 0 ? integer : 0,
    announcement: values.get('announcement') ?? '',
    showHero: values.get('show_hero') !== 'false',
    showNewest: values.get('show_newest') !== 'false',
    showTodaysPicks: values.get('show_todays_picks') !== 'false',
    showExternalPicks: values.get('show_external_picks') !== 'false',
  };
}

function throwMutationUserErrors(errors: readonly GraphqlUserError[]): void {
  if (errors.length > 0) throw new ShopifyAdminUserError(errors);
}

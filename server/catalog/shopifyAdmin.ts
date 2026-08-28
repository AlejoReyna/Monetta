import type { AdminProduct } from "./types.js";

const PRODUCT_FIELDS = `
  fragment MobileProduct on Product {
    id
    legacyResourceId
    handle
    title
    vendor
    productType
    tags
    descriptionHtml
    createdAt
    updatedAt
    publishedAt
    status
    brandOverride: metafield(namespace: "app", key: "brand_override") { value }
    categoryOverride: metafield(namespace: "app", key: "category_override") { value }
    images(first: 20) { nodes { url } }
    collections(first: 10) { nodes { handle } }
    variants(first: 20) {
      nodes {
        id
        title
        price
        compareAtPrice
        sku
        availableForSale
        inventoryQuantity
        inventoryPolicy
        inventoryItem { id }
      }
    }
  }
`;

interface GraphqlEnvelope<T> {
  readonly data?: T;
  readonly errors?: ReadonlyArray<{ readonly message?: string }>;
}

interface ProductsPage {
  readonly products: {
    readonly nodes: readonly AdminProduct[];
    readonly pageInfo: { readonly hasNextPage: boolean; readonly endCursor: string | null };
  };
}

interface AccessTokenEnvelope {
  readonly access_token?: unknown;
  readonly scope?: unknown;
  readonly expires_in?: unknown;
}

interface CachedAccessToken {
  readonly value: string;
  readonly refreshAt: number;
}

export class ShopifyAdminClient {
  private cachedAccessToken: CachedAccessToken | null = null;

  constructor(
    private readonly shopDomain: string,
    private readonly clientId: string,
    private readonly clientSecret: string,
    private readonly apiVersion: string,
  ) {
    if (!/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/.test(shopDomain)) {
      throw new Error("Invalid SHOPIFY_SHOP_DOMAIN");
    }
    if (!/^20\d{2}-(01|04|07|10)$/.test(apiVersion)) {
      throw new Error("Invalid Shopify API version");
    }
    if (!/^[a-f0-9]{32}$/.test(clientId)) throw new Error("Invalid Shopify client id");
    if (clientSecret.length < 32) throw new Error("Missing Shopify client secret");
  }

  async getProduct(productGid: string): Promise<AdminProduct | null> {
    const data = await this.query<{ readonly product: AdminProduct | null }>(
      `${PRODUCT_FIELDS}\nquery ProductForMobile($id: ID!) { product(id: $id) { ...MobileProduct } }`,
      { id: productGid },
    );
    return data.product;
  }

  async getProductForInventoryItem(inventoryItemGid: string): Promise<AdminProduct | null> {
    const data = await this.query<{
      readonly inventoryItem: { readonly variant: { readonly product: AdminProduct } } | null;
    }>(
      `${PRODUCT_FIELDS}\nquery ProductForInventoryItem($id: ID!) {
        inventoryItem(id: $id) { variant { product { ...MobileProduct } } }
      }`,
      { id: inventoryItemGid },
    );
    return data.inventoryItem?.variant.product ?? null;
  }

  async listProducts(after: string | null): Promise<ProductsPage["products"]> {
    const data = await this.query<ProductsPage>(
      `${PRODUCT_FIELDS}\nquery ProductsForMobile($after: String) {
        products(first: 50, after: $after, sortKey: ID) {
          nodes { ...MobileProduct }
          pageInfo { hasNextPage endCursor }
        }
      }`,
      { after },
    );
    return data.products;
  }

  private async query<T>(query: string, variables: Readonly<Record<string, unknown>>): Promise<T> {
    const accessToken = await this.accessToken();
    const controller = new AbortController();
    // Shopify requires the entire webhook response within five seconds. Leave
    // enough of that budget for Firestore initialization and the transaction.
    const timeout = setTimeout(() => controller.abort(), 2_750);
    try {
      const response = await fetch(
        `https://${this.shopDomain}/admin/api/${this.apiVersion}/graphql.json`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-shopify-access-token": accessToken,
          },
          body: JSON.stringify({ query, variables }),
          signal: controller.signal,
        },
      );
      if (!response.ok) throw new Error(`Shopify Admin API returned HTTP ${response.status}`);

      const envelope = (await response.json()) as GraphqlEnvelope<T>;
      if (envelope.errors?.length || envelope.data === undefined) {
        // Never include the response body: GraphQL messages and extensions can
        // expose store details that do not belong in public function logs.
        throw new Error("Shopify Admin GraphQL query failed");
      }
      return envelope.data;
    } finally {
      clearTimeout(timeout);
    }
  }

  /** Exchanges Dev Dashboard credentials for Shopify's 24-hour Admin token. */
  private async accessToken(): Promise<string> {
    const now = Date.now();
    if (this.cachedAccessToken !== null && this.cachedAccessToken.refreshAt > now) {
      return this.cachedAccessToken.value;
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2_750);
    try {
      const response = await fetch(
        `https://${this.shopDomain}/admin/oauth/access_token`,
        {
          method: "POST",
          headers: { "content-type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            grant_type: "client_credentials",
            client_id: this.clientId,
            client_secret: this.clientSecret,
          }),
          signal: controller.signal,
        },
      );
      if (!response.ok) throw new Error(`Shopify token endpoint returned HTTP ${response.status}`);

      const envelope = (await response.json()) as AccessTokenEnvelope;
      if (
        typeof envelope.access_token !== "string" || envelope.access_token.length < 16 ||
        typeof envelope.scope !== "string" ||
        typeof envelope.expires_in !== "number" || !Number.isFinite(envelope.expires_in) ||
        envelope.expires_in < 600
      ) {
        throw new Error("Shopify token endpoint returned an invalid response");
      }
      const scopes = new Set(envelope.scope.split(",").map((scope) => scope.trim()));
      if (!scopes.has("read_products") || !scopes.has("read_inventory")) {
        throw new Error("Shopify token is missing catalog read scopes");
      }

      this.cachedAccessToken = {
        value: envelope.access_token,
        // Refresh five minutes early so no request starts with a nearly expired token.
        refreshAt: now + (envelope.expires_in - 300) * 1_000,
      };
      return envelope.access_token;
    } finally {
      clearTimeout(timeout);
    }
  }
}

export function productGid(legacyId: string): string {
  const id = String(legacyId);
  if (!/^\d+$/.test(id)) throw new Error("Invalid Shopify product id");
  return `gid://shopify/Product/${id}`;
}

export function inventoryItemGid(legacyId: string): string {
  const id = String(legacyId);
  if (!/^\d+$/.test(id)) throw new Error("Invalid Shopify inventory item id");
  return `gid://shopify/InventoryItem/${id}`;
}

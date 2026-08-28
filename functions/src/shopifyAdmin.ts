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
    images(first: 6) { nodes { url } }
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

export class ShopifyAdminClient {
  constructor(
    private readonly shopDomain: string,
    private readonly accessToken: string,
    private readonly apiVersion: string,
  ) {
    if (!/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/.test(shopDomain)) {
      throw new Error("Invalid SHOPIFY_SHOP_DOMAIN");
    }
    if (!/^20\d{2}-(01|04|07|10)$/.test(apiVersion)) {
      throw new Error("Invalid Shopify API version");
    }
    if (accessToken.length < 16) throw new Error("Missing Shopify Admin access token");
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
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4_000);
    try {
      const response = await fetch(
        `https://${this.shopDomain}/admin/api/${this.apiVersion}/graphql.json`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-shopify-access-token": this.accessToken,
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

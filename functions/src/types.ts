export type CatalogWebhookTopic =
  | "products/create"
  | "products/update"
  | "products/delete"
  | "inventory_levels/update";

export interface ProductWebhookPayload {
  readonly id: string;
  readonly admin_graphql_api_id?: string;
}

export interface InventoryLevelWebhookPayload {
  readonly inventory_item_id: string;
  readonly location_id: string;
  readonly available: number | null;
  readonly updated_at?: string;
}

export interface AdminProduct {
  readonly id: string;
  readonly legacyResourceId: string;
  readonly handle: string;
  readonly title: string;
  readonly vendor: string;
  readonly productType: string;
  readonly tags: readonly string[];
  readonly descriptionHtml: string;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly publishedAt: string | null;
  readonly status: "ACTIVE" | "ARCHIVED" | "DRAFT" | "UNLISTED" | string;
  readonly brandOverride: { readonly value: string } | null;
  readonly categoryOverride: { readonly value: string } | null;
  readonly images: {
    readonly nodes: ReadonlyArray<{ readonly url: string }>;
  };
  readonly collections: {
    readonly nodes: ReadonlyArray<{ readonly handle: string }>;
  };
  readonly variants: {
    readonly nodes: ReadonlyArray<{
      readonly id: string;
      readonly title: string;
      readonly price: string;
      readonly compareAtPrice: string | null;
      readonly sku: string | null;
      readonly availableForSale: boolean;
      readonly inventoryQuantity: number | null;
      readonly inventoryPolicy: "CONTINUE" | "DENY" | string;
      readonly inventoryItem: { readonly id: string };
    }>;
  };
}

export interface CatalogProductDocument {
  readonly schemaVersion: 1;
  readonly source: "shopify";
  readonly id: string;
  readonly shopifyLegacyId: string;
  readonly handle: string;
  readonly title: string;
  readonly vendor: string;
  readonly productType: string;
  readonly tags: readonly string[];
  readonly descriptionHtml: string;
  readonly images: readonly string[];
  readonly collectionHandles: readonly string[];
  readonly brandOverride: string | null;
  readonly categoryOverride: string | null;
  readonly variants: ReadonlyArray<{
    readonly id: string;
    readonly title: string;
    readonly price: number;
    readonly compareAtPrice: number | null;
    readonly sku: string | null;
    readonly available: boolean;
    readonly inventoryQuantity: number | null;
    readonly inventoryPolicy: string;
    readonly inventoryItemId: string;
  }>;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly publishedAt: string;
  readonly isPublished: true;
  readonly isInStock: boolean;
  readonly minPrice: number;
}

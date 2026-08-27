import { describe, expect, it } from "vitest";
import { isPublicProduct, toCatalogProduct } from "../src/catalog.js";
import type { AdminProduct } from "../src/types.js";

const product: AdminProduct = {
  id: "gid://shopify/Product/123",
  legacyResourceId: "123",
  handle: "bolsa-negra",
  title: "Bolsa negra",
  vendor: "Monetta",
  productType: "Bolsas",
  tags: ["bolsa", "negro"],
  descriptionHtml: "<p>Descripción</p>",
  createdAt: "2026-08-01T12:00:00Z",
  updatedAt: "2026-08-26T12:00:00Z",
  publishedAt: "2026-08-01T12:00:00Z",
  status: "ACTIVE",
  brandOverride: { value: "Coach" },
  categoryOverride: null,
  images: { nodes: [{ url: "https://cdn.shopify.com/product.jpg" }] },
  collections: { nodes: [{ handle: "bolsas" }] },
  variants: {
    nodes: [{
      id: "gid://shopify/ProductVariant/456",
      title: "Default Title",
      price: "1299.00",
      compareAtPrice: "1499.00",
      sku: null,
      availableForSale: true,
      inventoryQuantity: 2,
      inventoryPolicy: "DENY",
      inventoryItem: { id: "gid://shopify/InventoryItem/789" },
    }],
  },
};

describe("catalog mapping", () => {
  it("creates the mobile document using Storefront-compatible GIDs", () => {
    expect(toCatalogProduct(product)).toMatchObject({
      id: "gid://shopify/Product/123",
      shopifyLegacyId: "123",
      minPrice: 1299,
      isInStock: true,
      brandOverride: "Coach",
      collectionHandles: ["bolsas"],
      variants: [{
        id: "gid://shopify/ProductVariant/456",
        price: 1299,
        compareAtPrice: 1499,
        available: true,
      }],
    });
  });

  it("excludes drafts and unpublished products from the public collection", () => {
    expect(isPublicProduct({ ...product, status: "DRAFT" })).toBe(false);
    expect(isPublicProduct({ ...product, publishedAt: null })).toBe(false);
  });
});

import type { AdminProduct, CatalogProductDocument } from "./types.js";

function finiteMoney(value: string | null): number | null {
  if (value === null || !/^\d+(?:\.\d+)?$/.test(value)) return null;
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

function parseSixMsiAmount(raw: string | null | undefined): number | null {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  if (trimmed === "") return null;
  const direct = finiteMoney(trimmed);
  if (direct !== null && direct > 0) return direct;
  if (trimmed.startsWith("{")) {
    try {
      const decoded = JSON.parse(trimmed) as { readonly amount?: unknown };
      if (typeof decoded.amount === "string") {
        const nested = finiteMoney(decoded.amount.trim());
        return nested !== null && nested > 0 ? nested : null;
      }
      if (typeof decoded.amount === "number" && Number.isFinite(decoded.amount) && decoded.amount > 0) {
        return decoded.amount;
      }
    } catch {
      return null;
    }
  }
  return null;
}

export function isPublicProduct(product: AdminProduct): boolean {
  return product.status === "ACTIVE" && product.publishedAt !== null;
}

/** Maps Admin GraphQL data to the exact, intentionally small mobile schema. */
export function toCatalogProduct(product: AdminProduct): CatalogProductDocument {
  if (!isPublicProduct(product)) {
    throw new Error("Cannot map an unpublished product into the public catalog");
  }

  const variants = product.variants.nodes.map((variant) => {
    const sixMsiInstallmentAmount = parseSixMsiAmount(variant.sixMsiAmount?.value);
    return {
      id: variant.id,
      title: variant.title,
      price: finiteMoney(variant.price) ?? 0,
      compareAtPrice: finiteMoney(variant.compareAtPrice),
      ...(sixMsiInstallmentAmount !== null ? { sixMsiInstallmentAmount } : {}),
      sku: variant.sku,
      selectedOptions: Object.fromEntries(
        (variant.selectedOptions ?? [])
          .filter((option) => typeof option.name === "string" && option.name.trim() !== "" &&
            typeof option.value === "string" && option.value.trim() !== "")
          .map((option) => [option.name, option.value]),
      ),
      imageUrls: variant.image?.url ? [variant.image.url] : [],
      available: variant.availableForSale,
    };
  });
  const availablePrices = variants
    .map((variant) => variant.price)
    .filter((price) => Number.isFinite(price));

  return {
    schemaVersion: 1,
    source: "shopify",
    id: product.id,
    shopifyLegacyId: product.legacyResourceId,
    handle: product.handle,
    title: product.title,
    vendor: product.vendor,
    productType: product.productType,
    tags: [...product.tags],
    descriptionHtml: product.descriptionHtml,
    images: product.images.nodes.map((image) => image.url),
    collectionHandles: product.collections.nodes.map((collection) => collection.handle),
    brandOverride: product.brandOverride?.value ?? null,
    categoryOverride: product.categoryOverride?.value ?? null,
    variants,
    createdAt: product.createdAt,
    updatedAt: product.updatedAt,
    publishedAt: product.publishedAt!,
    isPublished: true,
    isInStock: variants.some((variant) => variant.available),
    minPrice: availablePrices.length === 0 ? 0 : Math.min(...availablePrices),
  };
}

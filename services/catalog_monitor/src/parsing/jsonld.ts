import * as cheerio from 'cheerio';
import { parsePriceUsd } from './price.js';
import type { Availability, ExtractedProduct } from '../domain/types.js';

interface JsonLdOffer {
  readonly price?: unknown;
  readonly priceCurrency?: unknown;
  readonly availability?: unknown;
}

interface JsonLdProduct {
  readonly '@type'?: unknown;
  readonly name?: unknown;
  readonly brand?: unknown;
  readonly category?: unknown;
  readonly image?: unknown;
  readonly sku?: unknown;
  readonly productID?: unknown;
  readonly offers?: unknown;
}

/** Extracts every JSON-LD block from a page, tolerating malformed JSON in any one of them. */
export function extractJsonLdBlocks(html: string): unknown[] {
  const $ = cheerio.load(html);
  const blocks: unknown[] = [];
  $('script[type="application/ld+json"]').each((_, el) => {
    const raw = $(el).contents().text();
    try {
      blocks.push(JSON.parse(raw));
    } catch {
      // Malformed JSON-LD on the page must not abort extraction — fall
      // through to the next block, and ultimately to metadata/selectors.
    }
  });
  return blocks;
}

function flattenProducts(blocks: unknown[]): JsonLdProduct[] {
  const out: JsonLdProduct[] = [];
  const visit = (node: unknown): void => {
    if (Array.isArray(node)) {
      node.forEach(visit);
      return;
    }
    if (node === null || typeof node !== 'object') return;
    const obj = node as Record<string, unknown>;
    const type = obj['@type'];
    const isProduct =
      type === 'Product' || (Array.isArray(type) && type.includes('Product'));
    if (isProduct) out.push(obj as JsonLdProduct);
    if ('@graph' in obj) visit(obj['@graph']);
  };
  blocks.forEach(visit);
  return out;
}

function firstString(value: unknown): string | null {
  if (typeof value === 'string' && value.trim() !== '') return value.trim();
  if (Array.isArray(value)) {
    for (const item of value) {
      const s = firstString(item);
      if (s) return s;
    }
  }
  return null;
}

function brandName(value: unknown): string | null {
  if (typeof value === 'string') return value.trim() || null;
  if (value && typeof value === 'object' && 'name' in (value as Record<string, unknown>)) {
    return firstString((value as Record<string, unknown>)['name']);
  }
  return null;
}

function availabilityFromSchema(value: unknown): Availability {
  const raw = firstString(value) ?? '';
  if (/InStock/i.test(raw)) return 'inStock';
  if (/OutOfStock|SoldOut|Discontinued/i.test(raw)) return 'outOfStock';
  return 'unknown';
}

function firstOffer(offers: unknown): JsonLdOffer | null {
  if (Array.isArray(offers)) return (offers[0] as JsonLdOffer) ?? null;
  if (offers && typeof offers === 'object') return offers as JsonLdOffer;
  return null;
}

/**
 * Extracts a product from JSON-LD `Product` nodes (including ones nested
 * under `@graph`). Returns `null` when no `Product` node is present at all;
 * returns a best-effort (possibly partially-null) product otherwise, so the
 * caller can measure required-field coverage rather than treat "found a
 * Product node but it's missing brand" as "no JSON-LD".
 */
export function extractProductFromJsonLd(
  html: string,
  fallbackBrand: string,
): Omit<ExtractedProduct, 'externalId' | 'canonicalUrl'> | null {
  const products = flattenProducts(extractJsonLdBlocks(html));
  if (products.length === 0) return null;

  const node = products[0]!;
  const offer = firstOffer(node.offers);
  const priceCurrency = offer ? firstString(offer.priceCurrency) : null;
  const rawPrice = offer?.price;
  const priceUsd =
    priceCurrency && priceCurrency.toUpperCase() !== 'USD'
      ? null
      : parsePriceUsd(typeof rawPrice === 'number' ? rawPrice : firstString(rawPrice));

  return {
    title: firstString(node.name) ?? '',
    brand: brandName(node.brand) ?? fallbackBrand,
    category: firstString(node.category),
    imageUrl: firstString(node.image),
    priceUsd,
    availability: offer ? availabilityFromSchema(offer.availability) : 'unknown',
  };
}

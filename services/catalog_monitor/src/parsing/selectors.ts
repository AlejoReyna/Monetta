import * as cheerio from 'cheerio';
import { parsePriceUsd } from './price.js';
import type { Availability, ExtractedProduct } from '../domain/types.js';

/** Adapter-specific CSS selectors — the third, last-resort extraction tier. */
export interface ProductSelectors {
  readonly title: string;
  readonly price: string;
  readonly image: string;
  readonly availability?: string;
  readonly category?: string;
  readonly inStockText?: RegExp;
  readonly outOfStockText?: RegExp;
}

export function extractProductFromSelectors(
  html: string,
  selectors: ProductSelectors,
  fallbackBrand: string,
): Omit<ExtractedProduct, 'externalId' | 'canonicalUrl'> | null {
  const $ = cheerio.load(html);

  const title = $(selectors.title).first().text().trim() || null;
  const priceText = $(selectors.price).first().text().trim() || null;
  const image =
    $(selectors.image).first().attr('src') ?? $(selectors.image).first().attr('data-src') ?? null;

  if (!title && !priceText && !image) return null;

  let availability: Availability = 'unknown';
  if (selectors.availability) {
    const text = $(selectors.availability).first().text().trim();
    if (selectors.outOfStockText?.test(text)) availability = 'outOfStock';
    else if (selectors.inStockText?.test(text)) availability = 'inStock';
    else if (text) availability = 'unknown';
  }

  const category = selectors.category ? $(selectors.category).first().text().trim() || null : null;

  return {
    title: title ?? '',
    brand: fallbackBrand,
    category,
    imageUrl: image,
    priceUsd: parsePriceUsd(priceText),
    availability,
  };
}

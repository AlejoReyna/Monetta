import * as cheerio from 'cheerio';
import { parsePriceUsd } from './price.js';
import type { Availability, ExtractedProduct } from '../domain/types.js';

function meta($: cheerio.CheerioAPI, ...names: string[]): string | null {
  for (const name of names) {
    const byProperty = $(`meta[property="${name}"]`).attr('content');
    if (byProperty && byProperty.trim()) return byProperty.trim();
    const byName = $(`meta[name="${name}"]`).attr('content');
    if (byName && byName.trim()) return byName.trim();
  }
  return null;
}

function availabilityFromOg(value: string | null): Availability {
  if (!value) return 'unknown';
  if (/in\s?stock/i.test(value)) return 'inStock';
  if (/out\s?of\s?stock|sold\s?out/i.test(value)) return 'outOfStock';
  return 'unknown';
}

/** Extracts from Open Graph / `product:*` meta tags — the second priority tier. */
export function extractProductFromMetadata(
  html: string,
  fallbackBrand: string,
): Omit<ExtractedProduct, 'externalId' | 'canonicalUrl'> | null {
  const $ = cheerio.load(html);

  const title = meta($, 'og:title', 'twitter:title');
  const priceAmount = meta($, 'product:price:amount', 'og:price:amount');
  const priceCurrency = meta($, 'product:price:currency', 'og:price:currency');
  const image = meta($, 'og:image', 'twitter:image');
  const brand = meta($, 'product:brand', 'og:brand') ?? fallbackBrand;
  const availability = meta($, 'product:availability', 'og:availability');
  const category = meta($, 'product:category', 'og:category');

  if (!title && !priceAmount && !image) return null;

  const priceUsd =
    priceCurrency && priceCurrency.toUpperCase() !== 'USD' ? null : parsePriceUsd(priceAmount);

  return {
    title: title ?? '',
    brand,
    category,
    imageUrl: image,
    priceUsd,
    availability: availabilityFromOg(availability),
  };
}

import { createHash } from 'node:crypto';
import type { ExtractedProduct } from '../domain/types.js';

/** Stable fingerprint for change detection — the fields a shopper would notice as "different." */
export function fingerprintOf(product: ExtractedProduct): string {
  const material = JSON.stringify({
    title: product.title,
    brand: product.brand,
    category: product.category,
    imageUrl: product.imageUrl,
    priceUsd: product.priceUsd,
    availability: product.availability,
  });
  return createHash('sha256').update(material).digest('hex');
}

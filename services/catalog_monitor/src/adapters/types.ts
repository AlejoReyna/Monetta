import type { ProductSelectors } from '../parsing/selectors.js';
import { SOURCE_IDS, type SourceDescriptor, type SourceId } from '../domain/types.js';

/**
 * One adapter per brand. An adapter only knows how to (a) recognize a real
 * product-detail URL among everything a sitemap lists, and (b) provide the
 * CSS selectors used as the last-resort extraction tier. Fetching, rate
 * limiting, retries, and persistence are all shared crawl-runner concerns —
 * see `crawl/runner.ts`.
 */
export interface BrandAdapter {
  readonly source: SourceDescriptor;
  readonly selectors: ProductSelectors;
  /** True if this URL is a product detail page worth fetching and parsing. */
  isProductUrl(url: string): boolean;
  /** Derives the source-scoped product ID from a canonical product URL. */
  externalIdFromUrl(url: string): string | null;
}

export const sourceIdList = (): SourceId[] => [...SOURCE_IDS];

/**
 * Path segments that must never be crawled regardless of what a sitemap
 * lists, per the spec: search, checkout, account, cart, wishlist, private
 * API paths. Shared across adapters; brand-specific adapters may add more.
 */
export const GLOBAL_EXCLUDED_PATH_RE =
  /\/(search|checkout|cart|account|login|register|wishlist|api|on\/demandware\.store|customer-service|store-locator|stores)(\/|$|\?)/i;

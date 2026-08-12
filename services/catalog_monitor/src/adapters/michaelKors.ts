import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

/**
 * michaelkors.com (Salesforce Commerce Cloud) exposes product-detail URLs in
 * two shapes observed in a sanitized capture of the site's product sitemap
 * (see test/fixtures/michael_kors/sitemap_products_1.xml):
 *   - legacy:  /{slug}/{style}.html
 *   - current: /product/{slug}/_/R-US_{style}
 * Both shapes are normalized to the same uppercase style code so the same
 * physical product is not double-counted if the sitemap lists it either way.
 */
const MK_HOSTS = new Set(['michaelkors.com', 'www.michaelkors.com']);

const MK_HTML_PATH_RE = /^\/([a-z0-9]+(?:-[a-z0-9]+)*)\/([a-z0-9-]+)\.html$/i;
const MK_RUS_PATH_RE = /^\/product\/([a-z0-9]+(?:-[a-z0-9]+)*)\/_\/R-US_([a-z0-9-]+)$/i;

function normalizeStyle(raw: string): string {
  return raw.trim().toUpperCase();
}

function parseHttpsUrl(url: string): URL | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== 'https:') return null;
  if (!MK_HOSTS.has(parsed.hostname.toLowerCase())) return null;
  return parsed;
}

const selectors: ProductSelectors = {
  title: '.product-name, h1.pdp-link, [data-test="product-name"]',
  price: '.price .sales .value, .product-price, [data-test="product-price"]',
  image: '.primary-images img, .pdp-carousel img',
  availability: '.availability-msg, [data-test="availability"]',
  category: '.breadcrumb li:last-child',
  inStockText: /in stock|available/i,
  outOfStockText: /out of stock|sold out|unavailable/i,
};

export const michaelKorsAdapter: BrandAdapter = {
  source: SOURCES.michael_kors_us,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parseHttpsUrl(url);
    if (!parsed) return false;
    if (GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname)) return false;
    return MK_HTML_PATH_RE.test(parsed.pathname) || MK_RUS_PATH_RE.test(parsed.pathname);
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parseHttpsUrl(url);
    if (!parsed) return null;
    const htmlMatch = MK_HTML_PATH_RE.exec(parsed.pathname);
    if (htmlMatch) return normalizeStyle(htmlMatch[2]!);
    const rusMatch = MK_RUS_PATH_RE.exec(parsed.pathname);
    if (rusMatch) return normalizeStyle(rusMatch[2]!);
    return null;
  },
};

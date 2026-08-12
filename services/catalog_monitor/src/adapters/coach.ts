import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

/**
 * coach.com product-detail URLs follow `/products/{slug}/{identifier}.html`,
 * confirmed against a sanitized capture of the site's product sitemap (see
 * test/fixtures/coach/sitemap_products_1.xml). The identifier segment is a
 * style/variant code such as `CEN52` or `CI032-B4YDT`; some variant
 * identifiers include percent-encoded components (e.g. a color qualifier
 * with a space). The older `/{slug}/{style}.html` shape (no `/products/`
 * prefix) is not present in the captured sitemap and is intentionally not
 * accepted.
 */
const COACH_HOSTS = new Set(['coach.com', 'www.coach.com']);

const COACH_PRODUCT_PATH_RE =
  /^\/products\/([a-z0-9]+(?:-[a-z0-9]+)*)\/((?:[a-z0-9+-]|%[0-9a-f]{2})+)\.html$/i;

function normalizeIdentifier(raw: string): string {
  let decoded: string;
  try {
    decoded = decodeURIComponent(raw);
  } catch {
    decoded = raw;
  }
  return decoded.trim().replace(/[+\s]+/g, '-').toUpperCase();
}

function parseHttpsUrl(url: string): URL | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== 'https:') return null;
  if (!COACH_HOSTS.has(parsed.hostname.toLowerCase())) return null;
  return parsed;
}

const selectors: ProductSelectors = {
  title: '.product-name, h1.pdp-title, [data-test="product-name"]',
  price: '.product-price .sales, .price .value, [data-test="product-price"]',
  image: '.product-primary-image img, .pdp-carousel img',
  availability: '.availability-msg, [data-test="availability"]',
  category: '.breadcrumb li:last-child',
  inStockText: /in stock|available/i,
  outOfStockText: /out of stock|sold out|unavailable/i,
};

export const coachAdapter: BrandAdapter = {
  source: SOURCES.coach_us,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parseHttpsUrl(url);
    if (!parsed) return false;
    if (GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname)) return false;
    return COACH_PRODUCT_PATH_RE.test(parsed.pathname);
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parseHttpsUrl(url);
    if (!parsed) return null;
    const match = COACH_PRODUCT_PATH_RE.exec(parsed.pathname);
    if (!match) return null;
    return normalizeIdentifier(match[2]!);
  },
};

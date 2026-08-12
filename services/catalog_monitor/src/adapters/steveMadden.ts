import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

/** Steve Madden US is a Shopify storefront with `/products/{handle}` PDPs. */
const STEVE_MADDEN_HOSTS = new Set(['stevemadden.com', 'www.stevemadden.com']);
const STEVE_MADDEN_PRODUCT_PATH_RE = /^\/products\/([a-z0-9]+(?:-[a-z0-9]+)*)\/?$/i;

function parseHttpsUrl(url: string): URL | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== 'https:') return null;
  if (!STEVE_MADDEN_HOSTS.has(parsed.hostname.toLowerCase())) return null;
  return parsed;
}

const selectors: ProductSelectors = {
  title: 'h1.product__title, h1[itemprop="name"], .product-single__title',
  price: '.price-item--sale, .price-item--regular, [itemprop="price"]',
  image: '.product__media img, .product-single__media img',
  availability: '.product-form__buttons, [data-product-availability]',
  category: '.breadcrumbs li:last-child, .breadcrumb li:last-child',
  inStockText: /add to (bag|cart)|in stock|available/i,
  outOfStockText: /out of stock|sold out|unavailable/i,
};

export const steveMaddenAdapter: BrandAdapter = {
  source: SOURCES.steve_madden_us,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parseHttpsUrl(url);
    if (!parsed) return false;
    if (GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname)) return false;
    return STEVE_MADDEN_PRODUCT_PATH_RE.test(parsed.pathname);
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parseHttpsUrl(url);
    if (!parsed) return null;
    const match = STEVE_MADDEN_PRODUCT_PATH_RE.exec(parsed.pathname);
    return match?.[1]?.toUpperCase() ?? null;
  },
};

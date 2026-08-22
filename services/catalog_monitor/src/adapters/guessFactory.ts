import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

const HOSTS = new Set(['guessfactory.com', 'www.guessfactory.com']);
const PRODUCT_PATH_RE =
  /^\/us\/en\/handbags\/(?:[a-z0-9-]+\/)+[a-z0-9]+(?:-[a-z0-9]+)+\.html$/i;
const IDENTIFIER_RE = /^(?=.*\d)[a-z0-9]+(?:-[a-z0-9]+)+$/i;

function parse(url: string): URL | null {
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:' || !HOSTS.has(parsed.hostname.toLowerCase())) return null;
    return parsed;
  } catch {
    return null;
  }
}

function identifier(pathname: string): string | null {
  const filename = pathname.split('/').at(-1);
  if (!filename?.toLowerCase().endsWith('.html')) return null;
  const value = filename.slice(0, -5);
  return IDENTIFIER_RE.test(value) ? value.toUpperCase() : null;
}

const selectors: ProductSelectors = {
  title: 'h1.product-name, h1.product-name__text, h1[itemprop="name"]',
  price: '.sales .value, .price .sales, [itemprop="price"]',
  image: '.product-detail .primary-images img, .product-carousel img',
  availability: '.availability, .availability-msg, [data-availability]',
  category: '.breadcrumb li:last-child, .breadcrumbs li:last-child',
  inStockText: /add to bag|in stock|available/i,
  outOfStockText: /out of stock|sold out|unavailable/i,
};

export const guessFactoryAdapter: BrandAdapter = {
  source: SOURCES.guess_factory_us,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parse(url);
    return parsed !== null && !GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname) && PRODUCT_PATH_RE.test(parsed.pathname) && identifier(parsed.pathname) !== null;
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parse(url);
    return parsed && PRODUCT_PATH_RE.test(parsed.pathname) ? identifier(parsed.pathname) : null;
  },
};

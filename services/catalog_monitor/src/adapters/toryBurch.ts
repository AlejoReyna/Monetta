import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

const HOSTS = new Set(['toryburch.com', 'www.toryburch.com']);
const PRODUCT_PATH_RE =
  /^\/en-us\/(?:handbags|wallets-card-cases)\/(?:[a-z0-9-]+\/)+([a-z0-9-]+)\/(\d+)\.html$/i;

function parse(url: string): URL | null {
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:' || !HOSTS.has(parsed.hostname.toLowerCase())) return null;
    return parsed;
  } catch {
    return null;
  }
}

const selectors: ProductSelectors = {
  title: 'h1.product-name, h1.product-title, h1[itemprop="name"]',
  price: '.price-sales, .product-price, [itemprop="price"]',
  image: '.product-primary-image img, .product-images img',
  availability: '.availability, .add-to-cart, [data-availability]',
  category: '.breadcrumb li:last-child, .breadcrumbs li:last-child',
  inStockText: /add to bag|in stock|available/i,
  outOfStockText: /sold out|out of stock|unavailable/i,
};

export const toryBurchAdapter: BrandAdapter = {
  source: SOURCES.tory_burch_us,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parse(url);
    return parsed !== null && !GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname) && PRODUCT_PATH_RE.test(parsed.pathname);
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parse(url);
    return parsed ? PRODUCT_PATH_RE.exec(parsed.pathname)?.[2] ?? null : null;
  },
};

import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

const HOSTS = new Set(['katespade.com', 'www.katespade.com']);
const PRODUCT_PATH_RE = /^\/products\/([a-z0-9]+(?:-[a-z0-9]+)*)\/([a-z0-9-]+)\.html$/i;
const BAG_OR_WALLET_RE =
  /(?:bag|tote|purse|wallet|card-case|crossbody|shoulder|satchel|clutch|hobo|backpack|wristlet|pochette)/i;

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
  price: '.sales .value, .product-price, [itemprop="price"]',
  image: '.primary-images img, .product-images img',
  availability: '.availability, .add-to-cart, [data-availability]',
  category: '.breadcrumb li:last-child, .breadcrumbs li:last-child',
  inStockText: /add to bag|in stock|available/i,
  outOfStockText: /almost gone|sold out|out of stock|unavailable/i,
};

export const kateSpadeAdapter: BrandAdapter = {
  source: SOURCES.kate_spade_us,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parse(url);
    if (!parsed || GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname)) return false;
    const match = PRODUCT_PATH_RE.exec(parsed.pathname);
    return match !== null && BAG_OR_WALLET_RE.test(match[1]!);
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parse(url);
    return parsed ? PRODUCT_PATH_RE.exec(parsed.pathname)?.[2]?.toUpperCase() ?? null : null;
  },
};

import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

const HOSTS = new Set(['marcjacobs.com', 'www.marcjacobs.com']);
const PRODUCT_PATH_RE = /^\/us-en\/([a-z0-9]+(?:-[a-z0-9]+)*)\/([a-z0-9-]+)\.html$/i;
const BAG_OR_WALLET_RE =
  /(?:bag|tote|snapshot|sack|purse|wallet|card-case|crossbody|shoulder|satchel|clutch|hobo|backpack|pochette)/i;

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
  title: 'h1.product-name, h1.product__name, h1[itemprop="name"]',
  price: '.price .sales, .product-price, [itemprop="price"]',
  image: '.product-primary-image img, .product-detail img',
  availability: '.availability, .product-availability, .add-to-cart',
  category: '.breadcrumb li:last-child, .breadcrumbs li:last-child',
  inStockText: /add to (bag|cart)|in stock|available/i,
  outOfStockText: /out of stock|sold out|unavailable/i,
};

export const marcJacobsAdapter: BrandAdapter = {
  source: SOURCES.marc_jacobs_us,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parse(url);
    if (!parsed || GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname)) return false;
    const match = PRODUCT_PATH_RE.exec(parsed.pathname);
    return match !== null && BAG_OR_WALLET_RE.test(match[1]!);
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parse(url);
    if (!parsed) return null;
    const match = PRODUCT_PATH_RE.exec(parsed.pathname);
    return match?.[2]?.split('-')[0]?.toUpperCase() ?? null;
  },
};

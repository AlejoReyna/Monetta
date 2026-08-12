import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

/**
 * GUESS US product pages are locale-prefixed and end in a color/style ID:
 * `/en-us/.../{style-color}.html` (with `/us/en/` retained for older US
 * routes). The locale requirement is the important market boundary: MX and
 * other global routes are never accepted even when they use the same host.
 */
const GUESS_HOSTS = new Set(['guess.com', 'www.guess.com']);
const GUESS_PRODUCT_PATH_RE =
  /^\/(?:en-us|us\/en)\/(?:[a-z0-9-]+\/)+[a-z0-9]+(?:-[a-z0-9]+)+\.html$/i;
const GUESS_IDENTIFIER_RE = /^(?=.*\d)[a-z0-9]+(?:-[a-z0-9]+)+$/i;

function parseHttpsUrl(url: string): URL | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== 'https:') return null;
  if (!GUESS_HOSTS.has(parsed.hostname.toLowerCase())) return null;
  return parsed;
}

function identifierFromPath(pathname: string): string | null {
  const filename = pathname.split('/').at(-1);
  if (filename === undefined || !filename.toLowerCase().endsWith('.html')) return null;
  const identifier = filename.slice(0, -5);
  return GUESS_IDENTIFIER_RE.test(identifier) ? identifier.toUpperCase() : null;
}

const selectors: ProductSelectors = {
  title: 'h1.product-name, h1.product-name__text, h1[itemprop="name"]',
  price: '.sales .value, .price .sales, [itemprop="price"]',
  image: '.product-detail .primary-images img, .product-carousel img',
  availability: '.availability, .availability-msg, [data-availability]',
  category: '.breadcrumb li:last-child, .breadcrumbs li:last-child',
  inStockText: /in stock|available|add to bag/i,
  outOfStockText: /out of stock|sold out|unavailable/i,
};

export const guessAdapter: BrandAdapter = {
  source: SOURCES.guess_us,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parseHttpsUrl(url);
    if (!parsed) return false;
    if (GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname)) return false;
    return (
      GUESS_PRODUCT_PATH_RE.test(parsed.pathname) && identifierFromPath(parsed.pathname) !== null
    );
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parseHttpsUrl(url);
    if (!parsed || !GUESS_PRODUCT_PATH_RE.test(parsed.pathname)) return null;
    return identifierFromPath(parsed.pathname);
  },
};

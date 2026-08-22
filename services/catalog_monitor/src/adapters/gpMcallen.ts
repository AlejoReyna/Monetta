import { SOURCES } from '../domain/types.js';
import { GLOBAL_EXCLUDED_PATH_RE, type BrandAdapter } from './types.js';
import type { ProductSelectors } from '../parsing/selectors.js';

const HOSTS = new Set(['gpmcallen.com', 'www.gpmcallen.com']);
const PRODUCT_PATH_RE = /^\/([a-z0-9]+(?:-[a-z0-9]+)*)\.html$/i;
const NON_PRODUCT_SLUGS = new Set([
  'new-arrivals',
  'ladies-perfumes',
  'mens-colognes',
  'ladies-sets',
  'mens-sets',
  'kids-perfumes',
  'unisex',
  'blog',
]);

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
  title: 'h1.page-title span, h1.page-title, h1[itemprop="name"]',
  price: '.product-info-price .price, .price-box .price, [itemprop="price"]',
  image: '.fotorama__stage img, .gallery-placeholder img, .product.media img',
  availability: '.stock.available, .stock.unavailable, .product-add-form',
  category: '.breadcrumbs li:last-child, .items > li:last-child',
  inStockText: /in stock|add to cart|available/i,
  outOfStockText: /out of stock|sold out|unavailable/i,
};

export const gpMcallenAdapter: BrandAdapter = {
  source: SOURCES.gp_mcallen_perfumes,
  selectors,
  isProductUrl(url: string): boolean {
    const parsed = parse(url);
    if (!parsed || GLOBAL_EXCLUDED_PATH_RE.test(parsed.pathname)) return false;
    const match = PRODUCT_PATH_RE.exec(parsed.pathname);
    return match !== null && !NON_PRODUCT_SLUGS.has(match[1]!.toLowerCase());
  },
  externalIdFromUrl(url: string): string | null {
    const parsed = parse(url);
    if (!parsed) return null;
    const slug = PRODUCT_PATH_RE.exec(parsed.pathname)?.[1];
    return slug && !NON_PRODUCT_SLUGS.has(slug.toLowerCase()) ? slug.toUpperCase() : null;
  },
};

// Catalog access for the browser build. The JSON is the dated fixture built
// by scripts/build-fixtures.mjs; nothing here talks to Shopify.
import data from '../data/catalog.json';
import { searchProducts } from './search.js';

export const catalog = data;
export const products = data.products;

const byHandle = new Map(products.map((product) => [product.handle, product]));
const byId = new Map(products.map((product) => [product.id, product]));
const variants = new Map(products.flatMap((product) => product.variants.map((variant) => [variant.id, { product, variant }])));
const collections = new Map(data.collections.map((collection) => [collection.handle, collection]));

export const ALL_COLLECTION = {
  handle: 'all',
  title: 'Catálogo',
  kind: 'all',
  productIds: products.map((product) => product.id),
};

export function productByHandle(handle) {
  return byHandle.get(handle) ?? null;
}

export function productById(id) {
  return byId.get(Number(id)) ?? null;
}

export function findVariant(variantId) {
  return variants.get(Number(variantId)) ?? null;
}

export function collectionByHandle(handle) {
  if (handle === 'all') return ALL_COLLECTION;
  return collections.get(handle) ?? null;
}

/** Products in Shopify's collection order ("Destacados"). */
export function collectionProducts(collection) {
  return collection.productIds.map((id) => byId.get(id)).filter(Boolean);
}

export function newestProducts(limit = 8) {
  return [...products].sort((a, b) => b.createdAt.localeCompare(a.createdAt)).slice(0, limit);
}

export function moreFromBrand(product, limit = 8) {
  return products.filter((candidate) => candidate.brand === product.brand && candidate.id !== product.id).slice(0, limit);
}

export function search(query) {
  return searchProducts(products, query);
}

/** Home "Selección Monetta": an owner-curated collection in production. */
export const FEATURED_HANDLES = [
  'bolso-coach-station-tote-bag-negro',
  'reloj-michael-kors-lennox-pave-gold',
  'bolsa-guess-tote-cafe-monograma-dijes',
  'bolso-tommy-hilfiger-crossbody-beige-y-rojo',
];

export function featuredProducts() {
  return FEATURED_HANDLES.map(productByHandle).filter(Boolean);
}

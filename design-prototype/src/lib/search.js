// Local product search for the prototype: folded, accent-insensitive prefix
// matching over title, brand and canonical facets. Production uses Shopify
// search and predictive search; this only stands in for their responses.
import {
  CATEGORY_LABELS,
  CATEGORY_PLURALS,
  COLOR_LABELS,
  PATTERN_LABELS,
  SILHOUETTE_LABELS,
  deliveryOf,
  DELIVERY_LABELS,
  fold,
  isInStock,
} from './facets.js';

const SYNONYMS = {
  bolso: 'bolsa',
  bolsos: 'bolsa',
  bolsas: 'bolsa',
  bag: 'bolsa',
  carteras: 'cartera',
  billetera: 'cartera',
  billeteras: 'cartera',
  wallet: 'cartera',
  relojes: 'reloj',
  watch: 'reloj',
  hombro: 'shoulder',
  bandolera: 'crossbody',
  crossbodys: 'crossbody',
  crossbosy: 'crossbody',
  totes: 'tote',
  marron: 'cafe',
  brown: 'cafe',
  black: 'negro',
  negra: 'negro',
  blanca: 'blanco',
  roja: 'rojo',
  mk: 'michael',
  tarjeteros: 'tarjetero',
};

function stem(token) {
  if (SYNONYMS[token]) return SYNONYMS[token];
  if (token.length > 4 && token.endsWith('es') && !token.endsWith('ees')) return SYNONYMS[token.slice(0, -2)] ?? token.slice(0, -2);
  if (token.length > 3 && token.endsWith('s')) return SYNONYMS[token.slice(0, -1)] ?? token.slice(0, -1);
  return token;
}

export function tokenize(text) {
  return fold(text)
    .split(/[^a-z0-9]+/)
    .filter(Boolean)
    .map(stem);
}

const indexCache = new WeakMap();

function indexOf(product) {
  let entry = indexCache.get(product);
  if (entry) return entry;
  const facetText = [
    CATEGORY_LABELS[product.category],
    CATEGORY_PLURALS[product.category],
    product.silhouette ? SILHOUETTE_LABELS[product.silhouette] : '',
    product.silhouette === 'shoulder' ? 'hombro' : '',
    ...product.colors.map((slug) => COLOR_LABELS[slug]),
    ...product.patterns.map((slug) => PATTERN_LABELS[slug]),
    ...product.tags,
    product.productType,
    deliveryOf(product) ? DELIVERY_LABELS[deliveryOf(product)] : '',
  ].join(' ');
  entry = {
    brand: tokenize(product.brandLabel),
    title: tokenize(product.title),
    facets: tokenize(facetText),
    phrase: fold(product.title),
  };
  indexCache.set(product, entry);
  return entry;
}

function bestMatch(tokens, query, exactWeight, prefixWeight) {
  let best = 0;
  for (const token of tokens) {
    if (token === query) return exactWeight;
    if (token.startsWith(query)) best = prefixWeight;
  }
  return best;
}

/** Relevance score, or 0 when any query word matches nothing. */
export function scoreProduct(product, queryTokens, phrase = '') {
  if (!queryTokens.length) return 0;
  const index = indexOf(product);
  let score = 0;
  for (const query of queryTokens) {
    const value = Math.max(
      bestMatch(index.brand, query, 6, 4),
      bestMatch(index.title, query, 3, 2),
      bestMatch(index.facets, query, 1.5, 1),
    );
    if (value === 0) return 0;
    score += value;
  }
  if (phrase && index.phrase.includes(phrase)) score += 3;
  if (isInStock(product)) score += 0.5;
  return score;
}

export function searchProducts(products, query) {
  const queryTokens = tokenize(query);
  const phrase = fold(query);
  return products
    .map((product) => ({ product, score: scoreProduct(product, queryTokens, phrase) }))
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score || b.product.createdAt.localeCompare(a.product.createdAt))
    .map((entry) => entry.product);
}

/** Query completions that lead somewhere, with their result counts. */
export function suggestTerms(products, query, limit = 5) {
  const queryTokens = tokenize(query);
  if (!queryTokens.length) return [];
  const candidates = new Set();
  for (const product of products) {
    candidates.add(product.brandLabel);
    candidates.add(CATEGORY_PLURALS[product.category]);
    if (product.silhouette) {
      const style = product.silhouette === 'shoulder' ? 'de hombro' : SILHOUETTE_LABELS[product.silhouette].toLowerCase();
      candidates.add(`Bolsa ${style}`);
    }
    for (const pattern of product.patterns) candidates.add(PATTERN_LABELS[pattern]);
    candidates.add(`${CATEGORY_LABELS[product.category]} ${product.brandLabel}`);
  }
  const suggestions = [];
  for (const term of candidates) {
    const termTokens = tokenize(term);
    const matches = queryTokens.every((query) => termTokens.some((token) => token.startsWith(query)));
    if (!matches) continue;
    const count = searchProducts(products, term).length;
    if (count > 0) suggestions.push({ term, count });
  }
  return suggestions
    .sort((a, b) => a.term.length - b.term.length || b.count - a.count)
    .slice(0, limit);
}

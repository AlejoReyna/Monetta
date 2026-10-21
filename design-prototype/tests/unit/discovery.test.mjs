// Discovery behaviour: filter URLs, facet counts, sorting, paging and search.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import {
  PAGE_SIZE,
  activeChips,
  applyFilters,
  clearFilters,
  facetOptions,
  parseState,
  runQuery,
  serializeState,
  sortProducts,
  withPrice,
  withSort,
  withValue,
} from '../../src/lib/filters.js';
import { hasReliableSwatches, swatchFor } from '../../src/lib/facets.js';
import { searchProducts, suggestTerms, tokenize } from '../../src/lib/search.js';

const catalog = JSON.parse(readFileSync(new URL('../../src/data/catalog.json', import.meta.url), 'utf8'));
const products = catalog.products;
const collection = (handle) => {
  const entry = catalog.collections.find((item) => item.handle === handle);
  return entry.productIds.map((id) => products.find((product) => product.id === id));
};

test('Shopify-style filter URLs parse and serialize back unchanged', () => {
  const query =
    'filter.v.availability=1&filter.p.m.custom.estilo=Satchel&filter.p.m.custom.marca=Guess&filter.p.m.custom.marca=Steve+Madden&filter.v.price.gte=1000&filter.v.price.lte=2500&sort_by=price-ascending&page=2';
  const state = parseState(new URLSearchParams(query));
  assert.deepEqual([...state.selected.brand], ['Guess', 'Steve Madden']);
  assert.equal(state.priceMin, 1000);
  assert.equal(state.priceMax, 2500);
  assert.equal(state.sort, 'price-ascending');
  assert.equal(state.page, 2);
  assert.equal(serializeState(state).toString(), query);
});

test('search URLs keep q and type, and default sort is omitted', () => {
  const state = parseState(new URLSearchParams('q=bolsa+negra&sort_by=relevance'), { mode: 'search' });
  assert.equal(state.sort, 'relevance');
  assert.equal(serializeState(state).toString(), 'q=bolsa+negra&type=product');
});

test('values combine with OR inside a facet and AND across facets', () => {
  const bags = collection('guess');
  const guess = withValue(parseState(new URLSearchParams()), 'brand', 'Guess', true);
  const guessOrMadden = withValue(guess, 'brand', 'Steve Madden', true);
  const satchels = withValue(guessOrMadden, 'style', 'Satchel', true);
  const countGuess = applyFilters(bags, guess).length;
  const countBoth = applyFilters(bags, guessOrMadden).length;
  const countSatchel = applyFilters(bags, satchels).length;
  assert.ok(countBoth > countGuess, 'adding a brand widens the result');
  assert.ok(countSatchel < countBoth, 'adding a style narrows the result');
  for (const product of applyFilters(bags, satchels)) {
    assert.ok(['Guess', 'Steve Madden'].includes(product.brandLabel));
    assert.equal(product.silhouette, 'satchel');
  }
});

test('facet counts answer "how many if I add this", excluding the facet itself', () => {
  const bags = collection('guess');
  const state = withValue(parseState(new URLSearchParams()), 'brand', 'Coach', true);
  const brand = facetOptions(bags, state).find((facet) => facet.id === 'brand');
  const guess = brand.options.find((option) => option.value === 'Guess');
  assert.equal(guess.count, bags.filter((product) => product.brandLabel === 'Guess').length);
  const style = facetOptions(bags, state).find((facet) => facet.id === 'style');
  const total = style.options.reduce((sum, option) => sum + option.count, 0);
  assert.ok(total <= applyFilters(bags, state).length, 'style counts stay within the Coach scope');
});

test('price range keeps any product with a variant inside it', () => {
  const state = withPrice(parseState(new URLSearchParams()), 3000, 4000);
  const matches = applyFilters(products, state);
  assert.ok(matches.length > 0);
  for (const product of matches) {
    assert.ok(product.variants.some((variant) => Number(variant.price) >= 3000 && Number(variant.price) <= 4000));
  }
  const swapped = withPrice(parseState(new URLSearchParams()), 4000, 3000);
  assert.equal(swapped.priceMin, 3000);
});

test('sorting by price and newest is stable and correct', () => {
  const ascending = sortProducts(products, 'price-ascending');
  const lowest = (product) => Math.min(...product.variants.map((variant) => Number(variant.price)));
  for (let index = 1; index < ascending.length; index += 1) assert.ok(lowest(ascending[index - 1]) <= lowest(ascending[index]));
  const newest = sortProducts(products, 'created-descending');
  assert.ok(newest[0].createdAt >= newest[newest.length - 1].createdAt);
  const manual = sortProducts(collection('guess'), 'manual');
  assert.deepEqual(manual, collection('guess'), 'Destacados keeps Shopify collection order');
});

test('changing filters or sort returns to page one; clearing keeps the query and sort', () => {
  let state = parseState(new URLSearchParams('q=coach&page=3&sort_by=price-descending'), { mode: 'search' });
  state = withValue(state, 'availability', '1', true);
  assert.equal(state.page, 1);
  state = withSort({ ...state, page: 4 }, 'created-descending');
  assert.equal(state.page, 1);
  const cleared = clearFilters(withPrice(state, 1000, null));
  assert.equal(cleared.q, 'coach');
  assert.equal(cleared.sort, 'created-descending');
  assert.equal(Object.keys(cleared.selected).length, 0);
  assert.equal(cleared.priceMin, null);
});

test('each active chip removes exactly its own value', () => {
  let state = withValue(parseState(new URLSearchParams()), 'brand', 'Coach', true);
  state = withValue(state, 'color', 'Negro', true);
  state = withPrice(state, null, 2000);
  const chips = activeChips(state);
  assert.deepEqual(
    chips.map((chip) => chip.label),
    ['Coach', 'Negro', 'Hasta $2,000'],
  );
  const withoutCoach = serializeState(chips[0].next).toString();
  assert.ok(!withoutCoach.includes('Coach') && withoutCoach.includes('Negro'));
});

test('load more pages through results in steps of PAGE_SIZE', () => {
  const state = parseState(new URLSearchParams());
  const first = runQuery(products, state);
  assert.equal(first.visible.length, Math.min(PAGE_SIZE, products.length));
  assert.equal(first.hasMore, products.length > PAGE_SIZE);
  const all = runQuery(products, { ...state, page: 99 });
  assert.equal(all.visible.length, products.length);
  assert.equal(all.hasMore, false);
});

test('search is accent-, plural- and synonym-tolerant and ranks brand matches first', () => {
  assert.deepEqual(tokenize('Bolsos CAFÉ'), ['bolsa', 'cafe']);
  const cafe = searchProducts(products, 'cafe');
  assert.ok(cafe.length > 0 && cafe.every((product) => /caf[eé]/i.test(`${product.title} ${product.tags.join(' ')} ${product.colors.join(' ')}`)));
  assert.equal(searchProducts(products, 'bolsos').length, searchProducts(products, 'bolsa').length);
  const mk = searchProducts(products, 'mich');
  assert.ok(mk.length > 0);
  assert.equal(mk[0].brandLabel, 'Michael Kors');
  assert.deepEqual(searchProducts(products, 'perfume dior'), []);
});

test('suggestions only offer terms that lead to results', () => {
  const terms = suggestTerms(products, 'cro');
  assert.ok(terms.length > 0);
  for (const term of terms) {
    assert.ok(term.count > 0);
    assert.ok(/cro/i.test(term.term));
  }
  assert.deepEqual(suggestTerms(products, 'zzz'), []);
});

test('swatches only for reliable single colours, never for bicolours', () => {
  assert.equal(swatchFor('Negro').slug, 'negro');
  assert.equal(swatchFor('Marrón').slug, 'cafe');
  assert.equal(swatchFor('Café/Dorado'), null);
  const madden = products.find((product) => product.handle === 'bolso-steve-madden-crossbody-3');
  assert.equal(hasReliableSwatches(madden), true);
  const coach = products.find((product) => product.handle === 'bolso-coach-shoulder-negro-rectangular');
  assert.equal(hasReliableSwatches(coach), false);
});

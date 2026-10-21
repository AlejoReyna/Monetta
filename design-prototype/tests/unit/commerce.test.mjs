// Money and cart behaviour: integer centavos, exact variants, limits.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { addToCart, cartTotals, removeLine, setLineQuantity } from '../../src/lib/cart.js';
import { discountPercent, formatCents, formatMoney, toCents } from '../../src/lib/money.js';

const catalog = JSON.parse(readFileSync(new URL('../../src/data/catalog.json', import.meta.url), 'utf8'));
const byHandle = (handle) => catalog.products.find((product) => product.handle === handle);
const resolve = (line) => {
  for (const product of catalog.products) {
    const variant = product.variants.find((entry) => entry.id === line.variantId);
    if (variant) return { product, variant };
  }
  return null;
};

test('money parses decimal strings into exact centavos and formats MXN labels', () => {
  assert.equal(toCents('1299.00'), 129900);
  assert.equal(toCents('5259.15'), 525915);
  assert.equal(toCents('0.1'), 10);
  assert.equal(toCents(null), null);
  assert.throws(() => toCents('12,99'));
  assert.equal(formatCents(525915), '$5,259.15');
  assert.equal(formatCents(129900, { code: true }), '$1,299.00 MXN');
  assert.equal(formatMoney('10926.03'), '$10,926.03');
});

test('a discount appears only for a genuine compare-at price', () => {
  assert.equal(discountPercent('1704.00', '1899.00'), 10);
  assert.equal(discountPercent('1299.00', '1299.00'), null);
  assert.equal(discountPercent('1299.00', null), null);
  assert.equal(discountPercent('1299.00', '999.00'), null);
});

test('adding the same exact variant raises its quantity; another colour is its own line', () => {
  const coach = byHandle('bolso-coach-shoulder-negro-rectangular');
  const arena = coach.variants.find((variant) => variant.title === 'Arena/Blanco Signature Canvas');
  const cafe = coach.variants.find((variant) => variant.title === 'Café');
  let result = addToCart([], coach, arena, 1);
  assert.equal(result.status, 'added');
  result = addToCart(result.lines, coach, arena, 2);
  result = addToCart(result.lines, coach, cafe, 1);
  assert.deepEqual(
    result.lines.map((line) => [line.variantId, line.quantity]),
    [
      [arena.id, 3],
      [cafe.id, 1],
    ],
  );
});

test('a sold-out variant is refused and never substituted', () => {
  const coach = byHandle('bolso-coach-shoulder-negro-rectangular');
  const soldOut = coach.variants.find((variant) => !variant.available);
  assert.ok(soldOut, 'fixture keeps a real sold-out variant');
  const result = addToCart([], coach, soldOut, 1);
  assert.equal(result.status, 'soldOut');
  assert.deepEqual(result.lines, []);
});

test('an inventory limit caps additions and quantity changes', () => {
  const wallet = byHandle('cartera-guess-compacta-negro');
  const variant = wallet.variants[0];
  assert.equal(variant.inventoryLimit, 2);
  let result = addToCart([], wallet, variant, 1);
  result = addToCart(result.lines, wallet, variant, 5);
  assert.equal(result.status, 'limited');
  assert.equal(result.lines[0].quantity, 2);
  const again = addToCart(result.lines, wallet, variant, 1);
  assert.equal(again.status, 'limited');
  assert.equal(again.added, 0);
  const set = setLineQuantity(result.lines, variant, 9);
  assert.equal(set.limited, true);
  assert.equal(set.lines[0].quantity, 2);
});

test('quantity zero and removal drop the line; totals are summed in centavos', () => {
  const watch = byHandle('reloj-coach-sammy-gold-white');
  const variant = watch.variants[0];
  let lines = addToCart([], watch, variant, 3).lines;
  assert.equal(cartTotals(lines, resolve).subtotal, 3 * 525915);
  assert.equal(formatCents(cartTotals(lines, resolve).subtotal), '$15,777.45');
  lines = setLineQuantity(lines, variant, 0).lines;
  assert.equal(lines.length, 0);
  const sale = byHandle('bolso-guess-crossbody-negro-1');
  lines = addToCart([], sale, sale.variants[0], 2).lines;
  const totals = cartTotals(lines, resolve);
  assert.equal(totals.count, 2);
  assert.equal(totals.compareAtSavings, 2 * (189900 - 170400));
  assert.deepEqual(removeLine(lines, sale.variants[0].id), []);
});

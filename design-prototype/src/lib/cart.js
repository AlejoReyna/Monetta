// Local demo cart. A line is keyed by its exact variant id: a colour is never
// substituted, and adding the same variant again only raises its quantity.
import { toCents } from './money.js';

export const MAX_LINE_QUANTITY = 99;

function limitFor(variant) {
  return Math.min(variant.inventoryLimit ?? MAX_LINE_QUANTITY, MAX_LINE_QUANTITY);
}

/**
 * Adds [quantity] of an exact variant. Returns the new lines plus what
 * happened, so the UI can explain a sold-out or limited result.
 */
export function addToCart(lines, product, variant, quantity = 1) {
  if (!variant || !variant.available) return { status: 'soldOut', lines, added: 0 };
  const existing = lines.find((line) => line.variantId === variant.id);
  const current = existing?.quantity ?? 0;
  const limit = limitFor(variant);
  const target = Math.min(current + Math.max(1, quantity), limit);
  const added = target - current;
  if (added <= 0) return { status: 'limited', lines, added: 0, limit };
  const next = existing
    ? lines.map((line) => (line.variantId === variant.id ? { ...line, quantity: target } : line))
    : [...lines, { variantId: variant.id, handle: product.handle, quantity: target }];
  return { status: added < quantity ? 'limited' : 'added', lines: next, added, limit };
}

export function setLineQuantity(lines, variant, quantity) {
  const limit = limitFor(variant);
  const wanted = Math.max(0, Math.floor(quantity));
  const target = Math.min(wanted, limit);
  const next = target === 0
    ? lines.filter((line) => line.variantId !== variant.id)
    : lines.map((line) => (line.variantId === variant.id ? { ...line, quantity: target } : line));
  return { lines: next, limited: wanted > limit, limit };
}

export function removeLine(lines, variantId) {
  return lines.filter((line) => line.variantId !== variantId);
}

/** Totals in centavos. [resolve] maps a line to its product and variant. */
export function cartTotals(lines, resolve) {
  let count = 0;
  let subtotal = 0;
  let compareAtSavings = 0;
  for (const line of lines) {
    const found = resolve(line);
    if (!found) continue;
    const price = toCents(found.variant.price);
    const compareAt = toCents(found.variant.compareAtPrice);
    count += line.quantity;
    subtotal += price * line.quantity;
    if (compareAt && compareAt > price) compareAtSavings += (compareAt - price) * line.quantity;
  }
  return { count, subtotal, compareAtSavings };
}

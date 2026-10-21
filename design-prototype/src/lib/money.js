// Money as integer centavos. Shopify sends decimal strings ("1299.00"); totals
// are summed as integers so no floating-point drift reaches a price label.

export function toCents(decimal) {
  if (decimal === null || decimal === undefined || decimal === '') return null;
  const match = String(decimal).trim().match(/^(-?)(\d+)(?:\.(\d{1,2}))?$/);
  if (!match) throw new Error(`Invalid money amount: ${decimal}`);
  const [, sign, pesos, centavos = '0'] = match;
  const cents = Number(pesos) * 100 + Number(centavos.padEnd(2, '0'));
  return sign ? -cents : cents;
}

/** "$1,299.00", or "$1,299.00 MXN" with { code: true }. */
export function formatCents(cents, { code = false } = {}) {
  const negative = cents < 0;
  const absolute = Math.abs(cents);
  const pesos = Math.floor(absolute / 100).toLocaleString('en-US');
  const centavos = String(absolute % 100).padStart(2, '0');
  return `${negative ? '−' : ''}$${pesos}.${centavos}${code ? ' MXN' : ''}`;
}

export function formatMoney(decimal, options) {
  const cents = toCents(decimal);
  return cents === null ? '' : formatCents(cents, options);
}

/** Whole-percent discount of a genuine compare-at price, else null. */
export function discountPercent(price, compareAt) {
  const current = toCents(price);
  const before = toCents(compareAt);
  if (current === null || before === null || before <= current) return null;
  return Math.round(((before - current) / before) * 100);
}

export function plural(count, one, many) {
  return `${count} ${count === 1 ? one : many}`;
}

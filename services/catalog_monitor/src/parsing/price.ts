/**
 * USD price parsing with no locale ambiguity.
 *
 * The target sites are US-market storefronts, so we accept exactly the US
 * grouping convention (`,` groups thousands, `.` is the decimal point) and
 * reject anything that could plausibly be a different locale's number
 * (`1.234,56`) rather than guess. A wrong "close enough" price is worse than
 * a missing one, because it silently corrupts a research listing.
 */
const US_PRICE_RE = /^(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{2})?$/;

export function parsePriceUsd(raw: string | number | null | undefined): number | null {
  if (raw === null || raw === undefined) return null;
  if (typeof raw === 'number') {
    return Number.isFinite(raw) && raw >= 0 ? round2(raw) : null;
  }

  let text = raw.trim();
  if (text === '') return null;

  // Strip a leading/trailing currency marker. Reject non-USD markers outright
  // rather than parsing the number and hoping the caller checked the currency
  // separately — a "€99.00" must never become priceUsd: 99.
  const currencyMarkerRe = /^(us\$|usd\s*\$?|\$)\s*|\s*(usd)$/gi;
  const hadUsdMarker = /\$|usd/i.test(text);
  const strippedOfOther = /[€£¥₹]/.test(text);
  if (strippedOfOther) return null;

  text = text.replace(currencyMarkerRe, '').trim();
  if (text === '') return null;
  if (!hadUsdMarker) {
    // No currency symbol at all — still fine (schema.org `price` is often a
    // bare number with `priceCurrency` given separately by the caller), but
    // we still require it to look like a plain US-formatted number.
  }

  if (!US_PRICE_RE.test(text)) return null;

  const numeric = Number.parseFloat(text.replace(/,/g, ''));
  if (!Number.isFinite(numeric) || numeric < 0) return null;
  return round2(numeric);
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

import type { BrandAdapter } from '../adapters/types.js';

export type MarketGuardFailure = 'wrong_market' | 'invalid_final_url';

export type MarketGuardResult =
  | { readonly ok: true; readonly finalUrl: string }
  | { readonly ok: false; readonly reason: MarketGuardFailure };

/**
 * Ensures that a page fetched for a US source is still a product page on the
 * source's US host after redirects. A regional page must be rejected before
 * parsing; otherwise its currency/content can be mislabeled as US data.
 */
export function validateFetchedMarket(
  adapter: BrandAdapter,
  requestedUrl: string,
  finalUrl: string | undefined,
): MarketGuardResult {
  const resolvedFinalUrl = finalUrl ?? requestedUrl;

  let parsed: URL;
  try {
    parsed = new URL(resolvedFinalUrl);
  } catch {
    return { ok: false, reason: 'invalid_final_url' };
  }

  if (parsed.protocol !== 'https:') {
    return { ok: false, reason: 'wrong_market' };
  }

  const hostname = parsed.hostname.toLowerCase();
  const allowed = adapter.source.allowedHosts.some((host) => host.toLowerCase() === hostname);
  if (!allowed || !adapter.isProductUrl(resolvedFinalUrl)) {
    return { ok: false, reason: 'wrong_market' };
  }

  return { ok: true, finalUrl: resolvedFinalUrl };
}

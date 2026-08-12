import { extractProductFromJsonLd } from './jsonld.js';
import { extractProductFromMetadata } from './metadata.js';
import { extractProductFromSelectors, type ProductSelectors } from './selectors.js';
import { hasAllRequiredFields, type ExtractedProduct } from '../domain/types.js';

export type ExtractionMethod = 'jsonld' | 'metadata' | 'selectors' | 'none';

export interface ExtractionResult {
  readonly product: ExtractedProduct | null;
  readonly method: ExtractionMethod;
  /** True once a tier produced a candidate with every required field filled. */
  readonly complete: boolean;
}

/**
 * Runs the four-tier extraction priority from the spec: JSON-LD, then Open
 * Graph/product metadata, then adapter-specific selectors. Playwright
 * rendering is a separate, heavier fallback orchestrated by the crawl runner
 * (it needs a browser, not just an HTML string) — this function only reports
 * `complete: false` so the caller knows to consider it.
 *
 * Each tier is tried in full even if an earlier tier produced a partial
 * result, and the first tier to produce a *complete* record wins. If no tier
 * is complete, the richest partial result is returned so the caller can
 * decide whether to merge it into a Playwright-rendered pass rather than
 * discard useful fields.
 */
export function extractProduct(
  html: string,
  params: {
    readonly canonicalUrl: string;
    readonly externalId: string;
    readonly fallbackBrand: string;
    readonly selectors: ProductSelectors;
  },
): ExtractionResult {
  const tiers: { method: ExtractionMethod; run: () => Omit<ExtractedProduct, 'externalId' | 'canonicalUrl'> | null }[] = [
    { method: 'jsonld', run: () => extractProductFromJsonLd(html, params.fallbackBrand) },
    { method: 'metadata', run: () => extractProductFromMetadata(html, params.fallbackBrand) },
    {
      method: 'selectors',
      run: () => extractProductFromSelectors(html, params.selectors, params.fallbackBrand),
    },
  ];

  let richest: ExtractedProduct | null = null;
  let richestMethod: ExtractionMethod = 'none';
  let richestFieldCount = -1;

  for (const tier of tiers) {
    const partial = tier.run();
    if (!partial) continue;
    const candidate: ExtractedProduct = {
      externalId: params.externalId,
      canonicalUrl: params.canonicalUrl,
      ...partial,
    };
    if (hasAllRequiredFields(candidate)) {
      return { product: candidate, method: tier.method, complete: true };
    }
    const fieldCount = countFilledFields(candidate);
    if (fieldCount > richestFieldCount) {
      richest = candidate;
      richestMethod = tier.method;
      richestFieldCount = fieldCount;
    }
  }

  return { product: richest, method: richestMethod, complete: false };
}

function countFilledFields(product: ExtractedProduct): number {
  return Object.values(product).filter((v) => v !== null && v !== '' && v !== undefined).length;
}

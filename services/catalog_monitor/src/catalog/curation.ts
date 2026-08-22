import { SOURCE_IDS, SOURCES, type SourceId } from '../domain/types.js';
import type { PresentedCatalogProduct } from './curatedUsCatalog.js';

export interface CatalogCurationPolicy {
  readonly fashionItemsPerSource: number;
  readonly perfumeItemsPerSource: number;
  readonly maximumItems: number;
}

export const DEFAULT_CURATION_POLICY: CatalogCurationPolicy = {
  fashionItemsPerSource: 8,
  perfumeItemsPerSource: 12,
  maximumItems: 52,
};

const FASHION_TERMS =
  /\b(bag|handbag|tote|wallet|crossbody|satchel|purse|clutch|hobo|backpack|card case|wristlet|pochette|shoulder)\b/i;
const PERFUME_TERMS =
  /\b(perfume|parfum|cologne|fragrance|eau de|edp|edt|extrait|spray)\b/i;

function eligible(record: PresentedCatalogProduct): boolean {
  if (record.availability === 'outOfStock') return false;
  if (record.priceUsd === null || record.priceUsd <= 0) return false;
  const text = `${record.title} ${record.category ?? ''}`;
  return SOURCES[record.sourceId].vertical === 'perfumes'
    ? PERFUME_TERMS.test(text)
    : FASHION_TERMS.test(text);
}

function score(record: PresentedCatalogProduct): number {
  let value = 0;
  if (record.availability === 'inStock') value += 100;
  if (record.imageUrl !== null) value += 30;
  if ((record.variants ?? []).some((variant) => variant.availability === 'inStock')) value += 15;
  if (record.dataOrigin === 'live_crawl') value += 10;

  const vertical = SOURCES[record.sourceId].vertical;
  if (vertical === 'perfumes' && record.priceUsd! >= 20 && record.priceUsd! <= 200) value += 8;
  if (vertical === 'bags_wallets' && record.priceUsd! >= 60 && record.priceUsd! <= 800) value += 8;
  return value;
}

function compareCandidates(a: PresentedCatalogProduct, b: PresentedCatalogProduct): number {
  const scoreDifference = score(b) - score(a);
  if (scoreDifference !== 0) return scoreDifference;
  const freshnessDifference = b.lastSeenAt.getTime() - a.lastSeenAt.getTime();
  if (freshnessDifference !== 0) return freshnessDifference;
  return `${a.sourceId}:${a.externalId}`.localeCompare(`${b.sourceId}:${b.externalId}`);
}

/**
 * Keeps a compact, varied storefront feed instead of exposing every product
 * a merchant publishes. The round-robin pass prevents one large brand from
 * consuming the global cap while still ranking the strongest candidates
 * first inside each source.
 */
export function curateCatalog(
  products: readonly PresentedCatalogProduct[],
  policy: CatalogCurationPolicy = DEFAULT_CURATION_POLICY,
): PresentedCatalogProduct[] {
  const queues = new Map<SourceId, PresentedCatalogProduct[]>();
  for (const sourceId of SOURCE_IDS) {
    const sourceLimit = SOURCES[sourceId].vertical === 'perfumes'
      ? policy.perfumeItemsPerSource
      : policy.fashionItemsPerSource;
    queues.set(
      sourceId,
      products
        .filter((record) => record.sourceId === sourceId && eligible(record))
        .sort(compareCandidates)
        .slice(0, Math.max(0, sourceLimit)),
    );
  }

  const selected: PresentedCatalogProduct[] = [];
  while (selected.length < policy.maximumItems) {
    let added = false;
    for (const sourceId of SOURCE_IDS) {
      const next = queues.get(sourceId)?.shift();
      if (!next) continue;
      selected.push(next);
      added = true;
      if (selected.length >= policy.maximumItems) break;
    }
    if (!added) break;
  }
  return selected;
}

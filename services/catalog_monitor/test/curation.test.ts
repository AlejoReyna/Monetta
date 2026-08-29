import { describe, expect, it } from 'vitest';
import { curateCatalog } from '../src/catalog/curation.js';
import type { PresentedCatalogProduct } from '../src/catalog/curatedUsCatalog.js';
import type { SourceId } from '../src/domain/types.js';

const observedAt = new Date('2026-08-21T00:00:00.000Z');

function item(
  sourceId: SourceId,
  externalId: string,
  overrides: Partial<PresentedCatalogProduct> = {},
): PresentedCatalogProduct {
  return {
    sourceId,
    externalId,
    canonicalUrl: `https://example.invalid/${externalId}`,
    title: sourceId === 'gp_mcallen_perfumes' ? `Perfume ${externalId} Eau de Parfum` : `Bag ${externalId}`,
    brand: 'Brand',
    category: sourceId === 'gp_mcallen_perfumes' ? 'Perfumes' : 'Handbags',
    imageUrl: `https://example.invalid/${externalId}.jpg`,
    priceUsd: 100,
    availability: 'inStock',
    fingerprint: externalId,
    firstSeenAt: observedAt,
    lastSeenAt: observedAt,
    lastChangedAt: observedAt,
    isActive: true,
    consecutiveMissingSnapshots: 0,
    dataOrigin: 'live_crawl',
    ...overrides,
  };
}

describe('curateCatalog', () => {
  it('caps each vertical and preserves brand variety with a global cap', () => {
    const candidates = [
      ...Array.from({ length: 5 }, (_, i) => item('coach_us', `C${i}`)),
      ...Array.from({ length: 5 }, (_, i) => item('kate_spade_us', `K${i}`)),
      ...Array.from({ length: 5 }, (_, i) => item('gp_mcallen_perfumes', `P${i}`)),
    ];
    const selected = curateCatalog(candidates, {
      fashionItemsPerSource: 2,
      perfumeItemsPerSource: 3,
      maximumItems: 6,
    });
    expect(selected.filter((p) => p.sourceId === 'coach_us')).toHaveLength(2);
    expect(selected.filter((p) => p.sourceId === 'kate_spade_us')).toHaveLength(2);
    expect(selected.filter((p) => p.sourceId === 'gp_mcallen_perfumes')).toHaveLength(2);
  });

  it('withdraws out-of-stock and irrelevant-category rows from presentation', () => {
    const selected = curateCatalog([
      item('coach_us', 'SOLD', { availability: 'outOfStock' }),
      item('coach_us', 'SHOE', { title: 'Leather Pump', category: 'Shoes' }),
      item('coach_us', 'GOOD'),
    ]);
    expect(selected.map((record) => record.externalId)).toEqual(['GOOD']);
  });

  it('prioritizes an in-stock item with an image over weaker candidates', () => {
    const selected = curateCatalog(
      [
        item('coach_us', 'UNKNOWN', { availability: 'unknown', imageUrl: null }),
        item('coach_us', 'BEST'),
      ],
      { fashionItemsPerSource: 1, perfumeItemsPerSource: 1, maximumItems: 2 },
    );
    expect(selected.map((record) => record.externalId)).toEqual(['BEST']);
  });
});

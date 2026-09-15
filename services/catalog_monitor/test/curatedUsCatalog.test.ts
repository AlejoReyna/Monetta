import { describe, expect, it } from 'vitest';
import { adapterFor } from '../src/adapters/registry.js';
import {
  CURATED_US_CATALOG,
  CURATED_US_CATALOG_OBSERVED_AT,
  CURATED_SOURCE_IDS,
  MINIMUM_PRODUCTS_PER_SOURCE,
  withMinimumUsCatalog,
} from '../src/catalog/curatedUsCatalog.js';
import { SOURCE_IDS, type CatalogProductRecord } from '../src/domain/types.js';

function liveProduct(overrides: Partial<CatalogProductRecord> = {}): CatalogProductRecord {
  const observedAt = new Date('2026-08-12T12:00:00.000Z');
  return {
    sourceId: 'coach_us',
    externalId: 'LIVE-1',
    canonicalUrl: 'https://www.coach.com/products/live-bag/LIVE-1.html',
    title: 'Live Bag',
    brand: 'Coach',
    category: 'Handbags',
    imageUrl: null,
    priceUsd: 300,
    availability: 'inStock',
    fingerprint: 'live-fingerprint',
    firstSeenAt: observedAt,
    lastSeenAt: observedAt,
    lastChangedAt: observedAt,
    isActive: true,
    consecutiveMissingSnapshots: 0,
    selectionState: 'selected',
    selectionVersion: null,
    watchTier: 'standard',
    placements: [],
    matchedRuleId: null,
    ...overrides,
  };
}

describe('curated US catalog floor', () => {
  it('contains ten valid, uniquely keyed official-US records per source', () => {
    expect(CURATED_US_CATALOG).toHaveLength(
      CURATED_SOURCE_IDS.length * MINIMUM_PRODUCTS_PER_SOURCE,
    );

    for (const sourceId of CURATED_SOURCE_IDS) {
      const records = CURATED_US_CATALOG.filter((record) => record.sourceId === sourceId);
      expect(records).toHaveLength(MINIMUM_PRODUCTS_PER_SOURCE);
      expect(new Set(records.map((record) => record.externalId)).size).toBe(records.length);

      for (const record of records) {
        const adapter = adapterFor(sourceId);
        expect(adapter.isProductUrl(record.canonicalUrl)).toBe(true);
        expect(adapter.externalIdFromUrl(record.canonicalUrl)).toBe(record.externalId);
        expect(record.priceUsd).toBeGreaterThan(0);
        expect(record.availability).toBe('unknown');
        expect(record.dataOrigin).toBe('curated_us_snapshot');
        expect(record.lastSeenAt).toEqual(CURATED_US_CATALOG_OBSERVED_AT);
        if (record.imageUrl !== null) {
          expect(new URL(record.imageUrl).protocol).toBe('https:');
        }
      }
    }
  });

  it('fills an empty database to ten products from each brand', () => {
    const presented = withMinimumUsCatalog([]);

    for (const sourceId of CURATED_SOURCE_IDS) {
      const records = presented.filter((record) => record.sourceId === sourceId);
      expect(records).toHaveLength(MINIMUM_PRODUCTS_PER_SOURCE);
      expect(records.every((record) => record.dataOrigin === 'curated_us_snapshot')).toBe(true);
    }
  });

  it('does not fabricate fallback inventory for newly configured sources', () => {
    const presented = withMinimumUsCatalog([]);
    const newSourceIds = SOURCE_IDS.filter((id) => !CURATED_SOURCE_IDS.includes(id));
    for (const sourceId of newSourceIds) {
      expect(presented.filter((record) => record.sourceId === sourceId)).toHaveLength(0);
    }
  });

  it('keeps a live row instead of the matching curated snapshot', () => {
    const curated = CURATED_US_CATALOG.find((record) => record.sourceId === 'coach_us')!;
    const live = liveProduct({
      externalId: curated.externalId,
      canonicalUrl: curated.canonicalUrl,
      title: `${curated.title} — live`,
    });

    const presented = withMinimumUsCatalog([live]);
    const coach = presented.filter((record) => record.sourceId === 'coach_us');
    expect(coach).toHaveLength(MINIMUM_PRODUCTS_PER_SOURCE);
    expect(coach.filter((record) => record.externalId === live.externalId)).toEqual([
      expect.objectContaining({ title: live.title, dataOrigin: 'live_crawl' }),
    ]);
  });

  it('does not add curated rows once a source already has ten live rows', () => {
    const live = Array.from({ length: MINIMUM_PRODUCTS_PER_SOURCE }, (_, index) =>
      liveProduct({
        externalId: `LIVE-${index}`,
        canonicalUrl: `https://www.coach.com/products/live-bag-${index}/LIVE-${index}.html`,
      }),
    );

    const coach = withMinimumUsCatalog(live).filter((record) => record.sourceId === 'coach_us');
    expect(coach).toHaveLength(MINIMUM_PRODUCTS_PER_SOURCE);
    expect(coach.every((record) => record.dataOrigin === 'live_crawl')).toBe(true);
  });

  it('never presents the old fictional demo rows', () => {
    const legacyDemo = liveProduct({
      externalId: 'LEGACY-DEMO',
      title: 'A Fake Bag (demo data)',
      imageUrl: 'https://picsum.photos/seed/fake/600/800',
    });

    const presented = withMinimumUsCatalog([legacyDemo]);
    expect(presented.some((record) => record.externalId === legacyDemo.externalId)).toBe(false);
    expect(presented.filter((record) => record.sourceId === 'coach_us')).toHaveLength(10);
  });
});

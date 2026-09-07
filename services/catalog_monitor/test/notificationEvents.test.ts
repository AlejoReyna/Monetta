import { describe, expect, it } from 'vitest';
import { catalogEvents } from '../src/db/pgProductRepository.js';
import type { CatalogProductRecord } from '../src/domain/types.js';

function record(
  overrides: Partial<CatalogProductRecord> = {},
): CatalogProductRecord {
  return {
    sourceId: 'coach_us',
    externalId: 'C1',
    canonicalUrl: 'https://www.coach.com/products/example/C1.html',
    title: 'Bolsa Coach',
    brand: 'Coach',
    category: 'Handbags',
    imageUrl: 'https://www.coach.com/example.jpg',
    priceUsd: 300,
    availability: 'inStock',
    variants: [],
    fingerprint: 'fingerprint-next',
    firstSeenAt: new Date('2026-08-01T00:00:00Z'),
    lastSeenAt: new Date('2026-08-25T12:00:00Z'),
    lastChangedAt: new Date('2026-08-25T12:00:00Z'),
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

describe('catalog notification transition events', () => {
  it('emits a canonical new-arrival event for a first observation', () => {
    const events = catalogEvents(null, record());
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({
      eventType: 'catalog.product.created',
      productKey: 'external:coach_us:C1',
      after: { brand: 'coach', category: 'handbags' },
    });
  });

  it('emits restock and price-drop transitions, but not unchanged snapshots', () => {
    const previous = record({
      availability: 'outOfStock',
      priceUsd: 350,
      fingerprint: 'fingerprint-before',
    });
    expect(catalogEvents(previous, record()).map((event) => event.eventType))
      .toEqual([
        'catalog.product.restocked',
        'catalog.product.price_dropped',
      ]);
    expect(catalogEvents(record(), record())).toEqual([]);
  });
});

import { describe, expect, it } from 'vitest';
import { diffFullSnapshot, CONSECUTIVE_MISSES_BEFORE_INACTIVE } from '../src/crawl/snapshotDiff.js';
import { fingerprintOf } from '../src/crawl/fingerprint.js';
import type { CatalogProductRecord, ExtractedProduct } from '../src/domain/types.js';

const now = new Date('2026-08-10T12:00:00.000Z');
const earlier = new Date('2026-08-09T12:00:00.000Z');

function extracted(overrides: Partial<ExtractedProduct> = {}): ExtractedProduct {
  return {
    externalId: 'A1',
    canonicalUrl: 'https://www.coach.com/a/A1.html',
    title: 'Bag A',
    brand: 'Coach',
    category: 'Handbags',
    imageUrl: 'https://coach.com/a.jpg',
    priceUsd: 100,
    availability: 'inStock',
    ...overrides,
  };
}

function record(overrides: Partial<CatalogProductRecord> = {}): CatalogProductRecord {
  const base = extracted();
  return {
    ...base,
    sourceId: 'coach_us',
    fingerprint: fingerprintOf(base),
    firstSeenAt: earlier,
    lastSeenAt: earlier,
    lastChangedAt: earlier,
    isActive: true,
    consecutiveMissingSnapshots: 0,
    ...overrides,
  };
}

describe('diffFullSnapshot', () => {
  it('adds a brand-new item', () => {
    const result = diffFullSnapshot('coach_us', [], [extracted()], now);
    expect(result.newItemCount).toBe(1);
    expect(result.toUpsert[0]).toMatchObject({ isActive: true, consecutiveMissingSnapshots: 0 });
    expect(result.toUpsert[0]!.firstSeenAt).toEqual(now);
  });

  it('detects a changed item via fingerprint and updates lastChangedAt', () => {
    const previous = [record()];
    const result = diffFullSnapshot('coach_us', previous, [extracted({ priceUsd: 120 })], now);
    expect(result.changedItemCount).toBe(1);
    expect(result.toUpsert[0]!.lastChangedAt).toEqual(now);
    expect(result.toUpsert[0]!.firstSeenAt).toEqual(earlier); // preserved
  });

  it('detects a price or stock change isolated to one color variant', () => {
    const original = extracted({
      variants: [
        {
          variantId: 'A1:black',
          sku: 'A1-BLK',
          colorName: 'Black',
          colorCode: 'BLK',
          imageUrl: 'https://coach.com/a-black.jpg',
          priceUsd: 100,
          availability: 'inStock',
          detailUrl: 'https://www.coach.com/a/A1-BLK.html',
        },
      ],
    });
    const previous = [
      record({
        ...original,
        fingerprint: fingerprintOf(original),
      }),
    ];
    const changed = extracted({
      variants: [
        {
          ...original.variants![0]!,
          availability: 'outOfStock',
        },
      ],
    });

    const result = diffFullSnapshot('coach_us', previous, [changed], now);
    expect(result.changedItemCount).toBe(1);
    expect(result.toUpsert[0]!.variants![0]!.availability).toBe('outOfStock');
  });

  it('leaves lastChangedAt untouched for an unchanged item, but bumps lastSeenAt', () => {
    const previous = [record()];
    const result = diffFullSnapshot('coach_us', previous, [extracted()], now);
    expect(result.unchangedItemCount).toBe(1);
    expect(result.toUpsert[0]!.lastChangedAt).toEqual(earlier);
    expect(result.toUpsert[0]!.lastSeenAt).toEqual(now);
  });

  it('does not deactivate an item missing from only one snapshot', () => {
    const previous = [record()];
    const result = diffFullSnapshot('coach_us', previous, [], now);
    expect(result.newlyInactive).toHaveLength(0);
    expect(result.missingButStillActive).toHaveLength(1);
    expect(result.missingButStillActive[0]!.consecutiveMissingSnapshots).toBe(1);
    expect(result.missingButStillActive[0]!.isActive).toBe(true);
  });

  it(`deactivates an item after ${CONSECUTIVE_MISSES_BEFORE_INACTIVE} consecutive misses`, () => {
    const previous = [record({ consecutiveMissingSnapshots: 1 })];
    const result = diffFullSnapshot('coach_us', previous, [], now);
    expect(result.newlyInactive).toHaveLength(1);
    expect(result.newlyInactive[0]!.isActive).toBe(false);
    expect(result.newlyInactive[0]!.consecutiveMissingSnapshots).toBe(2);
  });

  it('resets consecutiveMissingSnapshots to 0 once an item reappears', () => {
    const previous = [record({ consecutiveMissingSnapshots: 1 })];
    const result = diffFullSnapshot('coach_us', previous, [extracted()], now);
    expect(result.toUpsert[0]!.consecutiveMissingSnapshots).toBe(0);
    expect(result.toUpsert[0]!.isActive).toBe(true);
  });

  it('handles multiple sources independently by construction (sourceId is stamped, not inferred)', () => {
    const result = diffFullSnapshot('michael_kors_us', [], [extracted({ externalId: 'R-1' })], now);
    expect(result.toUpsert[0]!.sourceId).toBe('michael_kors_us');
  });
});

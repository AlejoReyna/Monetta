import { describe, expect, it } from 'vitest';
import {
  diffFullSnapshot,
  diffSelectionSnapshot,
  CONSECUTIVE_MISSES_BEFORE_INACTIVE,
  type MatchedExtractedProduct,
} from '../src/crawl/snapshotDiff.js';
import { fingerprintOf } from '../src/crawl/fingerprint.js';
import type { CatalogProductRecord, ExtractedProduct } from '../src/domain/types.js';
import { compileSelection } from '../src/selection/engine.js';
import { parseSelectionDocument } from '../src/selection/document.js';
import type { SelectionDocument } from '../src/selection/types.js';

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
    selectionState: 'selected',
    selectionVersion: null,
    watchTier: 'standard',
    placements: [],
    matchedRuleId: null,
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
    expect(result.toUpsert[0]!.selectionState).toBe('selected');
    expect(result.toUpsert[0]!.selectionVersion).toBeNull();
    expect(result.toUpsert[0]!.watchTier).toBe('standard');
    expect(result.toUpsert[0]!.placements).toEqual([]);
    expect(result.toUpsert[0]!.matchedRuleId).toBeNull();
  });
});

function matched(overrides: Partial<MatchedExtractedProduct> = {}): MatchedExtractedProduct {
  return {
    ...extracted(),
    watchTier: 'standard',
    placements: ['home_rail', 'catalog_browse'],
    matchedRuleId: 'rule-tabby',
    ...overrides,
  };
}

describe('diffSelectionSnapshot', () => {
  it('adds a brand-new item carrying winning selection metadata and version', () => {
    const result = diffSelectionSnapshot({
      sourceId: 'coach_us',
      selectionVersion: 1,
      selectedItems: [matched({ externalId: 'NEW-1', watchTier: 'pinned', matchedRuleId: 'pin-rule' })],
      previousActive: [],
      now,
    });

    expect(result.newItemCount).toBe(1);
    expect(result.toUpsert).toHaveLength(1);
    expect(result.toUpsert[0]!).toMatchObject({
      externalId: 'NEW-1',
      selectionState: 'selected',
      selectionVersion: 1,
      watchTier: 'pinned',
      matchedRuleId: 'pin-rule',
      isActive: true,
      consecutiveMissingSnapshots: 0,
      firstSeenAt: now,
      lastSeenAt: now,
      lastChangedAt: now,
    });
  });

  it('reselects a historical row preserving firstSeenAt and does not count it as a new product', () => {
    const previous = record({
      externalId: 'A1',
      firstSeenAt: earlier,
      lastSeenAt: earlier,
      lastChangedAt: earlier,
      selectionState: 'deselected',
      selectionVersion: 1,
    });

    const result = diffSelectionSnapshot({
      sourceId: 'coach_us',
      selectionVersion: 2,
      selectedItems: [matched({ externalId: 'A1' })],
      previousActive: [previous],
      now,
    });

    expect(result.newItemCount).toBe(0);
    expect(result.unchangedItemCount).toBe(1);
    expect(result.toUpsert[0]!.firstSeenAt).toEqual(earlier);
    expect(result.toUpsert[0]!.lastSeenAt).toEqual(now);
    expect(result.toUpsert[0]!.lastChangedAt).toEqual(earlier); // selection change is not a merchant data change
    expect(result.toUpsert[0]!.selectionState).toBe('selected');
    expect(result.toUpsert[0]!.selectionVersion).toBe(2);
    expect(result.toUpsert[0]!.isActive).toBe(true);
  });

  it('narrowing from 100 selected active products at version 1 to 5 at version 2: deactivates zero, deselects 95, preserves history and isActive, marks retained five as selected at version 2', () => {
    // 100 active products previously selected at version 1
    const previous100: CatalogProductRecord[] = Array.from({ length: 100 }, (_, i) =>
      record({
        externalId: `ITEM_${i}`,
        firstSeenAt: earlier,
        lastSeenAt: earlier,
        lastChangedAt: earlier,
        selectionState: 'selected',
        selectionVersion: 1,
        consecutiveMissingSnapshots: 0,
        isActive: true,
      }),
    );

    // Only 5 items retained in current selection version 2
    const retained5: MatchedExtractedProduct[] = Array.from({ length: 5 }, (_, i) =>
      matched({
        externalId: `ITEM_${i}`,
        title: `Retained Item ${i}`,
        watchTier: 'standard',
        placements: ['catalog_browse'],
        matchedRuleId: 'rule-retained',
      }),
    );

    // Selection doc that matches only the 5 retained items
    const selectionDoc = parseSelectionDocument({
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: retained5.map((r) => ({
            id: 'include-' + r.externalId,
            kind: 'externalId',
            value: r.externalId,
          })),
        },
      },
    }) as SelectionDocument;
    const selection = compileSelection(selectionDoc);

    const result = diffSelectionSnapshot({
      sourceId: 'coach_us',
      selectionVersion: 2,
      selection,
      selectedItems: retained5,
      previousActive: previous100,
      now,
      suppressDeactivation: true,
    });

    // Deactivates zero
    expect(result.newlyInactive).toHaveLength(0);
    // Missing items from same-version baseline is zero (none existed at v2 yet)
    expect(result.missingButStillActive).toHaveLength(0);

    // Deselects 95
    expect(result.deselectedItemCount).toBe(95);
    expect(result.toDeselect).toHaveLength(95);

    // Deselected rows keep isActive, firstSeenAt, and history
    for (const d of result.toDeselect) {
      expect(d.isActive).toBe(true);
      expect(d.selectionState).toBe('deselected');
      expect(d.selectionVersion).toBe(2);
      expect(d.watchTier).toBe('standard');
      expect(d.placements).toEqual([]);
      expect(d.matchedRuleId).toBeNull();
      expect(d.firstSeenAt).toEqual(earlier);
    }

    // Marks the retained five as selected at version 2
    expect(result.toUpsert).toHaveLength(5);
    expect(result.newItemCount).toBe(0);
    for (const u of result.toUpsert) {
      expect(u.selectionState).toBe('selected');
      expect(u.selectionVersion).toBe(2);
      expect(u.isActive).toBe(true);
      expect(u.firstSeenAt).toEqual(earlier);
      expect(u.lastSeenAt).toEqual(now);
    }
  });

  it('a second full run at version 2 does not deactivate anything merely due to the version change', () => {
    // Retained 5 are now selected at v2; the 95 others are deselected at v2
    const currentActive: CatalogProductRecord[] = [
      ...Array.from({ length: 5 }, (_, i) =>
        record({
          externalId: `ITEM_${i}`,
          selectionState: 'selected',
          selectionVersion: 2,
          consecutiveMissingSnapshots: 0,
        }),
      ),
      ...Array.from({ length: 95 }, (_, i) =>
        record({
          externalId: `ITEM_${i + 5}`,
          selectionState: 'deselected',
          selectionVersion: 2,
          consecutiveMissingSnapshots: 0,
        }),
      ),
    ];

    const retained5: MatchedExtractedProduct[] = Array.from({ length: 5 }, (_, i) =>
      matched({ externalId: `ITEM_${i}` }),
    );

    const selectionDoc = parseSelectionDocument({
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: retained5.map((r) => ({
            id: 'include-' + r.externalId,
            kind: 'externalId',
            value: r.externalId,
          })),
        },
      },
    }) as SelectionDocument;
    const selection = compileSelection(selectionDoc);

    const result = diffSelectionSnapshot({
      sourceId: 'coach_us',
      selectionVersion: 2,
      selection,
      selectedItems: retained5,
      previousActive: currentActive,
      now,
      suppressDeactivation: false, // Second run: normal stable version diffing
    });

    expect(result.newlyInactive).toHaveLength(0);
    expect(result.missingButStillActive).toHaveLength(0);
    expect(result.deselectedItemCount).toBe(0);
    expect(result.toDeselect).toHaveLength(0);
    expect(result.toUpsert).toHaveLength(5);
  });

  it('a genuinely missing selected item becomes inactive only after two complete runs at a stable version', () => {
    // 5 items selected at version 2 in baseline
    const baseline5: CatalogProductRecord[] = Array.from({ length: 5 }, (_, i) =>
      record({
        externalId: `ITEM_${i}`,
        selectionState: 'selected',
        selectionVersion: 2,
        consecutiveMissingSnapshots: 0,
      }),
    );

    // Run 1: ITEM_4 is missing from the crawl (only 4 crawled)
    const crawl4: MatchedExtractedProduct[] = Array.from({ length: 4 }, (_, i) =>
      matched({ externalId: `ITEM_${i}` }),
    );

    const run1 = diffSelectionSnapshot({
      sourceId: 'coach_us',
      selectionVersion: 2,
      selectedItems: crawl4,
      previousActive: baseline5,
      now,
      suppressDeactivation: false,
    });

    expect(run1.newlyInactive).toHaveLength(0);
    expect(run1.missingButStillActive).toHaveLength(1);
    expect(run1.missingButStillActive[0]!.externalId).toBe('ITEM_4');
    expect(run1.missingButStillActive[0]!.consecutiveMissingSnapshots).toBe(1);
    expect(run1.missingButStillActive[0]!.isActive).toBe(true);

    // Run 2: ITEM_4 is missing again
    const updatedPrevious: CatalogProductRecord[] = [
      ...Array.from({ length: 4 }, (_, i) =>
        record({
          externalId: `ITEM_${i}`,
          selectionState: 'selected',
          selectionVersion: 2,
          consecutiveMissingSnapshots: 0,
        }),
      ),
      run1.missingButStillActive[0]!, // consecutiveMissingSnapshots = 1
    ];

    const run2 = diffSelectionSnapshot({
      sourceId: 'coach_us',
      selectionVersion: 2,
      selectedItems: crawl4,
      previousActive: updatedPrevious,
      now,
      suppressDeactivation: false,
    });

    expect(run2.missingButStillActive).toHaveLength(0);
    expect(run2.newlyInactive).toHaveLength(1);
    expect(run2.newlyInactive[0]!.externalId).toBe('ITEM_4');
    expect(run2.newlyInactive[0]!.consecutiveMissingSnapshots).toBe(2);
    expect(run2.newlyInactive[0]!.isActive).toBe(false);
  });

  it('a rejected-but-previously-selected product becomes deselected, not inactive', () => {
    const previouslySelected = record({
      externalId: 'TABBY_1',
      selectionState: 'selected',
      selectionVersion: 2,
      isActive: true,
      consecutiveMissingSnapshots: 0,
    });

    const rejectedExtraction = extracted({ externalId: 'TABBY_1', priceUsd: 1500 });

    const result = diffSelectionSnapshot({
      sourceId: 'coach_us',
      selectionVersion: 2,
      selectedItems: [],
      rejectedProducts: [rejectedExtraction],
      previousActive: [previouslySelected],
      now,
      suppressDeactivation: false,
    });

    expect(result.newlyInactive).toHaveLength(0);
    expect(result.missingButStillActive).toHaveLength(0);
    expect(result.deselectedItemCount).toBe(1);
    expect(result.toDeselect).toHaveLength(1);
    expect(result.toDeselect[0]!).toMatchObject({
      externalId: 'TABBY_1',
      selectionState: 'deselected',
      selectionVersion: 2,
      isActive: true, // Not inactive!
    });
  });

  it('a deselected product that later matches again is restored with its original firstSeenAt', () => {
    const originalFirstSeen = new Date('2026-01-01T00:00:00Z');
    const previouslyDeselected = record({
      externalId: 'RESTORE_1',
      firstSeenAt: originalFirstSeen,
      lastSeenAt: earlier,
      selectionState: 'deselected',
      selectionVersion: 2,
      isActive: true,
    });

    const matchedItem = matched({
      externalId: 'RESTORE_1',
      watchTier: 'pinned',
      matchedRuleId: 'restore-rule',
    });

    const result = diffSelectionSnapshot({
      sourceId: 'coach_us',
      selectionVersion: 3,
      selectedItems: [matchedItem],
      previousActive: [previouslyDeselected],
      now,
      suppressDeactivation: true,
    });

    expect(result.newItemCount).toBe(0);
    expect(result.toUpsert).toHaveLength(1);
    expect(result.toUpsert[0]!).toMatchObject({
      externalId: 'RESTORE_1',
      firstSeenAt: originalFirstSeen, // Preserved!
      lastSeenAt: now,
      selectionState: 'selected',
      selectionVersion: 3,
      watchTier: 'pinned',
      matchedRuleId: 'restore-rule',
      isActive: true,
      consecutiveMissingSnapshots: 0,
    });
  });
});

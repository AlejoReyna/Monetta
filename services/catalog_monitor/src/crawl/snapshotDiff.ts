import { fingerprintOf } from './fingerprint.js';
import type { CatalogProductRecord, ExtractedProduct, SourceId } from '../domain/types.js';
import type { CompiledSelection, Placement, WatchTier } from '../selection/types.js';

/**
 * The rule that keeps a flaky crawl from wiping out the catalog: an item is
 * only demoted to inactive after it is absent from this many consecutive
 * *successful full* snapshots. A single missed page, or a run that failed
 * outright, must never look like "the item disappeared."
 */
export const CONSECUTIVE_MISSES_BEFORE_INACTIVE = 2;

export interface SnapshotDiffResult {
  readonly toUpsert: readonly CatalogProductRecord[];
  readonly newItemCount: number;
  readonly changedItemCount: number;
  readonly unchangedItemCount: number;
  readonly missingButStillActive: readonly CatalogProductRecord[];
  readonly newlyInactive: readonly CatalogProductRecord[];
}

/**
 * Pure reconciliation: given the currently-active records for a source and
 * the items observed in one *complete, successful* crawl of that source,
 * decide what changed. Contains no I/O — callers persist the result.
 *
 * Only call this for a run that visited every discovered, classified
 * product URL for the source without a fatal abort. A partial or failed run
 * must not call this function at all (see `crawl/runner.ts`), because any
 * item missing from `currentItems` would otherwise be wrongly counted as a
 * miss.
 */
export function diffFullSnapshot(
  sourceId: SourceId,
  previousActive: readonly CatalogProductRecord[],
  currentItems: readonly ExtractedProduct[],
  now: Date,
): SnapshotDiffResult {
  const previousById = new Map(previousActive.map((p) => [p.externalId, p]));
  const seenIds = new Set<string>();

  const toUpsert: CatalogProductRecord[] = [];
  let newItemCount = 0;
  let changedItemCount = 0;
  let unchangedItemCount = 0;

  for (const item of currentItems) {
    seenIds.add(item.externalId);
    const previous = previousById.get(item.externalId);
    const fingerprint = fingerprintOf(item);

    if (!previous) {
      newItemCount++;
      toUpsert.push({
        ...item,
        sourceId,
        fingerprint,
        firstSeenAt: now,
        lastSeenAt: now,
        lastChangedAt: now,
        isActive: true,
        consecutiveMissingSnapshots: 0,
        selectionState: 'selected',
        selectionVersion: null,
        watchTier: 'standard',
        placements: [],
        matchedRuleId: null,
      });
      continue;
    }

    const changed = previous.fingerprint !== fingerprint;
    if (changed) changedItemCount++;
    else unchangedItemCount++;

    toUpsert.push({
      ...item,
      sourceId,
      fingerprint,
      firstSeenAt: previous.firstSeenAt,
      lastSeenAt: now,
      lastChangedAt: changed ? now : previous.lastChangedAt,
      isActive: true,
      consecutiveMissingSnapshots: 0,
      selectionState: previous.selectionState ?? 'selected',
      selectionVersion: previous.selectionVersion ?? null,
      watchTier: previous.watchTier ?? 'standard',
      placements: previous.placements ?? [],
      matchedRuleId: previous.matchedRuleId ?? null,
    });
  }

  const missingButStillActive: CatalogProductRecord[] = [];
  const newlyInactive: CatalogProductRecord[] = [];

  for (const previous of previousActive) {
    if (seenIds.has(previous.externalId)) continue;
    const misses = previous.consecutiveMissingSnapshots + 1;
    if (misses >= CONSECUTIVE_MISSES_BEFORE_INACTIVE) {
      newlyInactive.push({
        ...previous,
        consecutiveMissingSnapshots: misses,
        isActive: false,
        selectionState: previous.selectionState ?? 'selected',
        selectionVersion: previous.selectionVersion ?? null,
        watchTier: previous.watchTier ?? 'standard',
        placements: previous.placements ?? [],
        matchedRuleId: previous.matchedRuleId ?? null,
      });
    } else {
      missingButStillActive.push({
        ...previous,
        consecutiveMissingSnapshots: misses,
        selectionState: previous.selectionState ?? 'selected',
        selectionVersion: previous.selectionVersion ?? null,
        watchTier: previous.watchTier ?? 'standard',
        placements: previous.placements ?? [],
        matchedRuleId: previous.matchedRuleId ?? null,
      });
    }
  }

  return {
    toUpsert,
    newItemCount,
    changedItemCount,
    unchangedItemCount,
    missingButStillActive,
    newlyInactive,
  };
}

export interface MatchedExtractedProduct extends ExtractedProduct {
  readonly watchTier: WatchTier;
  readonly placements: readonly Placement[];
  readonly matchedRuleId: string | null;
}

export interface SelectionSnapshotDiffParams {
  readonly sourceId: SourceId;
  readonly selectionVersion: number;
  readonly selection?: CompiledSelection;
  readonly selectedItems: readonly MatchedExtractedProduct[];
  readonly rejectedProducts?: readonly ExtractedProduct[];
  readonly previousActive: readonly CatalogProductRecord[];
  readonly sameVersionBaseline?: readonly CatalogProductRecord[];
  readonly now: Date;
  readonly suppressDeactivation?: boolean;
}

export interface SelectionSnapshotDiffResult {
  readonly toUpsert: readonly CatalogProductRecord[];
  readonly carriedOverToStamp: readonly CatalogProductRecord[];
  readonly toDeselect: readonly CatalogProductRecord[];
  readonly missingButStillActive: readonly CatalogProductRecord[];
  readonly newlyInactive: readonly CatalogProductRecord[];
  readonly newItemCount: number;
  readonly changedItemCount: number;
  readonly unchangedItemCount: number;
  readonly deselectedItemCount: number;
}

/**
 * Pure selection-aware reconciliation implementing invariants I1–I6:
 *
 * - I1: Selection-scoped snapshot diffing.
 * - I2: Baseline for missing-items is version-scoped (selection_version = currentVersion).
 * - I3: Version changes never deactivate (suppressDeactivation, carries over matching rows).
 * - I4: Leaving selection is deselection, never disappearance (keeps isActive and history).
 * - I6: Pure reconciliation only — caller persists only for a complete full snapshot.
 */
export function diffSelectionSnapshot(
  params: SelectionSnapshotDiffParams,
): SelectionSnapshotDiffResult {
  const previousById = new Map(params.previousActive.map((p) => [p.externalId, p]));
  const baselineById = params.sameVersionBaseline
    ? new Map(params.sameVersionBaseline.map((p) => [p.externalId, p]))
    : null;

  const seenSelectedIds = new Set<string>();
  const seenRejectedIds = new Set<string>();

  const toUpsert: CatalogProductRecord[] = [];
  let newItemCount = 0;
  let changedItemCount = 0;
  let unchangedItemCount = 0;

  // 1. Process all successfully extracted & selected items
  for (const item of params.selectedItems) {
    seenSelectedIds.add(item.externalId);
    const previous = previousById.get(item.externalId);
    const fingerprint = fingerprintOf(item);

    if (!previous) {
      newItemCount++;
      toUpsert.push({
        ...item,
        sourceId: params.sourceId,
        fingerprint,
        firstSeenAt: params.now,
        lastSeenAt: params.now,
        lastChangedAt: params.now,
        isActive: true,
        consecutiveMissingSnapshots: 0,
        selectionState: 'selected',
        selectionVersion: params.selectionVersion,
        watchTier: item.watchTier,
        placements: item.placements,
        matchedRuleId: item.matchedRuleId,
      });
      continue;
    }

    // Historical row reselected or carried over:
    // Product change counts remain merchant-data/fingerprint changes;
    // selection-only transitions must not be reported as newly discovered products.
    const changed = previous.fingerprint !== fingerprint;
    if (changed) changedItemCount++;
    else unchangedItemCount++;

    toUpsert.push({
      ...item,
      sourceId: params.sourceId,
      fingerprint,
      firstSeenAt: previous.firstSeenAt,
      lastSeenAt: params.now,
      lastChangedAt: changed ? params.now : previous.lastChangedAt,
      isActive: true,
      consecutiveMissingSnapshots: 0,
      selectionState: 'selected',
      selectionVersion: params.selectionVersion,
      watchTier: item.watchTier,
      placements: item.placements,
      matchedRuleId: item.matchedRuleId,
    });
  }

  // 2. Process rejected products: if previously selected, they become deselected, not inactive
  const toDeselect: CatalogProductRecord[] = [];
  let deselectedItemCount = 0;

  for (const item of params.rejectedProducts ?? []) {
    seenRejectedIds.add(item.externalId);
    if (seenSelectedIds.has(item.externalId)) continue;
    const previous = previousById.get(item.externalId);
    if (previous && previous.selectionState === 'selected') {
      toDeselect.push({
        ...previous,
        selectionState: 'deselected',
        selectionVersion: params.selectionVersion,
        watchTier: 'standard',
        placements: [],
        matchedRuleId: null,
      });
      deselectedItemCount++;
    }
  }

  // 3. Process previously active products that were NOT seen in this crawl
  const carriedOverToStamp: CatalogProductRecord[] = [];
  const missingButStillActive: CatalogProductRecord[] = [];
  const newlyInactive: CatalogProductRecord[] = [];

  for (const previous of params.previousActive) {
    if (seenSelectedIds.has(previous.externalId)) continue;
    if (seenRejectedIds.has(previous.externalId)) continue;

    // A row that is already deselected stays deselected
    if (previous.selectionState === 'deselected') continue;

    // Previous was selected (previous.selectionState === 'selected')
    const isSameVersionBaseline = baselineById
      ? baselineById.has(previous.externalId)
      : previous.selectionVersion === params.selectionVersion;

    if (isSameVersionBaseline) {
      // It is part of the version-scoped missing baseline (I2).
      // Rows from any other selection version must never be counted missing.
      if (params.suppressDeactivation) {
        // I3: deactivation suppressed for version changes
        missingButStillActive.push({
          ...previous,
          consecutiveMissingSnapshots: 0,
        });
      } else {
        const misses = previous.consecutiveMissingSnapshots + 1;
        if (misses >= CONSECUTIVE_MISSES_BEFORE_INACTIVE) {
          newlyInactive.push({
            ...previous,
            consecutiveMissingSnapshots: misses,
            isActive: false,
          });
        } else {
          missingButStillActive.push({
            ...previous,
            consecutiveMissingSnapshots: misses,
          });
        }
      }
    } else {
      // previous.selectionVersion !== params.selectionVersion:
      // It was selected under an older (or null) selection version.
      if (params.selection) {
        const match = params.selection.matchProduct(params.sourceId, previous);
        if (match.selected) {
          // Carried-over matching selected row! (I3)
          // Safely stamped with new version and consecutiveMissingSnapshots = 0
          // without falsifying lastSeenAt or merchant history.
          carriedOverToStamp.push({
            ...previous,
            selectionState: 'selected',
            selectionVersion: params.selectionVersion,
            watchTier: match.tier,
            placements: match.placements,
            matchedRuleId: match.ruleId,
            consecutiveMissingSnapshots: 0,
          });
          continue;
        }
      }

      // Leaving selection is deselection, never disappearance (I4):
      toDeselect.push({
        ...previous,
        selectionState: 'deselected',
        selectionVersion: params.selectionVersion,
        watchTier: 'standard',
        placements: [],
        matchedRuleId: null,
      });
      deselectedItemCount++;
    }
  }

  return {
    toUpsert,
    carriedOverToStamp,
    toDeselect,
    missingButStillActive,
    newlyInactive,
    newItemCount,
    changedItemCount,
    unchangedItemCount,
    deselectedItemCount,
  };
}

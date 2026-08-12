import { fingerprintOf } from './fingerprint.js';
import type { CatalogProductRecord, ExtractedProduct, SourceId } from '../domain/types.js';

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
    });
  }

  const missingButStillActive: CatalogProductRecord[] = [];
  const newlyInactive: CatalogProductRecord[] = [];

  for (const previous of previousActive) {
    if (seenIds.has(previous.externalId)) continue;
    const misses = previous.consecutiveMissingSnapshots + 1;
    if (misses >= CONSECUTIVE_MISSES_BEFORE_INACTIVE) {
      newlyInactive.push({ ...previous, consecutiveMissingSnapshots: misses, isActive: false });
    } else {
      missingButStillActive.push({ ...previous, consecutiveMissingSnapshots: misses });
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

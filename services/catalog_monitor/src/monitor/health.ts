import type { CrawlRunRepository } from '../crawl/ports.js';
import type { SourceId } from '../domain/types.js';

export const STALE_RUN_HOURS = 36;
export const MIN_REQUIRED_FIELD_COVERAGE = 0.98;
export const MAX_PRODUCT_COUNT_DROP_FRACTION = 0.2;

export type HealthReason =
  | 'no_recent_successful_run'
  | 'low_parse_coverage'
  | 'product_count_drop'
  | 'widespread_failures';

export interface SourceHealth {
  readonly sourceId: SourceId;
  readonly status: 'healthy' | 'unhealthy';
  readonly reasons: readonly HealthReason[];
  readonly lastSuccessfulRunAt: Date | null;
  readonly freshnessHours: number | null;
  readonly lastRequiredFieldCoverage: number | null;
}

export async function evaluateSourceHealth(
  sourceId: SourceId,
  crawlRuns: CrawlRunRepository,
  now: Date = new Date(),
): Promise<SourceHealth> {
  const reasons: HealthReason[] = [];

  // Health and freshness are only meaningful against a run that both
  // succeeded *and* walked the whole catalog — a capped `--limit` smoke run
  // has `status: 'success'` but `isFullSnapshot: false`, and must never be
  // able to refresh freshness or mask a stale/degraded catalog.
  const lastSuccessful = await crawlRuns.lastSuccessfulFullSnapshotRun(sourceId);
  const freshnessHours = lastSuccessful
    ? (now.getTime() - (lastSuccessful.endedAt ?? lastSuccessful.startedAt).getTime()) /
      (1000 * 60 * 60)
    : null;

  if (!lastSuccessful || freshnessHours === null || freshnessHours > STALE_RUN_HOURS) {
    reasons.push('no_recent_successful_run');
  }

  let coverage: number | null = null;
  if (lastSuccessful && lastSuccessful.pagesFetched > 0) {
    coverage = lastSuccessful.successfulParses / lastSuccessful.pagesFetched;
    if (coverage < MIN_REQUIRED_FIELD_COVERAGE) reasons.push('low_parse_coverage');
  }

  const recent = await crawlRuns.recentRuns(sourceId, 10);
  // Product-count-drop comparison must use consecutive successful *full*
  // snapshots — comparing against a partial or capped run would read as a
  // catalog collapse when nothing actually changed.
  const successfulRuns = recent.filter((r) => r.status === 'success' && r.isFullSnapshot);
  if (successfulRuns.length >= 2) {
    const [latest, previous] = successfulRuns;
    if (previous!.successfulParses > 0) {
      const drop = 1 - latest!.successfulParses / previous!.successfulParses;
      if (drop > MAX_PRODUCT_COUNT_DROP_FRACTION) reasons.push('product_count_drop');
    }
  }

  const mostRecent = recent[0];
  if (mostRecent && (mostRecent.status === 'blocked' || mostRecent.status === 'failed')) {
    const totalErrors = Object.values(mostRecent.errorsByType).reduce(
      (sum, n) => sum + (n ?? 0),
      0,
    );
    if (
      mostRecent.status === 'blocked' ||
      (mostRecent.urlsDiscovered > 0 && totalErrors / mostRecent.urlsDiscovered >= 0.5)
    ) {
      reasons.push('widespread_failures');
    }
  }

  return {
    sourceId,
    status: reasons.length === 0 ? 'healthy' : 'unhealthy',
    reasons,
    lastSuccessfulRunAt: lastSuccessful ? (lastSuccessful.endedAt ?? lastSuccessful.startedAt) : null,
    freshnessHours,
    lastRequiredFieldCoverage: coverage,
  };
}

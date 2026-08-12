import type {
  CatalogProductRecord,
  CrawlRunMetrics,
  CrawlRunStatus,
  SourceId,
} from '../domain/types.js';

/**
 * Storage seams. Postgres implementations live in `src/db/*`; tests use an
 * in-memory fake (`test/support/inMemoryRepositories.ts`) so the crawl
 * runner, snapshot diffing, health checks and API can all be exercised with
 * zero real database and zero real network.
 */
export interface ProductRepository {
  getActiveProducts(sourceId: SourceId): Promise<CatalogProductRecord[]>;
  getAllActiveProducts(): Promise<CatalogProductRecord[]>;
  upsertMany(records: readonly CatalogProductRecord[]): Promise<void>;
}

export interface CrawlRunRepository {
  start(params: { sourceId: SourceId; startedAt: Date }): Promise<number>;
  finish(
    runId: number,
    params: {
      endedAt: Date;
      status: CrawlRunStatus;
      isFullSnapshot: boolean;
      urlsDiscovered: number;
      pagesFetched: number;
      successfulParses: number;
      newItems: number;
      changedItems: number;
      missingItems: number;
      inactiveItems: number;
      errorsByType: Partial<Record<string, number>>;
    },
  ): Promise<void>;
  /** Most recent runs per source, newest first, capped at `limit`. */
  recentRuns(sourceId: SourceId, limit: number): Promise<CrawlRunMetrics[]>;
  /**
   * Most recent run that is both `status = 'success'` and
   * `isFullSnapshot = true` — a capped smoke run or a partial run must never
   * satisfy this, since health and freshness are only meaningful against a
   * run that actually walked the whole catalog.
   */
  lastSuccessfulFullSnapshotRun(sourceId: SourceId): Promise<CrawlRunMetrics | null>;
}

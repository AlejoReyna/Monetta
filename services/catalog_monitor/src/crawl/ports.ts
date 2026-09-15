import type {
  CatalogProductRecord,
  CrawlRunMetrics,
  CrawlRunStatus,
  SourceId,
} from '../domain/types.js';

export interface SelectionSnapshotPersistence {
  readonly toDeselect: readonly CatalogProductRecord[];
  readonly carriedOverToStamp: readonly CatalogProductRecord[];
  readonly toUpsert: readonly CatalogProductRecord[];
  readonly missingButStillActive: readonly CatalogProductRecord[];
  readonly newlyInactive: readonly CatalogProductRecord[];
}

export interface CrawlRunFinishParams {
  readonly endedAt: Date;
  readonly status: CrawlRunStatus;
  readonly isFullSnapshot: boolean;
  readonly selectionVersion: number | null;
  readonly urlsDiscovered: number;
  readonly urlsSelected: number;
  readonly pagesFetched: number;
  readonly successfulParses: number;
  readonly newItems: number;
  readonly changedItems: number;
  readonly missingItems: number;
  readonly inactiveItems: number;
  readonly deselectedItems: number;
  readonly errorsByType: Partial<Record<string, number>>;
}

/**
 * Commits the two state changes that make a selected full snapshot visible:
 * product reconciliation (and its outbox rows) plus successful run metrics.
 * Implementations must make both durable together or neither durable.
 */
export interface SelectionSnapshotCommitter {
  commit(params: {
    readonly diff: SelectionSnapshotPersistence;
    readonly runId: number;
    readonly completion: CrawlRunFinishParams & {
      readonly status: 'success';
      readonly isFullSnapshot: true;
    };
  }): Promise<void>;
}

/**
 * Storage seams. Postgres implementations live in `src/db/*`; tests use an
 * in-memory fake (`test/support/inMemoryRepositories.ts`) so the crawl
 * runner, snapshot diffing, health checks and API can all be exercised with
 * zero real database and zero real network.
 */
export interface ProductRepository {
  getActiveProducts(sourceId: SourceId): Promise<CatalogProductRecord[]>;
  getAllActiveProducts(): Promise<CatalogProductRecord[]>;
  getSelectedActiveProducts(sourceId: SourceId, selectionVersion: number): Promise<CatalogProductRecord[]>;
  applySelectionSnapshot(diff: SelectionSnapshotPersistence): Promise<void>;
  upsertMany(records: readonly CatalogProductRecord[]): Promise<void>;
}

export interface CrawlRunRepository {
  start(params: { sourceId: SourceId; startedAt: Date }): Promise<number>;
  finish(
    runId: number,
    params: CrawlRunFinishParams,
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

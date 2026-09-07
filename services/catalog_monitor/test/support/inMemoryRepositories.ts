import type {
  CrawlRunFinishParams,
  CrawlRunRepository,
  ProductRepository,
  SelectionSnapshotCommitter,
  SelectionSnapshotPersistence,
} from '../../src/crawl/ports.js';
import type {
  CatalogProductRecord,
  CrawlRunMetrics,
  CrawlRunStatus,
  SourceId,
} from '../../src/domain/types.js';

export class InMemoryProductRepository implements ProductRepository {
  private byKey = new Map<string, CatalogProductRecord>();

  private key(sourceId: SourceId, externalId: string): string {
    return `${sourceId}:${externalId}`;
  }

  async getActiveProducts(sourceId: SourceId): Promise<CatalogProductRecord[]> {
    return [...this.byKey.values()].filter((p) => p.sourceId === sourceId && p.isActive);
  }

  async getAllActiveProducts(): Promise<CatalogProductRecord[]> {
    return [...this.byKey.values()].filter((p) => p.isActive);
  }

  async getSelectedActiveProducts(
    sourceId: SourceId,
    selectionVersion: number,
  ): Promise<CatalogProductRecord[]> {
    return [...this.byKey.values()].filter(
      (p) =>
        p.sourceId === sourceId &&
        p.isActive &&
        p.selectionState === 'selected' &&
        p.selectionVersion === selectionVersion,
    );
  }

  async applySelectionSnapshot(diff: SelectionSnapshotPersistence): Promise<void> {
    const nextByKey = new Map<string, CatalogProductRecord>(this.byKey);

    for (const r of diff.toDeselect) {
      const key = this.key(r.sourceId, r.externalId);
      const existing = nextByKey.get(key);
      if (existing) {
        nextByKey.set(key, {
          ...existing,
          selectionState: 'deselected',
          selectionVersion: r.selectionVersion,
          watchTier: 'standard',
          placements: [],
          matchedRuleId: null,
        });
      }
    }

    for (const r of diff.carriedOverToStamp) {
      const key = this.key(r.sourceId, r.externalId);
      const existing = nextByKey.get(key);
      if (existing) {
        nextByKey.set(key, {
          ...existing,
          selectionState: 'selected',
          selectionVersion: r.selectionVersion,
          watchTier: r.watchTier,
          placements: r.placements,
          matchedRuleId: r.matchedRuleId,
          consecutiveMissingSnapshots: 0,
        });
      }
    }

    for (const r of [...diff.toUpsert, ...diff.missingButStillActive, ...diff.newlyInactive]) {
      nextByKey.set(this.key(r.sourceId, r.externalId), r);
    }

    this.byKey = nextByKey;
  }

  /** Test-double transaction used by the selected-snapshot commit seam. */
  async applySelectionSnapshotAndFinish(
    diff: SelectionSnapshotPersistence,
    finish: () => Promise<void>,
  ): Promise<void> {
    const before = new Map(this.byKey);
    try {
      await this.applySelectionSnapshot(diff);
      await finish();
    } catch (error) {
      this.byKey = before;
      throw error;
    }
  }

  async upsertMany(records: readonly CatalogProductRecord[]): Promise<void> {
    for (const r of records) {
      this.byKey.set(this.key(r.sourceId, r.externalId), r);
    }
  }

  // Test-only helpers, not part of ProductRepository.
  seed(records: readonly CatalogProductRecord[]): void {
    for (const r of records) this.byKey.set(this.key(r.sourceId, r.externalId), r);
  }

  all(): CatalogProductRecord[] {
    return [...this.byKey.values()];
  }
}

interface StoredRun extends CrawlRunMetrics {
  id: number;
}

export class InMemoryCrawlRunRepository implements CrawlRunRepository {
  private readonly runs: StoredRun[] = [];
  private nextId = 1;

  async start(params: { sourceId: SourceId; startedAt: Date }): Promise<number> {
    const id = this.nextId++;
    this.runs.push({
      id,
      sourceId: params.sourceId,
      startedAt: params.startedAt,
      endedAt: null,
      status: 'running',
      isFullSnapshot: false,
      selectionVersion: null,
      urlsDiscovered: 0,
      urlsSelected: 0,
      pagesFetched: 0,
      successfulParses: 0,
      newItems: 0,
      changedItems: 0,
      missingItems: 0,
      inactiveItems: 0,
      deselectedItems: 0,
      errorsByType: {},
    });
    return id;
  }

  async finish(
    runId: number,
    params: {
      endedAt: Date;
      status: CrawlRunStatus;
      isFullSnapshot: boolean;
      selectionVersion: number | null;
      urlsDiscovered: number;
      urlsSelected: number;
      pagesFetched: number;
      successfulParses: number;
      newItems: number;
      changedItems: number;
      missingItems: number;
      inactiveItems: number;
      deselectedItems: number;
      errorsByType: Partial<Record<string, number>>;
    },
  ): Promise<void> {
    const run = this.runs.find((r) => r.id === runId);
    if (!run) throw new Error(`No such run: ${runId}`);
    Object.assign(run, params);
  }

  async recentRuns(sourceId: SourceId, limit: number): Promise<CrawlRunMetrics[]> {
    return this.runs
      .filter((r) => r.sourceId === sourceId)
      .sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime())
      .slice(0, limit);
  }

  async lastSuccessfulFullSnapshotRun(sourceId: SourceId): Promise<CrawlRunMetrics | null> {
    const successful = this.runs
      .filter((r) => r.sourceId === sourceId && r.status === 'success' && r.isFullSnapshot)
      .sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime());
    return successful[0] ?? null;
  }

  // Test-only helper for pre-seeding history.
  seedRun(run: Omit<StoredRun, 'id'>): number {
    const id = this.nextId++;
    this.runs.push({ ...run, id });
    return id;
  }
}

/**
 * In-memory equivalent of the Postgres selected-snapshot transaction. It is
 * intentionally composed from the same two repository doubles used by tests.
 */
export class InMemorySelectionSnapshotCommitter implements SelectionSnapshotCommitter {
  constructor(
    private readonly products: InMemoryProductRepository,
    private readonly crawlRuns: InMemoryCrawlRunRepository,
  ) {}

  async commit(params: {
    readonly diff: SelectionSnapshotPersistence;
    readonly runId: number;
    readonly completion: CrawlRunFinishParams & {
      readonly status: 'success';
      readonly isFullSnapshot: true;
    };
  }): Promise<void> {
    await this.products.applySelectionSnapshotAndFinish(
      params.diff,
      () => this.crawlRuns.finish(params.runId, params.completion),
    );
  }
}

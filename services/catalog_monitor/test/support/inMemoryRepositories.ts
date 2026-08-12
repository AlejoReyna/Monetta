import type { CrawlRunRepository, ProductRepository } from '../../src/crawl/ports.js';
import type {
  CatalogProductRecord,
  CrawlRunMetrics,
  CrawlRunStatus,
  SourceId,
} from '../../src/domain/types.js';

export class InMemoryProductRepository implements ProductRepository {
  private readonly byKey = new Map<string, CatalogProductRecord>();

  private key(sourceId: SourceId, externalId: string): string {
    return `${sourceId}:${externalId}`;
  }

  async getActiveProducts(sourceId: SourceId): Promise<CatalogProductRecord[]> {
    return [...this.byKey.values()].filter((p) => p.sourceId === sourceId && p.isActive);
  }

  async getAllActiveProducts(): Promise<CatalogProductRecord[]> {
    return [...this.byKey.values()].filter((p) => p.isActive);
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
      urlsDiscovered: 0,
      pagesFetched: 0,
      successfulParses: 0,
      newItems: 0,
      changedItems: 0,
      missingItems: 0,
      inactiveItems: 0,
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
      urlsDiscovered: number;
      pagesFetched: number;
      successfulParses: number;
      newItems: number;
      changedItems: number;
      missingItems: number;
      inactiveItems: number;
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

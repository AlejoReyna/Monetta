import type pg from 'pg';
import type { CrawlRunRepository } from '../crawl/ports.js';
import type { CrawlRunMetrics, CrawlRunStatus, SourceId } from '../domain/types.js';

interface CrawlRunRow {
  id: string;
  source_id: string;
  started_at: Date;
  ended_at: Date | null;
  status: CrawlRunStatus;
  is_full_snapshot: boolean;
  urls_discovered: number;
  pages_fetched: number;
  successful_parses: number;
  new_items: number;
  changed_items: number;
  missing_items: number;
  inactive_items: number;
  errors_by_type: Record<string, number>;
}

function fromRow(row: CrawlRunRow): CrawlRunMetrics {
  return {
    sourceId: row.source_id as SourceId,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    status: row.status,
    isFullSnapshot: row.is_full_snapshot,
    urlsDiscovered: row.urls_discovered,
    pagesFetched: row.pages_fetched,
    successfulParses: row.successful_parses,
    newItems: row.new_items,
    changedItems: row.changed_items,
    missingItems: row.missing_items,
    inactiveItems: row.inactive_items,
    errorsByType: row.errors_by_type,
  };
}

export class PgCrawlRunRepository implements CrawlRunRepository {
  constructor(private readonly pool: pg.Pool) {}

  async start(params: { sourceId: SourceId; startedAt: Date }): Promise<number> {
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO crawl_runs (source_id, started_at, status) VALUES ($1, $2, 'running')
       RETURNING id`,
      [params.sourceId, params.startedAt],
    );
    return Number.parseInt(rows[0]!.id, 10);
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
    await this.pool.query(
      `UPDATE crawl_runs SET
         ended_at = $2, status = $3, is_full_snapshot = $4, urls_discovered = $5,
         pages_fetched = $6, successful_parses = $7, new_items = $8, changed_items = $9,
         missing_items = $10, inactive_items = $11, errors_by_type = $12
       WHERE id = $1`,
      [
        runId,
        params.endedAt,
        params.status,
        params.isFullSnapshot,
        params.urlsDiscovered,
        params.pagesFetched,
        params.successfulParses,
        params.newItems,
        params.changedItems,
        params.missingItems,
        params.inactiveItems,
        JSON.stringify(params.errorsByType),
      ],
    );
  }

  async recentRuns(sourceId: SourceId, limit: number): Promise<CrawlRunMetrics[]> {
    const { rows } = await this.pool.query<CrawlRunRow>(
      `SELECT * FROM crawl_runs WHERE source_id = $1 ORDER BY started_at DESC LIMIT $2`,
      [sourceId, limit],
    );
    return rows.map(fromRow);
  }

  async lastSuccessfulFullSnapshotRun(sourceId: SourceId): Promise<CrawlRunMetrics | null> {
    const { rows } = await this.pool.query<CrawlRunRow>(
      `SELECT * FROM crawl_runs WHERE source_id = $1 AND status = 'success' AND is_full_snapshot = TRUE
       ORDER BY started_at DESC LIMIT 1`,
      [sourceId],
    );
    return rows[0] ? fromRow(rows[0]) : null;
  }
}

import type pg from 'pg';
import type { CrawlRunFinishParams, CrawlRunRepository } from '../crawl/ports.js';
import type { CrawlRunMetrics, CrawlRunStatus, SourceId } from '../domain/types.js';

interface CrawlRunRow {
  id: string;
  source_id: string;
  started_at: Date;
  ended_at: Date | null;
  status: CrawlRunStatus;
  is_full_snapshot: boolean;
  selection_version?: string | number | null;
  urls_discovered: number;
  urls_selected?: number;
  pages_fetched: number;
  successful_parses: number;
  new_items: number;
  changed_items: number;
  missing_items: number;
  inactive_items: number;
  deselected_items?: number;
  errors_by_type: Record<string, number>;
}

function fromRow(row: CrawlRunRow): CrawlRunMetrics {
  return {
    sourceId: row.source_id as SourceId,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    status: row.status,
    isFullSnapshot: row.is_full_snapshot,
    selectionVersion:
      row.selection_version === null || row.selection_version === undefined
        ? null
        : typeof row.selection_version === 'string'
          ? Number.parseInt(row.selection_version, 10)
          : row.selection_version,
    urlsDiscovered: row.urls_discovered,
    urlsSelected: row.urls_selected ?? 0,
    pagesFetched: row.pages_fetched,
    successfulParses: row.successful_parses,
    newItems: row.new_items,
    changedItems: row.changed_items,
    missingItems: row.missing_items,
    inactiveItems: row.inactive_items,
    deselectedItems: row.deselected_items ?? 0,
    errorsByType: row.errors_by_type,
  };
}

type PgQueryClient = Pick<pg.PoolClient, 'query'>;

/** Updates a run using a caller-owned connection, including a shared transaction. */
export async function finishCrawlRunWithClient(
  client: PgQueryClient,
  runId: number,
  params: CrawlRunFinishParams,
): Promise<void> {
  await client.query(
    `UPDATE crawl_runs SET
       ended_at = $2, status = $3, is_full_snapshot = $4, selection_version = $5,
       urls_discovered = $6, urls_selected = $7, pages_fetched = $8,
       successful_parses = $9, new_items = $10, changed_items = $11,
       missing_items = $12, inactive_items = $13, deselected_items = $14,
       errors_by_type = $15
     WHERE id = $1`,
    [
      runId,
      params.endedAt,
      params.status,
      params.isFullSnapshot,
      params.selectionVersion,
      params.urlsDiscovered,
      params.urlsSelected,
      params.pagesFetched,
      params.successfulParses,
      params.newItems,
      params.changedItems,
      params.missingItems,
      params.inactiveItems,
      params.deselectedItems,
      JSON.stringify(params.errorsByType),
    ],
  );
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
    params: CrawlRunFinishParams,
  ): Promise<void> {
    await finishCrawlRunWithClient(this.pool, runId, params);
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

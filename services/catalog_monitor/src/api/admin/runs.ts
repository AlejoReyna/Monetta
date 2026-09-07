import type { Express, NextFunction, Request, RequestHandler, Response } from 'express';
import { computeEtag } from '../etag.js';
import { SOURCE_IDS, type CrawlRunStatus, type SourceId } from '../../domain/types.js';
import type { CrawlRunRepository } from '../../crawl/ports.js';

/**
 * WP-61 read endpoint: run history + run detail.
 *
 * `CrawlRunMetrics` (the crawl port) carries no run id and no `run_kind`
 * (WP-20's watch/discovery split is not in the domain type yet), but the
 * Runs screen (§ 6.2) filters by kind and opens rows by id — so this module
 * defines its own `AdminRunRecord` with both. The Postgres store reads the
 * `run_kind` column written by migration 008 directly; the repository-backed
 * fallback treats everything as `discovery` with a synthetic id.
 */

export type AdminRunKind = 'discovery' | 'watch';
export type AdminRunStatus = CrawlRunStatus;

const RUN_KINDS: readonly string[] = ['discovery', 'watch'];
const RUN_STATUSES: readonly string[] = ['running', 'success', 'partial', 'failed', 'blocked'];

export interface AdminRunRecord {
  readonly id: string;
  readonly source: SourceId;
  readonly kind: AdminRunKind;
  readonly status: AdminRunStatus;
  readonly startedAt: string;
  readonly endedAt: string | null;
  /** Milliseconds between start and end, null while running. */
  readonly durationMs: number | null;
  readonly selectionVersion: number | null;
  readonly urlsDiscovered: number;
  readonly urlsSelected: number;
  readonly pagesFetched: number;
  readonly successfulParses: number;
  readonly coverage: number | null;
  readonly newItems: number;
  readonly changedItems: number;
  readonly missingItems: number;
  readonly inactiveItems: number;
  readonly deselectedItems: number;
  readonly errorsByType: Readonly<Record<string, number>>;
}

export interface AdminRunListOptions {
  readonly source?: SourceId;
  readonly kind?: AdminRunKind;
  readonly status?: AdminRunStatus;
  readonly limit: number;
  /** Exclusive cursor: page strictly before this run id (newest-first). */
  readonly before?: string;
}

export interface AdminRunStore {
  list(options: AdminRunListOptions): Promise<{ runs: AdminRunRecord[]; nextCursor: string | null }>;
  getById(id: string): Promise<AdminRunRecord | null>;
}

/** In-memory store: the seam tests seed directly. */
export class InMemoryAdminRunStore implements AdminRunStore {
  private readonly runs: AdminRunRecord[] = [];

  seed(runs: readonly AdminRunSeed[]): void {
    for (const run of runs) this.runs.push(toRecord(run));
  }

  async list(options: AdminRunListOptions): Promise<{ runs: AdminRunRecord[]; nextCursor: string | null }> {
    const ordered = this.runs
      .filter((run) => (options.source === undefined ? true : run.source === options.source))
      .filter((run) => (options.kind === undefined ? true : run.kind === options.kind))
      .filter((run) => (options.status === undefined ? true : run.status === options.status))
      .sort((a, b) =>
        b.startedAt.localeCompare(a.startedAt) || b.id.localeCompare(a.id),
      );
    let start = 0;
    if (options.before !== undefined) {
      const index = ordered.findIndex((run) => run.id === options.before);
      start = index === -1 ? ordered.length : index + 1;
    }
    const page = ordered.slice(start, start + options.limit);
    const hasMore = start + options.limit < ordered.length;
    return { runs: page, nextCursor: hasMore && page.length > 0 ? page[page.length - 1]!.id : null };
  }

  async getById(id: string): Promise<AdminRunRecord | null> {
    return this.runs.find((run) => run.id === id) ?? null;
  }
}

export interface AdminRunSeed {
  readonly id: string;
  readonly source: SourceId;
  readonly kind?: AdminRunKind;
  readonly status: AdminRunStatus;
  readonly startedAt: Date | string;
  readonly endedAt?: Date | string | null;
  readonly selectionVersion?: number | null;
  readonly urlsDiscovered?: number;
  readonly urlsSelected?: number;
  readonly pagesFetched?: number;
  readonly successfulParses?: number;
  readonly newItems?: number;
  readonly changedItems?: number;
  readonly missingItems?: number;
  readonly inactiveItems?: number;
  readonly deselectedItems?: number;
  readonly errorsByType?: Readonly<Record<string, number>>;
}

function toRecord(seed: AdminRunSeed): AdminRunRecord {
  const startedAt = typeof seed.startedAt === 'string' ? seed.startedAt : seed.startedAt.toISOString();
  const endedAt =
    seed.endedAt === undefined || seed.endedAt === null
      ? null
      : typeof seed.endedAt === 'string'
        ? seed.endedAt
        : seed.endedAt.toISOString();
  const pagesFetched = seed.pagesFetched ?? 0;
  const successfulParses = seed.successfulParses ?? 0;
  return {
    id: seed.id,
    source: seed.source,
    kind: seed.kind ?? 'discovery',
    status: seed.status,
    startedAt,
    endedAt,
    durationMs:
      endedAt === null ? null : Math.max(Date.parse(endedAt) - Date.parse(startedAt), 0),
    selectionVersion: seed.selectionVersion ?? null,
    urlsDiscovered: seed.urlsDiscovered ?? 0,
    urlsSelected: seed.urlsSelected ?? 0,
    pagesFetched,
    successfulParses,
    coverage: pagesFetched > 0 ? successfulParses / pagesFetched : null,
    newItems: seed.newItems ?? 0,
    changedItems: seed.changedItems ?? 0,
    missingItems: seed.missingItems ?? 0,
    inactiveItems: seed.inactiveItems ?? 0,
    deselectedItems: seed.deselectedItems ?? 0,
    errorsByType: seed.errorsByType ?? {},
  };
}

/** Minimal structural DB seam so this module never imports `pg` directly. */
export interface AdminDbClient {
  query(sql: string, params?: readonly unknown[]): Promise<{ rows: Array<Record<string, unknown>> }>;
}

function toInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function rowToRecord(row: Record<string, unknown>): AdminRunRecord | null {
  const source = String(row.source_id ?? '');
  if (!(SOURCE_IDS as readonly string[]).includes(source)) return null;
  const kind = String(row.run_kind ?? 'discovery');
  if (!(RUN_KINDS as readonly string[]).includes(kind)) return null;
  const status = String(row.status ?? '');
  if (!(RUN_STATUSES as readonly string[]).includes(status)) return null;
  const startedRaw = row.started_at;
  const startedAt = startedRaw instanceof Date ? startedRaw.toISOString() : String(startedRaw ?? '');
  if (startedAt === '') return null;
  const endedRaw = row.ended_at;
  const endedAt = endedRaw === null || endedRaw === undefined
    ? null
    : endedRaw instanceof Date
      ? endedRaw.toISOString()
      : String(endedRaw);
  const pagesFetched = toInt(row.pages_fetched, 0);
  const successfulParses = toInt(row.successful_parses, 0);
  let errorsByType: Record<string, number> = {};
  const rawErrors = row.errors_by_type;
  if (typeof rawErrors === 'string') {
    try {
      const parsed: unknown = JSON.parse(rawErrors);
      if (typeof parsed === 'object' && parsed !== null) {
        errorsByType = Object.fromEntries(
          Object.entries(parsed as Record<string, unknown>)
            .filter(([, n]) => typeof n === 'number' && Number.isFinite(n))
            .map(([k, n]) => [k, n as number]),
        );
      }
    } catch {
      errorsByType = {};
    }
  } else if (typeof rawErrors === 'object' && rawErrors !== null) {
    errorsByType = Object.fromEntries(
      Object.entries(rawErrors as Record<string, unknown>)
        .filter(([, n]) => typeof n === 'number' && Number.isFinite(n))
        .map(([k, n]) => [k, n as number]),
    );
  }
  return {
    id: String(row.id ?? ''),
    source: source as SourceId,
    kind: kind as AdminRunKind,
    status: status as AdminRunStatus,
    startedAt,
    endedAt,
    durationMs: endedAt === null ? null : Math.max(Date.parse(endedAt) - Date.parse(startedAt), 0),
    selectionVersion: row.selection_version === null || row.selection_version === undefined
      ? null
      : toInt(row.selection_version, 0),
    urlsDiscovered: toInt(row.urls_discovered, 0),
    urlsSelected: toInt(row.urls_selected, 0),
    pagesFetched,
    successfulParses,
    coverage: pagesFetched > 0 ? successfulParses / pagesFetched : null,
    newItems: toInt(row.new_items, 0),
    changedItems: toInt(row.changed_items, 0),
    missingItems: toInt(row.missing_items, 0),
    inactiveItems: toInt(row.inactive_items, 0),
    deselectedItems: toInt(row.deselected_items, 0),
    errorsByType,
  };
}

/** Production store: reads `crawl_runs` (+ 008 columns) directly. */
export function createPgAdminRunStore(db: AdminDbClient): AdminRunStore {
  return {
    async list(options: AdminRunListOptions) {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (options.source !== undefined) {
        params.push(options.source);
        conditions.push(`source_id = $${params.length}`);
      }
      if (options.kind !== undefined) {
        params.push(options.kind);
        conditions.push(`run_kind = $${params.length}`);
      }
      if (options.status !== undefined) {
        params.push(options.status);
        conditions.push(`status = $${params.length}`);
      }
      if (options.before !== undefined) {
        params.push(options.before);
        conditions.push(
          `(started_at, id) < (SELECT started_at, id FROM crawl_runs WHERE id = $${params.length})`,
        );
      }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      params.push(options.limit + 1);
      const { rows } = await db.query(
        `SELECT * FROM crawl_runs ${where} ORDER BY started_at DESC, id DESC LIMIT $${params.length}`,
        params,
      );
      const records = rows.map(rowToRecord).filter((r): r is AdminRunRecord => r !== null);
      const page = records.slice(0, options.limit);
      const hasMore = records.length > page.length;
      return {
        runs: page,
        nextCursor: hasMore && page.length > 0 ? page[page.length - 1]!.id : null,
      };
    },
    async getById(id: string) {
      const { rows } = await db.query(`SELECT * FROM crawl_runs WHERE id = $1`, [id]);
      const row = rows[0];
      return row === undefined ? null : rowToRecord(row);
    },
  };
}

/**
 * Fallback when no DB handle is wired (e.g. unit tests that only exercise
 * other endpoints): adapts the crawl port. Kind is always `discovery` here —
 * the port does not carry `run_kind` — and ids are synthetic but stable.
 */
export function createRepositoryAdminRunStore(crawlRuns: CrawlRunRepository): AdminRunStore {
  const syntheticId = (source: SourceId, startedAt: Date, index: number): string =>
    `${source}:${startedAt.toISOString()}#${index}`;
  const toAdmin = (
    source: SourceId,
    metrics: {
      startedAt: Date;
      endedAt: Date | null;
      status: AdminRunStatus;
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
      errorsByType: Readonly<Record<string, number>>;
    },
    index: number,
  ): AdminRunRecord => ({
    id: syntheticId(source, metrics.startedAt, index),
    source,
    kind: 'discovery',
    status: metrics.status,
    startedAt: metrics.startedAt.toISOString(),
    endedAt: metrics.endedAt?.toISOString() ?? null,
    durationMs:
      metrics.endedAt === null
        ? null
        : Math.max(metrics.endedAt.getTime() - metrics.startedAt.getTime(), 0),
    selectionVersion: metrics.selectionVersion,
    urlsDiscovered: metrics.urlsDiscovered,
    urlsSelected: metrics.urlsSelected,
    pagesFetched: metrics.pagesFetched,
    successfulParses: metrics.successfulParses,
    coverage: metrics.pagesFetched > 0 ? metrics.successfulParses / metrics.pagesFetched : null,
    newItems: metrics.newItems,
    changedItems: metrics.changedItems,
    missingItems: metrics.missingItems,
    inactiveItems: metrics.inactiveItems,
    deselectedItems: metrics.deselectedItems,
    errorsByType: metrics.errorsByType,
  });
  return {
    async list(options: AdminRunListOptions) {
      const sources = options.source !== undefined ? [options.source] : [...SOURCE_IDS];
      const collected: AdminRunRecord[] = [];
      for (const source of sources) {
        const recent = await crawlRuns.recentRuns(source, 50);
        recent.forEach((run, index) => {
          collected.push(
            toAdmin(source, {
              ...run,
              errorsByType: run.errorsByType as Readonly<Record<string, number>>,
            }, index),
          );
        });
      }
      const ordered = collected
        .filter((run) => (options.kind === undefined ? true : run.kind === options.kind))
        .filter((run) => (options.status === undefined ? true : run.status === options.status))
        .sort((a, b) => b.startedAt.localeCompare(a.startedAt) || b.id.localeCompare(a.id));
      let start = 0;
      if (options.before !== undefined) {
        const index = ordered.findIndex((run) => run.id === options.before);
        start = index === -1 ? ordered.length : index + 1;
      }
      const page = ordered.slice(start, start + options.limit);
      const hasMore = start + options.limit < ordered.length;
      return { runs: page, nextCursor: hasMore && page.length > 0 ? page[page.length - 1]!.id : null };
    },
    async getById(id: string) {
      const { runs } = await this.list({ limit: 200 });
      return runs.find((run) => run.id === id) ?? null;
    },
  };
}

export const ADMIN_RUNS_LIMIT_DEFAULT = 50;
export const ADMIN_LIST_LIMIT_MAX = 200;

export function clampLimit(raw: unknown, fallback: number): number {
  if (typeof raw !== 'string' || raw.trim() === '') return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, ADMIN_LIST_LIMIT_MAX);
}

function sendEtagged(req: Request, res: Response, body: unknown): void {
  const json = JSON.stringify(body);
  const etag = computeEtag(json);
  res.setHeader('ETag', etag);
  if (req.header('If-None-Match') === etag) {
    res.status(304).end();
    return;
  }
  res.status(200).json(body);
}

function asyncRoute(handler: (req: Request, res: Response) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction): void => {
    void handler(req, res).catch(next);
  };
}

function invalidSource(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value !== '' &&
    !(SOURCE_IDS as readonly string[]).includes(value)
  );
}

export interface AdminRunsRouteDeps {
  readonly gate: RequestHandler;
  readonly store: AdminRunStore;
}

export function registerAdminRunsRoutes(app: Express, deps: AdminRunsRouteDeps): void {
  app.get(
    '/admin/runs',
    deps.gate,
    asyncRoute(async (req, res) => {
      if (invalidSource(req.query.source)) {
        res.status(400).json({ error: 'invalid_source' });
        return;
      }
      const kind = typeof req.query.kind === 'string' && req.query.kind !== '' ? req.query.kind : undefined;
      if (kind !== undefined && !(RUN_KINDS as readonly string[]).includes(kind)) {
        res.status(400).json({ error: 'invalid_kind' });
        return;
      }
      const status = typeof req.query.status === 'string' && req.query.status !== '' ? req.query.status : undefined;
      if (status !== undefined && !(RUN_STATUSES as readonly string[]).includes(status)) {
        res.status(400).json({ error: 'invalid_status' });
        return;
      }
      const before = typeof req.query.before === 'string' && req.query.before !== '' ? req.query.before : undefined;
      const { runs, nextCursor } = await deps.store.list({
        source: typeof req.query.source === 'string' && req.query.source !== ''
          ? (req.query.source as SourceId)
          : undefined,
        kind: kind as AdminRunKind | undefined,
        status: status as AdminRunStatus | undefined,
        limit: clampLimit(req.query.limit, ADMIN_RUNS_LIMIT_DEFAULT),
        before,
      });
      sendEtagged(req, res, { runs, nextCursor });
    }),
  );

  app.get(
    '/admin/runs/:id',
    deps.gate,
    asyncRoute(async (req, res) => {
      const run = await deps.store.getById(req.params.id as string);
      if (run === null) {
        res.status(404).json({ error: 'run_not_found' });
        return;
      }
      sendEtagged(req, res, { run });
    }),
  );
}

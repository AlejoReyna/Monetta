import type { Express, NextFunction, Request, RequestHandler, Response } from 'express';
import { computeEtag } from '../etag.js';
import { SOURCE_IDS, type SourceId } from '../../domain/types.js';
import type { CatalogProductRecord } from '../../domain/types.js';
import type { CrawlRunRepository, ProductRepository } from '../../crawl/ports.js';
import { evaluateSourceHealth } from '../../monitor/health.js';
import { isValidPlacement, type Placement } from '../../selection/types.js';
import type { AdminAlertStore } from './alerts.js';
import type { AdminDbClient, AdminRunRecord, AdminRunStore } from './runs.js';

/**
 * WP-61 read endpoint: one batched call for the whole Overview screen
 * (§ 6.1) — per-source health, last discovery + last watch run, separate
 * freshness clocks, selected/served/deselected/inactive counts, today's
 * page budget, the current selection version, and the 5 most recent alerts.
 *
 * Six independent polls every 15 s from a few tabs, against a 2-vCPU box
 * that is also crawling, is a self-inflicted load problem — hence the
 * aggregate (§ 5).
 */

export interface AdminSelectionInfo {
  readonly version: number;
  readonly hash: string;
  readonly appliedBy: string;
  readonly appliedAt: string;
  readonly note: string | null;
}

export type AdminSelectionProvider = () => Promise<AdminSelectionInfo | null>;

export interface AdminPageBudget {
  readonly limit: number;
  readonly usedToday: number;
  readonly remaining: number;
}

export type AdminPageBudgetProvider = () => Promise<{ limit: number; usedToday: number }>;

export type AdminProductLister = () => Promise<CatalogProductRecord[]>;

export interface AdminRunSummary {
  readonly id: string;
  readonly kind: 'discovery' | 'watch';
  readonly status: string;
  readonly startedAt: string;
  readonly endedAt: string | null;
}

export interface AdminSourceOverview {
  readonly source: SourceId;
  readonly status: 'healthy' | 'unhealthy';
  readonly reasons: readonly string[];
  readonly freshness: {
    /** Hours since the last successful full discovery snapshot (health basis). */
    readonly discoveryHours: number | null;
    /** Hours since the last successful watch run; null when never watched. */
    readonly watchHours: number | null;
  };
  readonly lastDiscoveryRun: AdminRunSummary | null;
  readonly lastWatchRun: AdminRunSummary | null;
  readonly counts: {
    readonly selected: number;
    readonly served: number;
    readonly deselected: number;
    readonly inactive: number;
  };
  readonly lastSuccessfulRunAt: string | null;
  readonly coverage: number | null;
}

/** Minutes without a successful watch run before `watch_stale` is reported. */
export const WATCH_STALE_MINUTES_DEFAULT = 360;

function toSummary(run: AdminRunRecord): AdminRunSummary {
  return {
    id: run.id,
    kind: run.kind,
    status: run.status,
    startedAt: run.startedAt,
    endedAt: run.endedAt,
  };
}

/** Latest selection row; null when no version was ever applied (or 008-only DB). */
export function createPgSelectionProvider(db: AdminDbClient): AdminSelectionProvider {
  return async () => {
    try {
      const { rows } = await db.query(
        `SELECT version, hash, applied_by, applied_at, note
           FROM selection_versions
          ORDER BY version DESC
          LIMIT 1`,
      );
      const row = rows[0];
      if (row === undefined) return null;
      const appliedRaw = row.applied_at;
      return {
        version: Number(row.version),
        hash: String(row.hash ?? ''),
        appliedBy: String(row.applied_by ?? ''),
        appliedAt: appliedRaw instanceof Date ? appliedRaw.toISOString() : String(appliedRaw ?? ''),
        note: typeof row.note === 'string' ? row.note : null,
      };
    } catch (error) {
      if (isUndefinedTable(error)) return null;
      throw error;
    }
  };
}

/** Today's page consumption summed from `crawl_runs` over the last 24 h. */
export function createPgPageBudgetProvider(db: AdminDbClient, limit: number): AdminPageBudgetProvider {
  return async () => {
    const { rows } = await db.query(
      `SELECT COALESCE(SUM(pages_fetched), 0) AS used_today
         FROM crawl_runs
        WHERE started_at > now() - interval '24 hours'`,
    );
    const raw = rows[0]?.used_today;
    const usedToday = typeof raw === 'number'
      ? raw
      : typeof raw === 'string' && raw.trim() !== ''
        ? Number.parseInt(raw, 10)
        : 0;
    return { limit, usedToday: Number.isFinite(usedToday) ? usedToday : 0 };
  };
}

/** Fallback budget over any run store (used when no DB handle is wired). */
export function createRunStorePageBudgetProvider(
  runs: AdminRunStore,
  limit: number,
  now: () => Date = () => new Date(),
): AdminPageBudgetProvider {
  return async () => {
    const cutoff = now().getTime() - 24 * 3_600_000;
    const { runs: recent } = await runs.list({ limit: 200 });
    const usedToday = recent
      .filter((run) => Date.parse(run.startedAt) > cutoff)
      .reduce((sum, run) => sum + run.pagesFetched, 0);
    return { limit, usedToday };
  };
}

/** Counts need every row; the crawl port only exposes active products. */
export function createPgProductLister(db: AdminDbClient): AdminProductLister {
  return async () => {
    const { rows } = await db.query(
      `SELECT source_id, external_id, canonical_url, title, brand, category,
              image_url, price_usd, availability, fingerprint,
              first_seen_at, last_seen_at, last_changed_at, is_active,
              consecutive_missing_snapshots, selection_state, selection_version,
              watch_tier, placements, matched_rule_id
         FROM products`,
    );
    return rows.flatMap((row): CatalogProductRecord[] => {
      const source = String(row.source_id ?? '');
      if (!(SOURCE_IDS as readonly string[]).includes(source)) return [];
      const toDate = (value: unknown): Date =>
        value instanceof Date ? value : new Date(String(value ?? 0));
      const priceRaw = row.price_usd;
      const placementsRaw = row.placements;
      const placements = Array.isArray(placementsRaw)
        ? (placementsRaw as unknown[]).filter(
            (p): p is Placement => typeof p === 'string' && isValidPlacement(p),
          )
        : [];
      return [
        {
          sourceId: source as SourceId,
          externalId: String(row.external_id ?? ''),
          canonicalUrl: String(row.canonical_url ?? ''),
          title: String(row.title ?? ''),
          brand: String(row.brand ?? ''),
          category: typeof row.category === 'string' ? row.category : null,
          imageUrl: typeof row.image_url === 'string' ? row.image_url : null,
          priceUsd: priceRaw === null || priceRaw === undefined ? null : Number.parseFloat(String(priceRaw)),
          availability:
            row.availability === 'inStock' || row.availability === 'outOfStock' ? row.availability : 'unknown',
          // Fingerprint stays server-side — it is only read so the row
          // shape stays complete for counting; it never leaves this module.
          fingerprint: typeof row.fingerprint === 'string' ? row.fingerprint : '',
          firstSeenAt: toDate(row.first_seen_at),
          lastSeenAt: toDate(row.last_seen_at),
          lastChangedAt: toDate(row.last_changed_at),
          isActive: row.is_active === true,
          consecutiveMissingSnapshots:
            typeof row.consecutive_missing_snapshots === 'number' ? row.consecutive_missing_snapshots : 0,
          selectionState: row.selection_state === 'deselected' ? 'deselected' : 'selected',
          selectionVersion:
            row.selection_version === null || row.selection_version === undefined
              ? null
              : Number(row.selection_version),
          watchTier: row.watch_tier === 'pinned' ? 'pinned' : 'standard',
          placements,
          matchedRuleId: typeof row.matched_rule_id === 'string' ? row.matched_rule_id : null,
        } as CatalogProductRecord,
      ];
    });
  };
}

/** Fallback lister: active products only (inactive counts read 0). */
export function createRepositoryProductLister(products: ProductRepository): AdminProductLister {
  return () => products.getAllActiveProducts();
}

function isUndefinedTable(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code: unknown }).code === '42P01'
  );
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

export interface AdminOverviewRouteDeps {
  readonly gate: RequestHandler;
  readonly now?: () => Date;
  readonly enabledSourceIds?: readonly SourceId[];
  readonly crawlRuns: CrawlRunRepository;
  readonly runStore: AdminRunStore;
  readonly listAllProducts: AdminProductLister;
  readonly getSelection: AdminSelectionProvider;
  readonly getPageBudget: AdminPageBudgetProvider;
  readonly alerts: AdminAlertStore;
  readonly watchStaleMinutes?: number;
}

export function registerAdminOverviewRoute(app: Express, deps: AdminOverviewRouteDeps): void {
  app.get(
    '/admin/overview',
    deps.gate,
    asyncRoute(async (req, res) => {
      const now = (deps.now ?? (() => new Date()))();
      const sources = deps.enabledSourceIds ?? SOURCE_IDS;
      const [allProducts, budget, selection, recentAlerts] = await Promise.all([
        deps.listAllProducts(),
        deps.getPageBudget(),
        deps.getSelection(),
        deps.alerts.list(5, now),
      ]);

      const bySource = new Map<SourceId, CatalogProductRecord[]>();
      for (const source of sources) bySource.set(source, []);
      for (const record of allProducts) {
        const bucket = bySource.get(record.sourceId);
        if (bucket !== undefined) bucket.push(record);
      }

      const views = await Promise.all(
        sources.map(async (source): Promise<AdminSourceOverview> => {
          const [health, discovery, watch] = await Promise.all([
            evaluateSourceHealth(source, deps.crawlRuns, now),
            deps.runStore.list({ source, kind: 'discovery', limit: 1 }),
            deps.runStore.list({ source, kind: 'watch', limit: 1 }),
          ]);
          const lastDiscovery = discovery.runs[0] ?? null;
          const lastWatch = watch.runs[0] ?? null;
          const lastSuccessfulWatch = watch.runs.find((run) => run.status === 'success') ?? null;
          const watchHours =
            lastSuccessfulWatch === null
              ? null
              : (now.getTime() - Date.parse(lastSuccessfulWatch.startedAt)) / 3_600_000;
          // `watch_stale` is derived here (not in `monitor/health.ts`): the
          // watch tier is WP-20's and has no health reason of its own yet.
          const staleAfter = deps.watchStaleMinutes ?? WATCH_STALE_MINUTES_DEFAULT;
          const reasons: string[] =
            watchHours === null || watchHours * 60 > staleAfter
              ? [...health.reasons, 'watch_stale']
              : [...health.reasons];
          const rows = bySource.get(source) ?? [];
          return {
            source,
            status: reasons.length === 0 ? 'healthy' : 'unhealthy',
            reasons,
            freshness: { discoveryHours: health.freshnessHours, watchHours },
            lastDiscoveryRun: lastDiscovery === null ? null : toSummary(lastDiscovery),
            lastWatchRun: lastWatch === null ? null : toSummary(lastWatch),
            counts: {
              selected: rows.filter((r) => r.selectionState === 'selected').length,
              served: rows.filter(
                (r) =>
                  r.selectionState === 'selected' &&
                  r.isActive &&
                  !(r.placements as readonly string[]).includes('hidden'),
              ).length,
              deselected: rows.filter((r) => r.selectionState === 'deselected').length,
              inactive: rows.filter((r) => !r.isActive).length,
            },
            lastSuccessfulRunAt: health.lastSuccessfulRunAt?.toISOString() ?? null,
            coverage: health.lastRequiredFieldCoverage,
          };
        }),
      );

      const overall = views.every((view) => view.status === 'healthy') ? 'healthy' : 'degraded';
      sendEtagged(req, res, {
        generatedAt: now.toISOString(),
        status: overall,
        sources: views,
        pageBudget: {
          limit: budget.limit,
          usedToday: budget.usedToday,
          remaining: Math.max(budget.limit - budget.usedToday, 0),
        } satisfies AdminPageBudget,
        selection,
        alerts: recentAlerts,
      });
    }),
  );
}

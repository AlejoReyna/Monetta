import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import express, { type Express, type NextFunction, type Request, type Response } from 'express';
import compression from 'compression';
import { renderCatalogFeedBody } from './feed.js';
import { evaluateSourceHealth } from '../monitor/health.js';
import { SOURCE_IDS } from '../domain/types.js';
import { logger } from '../logger.js';
import { loadConfig } from '../config.js';
import { getPool, closePool } from '../db/pool.js';
import { PgProductRepository } from '../db/pgProductRepository.js';
import { PgCrawlRunRepository } from '../db/pgCrawlRunRepository.js';
import type { CrawlRunRepository, ProductRepository } from '../crawl/ports.js';
import type { SourceHealth } from '../monitor/health.js';
import type { SourceId } from '../domain/types.js';
import { registerInternalAdminRoutes } from './internalAdmin.js';
import { dashboardCors, parseDashboardOrigins } from './cors.js';
import { PgDashboardSessionRepository } from '../db/pgSessionRepository.js';
import {
  InMemoryDashboardSessionStore,
  registerDashboardSessionRoutes,
  requireDashboardSession,
  type DashboardSessionStore,
} from './session.js';
import type { SourcePolicyRepository } from '../admin/sourcePolicy.js';
import {
  createPgAdminRunStore,
  createRepositoryAdminRunStore,
  registerAdminRunsRoutes,
  type AdminDbClient,
  type AdminRunStore,
} from './admin/runs.js';
import {
  createPgAdminProductStore,
  createRepositoryAdminProductStore,
  registerAdminProductsRoutes,
  type AdminProductStore,
} from './admin/products.js';
import {
  createPgAdminEventStore,
  InMemoryAdminEventStore,
  registerAdminEventsRoutes,
  type AdminEventStore,
} from './admin/events.js';
import {
  ALERT_DEDUPE_WINDOW_HOURS_DEFAULT,
  createPgAdminAlertStore,
  InMemoryAdminAlertStore,
  registerAdminAlertsRoutes,
  type AdminAlertStore,
} from './admin/alerts.js';
import {
  createPgPageBudgetProvider,
  createPgProductLister,
  createPgSelectionProvider,
  createRepositoryProductLister,
  createRunStorePageBudgetProvider,
  registerAdminOverviewRoute,
  type AdminPageBudgetProvider,
  type AdminProductLister,
  type AdminSelectionProvider,
} from './admin/overview.js';
import {
  createPgSelectionVersionStore,
  InMemorySelectionVersionStore,
  registerAdminSelectionRoutes,
  type SelectionVersionStore,
} from './admin/selection.js';
import { PgSourcePolicyRepository } from '../db/pgSourcePolicyRepository.js';
import {
  PgInternalRequestReplayRepository,
  type InternalRequestReplayRepository,
} from './internalReplay.js';
import type { CatalogCurationPolicy } from '../catalog/curation.js';
import type { RetailPricingPolicy } from '../pricing/commission.js';

export interface ServerDeps {
  readonly products: ProductRepository;
  readonly crawlRuns: CrawlRunRepository;
  readonly now?: () => Date;
  /** Test seam; production defaults to the documented 10-per-source floor. */
  readonly minimumProductsPerSource?: number;
  readonly curationPolicy?: CatalogCurationPolicy;
  readonly pricingPolicy?: RetailPricingPolicy;
  readonly enabledSourceIds?: readonly SourceId[];
  readonly policies?: SourcePolicyRepository;
  readonly internalServiceSecret?: string;
  readonly internalRequestReplay?: InternalRequestReplayRepository;
  /** WP-60 dashboard console. When omitted, CORS emits no allowlist headers and `/admin/session` is unmounted. */
  readonly dashboardOrigins?: readonly string[];
  readonly dashboardPassphraseVerifier?: string | null;
  readonly dashboardSessionTtlHours?: number;
  readonly dashboardSessions?: DashboardSessionStore;
  /**
   * WP-61 read-model seam. Production passes the pg pool (structural —
   * this file never imports `pg`); tests inject in-memory stores.
   * The `/admin/*` reads mount only when `dashboardPassphraseVerifier`
   * is set, always behind `requireDashboardSession`.
   */
  readonly adminDb?: AdminDbClient;
  /** Today's page budget ceiling (`DAILY_PAGE_BUDGET`, default 3000). */
  readonly dailyPageBudget?: number;
  readonly alertDedupeWindowHours?: number;
  readonly adminStores?: {
    readonly runs?: AdminRunStore;
    readonly products?: AdminProductStore;
    readonly events?: AdminEventStore;
    readonly alerts?: AdminAlertStore;
    readonly selectionVersions?: SelectionVersionStore;
    readonly listAllProducts?: AdminProductLister;
    readonly getSelection?: AdminSelectionProvider;
    readonly getPageBudget?: AdminPageBudgetProvider;
  };
}

export function createApp(deps: ServerDeps): Express {
  const app = express();
  app.disable('x-powered-by');
  app.use((req: Request, res: Response, next: NextFunction) => {
    const requestId = `req_${randomUUID()}`;
    const startedAt = Date.now();
    res.locals.requestId = requestId;
    res.setHeader('X-Request-Id', requestId);
    res.once('finish', () => {
      logger.info('http request completed', {
        requestId,
        method: req.method,
        path: req.path,
        status: res.statusCode,
        latencyMs: Date.now() - startedAt,
      });
    });
    next();
  });
  app.use(express.json({ limit: '32kb' }));
  // WP-60 exact-origin CORS (CATALOG_DASHBOARD.md § 4). Empty allowlist =
  // no CORS headers; never a 403 for non-matching origins.
  app.use(dashboardCors(deps.dashboardOrigins ?? []));
  if (deps.dashboardPassphraseVerifier) {
    const dashboardStore = deps.dashboardSessions ?? new InMemoryDashboardSessionStore();
    registerDashboardSessionRoutes(app, {
      store: dashboardStore,
      passphraseVerifier: deps.dashboardPassphraseVerifier,
      ttlHours: deps.dashboardSessionTtlHours,
      now: deps.now,
    });
    // WP-61 reads: session-gated, never mounted without the verifier.
    const gate = requireDashboardSession({ store: dashboardStore, now: deps.now });
    const adminDb = deps.adminDb;
    const runStore = deps.adminStores?.runs ??
      (adminDb !== undefined ? createPgAdminRunStore(adminDb) : createRepositoryAdminRunStore(deps.crawlRuns));
    const productStore = deps.adminStores?.products ??
      (adminDb !== undefined
        ? createPgAdminProductStore(adminDb)
        : createRepositoryAdminProductStore(deps.products));
    const eventStore = deps.adminStores?.events ??
      (adminDb !== undefined ? createPgAdminEventStore(adminDb) : new InMemoryAdminEventStore());
    const dedupeHours = deps.alertDedupeWindowHours ?? ALERT_DEDUPE_WINDOW_HOURS_DEFAULT;
    const alertStore = deps.adminStores?.alerts ??
      (adminDb !== undefined ? createPgAdminAlertStore(adminDb, dedupeHours) : new InMemoryAdminAlertStore(dedupeHours));
    const budgetLimit = deps.dailyPageBudget ?? 3000;
    registerAdminOverviewRoute(app, {
      gate,
      now: deps.now,
      enabledSourceIds: deps.enabledSourceIds,
      crawlRuns: deps.crawlRuns,
      runStore,
      listAllProducts: deps.adminStores?.listAllProducts ??
        (adminDb !== undefined ? createPgProductLister(adminDb) : createRepositoryProductLister(deps.products)),
      getSelection: deps.adminStores?.getSelection ??
        (adminDb !== undefined ? createPgSelectionProvider(adminDb) : (async () => null)),
      getPageBudget: deps.adminStores?.getPageBudget ??
        (adminDb !== undefined
          ? createPgPageBudgetProvider(adminDb, budgetLimit)
          : createRunStorePageBudgetProvider(runStore, budgetLimit, deps.now)),
      alerts: alertStore,
    });
    registerAdminRunsRoutes(app, { gate, store: runStore });
    registerAdminProductsRoutes(app, { gate, store: productStore });
    registerAdminEventsRoutes(app, { gate, store: eventStore, now: deps.now });
    registerAdminAlertsRoutes(app, { gate, store: alertStore, now: deps.now });
    // WP-62 selection console: session-gated, never mounted without the
    // verifier. Feed preview renders the public feed body for the same
    // state through the shared builder, so it is byte-identical by
    // construction.
    const selectionVersions = deps.adminStores?.selectionVersions ??
      (adminDb !== undefined
        ? createPgSelectionVersionStore(adminDb, deps.now)
        : new InMemorySelectionVersionStore());
    registerAdminSelectionRoutes(app, {
      gate,
      store: selectionVersions,
      now: deps.now,
      buildFeed: async () => {
        const [activeProducts, healthBySource] = await Promise.all([
          deps.products.getAllActiveProducts(),
          allSourceHealth(deps),
        ]);
        return renderCatalogFeedBody({
          activeProducts,
          healthBySource,
          enabledSourceIds: deps.enabledSourceIds,
          minimumProductsPerSource: deps.minimumProductsPerSource,
          curationPolicy: deps.curationPolicy,
          pricingPolicy: deps.pricingPolicy,
        });
      },
    });
  }
  // threshold: 0 — the catalog payload is small JSON, and "use gzip where
  // supported" should not silently stop applying once the response shrinks
  // below compression's 1kb default.
  app.use(compression({ threshold: 0 }));

  // Process liveness is intentionally separate from crawl/data health. A
  // deployment can serve the dated catalog floor while /healthz truthfully
  // remains degraded until a live US crawl succeeds.
  app.get('/livez', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/healthz', async (_req: Request, res: Response, next: NextFunction) => {
    try {
      const healthBySource = await allSourceHealth(deps);
      const overall = [...healthBySource.values()].every((h) => h.status === 'healthy')
        ? 'ok'
        : 'degraded';

      res.status(overall === 'ok' ? 200 : 503).json({
        status: overall,
        sources: [...healthBySource.values()].map((h) => ({
          source: h.sourceId,
          status: h.status,
          reasons: h.reasons,
          lastSuccessfulRunAt: h.lastSuccessfulRunAt?.toISOString() ?? null,
          freshnessHours: h.freshnessHours,
        })),
      });
    } catch (error) {
      next(error);
    }
  });

  app.get('/v1/external-catalog', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const [activeProducts, healthBySource] = await Promise.all([
        deps.products.getAllActiveProducts(),
        allSourceHealth(deps),
      ]);
      // Same builder as `/admin/feed-preview` (WP-62) — one code path means
      // the preview cannot drift from the public feed.
      const { json, etag } = renderCatalogFeedBody({
        activeProducts,
        healthBySource,
        enabledSourceIds: deps.enabledSourceIds,
        minimumProductsPerSource: deps.minimumProductsPerSource,
        curationPolicy: deps.curationPolicy,
        pricingPolicy: deps.pricingPolicy,
      });

      res.setHeader('ETag', etag);
      res.setHeader('Cache-Control', 'public, max-age=60');

      const ifNoneMatch = req.headers['if-none-match'];
      if (ifNoneMatch === etag) {
        res.status(304).end();
        return;
      }

      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.status(200).send(json);
    } catch (error) {
      next(error);
    }
  });

  if (deps.policies !== undefined && deps.internalServiceSecret !== undefined) {
    registerInternalAdminRoutes(app, {
      products: deps.products,
      crawlRuns: deps.crawlRuns,
      policies: deps.policies,
      replay: deps.internalRequestReplay,
      secret: deps.internalServiceSecret,
      now: deps.now,
      enabledSourceIds: deps.enabledSourceIds,
    });
  }

  // Catch-all error handler: never leak internals (stack traces, DB errors,
  // raw HTML from a scraped page) into the HTTP response.
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    logger.error('unhandled API error', { error: err instanceof Error ? err.message : String(err) });
    res.status(500).json({ error: 'internal_error' });
  });

  return app;
}

async function allSourceHealth(deps: ServerDeps): Promise<Map<SourceId, SourceHealth>> {
  const entries = await Promise.all(
    (deps.enabledSourceIds ?? SOURCE_IDS).map(
      async (id) => [id, await evaluateSourceHealth(id, deps.crawlRuns, deps.now?.())] as const,
    ),
  );
  return new Map(entries);
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  const config = loadConfig();
  const pool = getPool();
  // WP-60 dashboard env (read here so `src/config.ts` stays untouched by this WP).
  const dashboardOrigins = parseDashboardOrigins(process.env.DASHBOARD_ORIGINS ?? '');
  const dashboardVerifier = (process.env.DASHBOARD_PASSPHRASE_VERIFIER ?? '').trim() || null;
  const dashboardTtl = Number.parseInt(process.env.DASHBOARD_SESSION_TTL_HOURS ?? '12', 10);
  const dailyBudgetRaw = Number.parseInt(process.env.DAILY_PAGE_BUDGET ?? '3000', 10);
  const app = createApp({
    products: new PgProductRepository(pool),
    crawlRuns: new PgCrawlRunRepository(pool),
    curationPolicy: {
      fashionItemsPerSource: config.fashionItemsPerSource,
      perfumeItemsPerSource: config.perfumeItemsPerSource,
      maximumItems: config.maximumCatalogItems,
    },
    pricingPolicy: {
      usdToMxnRate: config.usdToMxnRate,
      defaultCommissionBps: config.defaultCommissionBps,
      highValueThresholdMxn: config.highValueThresholdMxn,
      highValueCommissionBps: config.highValueCommissionBps,
      sourceCommissionBps: config.sourceCommissionBps,
      productCommissionBps: config.productCommissionBps,
    },
    enabledSourceIds: config.enabledSourceIds,
    policies: new PgSourcePolicyRepository(pool),
    internalServiceSecret: config.internalServiceSecret ?? undefined,
    internalRequestReplay: new PgInternalRequestReplayRepository(pool),
    dashboardOrigins,
    adminDb: pool,
    dailyPageBudget: Number.isFinite(dailyBudgetRaw) && dailyBudgetRaw > 0 ? dailyBudgetRaw : 3000,
    ...(dashboardVerifier === null ? {} : {
      dashboardPassphraseVerifier: dashboardVerifier,
      dashboardSessionTtlHours: Number.isFinite(dashboardTtl) && dashboardTtl > 0 ? dashboardTtl : 12,
      dashboardSessions: new PgDashboardSessionRepository(pool),
    }),
  });
  const server = app.listen(config.port, () => {
    logger.info('catalog monitor API listening', { port: config.port });
  });

  let shuttingDown = false;
  const shutdown = (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info('API shutting down', { signal });
    server.close(async () => {
      await closePool();
      process.exit(0);
    });
    // Force-exit if in-flight requests don't drain in time.
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.once('SIGTERM', () => shutdown('SIGTERM'));
  process.once('SIGINT', () => shutdown('SIGINT'));
}

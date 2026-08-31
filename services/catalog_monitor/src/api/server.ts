import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import express, { type Express, type NextFunction, type Request, type Response } from 'express';
import compression from 'compression';
import { buildExternalCatalogResponse } from './schema.js';
import { computeEtag } from './etag.js';
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
import type { SourcePolicyRepository } from '../admin/sourcePolicy.js';
import { PgSourcePolicyRepository } from '../db/pgSourcePolicyRepository.js';
import {
  PgInternalRequestReplayRepository,
  type InternalRequestReplayRepository,
} from './internalReplay.js';
import {
  MINIMUM_PRODUCTS_PER_SOURCE,
  withMinimumUsCatalog,
} from '../catalog/curatedUsCatalog.js';
import {
  curateCatalog,
  DEFAULT_CURATION_POLICY,
  type CatalogCurationPolicy,
} from '../catalog/curation.js';
import {
  DEFAULT_RETAIL_PRICING_POLICY,
  type RetailPricingPolicy,
} from '../pricing/commission.js';

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
      const enabledSourceIds = deps.enabledSourceIds ?? SOURCE_IDS;
      const enabledSources = new Set<SourceId>(enabledSourceIds);
      const presentableProducts = withMinimumUsCatalog(
        activeProducts.filter((record) => enabledSources.has(record.sourceId)),
        deps.minimumProductsPerSource ?? MINIMUM_PRODUCTS_PER_SOURCE,
      ).filter((record) => enabledSources.has(record.sourceId));
      const curatedProducts = curateCatalog(
        presentableProducts,
        deps.curationPolicy ?? DEFAULT_CURATION_POLICY,
      );
      const body = buildExternalCatalogResponse(
        curatedProducts,
        healthBySource,
        deps.pricingPolicy ?? DEFAULT_RETAIL_PRICING_POLICY,
        enabledSourceIds,
      );
      const json = JSON.stringify(body);
      const etag = computeEtag(json);

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

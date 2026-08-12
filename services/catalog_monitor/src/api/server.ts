import { fileURLToPath } from 'node:url';
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
import {
  MINIMUM_PRODUCTS_PER_SOURCE,
  withMinimumUsCatalog,
} from '../catalog/curatedUsCatalog.js';

export interface ServerDeps {
  readonly products: ProductRepository;
  readonly crawlRuns: CrawlRunRepository;
  readonly now?: () => Date;
  /** Test seam; production defaults to the documented 10-per-source floor. */
  readonly minimumProductsPerSource?: number;
}

export function createApp(deps: ServerDeps): Express {
  const app = express();
  app.disable('x-powered-by');
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
      const presentableProducts = withMinimumUsCatalog(
        activeProducts,
        deps.minimumProductsPerSource ?? MINIMUM_PRODUCTS_PER_SOURCE,
      );
      const body = buildExternalCatalogResponse(presentableProducts, healthBySource);
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
    SOURCE_IDS.map(async (id) => [id, await evaluateSourceHealth(id, deps.crawlRuns, deps.now?.())] as const),
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

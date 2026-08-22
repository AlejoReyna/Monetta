import cron from 'node-cron';
import { loadConfig } from '../config.js';
import { logger } from '../logger.js';
import { getPool, closePool } from '../db/pool.js';
import { PgProductRepository } from '../db/pgProductRepository.js';
import { PgCrawlRunRepository } from '../db/pgCrawlRunRepository.js';
import { adapterFor } from '../adapters/registry.js';
import { crawlSourceWithRobotsGate } from '../crawl/guardedCrawl.js';
import { DomainRateLimiter } from '../crawl/rateLimiter.js';
import { liveFetch } from '../crawl/httpFetcher.js';
import { renderWithPlaywright } from '../crawl/playwrightFallback.js';
import { withDbLock, SOURCE_LOCK_KEYS } from '../db/advisoryLock.js';
import type { BrandAdapter } from '../adapters/types.js';
import type pg from 'pg';

/**
 * The one place a daily cron job gets registered. If `LIVE_CRAWL_ENABLED`
 * is false — the default — this logs once and exits without scheduling
 * anything, so a fresh checkout or a misconfigured deploy never starts
 * making live requests to coach.com / michaelkors.com on its own. See
 * `docs/OPERATIONS.md` for the explicit env change required to enable it.
 */
export async function startScheduler(): Promise<void> {
  const config = loadConfig();
  if (!config.liveCrawlEnabled) {
    logger.info('scheduler not started: LIVE_CRAWL_ENABLED is false');
    return;
  }

  const pool = getPool();
  const products = new PgProductRepository(pool);
  const crawlRuns = new PgCrawlRunRepository(pool);
  const rateLimiter = new DomainRateLimiter(config.requestDelayMs);

  const runAll = async () => {
    // A failure attempting one source (thrown exception, lock contention,
    // robots failure) must never prevent the other source from being
    // attempted — each source is fully isolated.
    for (const sourceId of config.enabledSourceIds) {
      const adapter = adapterFor(sourceId);
      try {
        await runOneSourceLocked(adapter, { pool, products, crawlRuns, rateLimiter, config });
      } catch (error) {
        logger.error('scheduled crawl run failed for source', {
          source: adapter.source.id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  };

  const task = cron.schedule(config.catalogCron, () => {
    runAll().catch((error) => {
      logger.error('scheduled crawl run failed', { error: String(error) });
    });
  });

  logger.info('catalog monitor scheduler started', { cron: config.catalogCron });

  let shuttingDown = false;
  const shutdown = async (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info('scheduler shutting down', { signal });
    task.stop();
    await closePool();
    process.exit(0);
  };
  process.once('SIGTERM', () => void shutdown('SIGTERM'));
  process.once('SIGINT', () => void shutdown('SIGINT'));
}

/**
 * Wraps a single source's crawl attempt in a Postgres advisory lock keyed by
 * source, so an overlapping cron fire or a second monitor replica can never
 * run the same source's crawl concurrently. If the lock is already held,
 * this attempt is skipped entirely (not queued, not retried) — the next
 * scheduled fire will try again.
 */
async function runOneSourceLocked(
  adapter: BrandAdapter,
  deps: {
    pool: pg.Pool;
    products: PgProductRepository;
    crawlRuns: PgCrawlRunRepository;
    rateLimiter: DomainRateLimiter;
    config: ReturnType<typeof loadConfig>;
  },
): Promise<void> {
  const lockKey = SOURCE_LOCK_KEYS[adapter.source.id];
  const acquired = await withDbLock(deps.pool, lockKey, () => runOneSource(adapter, deps));
  if (!acquired) {
    logger.warn('skipped crawl: another scheduler or replica already holds the lock', {
      source: adapter.source.id,
    });
  }
}

async function runOneSource(
  adapter: BrandAdapter,
  deps: {
    products: PgProductRepository;
    crawlRuns: PgCrawlRunRepository;
    rateLimiter: DomainRateLimiter;
    config: ReturnType<typeof loadConfig>;
  },
): Promise<void> {
  const outcome = await crawlSourceWithRobotsGate({
    adapter,
    fetchRobots: fetchRobotsTxt,
    userAgent: deps.config.userAgent,
    fetchSitemap: async (url) => {
      const r = await liveFetch(url);
      return { status: r.status, body: r.body };
    },
    fetchPage: async (url) => {
      const r = await liveFetch(url);
      return { status: r.status, body: r.body, finalUrl: r.finalUrl };
    },
    products: deps.products,
    crawlRuns: deps.crawlRuns,
    rateLimiter: deps.rateLimiter,
    playwrightFallbackEnabled: deps.config.playwrightFallbackEnabled,
    renderWithPlaywright: deps.config.playwrightFallbackEnabled ? renderWithPlaywright : undefined,
  });

  if (!outcome.robotsOk) {
    logger.error('robots.txt unavailable — refusing to crawl this source', {
      source: adapter.source.id,
      reason: outcome.reason,
    });
    return;
  }

  const result = outcome.result;
  logger.info('crawl run finished', {
    source: adapter.source.id,
    status: result.status,
    isFullSnapshot: result.isFullSnapshot,
    urlsDiscovered: result.urlsDiscovered,
    pagesFetched: result.pagesFetched,
    successfulParses: result.successfulParses,
    newItems: result.newItems,
    changedItems: result.changedItems,
    missingItems: result.missingItems,
    inactiveItems: result.inactiveItems,
    errorsByType: result.errorsByType,
  });
}

async function fetchRobotsTxt(url: string): Promise<{ status: number; body: string }> {
  const r = await liveFetch(url);
  return { status: r.status, body: r.body };
}

const isMain = process.argv[1]?.endsWith('scheduler.ts') || process.argv[1]?.endsWith('scheduler.js');
if (isMain) {
  startScheduler().catch((error) => {
    logger.error('scheduler failed to start', { error: String(error) });
    process.exitCode = 1;
  });
}

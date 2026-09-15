import cron from 'node-cron';
import { loadConfig } from '../config.js';
import { logger } from '../logger.js';
import { getPool, closePool } from '../db/pool.js';
import { PgProductRepository } from '../db/pgProductRepository.js';
import { PgCrawlRunRepository } from '../db/pgCrawlRunRepository.js';
import { PgSelectionSnapshotCommitter } from '../db/pgSelectionSnapshotCommitter.js';
import { adapterFor } from '../adapters/registry.js';
import { crawlSourceWithRobotsGate } from '../crawl/guardedCrawl.js';
import { DomainRateLimiter } from '../crawl/rateLimiter.js';
import { liveFetch } from '../crawl/httpFetcher.js';
import { renderWithPlaywright } from '../crawl/playwrightFallback.js';
import { withDbLock, SOURCE_LOCK_KEYS } from '../db/advisoryLock.js';
import type { BrandAdapter } from '../adapters/types.js';
import type pg from 'pg';
import { CatalogEventOutbox } from '../notifications/catalogEventOutbox.js';
import { PgSourcePolicyRepository } from '../db/pgSourcePolicyRepository.js';

/**
 * The one place a daily cron job gets registered. If `LIVE_CRAWL_ENABLED`
 * is false — the default — this logs once and exits without scheduling
 * anything, so a fresh checkout or a misconfigured deploy never starts
 * making live requests to coach.com / michaelkors.com on its own. See
 * `docs/OPERATIONS.md` for the explicit env change required to enable it.
 */
export async function startScheduler(): Promise<void> {
  const config = loadConfig();
  if (!config.liveCrawlEnabled && config.notificationEventsUrl === null) {
    logger.info('scheduler not started: LIVE_CRAWL_ENABLED is false');
    return;
  }
  if (!config.liveCrawlEnabled) {
    logger.info('live crawling disabled; notification outbox worker only');
  }

  const pool = getPool();
  const products = new PgProductRepository(pool);
  const crawlRuns = new PgCrawlRunRepository(pool);
  const selectionSnapshotCommitter = new PgSelectionSnapshotCommitter(pool);
  const policies = new PgSourcePolicyRepository(pool);
  const rateLimiter = new DomainRateLimiter(config.requestDelayMs);
  const outbox = config.notificationEventsUrl !== null && config.notificationEventsSecret !== null
    ? new CatalogEventOutbox(
        pool,
        config.notificationEventsUrl,
        config.notificationEventsSecret,
      )
    : null;

  const dispatchOutbox = async () => {
    if (outbox === null) return;
    try {
      const delivered = await outbox.dispatchOnce();
      if (delivered > 0) logger.info('catalog notification events dispatched', { delivered });
    } catch (error) {
      logger.error('catalog notification outbox dispatch failed', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  };
  const outboxTimer = outbox === null
    ? null
    : setInterval(() => void dispatchOutbox(), 30_000);
  void dispatchOutbox();

  const runAll = async () => {
    // A failure attempting one source (thrown exception, lock contention,
    // robots failure) must never prevent the other source from being
    // attempted — each source is fully isolated.
    const configuredPolicies = new Map(
      (await policies.list()).map((policy) => [policy.sourceId, policy]),
    );
    for (const sourceId of config.enabledSourceIds) {
      if (configuredPolicies.get(sourceId)?.enabled === false) {
        logger.info('skipped disabled source policy', { source: sourceId });
        continue;
      }
      const adapter = adapterFor(sourceId);
      try {
        await runOneSourceLocked(adapter, {
          pool,
          products,
          crawlRuns,
          selectionSnapshotCommitter,
          rateLimiter,
          config,
        });
      } catch (error) {
        logger.error('scheduled crawl run failed for source', {
          source: adapter.source.id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
      await dispatchOutbox();
    }
  };

  const task = config.liveCrawlEnabled
    ? cron.schedule(config.catalogCron, () => {
        runAll().catch((error) => {
          logger.error('scheduled crawl run failed', { error: String(error) });
        });
      })
    : null;

  if (task !== null) {
    logger.info('catalog monitor scheduler started', { cron: config.catalogCron });
  }

  let shuttingDown = false;
  const shutdown = async (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info('scheduler shutting down', { signal });
    task?.stop();
    if (outboxTimer !== null) clearInterval(outboxTimer);
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
    selectionSnapshotCommitter: PgSelectionSnapshotCommitter;
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
    selectionSnapshotCommitter: PgSelectionSnapshotCommitter;
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
    selectionSnapshotCommitter: deps.selectionSnapshotCommitter,
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
    selectionVersion: result.selectionVersion,
    urlsDiscovered: result.urlsDiscovered,
    urlsSelected: result.urlsSelected,
    pagesFetched: result.pagesFetched,
    successfulParses: result.successfulParses,
    newItems: result.newItems,
    changedItems: result.changedItems,
    missingItems: result.missingItems,
    inactiveItems: result.inactiveItems,
    deselectedItems: result.deselectedItems,
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

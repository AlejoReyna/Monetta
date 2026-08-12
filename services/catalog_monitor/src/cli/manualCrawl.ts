#!/usr/bin/env node
/**
 * Manual crawl CLI.
 *
 *   npm run crawl -- --brand coach --limit 5 --dry-run
 *
 * `--dry-run` skips the database entirely — no read, no write — but still
 * performs real HTTP requests if `LIVE_CRAWL_ENABLED=true`. It reports raw
 * extraction stats (URLs discovered, pages fetched, parses, sample items)
 * with no new/changed/missing/inactive counts, since those require
 * comparing against stored state. This is what makes `--dry-run` usable as
 * a capped live smoke test with no database running at all. With
 * `LIVE_CRAWL_ENABLED=false` (the default), `httpFetcher.liveFetch` refuses
 * to open a socket at all and the command fails fast with that explanation,
 * regardless of `--dry-run`. This is the "opt-in through configuration" gate
 * from the spec: the CLI alone is not enough to crawl live, the environment
 * must also say so.
 */
import { fileURLToPath } from 'node:url';
import { loadConfig } from '../config.js';
import { logger } from '../logger.js';
import { getPool, closePool } from '../db/pool.js';
import { PgProductRepository } from '../db/pgProductRepository.js';
import { PgCrawlRunRepository } from '../db/pgCrawlRunRepository.js';
import { allAdapters, adapterFor } from '../adapters/registry.js';
import { crawlSourceWithRobotsGate } from '../crawl/guardedCrawl.js';
import { DomainRateLimiter } from '../crawl/rateLimiter.js';
import { liveFetch } from '../crawl/httpFetcher.js';
import { renderWithPlaywright } from '../crawl/playwrightFallback.js';
import type { SourceId } from '../domain/types.js';

interface CliArgs {
  readonly brand: 'coach' | 'michael_kors' | 'guess' | 'steve_madden' | 'all';
  readonly limit: number | undefined;
  readonly dryRun: boolean;
}

const BRAND_TO_SOURCE: Record<Exclude<CliArgs['brand'], 'all'>, SourceId> = {
  coach: 'coach_us',
  michael_kors: 'michael_kors_us',
  guess: 'guess_us',
  steve_madden: 'steve_madden_us',
};

export function parseArgs(argv: readonly string[]): CliArgs {
  let brand: CliArgs['brand'] = 'all';
  let limit: number | undefined;
  let dryRun = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--brand') {
      const value = argv[++i];
      if (
        value !== 'coach' &&
        value !== 'michael_kors' &&
        value !== 'guess' &&
        value !== 'steve_madden' &&
        value !== 'all'
      ) {
        throw new Error(
          `--brand must be coach|michael_kors|guess|steve_madden|all, got "${value}"`,
        );
      }
      brand = value;
    } else if (arg === '--limit') {
      const value = Number.parseInt(argv[++i] ?? '', 10);
      if (!Number.isFinite(value) || value <= 0) {
        throw new Error('--limit must be a positive integer');
      }
      limit = value;
    } else if (arg === '--dry-run') {
      dryRun = true;
    } else if (arg?.startsWith('--')) {
      throw new Error(`Unknown flag: ${arg}`);
    }
  }

  return { brand, limit, dryRun };
}

async function fetchRobotsTxt(url: string): Promise<{ status: number; body: string }> {
  const r = await liveFetch(url);
  return { status: r.status, body: r.body };
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const config = loadConfig();

  const sourceIds: SourceId[] =
    args.brand === 'all' ? allAdapters().map((a) => a.source.id) : [BRAND_TO_SOURCE[args.brand]];

  const pool = getPool();
  const products = new PgProductRepository(pool);
  const crawlRuns = new PgCrawlRunRepository(pool);
  const rateLimiter = new DomainRateLimiter(config.requestDelayMs);

  for (const sourceId of sourceIds) {
    const adapter = adapterFor(sourceId);
    logger.info('starting manual crawl', {
      source: sourceId,
      limit: args.limit,
      dryRun: args.dryRun,
      liveCrawlEnabled: config.liveCrawlEnabled,
    });

    const outcome = await crawlSourceWithRobotsGate({
      adapter,
      fetchRobots: fetchRobotsTxt,
      userAgent: config.userAgent,
      fetchSitemap: async (url) => {
        const r = await liveFetch(url);
        return { status: r.status, body: r.body };
      },
      fetchPage: async (url) => {
        const r = await liveFetch(url);
        return { status: r.status, body: r.body, finalUrl: r.finalUrl };
      },
      products,
      crawlRuns,
      rateLimiter,
      limit: args.limit,
      dryRun: args.dryRun,
      playwrightFallbackEnabled: config.playwrightFallbackEnabled,
      renderWithPlaywright: config.playwrightFallbackEnabled ? renderWithPlaywright : undefined,
    });

    if (!outcome.robotsOk) {
      logger.error('robots.txt unavailable — refusing to crawl this source', {
        source: sourceId,
        reason: outcome.reason,
      });
      console.error(`robots.txt unavailable for ${sourceId}: ${outcome.reason}. Refusing to crawl.`);
      process.exitCode = 1;
      continue;
    }

    const result = outcome.result;
    logger.info('manual crawl finished', { source: sourceId, ...result, items: undefined });
    console.log(
      JSON.stringify(
        {
          source: sourceId,
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
          sampleItems: result.items.slice(0, 3),
        },
        null,
        2,
      ),
    );
  }

  await closePool();
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main().catch((error) => {
    const message = error instanceof Error ? (error.stack ?? error.message) : String(error);
    logger.error('manual crawl failed', { error: message });
    console.error(message);
    process.exitCode = 1;
  });
}

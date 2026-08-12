#!/usr/bin/env node
/**
 * Local-demo-only seed data — NOT a live crawl.
 *
 * Populates a handful of hand-written, clearly-fictional-looking sample
 * items so `GET /v1/external-catalog` has something to serve and the
 * Flutter mixed-feed UI can be exercised end-to-end without a real crawl
 * Legacy development helper retained for its safety-guard tests. Normal
 * local and deployed startup no longer uses it: the API's dated curated US
 * floor supplies 10 records per source without writing fixture rows to the
 * database (see `catalog/curatedUsCatalog.ts`). Its `(demo data)` rows are
 * explicitly filtered from public responses.
 *
 * Guarded so it cannot run accidentally against a real database: all three
 * of `ALLOW_DEMO_SEED=true`, a non-production `NODE_ENV`, and a
 * loopback/local `DATABASE_URL` host are required, checked *before* any
 * database connection is opened. The crawl-run rows it writes are
 * deliberately `status: 'partial'` / `isFullSnapshot: false` — never a fake
 * successful full snapshot — so `/healthz` stays truthfully degraded (no
 * real crawl has ever run) even with demo products visible in the catalog.
 */
import { fileURLToPath } from 'node:url';
import { loadConfig, type CatalogMonitorConfig } from '../config.js';
import { getPool, closePool } from '../db/pool.js';
import { PgProductRepository } from '../db/pgProductRepository.js';
import { PgCrawlRunRepository } from '../db/pgCrawlRunRepository.js';
import { fingerprintOf } from '../crawl/fingerprint.js';
import { logger } from '../logger.js';
import type { CatalogProductRecord, ExtractedProduct } from '../domain/types.js';

const now = new Date();

const LOOPBACK_HOSTS = new Set(['localhost', '127.0.0.1', '::1', '0.0.0.0']);

/**
 * Throws (without ever touching the database) unless every guard holds.
 * Exported for tests — must be called, and must pass, before `getPool()`.
 */
export function assertSafeToSeedDemoData(
  config: Pick<CatalogMonitorConfig, 'databaseUrl'>,
  env: NodeJS.ProcessEnv = process.env,
): void {
  if (env.ALLOW_DEMO_SEED !== 'true') {
    throw new Error(
      'Refusing to seed demo data: ALLOW_DEMO_SEED=true is required. This is a deliberate ' +
        'guard against accidentally seeding fictional data into a real database.',
    );
  }
  const nodeEnv = (env.NODE_ENV ?? '').trim().toLowerCase();
  if (nodeEnv === 'production') {
    throw new Error('Refusing to seed demo data: NODE_ENV=production.');
  }

  let host: string;
  try {
    host = new URL(config.databaseUrl).hostname.toLowerCase();
  } catch {
    throw new Error('Refusing to seed demo data: DATABASE_URL is not a valid URL.');
  }
  if (!LOOPBACK_HOSTS.has(host)) {
    throw new Error(
      `Refusing to seed demo data: DATABASE_URL host "${host}" is not loopback/local. ` +
        `Only ${[...LOOPBACK_HOSTS].join(', ')} are permitted.`,
    );
  }
}

const DEMO_ITEMS: readonly { sourceId: 'coach_us' | 'michael_kors_us'; item: ExtractedProduct }[] = [
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CEN52',
      canonicalUrl: 'https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html',
      title: 'Tabby Shoulder Bag 26 (demo data)',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: 'https://picsum.photos/seed/coach-tabby/600/800',
      priceUsd: 350,
      availability: 'inStock',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'C4295',
      canonicalUrl: 'https://www.coach.com/products/rowan-satchel/C4295.html',
      title: 'Rowan Satchel (demo data)',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: 'https://picsum.photos/seed/coach-rowan/600/800',
      priceUsd: 428,
      availability: 'inStock',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: 'MM1Q843',
      canonicalUrl: 'https://www.michaelkors.com/product/scoop-back-swimsuit/_/R-US_MM1Q843',
      title: 'Scoop Back Swimsuit (demo data)',
      brand: 'Michael Kors',
      category: 'Swimwear',
      imageUrl: 'https://picsum.photos/seed/mk-swimsuit/600/800',
      priceUsd: 228,
      availability: 'inStock',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: 'MKC1096AN',
      canonicalUrl:
        'https://www.michaelkors.com/14k-gold-plated-sterling-silver-pave-alphabet-charm/MKC1096AN.html',
      title: '14k Gold-Plated Sterling Silver Pavé Alphabet Charm (demo data)',
      brand: 'Michael Kors',
      category: 'Jewelry',
      imageUrl: 'https://picsum.photos/seed/mk-charm/600/800',
      priceUsd: 65,
      availability: 'outOfStock',
    },
  },
];

async function main(): Promise<void> {
  const config = loadConfig();
  // Must run before any database connection is opened — see docstring.
  assertSafeToSeedDemoData(config);

  const pool = getPool();
  const products = new PgProductRepository(pool);
  const crawlRuns = new PgCrawlRunRepository(pool);

  const records: CatalogProductRecord[] = DEMO_ITEMS.map(({ sourceId, item }) => ({
    ...item,
    sourceId,
    fingerprint: fingerprintOf(item),
    firstSeenAt: now,
    lastSeenAt: now,
    lastChangedAt: now,
    isActive: true,
    consecutiveMissingSnapshots: 0,
  }));

  await products.upsertMany(records);

  for (const sourceId of ['coach_us', 'michael_kors_us'] as const) {
    const count = records.filter((r) => r.sourceId === sourceId).length;
    const runId = await crawlRuns.start({ sourceId, startedAt: now });
    await crawlRuns.finish(runId, {
      endedAt: now,
      // Deliberately never 'success' + isFullSnapshot: true — this is
      // hand-written fixture data, not a crawl result, and must never make
      // /healthz report a source as healthy or become a diffing baseline.
      status: 'partial',
      isFullSnapshot: false,
      urlsDiscovered: count,
      pagesFetched: count,
      successfulParses: count,
      newItems: count,
      changedItems: 0,
      missingItems: 0,
      inactiveItems: 0,
      errorsByType: {},
    });
  }

  logger.info('seeded demo data (catalog only — /healthz remains degraded, no crawl has run)', {
    items: records.length,
  });
  await closePool();
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main().catch((error) => {
    logger.error('seed failed', { error: error instanceof Error ? error.stack : String(error) });
    process.exitCode = 1;
  });
}

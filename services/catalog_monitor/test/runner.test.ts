import { describe, expect, it } from 'vitest';
import { runCrawl, type PageFetchResult } from '../src/crawl/runner.js';
import { coachAdapter } from '../src/adapters/coach.js';
import { DomainRateLimiter } from '../src/crawl/rateLimiter.js';
import {
  InMemoryCrawlRunRepository,
  InMemoryProductRepository,
  InMemorySelectionSnapshotCommitter,
} from './support/inMemoryRepositories.js';
import { readFixture } from './support/fixtures.js';
import type { ExtractedProduct } from '../src/domain/types.js';
import type { ProductRepository, SelectionSnapshotPersistence } from '../src/crawl/ports.js';
import type { SitemapFetcher } from '../src/discovery/sitemap.js';
import { compileSelection } from '../src/selection/engine.js';
import { parseSelectionDocument } from '../src/selection/document.js';
import type { SelectionDocument } from '../src/selection/types.js';

const SITEMAP_INDEX = `<?xml version="1.0"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html</loc></url>
  <url><loc>https://www.coach.com/products/rowan-satchel/C4295.html</loc></url>
</urlset>`;

const PAGES: Record<string, string> = {
  'https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html': readFixture('coach/product_jsonld.html'),
  'https://www.coach.com/products/rowan-satchel/C4295.html': readFixture('coach/product_selectors_only.html'),
};

const noRateDelayLimiter = () => new DomainRateLimiter(0);
const openRobots = { disallow: [], allow: [] };

const sitemapOf: (xml: string) => SitemapFetcher = (xml) => async () => ({ status: 200, body: xml });

function seedRecord(externalId: string): ReturnType<InMemoryProductRepository['all']>[number] {
  const extracted: ExtractedProduct = {
    externalId,
    canonicalUrl: `https://www.coach.com/old/${externalId}.html`,
    title: 'Old Item',
    brand: 'Coach',
    category: null,
    imageUrl: null,
    priceUsd: 50,
    availability: 'inStock',
  };
  return {
    ...extracted,
    sourceId: 'coach_us',
    fingerprint: 'irrelevant',
    firstSeenAt: new Date('2026-08-01T00:00:00Z'),
    lastSeenAt: new Date('2026-08-01T00:00:00Z'),
    lastChangedAt: new Date('2026-08-01T00:00:00Z'),
    isActive: true,
    consecutiveMissingSnapshots: 0,
    selectionState: 'selected',
    selectionVersion: null,
    watchTier: 'standard',
    placements: [],
    matchedRuleId: null,
  };
}

describe('runCrawl happy path', () => {
  it('discovers, classifies, fetches, extracts, diffs and persists a full snapshot', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP_INDEX),
      fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.status).toBe('success');
    expect(result.isFullSnapshot).toBe(true);
    expect(result.urlsDiscovered).toBe(2);
    expect(result.urlsSelected).toBe(2);
    expect(result.pagesFetched).toBe(2);
    expect(result.successfulParses).toBe(2);
    expect(result.newItems).toBe(2);

    const stored = await products.getActiveProducts('coach_us');
    expect(stored).toHaveLength(2);

    const runs = await crawlRuns.recentRuns('coach_us', 1);
    expect(runs[0]!.status).toBe('success');
    expect(runs[0]!.isFullSnapshot).toBe(true);
    expect(runs[0]!.urlsDiscovered).toBe(2);
    expect(runs[0]!.urlsSelected).toBe(2);
  });
});

describe('runCrawl failure handling', () => {
  it('rejects a product response redirected to a regional storefront', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('CEN52')]);
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP_INDEX),
      fetchPage: async () => ({
        status: 200,
        body: readFixture('coach/product_jsonld.html'),
        finalUrl: 'https://mx.coach.com/es_MX/productos/bolso.html',
      }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.status).toBe('partial');
    expect(result.successfulParses).toBe(0);
    expect(result.errorsByType.wrong_market).toBe(2);
    expect(await products.getActiveProducts('coach_us')).toHaveLength(1);
  });

  it('stores the final US product URL when a same-market redirect is used', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();
    const finalUrl = 'https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html';

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>https://www.coach.com/products/old/CEN52.html</loc></url></urlset>',
      ),
      fetchPage: async () => ({
        status: 200,
        body: readFixture('coach/product_jsonld.html'),
        finalUrl,
      }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.successfulParses).toBe(1);
    expect((await products.getActiveProducts('coach_us'))[0]!.canonicalUrl).toBe(finalUrl);
  });

  it('preserves the previous catalog when every page fetch fails', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('CEN52')]);
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP_INDEX),
      fetchPage: async () => {
        throw new Error('ECONNRESET simulated network failure');
      },
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      retryOptions: { maxRetries: 0, sleep: async () => {} },
    });

    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);

    const stored = await products.getActiveProducts('coach_us');
    expect(stored).toHaveLength(1);
    expect(stored[0]!.title).toBe('Old Item'); // untouched
  });

  it('stops immediately and reports "blocked" when a CAPTCHA marker is detected', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();
    let fetchCount = 0;

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP_INDEX),
      fetchPage: async (): Promise<PageFetchResult> => {
        fetchCount++;
        return { status: 403, body: '<html>Please complete this CAPTCHA to continue</html>' };
      },
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.status).toBe('blocked');
    expect(result.isFullSnapshot).toBe(false);
    expect(fetchCount).toBe(1); // stopped after the first blocked response
    expect(result.errorsByType.captcha_or_block).toBe(1);
    expect(await products.getActiveProducts('coach_us')).toHaveLength(0);
  });

  it('never treats a failed sitemap fetch as a full snapshot, even with zero page errors', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('CEN52')]);
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      // The index itself resolves, but one nested sitemap 500s — a partial
      // discovery must not be read as "these are the only products left."
      fetchSitemap: async (url) => {
        if (url.includes('broken')) throw new Error('simulated 500 fetching nested sitemap');
        return {
          status: 200,
          body: `<?xml version="1.0"?>
          <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <sitemap><loc>https://www.coach.com/sitemap_broken.xml</loc></sitemap>
          </sitemapindex>`,
        };
      },
      fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.isFullSnapshot).toBe(false);
    expect(result.status).toBe('partial');
    expect(result.errorsByType.network).toBe(1);

    const stored = await products.getActiveProducts('coach_us');
    expect(stored).toHaveLength(1);
    expect(stored[0]!.title).toBe('Old Item'); // preserved, not wiped
  });

  it('treats a non-2xx sitemap response as an error, not an empty sitemap', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('CEN52')]);
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: async () => ({ status: 503, body: '' }),
      fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);
    expect(result.errorsByType.http_5xx).toBe(1);
    expect(await products.getActiveProducts('coach_us')).toHaveLength(1); // preserved
  });

  it('never treats an empty sitemap as a successful full run', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('CEN52')]);
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(
        `<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>`,
      ),
      fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);
    expect(result.urlsDiscovered).toBe(0);
    expect(result.urlsSelected).toBe(0);
    expect(await products.getActiveProducts('coach_us')).toHaveLength(1); // preserved
  });

  it('never treats zero classified products as a successful full run', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('CEN52')]);
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      // The sitemap resolves with entries, but none of them are product URLs
      // under the adapter's real URL shape — a sitemap-shape regression, not
      // "this catalog has zero products."
      fetchSitemap: sitemapOf(
        `<?xml version="1.0"?>
         <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
           <url><loc>https://www.coach.com/handbags</loc></url>
           <url><loc>https://www.coach.com/tabby-shoulder-bag-26/CEN52.html</loc></url>
         </urlset>`,
      ),
      fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);
    expect(result.urlsDiscovered).toBe(0);
    expect(result.urlsSelected).toBe(0);
    expect(await products.getActiveProducts('coach_us')).toHaveLength(1); // preserved
  });

  it('is truncated (and therefore partial) when maxSitemaps is reached with sitemaps still queued', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: async (url) => {
        if (url === 'https://www.coach.com/sitemap_index.xml') {
          return {
            status: 200,
            body: `<?xml version="1.0"?>
            <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <sitemap><loc>https://www.coach.com/sitemap_a.xml</loc></sitemap>
              <sitemap><loc>https://www.coach.com/sitemap_b.xml</loc></sitemap>
            </sitemapindex>`,
          };
        }
        return { status: 200, body: SITEMAP_INDEX };
      },
      fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      maxSitemaps: 1,
    });

    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);
  });

  it('retries a temporary 503 and still succeeds, counting one page fetch', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();
    const attemptsByUrl = new Map<string, number>();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP_INDEX),
      fetchPage: async (url): Promise<PageFetchResult> => {
        const attempts = (attemptsByUrl.get(url) ?? 0) + 1;
        attemptsByUrl.set(url, attempts);
        if (url.includes('CEN52') && attempts < 3) {
          return { status: 503, body: 'temporarily unavailable' };
        }
        return { status: 200, body: PAGES[url]! };
      },
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      retryOptions: { maxRetries: 3, baseDelayMs: 1, sleep: async () => {} },
    });

    expect(result.status).toBe('success');
    expect(result.pagesFetched).toBe(2); // one increment per URL, not per retry attempt
    expect(attemptsByUrl.get('https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html')).toBe(3);
  });

  it('treats 97% required-field parse coverage as below the 98% bar and stays partial', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();

    const total = 100;
    const incompleteCount = 3; // 97/100 = 0.97 < 0.98
    const urls: string[] = [];
    const pages: Record<string, string> = {};
    const completeFixture = readFixture('coach/product_jsonld.html');
    const incompleteFixture = readFixture('coach/product_missing_fields.html');
    for (let i = 1; i <= total; i++) {
      const url = `https://www.coach.com/products/item-${i}/C${i}.html`;
      urls.push(url);
      pages[url] = i <= incompleteCount ? incompleteFixture : completeFixture;
    }
    const xml = `<?xml version="1.0"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls
      .map((u) => `  <url><loc>${u}</loc></url>`)
      .join('\n')}\n</urlset>`;

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(xml),
      fetchPage: async (url) => ({ status: 200, body: pages[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
    });

    expect(result.pagesFetched).toBe(100);
    expect(result.successfulParses).toBe(97);
    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);
    // Below-coverage runs must not execute full-snapshot diffing.
    expect(result.newItems).toBe(0);
    expect(result.missingItems).toBe(0);
    expect(await products.getAllActiveProducts()).toHaveLength(0);
  });

  it('finalizes the run record as failed (not left running) when an unexpected exception occurs', async () => {
    const crawlRuns = new InMemoryCrawlRunRepository();
    const throwingProducts: ProductRepository = {
      getActiveProducts: async () => {
        throw new Error('simulated unexpected persistence failure');
      },
      getAllActiveProducts: async () => [],
      upsertMany: async () => {},
    };

    await expect(
      runCrawl({
        adapter: coachAdapter,
        fetchSitemap: sitemapOf(SITEMAP_INDEX),
        fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
        robots: openRobots,
        products: throwingProducts,
        crawlRuns,
        rateLimiter: noRateDelayLimiter(),
      }),
    ).rejects.toThrow('simulated unexpected persistence failure');

    const runs = await crawlRuns.recentRuns('coach_us', 1);
    expect(runs).toHaveLength(1);
    expect(runs[0]!.status).toBe('failed');
    expect(runs[0]!.status).not.toBe('running');
  });
});

describe('runCrawl --limit', () => {
  it('forces isFullSnapshot: false even when every fetched page succeeds', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP_INDEX),
      fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      limit: 1,
    });

    expect(result.pagesFetched).toBe(1);
    expect(result.isFullSnapshot).toBe(false);
  });
});

describe('runCrawl --dry-run', () => {
  it('never writes to the repositories', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();

    await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP_INDEX),
      fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      dryRun: true,
    });

    expect(await products.getAllActiveProducts()).toHaveLength(0);
    expect(await crawlRuns.recentRuns('coach_us', 10)).toHaveLength(0);
  });
});

describe('runCrawl confirmed removal across consecutive full snapshots', () => {
  it('only marks an item inactive after two consecutive successful full snapshots miss it', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('GONE1')]);
    const crawlRuns = new InMemoryCrawlRunRepository();

    const runOnce = () =>
      runCrawl({
        adapter: coachAdapter,
        fetchSitemap: sitemapOf(SITEMAP_INDEX),
        fetchPage: async (url) => ({ status: 200, body: PAGES[url]! }),
        robots: openRobots,
        products,
        crawlRuns,
        rateLimiter: noRateDelayLimiter(),
      });

    const first = await runOnce();
    expect(first.status).toBe('success');
    expect(first.isFullSnapshot).toBe(true);
    let gone = (await products.getActiveProducts('coach_us')).find((p) => p.externalId === 'GONE1');
    expect(gone?.isActive).toBe(true);
    expect(gone?.consecutiveMissingSnapshots).toBe(1);

    const second = await runOnce();
    expect(second.status).toBe('success');
    expect(second.isFullSnapshot).toBe(true);
    const all = await products.getAllActiveProducts();
    gone = all.find((p) => p.externalId === 'GONE1');
    // No longer active — confirmed removed after two consecutive full misses.
    expect(gone).toBeUndefined();
    expect(second.inactiveItems).toBe(1);
  });
});

describe('WP-12 Stage-A filtering in discovery', () => {
  const threeTabbyUrls = [
    'https://www.coach.com/products/tabby/CU001.html',
    'https://www.coach.com/products/tabby/CU002.html',
    'https://www.coach.com/products/tabby/CU003.html',
  ];
  const thousandUrls = [
    ...threeTabbyUrls,
    ...Array.from({ length: 997 }, (_, i) => `https://www.coach.com/products/satchel/C${i + 4}.html`),
  ];
  const thousandUrlSitemapXml = `<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${thousandUrls
    .map((loc) => `<url><loc>${loc}</loc></url>`)
    .join('')}</urlset>`;

  const tabbySelectionDoc = parseSelectionDocument({
    version: 1,
    sources: {
      coach_us: {
        enabled: true,
        include: [
          {
            id: 'tabby-only',
            kind: 'urlPattern',
            value: '/products/tabby/*',
          },
        ],
      },
    },
  }) as SelectionDocument;
  const tabbySelection = compileSelection(tabbySelectionDoc);

  it('synthetic 1,000-URL sitemap with a Stage-A rule matching exactly 3 URLs', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('PRE_EXISTING')]);
    const crawlRuns = new InMemoryCrawlRunRepository();
    const fetchedUrls: string[] = [];

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(thousandUrlSitemapXml),
      fetchPage: async (url) => {
        fetchedUrls.push(url);
        return {
          status: 200,
          body: PAGES['https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html']!,
        };
      },
      robots: openRobots,
      products,
      crawlRuns,
      selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
      rateLimiter: noRateDelayLimiter(),
      selection: tabbySelection,
    });

    expect(result.urlsDiscovered).toBe(1000);
    expect(result.urlsSelected).toBe(3);
    expect(result.pagesFetched).toBe(3);
    expect(fetchedUrls).toEqual(threeTabbyUrls);
    expect(result.items).toHaveLength(3);
    expect(result.isFullSnapshot).toBe(true);
    expect(result.selectionVersion).toBe(tabbySelection.version);

    // Lifecycle changes persisted with selection metadata; pre-existing unselected item is deselected
    const activeProducts = await products.getActiveProducts('coach_us');
    expect(activeProducts).toHaveLength(4);
    const selectedActive = await products.getSelectedActiveProducts('coach_us', tabbySelection.version);
    expect(selectedActive).toHaveLength(3);

    const deselected = activeProducts.find((p) => p.externalId === 'PRE_EXISTING');
    expect(deselected).toBeDefined();
    expect(deselected!.selectionState).toBe('deselected');
    expect(deselected!.isActive).toBe(true);

    const runs = await crawlRuns.recentRuns('coach_us', 1);
    expect(runs[0]!.urlsDiscovered).toBe(1000);
    expect(runs[0]!.urlsSelected).toBe(3);
    expect(runs[0]!.pagesFetched).toBe(3);
    expect(runs[0]!.isFullSnapshot).toBe(true);
    expect(runs[0]!.selectionVersion).toBe(tabbySelection.version);
    expect(runs[0]!.deselectedItems).toBe(1);
  });

  it('maxSelectedUrlsPerSource exceeded aborts before fetching any pages', async () => {
    const products = new InMemoryProductRepository();
    products.seed([seedRecord('PRE_EXISTING')]);
    const crawlRuns = new InMemoryCrawlRunRepository();
    const fetchedUrls: string[] = [];

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(thousandUrlSitemapXml),
      fetchPage: async (url) => {
        fetchedUrls.push(url);
        return {
          status: 200,
          body: PAGES['https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html']!,
        };
      },
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      selection: tabbySelection,
      maxSelectedUrlsPerSource: 2,
    });

    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);
    expect(result.pagesFetched).toBe(0);
    expect(fetchedUrls).toHaveLength(0);
    expect(result.errorsByType.selection_over_budget).toBe(1);

    // Seeded products remain unchanged
    const activeProducts = await products.getActiveProducts('coach_us');
    expect(activeProducts).toHaveLength(1);
    expect(activeProducts[0]!.externalId).toBe('PRE_EXISTING');

    // Persisted crawl run metrics record urlsDiscovered and urlsSelected
    const runs = await crawlRuns.recentRuns('coach_us', 1);
    expect(runs[0]!.urlsDiscovered).toBe(1000);
    expect(runs[0]!.urlsSelected).toBe(3);
    expect(runs[0]!.pagesFetched).toBe(0);
    expect(runs[0]!.status).toBe('partial');
    expect(runs[0]!.isFullSnapshot).toBe(false);
    expect(runs[0]!.errorsByType.selection_over_budget).toBe(1);
  });

  it('maxPagesPerRun exceeded after robots filtering aborts before fetching', async () => {
    const fourTabbyUrls = [
      'https://www.coach.com/products/tabby/CU001.html',
      'https://www.coach.com/products/tabby/CU002.html',
      'https://www.coach.com/products/tabby/CU003.html',
      'https://www.coach.com/products/tabby/CU004.html',
    ];
    const sitemapXml = `<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${fourTabbyUrls
      .map((loc) => `<url><loc>${loc}</loc></url>`)
      .join('')}</urlset>`;

    const products = new InMemoryProductRepository();
    products.seed([seedRecord('PRE_EXISTING')]);
    const crawlRuns = new InMemoryCrawlRunRepository();
    const fetchedUrls: string[] = [];

    // Robots blocks CU004, so 3 pass robots
    const robotsWithBlock = {
      disallow: ['/products/tabby/CU004.html'],
      allow: [],
    };

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(sitemapXml),
      fetchPage: async (url) => {
        fetchedUrls.push(url);
        return {
          status: 200,
          body: PAGES['https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html']!,
        };
      },
      robots: robotsWithBlock,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      selection: tabbySelection,
      maxSelectedUrlsPerSource: 10, // selected candidate count (4) is within selection budget (10)
      maxPagesPerRun: 2, // selected robots-allowed count (3) exceeds page budget (2)
    });

    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);
    expect(result.pagesFetched).toBe(0);
    expect(fetchedUrls).toHaveLength(0);
    expect(result.errorsByType.selection_over_budget).toBe(1);
    expect(result.urlsSelected).toBe(4);
    expect(result.urlsDiscovered).toBe(4);

    const activeProducts = await products.getActiveProducts('coach_us');
    expect(activeProducts).toHaveLength(1);
    expect(activeProducts[0]!.externalId).toBe('PRE_EXISTING');

    const runs = await crawlRuns.recentRuns('coach_us', 1);
    expect(runs[0]!.urlsSelected).toBe(4);
    expect(runs[0]!.pagesFetched).toBe(0);
    expect(runs[0]!.status).toBe('partial');
    expect(runs[0]!.errorsByType.selection_over_budget).toBe(1);
  });

  it('source with no Stage-A include rules selects zero pages and writes no products', async () => {
    const docNoStageA = parseSelectionDocument({
      version: 1,
      sources: {
        coach_us: {
          enabled: true,
          include: [
            { id: 'price-only', kind: 'priceUsdRange', value: [100, 500] },
          ],
        },
      },
    }) as SelectionDocument;
    const selectionNoStageA = compileSelection(docNoStageA);

    const products = new InMemoryProductRepository();
    products.seed([seedRecord('PRE_EXISTING')]);
    const crawlRuns = new InMemoryCrawlRunRepository();
    const fetchedUrls: string[] = [];

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(thousandUrlSitemapXml),
      fetchPage: async (url) => {
        fetchedUrls.push(url);
        return { status: 200, body: '' };
      },
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      selection: selectionNoStageA,
    });

    expect(result.urlsDiscovered).toBe(1000);
    expect(result.urlsSelected).toBe(0);
    expect(result.pagesFetched).toBe(0);
    expect(fetchedUrls).toHaveLength(0);
    expect(result.status).toBe('partial');
    expect(result.isFullSnapshot).toBe(false);
    expect(result.items).toHaveLength(0);

    const activeProducts = await products.getActiveProducts('coach_us');
    expect(activeProducts).toHaveLength(1);
    expect(activeProducts[0]!.externalId).toBe('PRE_EXISTING');
  });
});

describe('WP-13 Stage-B product filtering and selection lifecycle invariants', () => {
  const threeUrlsSitemapXml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html</loc></url>
  <url><loc>https://www.coach.com/products/wristlet-small/W0001.html</loc></url>
</urlset>`;

  const tabbyHtml = PAGES['https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html']!;
  // Wristlet HTML: price $150, category 'Small Leather Goods'
  const wristletHtml = tabbyHtml
    .replace('CEN52', 'W0001')
    .replace('Tabby Shoulder Bag 26', 'Small Wristlet')
    .replace('350.00', '150.00')
    .replace('$350', '$150');

  it('Stage-B include/exclude rules run after extraction; rejected products are excluded from selected snapshot output but count for coverage', async () => {
    // Stage A: include all /products/**
    // Stage B: exclude items with priceUsd <= 200
    const selectionDoc = parseSelectionDocument({
      version: 1,
      sources: {
        coach_us: {
          enabled: true,
          include: [
            { id: 'all-products', kind: 'urlPattern', value: '/products/**' },
          ],
          exclude: [
            { id: 'cheap-items', kind: 'priceUsdRange', value: [0, 200] },
          ],
        },
      },
    }) as SelectionDocument;
    const selection = compileSelection(selectionDoc);

    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(threeUrlsSitemapXml),
      fetchPage: async (url) => {
        if (url.includes('CEN52')) return { status: 200, body: tabbyHtml };
        if (url.includes('W0001')) return { status: 200, body: wristletHtml };
        return { status: 404, body: '' };
      },
      robots: openRobots,
      products,
      crawlRuns,
      selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
      rateLimiter: noRateDelayLimiter(),
      selection,
    });

    // Both 2 pages were attempted and parsed successfully -> coverage is 2/2 = 100%
    expect(result.urlsDiscovered).toBe(2);
    expect(result.urlsSelected).toBe(2);
    expect(result.pagesFetched).toBe(2);
    expect(result.successfulParses).toBe(2);
    expect(result.isFullSnapshot).toBe(true);

    // Only CEN52 ($350) is selected; W0001 ($150) was rejected by Stage B
    expect(result.items).toHaveLength(1);
    expect(result.items[0]!.externalId).toBe('CEN52');
    expect(result.newItems).toBe(1);

    // Repository has only the selected item
    const selectedActive = await products.getSelectedActiveProducts('coach_us', 1);
    expect(selectedActive).toHaveLength(1);
    expect(selectedActive[0]!.externalId).toBe('CEN52');
    expect(selectedActive[0]!.selectionState).toBe('selected');
    expect(selectedActive[0]!.selectionVersion).toBe(1);
  });

  it('a pinned Stage-A product remains selected even if it fails a Stage-B rule', async () => {
    // Stage A: pin tabby
    // Stage B: exclude priceUsd [300, 400] (which CEN52 falls into)
    const selectionDoc = parseSelectionDocument({
      version: 1,
      sources: {
        coach_us: {
          enabled: true,
          include: [
            {
              id: 'pin-tabby',
              kind: 'urlPattern',
              value: '/products/tabby**',
              tier: 'pinned',
              placements: ['home_rail'],
            },
          ],
          exclude: [
            { id: 'exclude-350', kind: 'priceUsdRange', value: [300, 400] },
          ],
        },
      },
    }) as SelectionDocument;
    const selection = compileSelection(selectionDoc);

    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(threeUrlsSitemapXml),
      fetchPage: async (url) => ({ status: 200, body: tabbyHtml }),
      robots: openRobots,
      products,
      crawlRuns,
      selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
      rateLimiter: noRateDelayLimiter(),
      selection,
    });

    expect(result.items).toHaveLength(1);
    expect(result.items[0]!.externalId).toBe('CEN52');

    const selectedActive = await products.getSelectedActiveProducts('coach_us', 1);
    expect(selectedActive).toHaveLength(1);
    expect(selectedActive[0]!.watchTier).toBe('pinned');
    expect(selectedActive[0]!.placements).toEqual(['home_rail']);
    expect(selectedActive[0]!.matchedRuleId).toBe('pin-tabby');
  });

  it('partial, blocked, and failed selected runs leave product state completely untouched (I6)', async () => {
    const selectionDoc = parseSelectionDocument({
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: [{ id: 'all', kind: 'urlPattern', value: '/products/**' }],
        },
      },
    }) as SelectionDocument;
    const selection = compileSelection(selectionDoc);

    const products = new InMemoryProductRepository();
    const baseline = seedRecord('PRE_EXISTING');
    baseline.selectionState = 'selected';
    baseline.selectionVersion = 1;
    products.seed([baseline]);

    const crawlRuns = new InMemoryCrawlRunRepository();

    // 1. Blocked run
    const blockedResult = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(threeUrlsSitemapXml),
      fetchPage: async () => ({
        status: 403,
        body: '<html><title>Access Denied - Cloudflare Captcha</title></html>',
      }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      selection,
    });

    expect(blockedResult.status).toBe('blocked');
    expect(blockedResult.isFullSnapshot).toBe(false);

    // Product untouched:
    let stored = products.all();
    expect(stored).toHaveLength(1);
    expect(stored[0]!.externalId).toBe('PRE_EXISTING');
    expect(stored[0]!.selectionVersion).toBe(1);
    expect(stored[0]!.selectionState).toBe('selected');
    expect(stored[0]!.consecutiveMissingSnapshots).toBe(0);

    // 2. Partial run (poor coverage: fetch succeeds but body is empty HTML so parsing fails)
    const partialResult = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(threeUrlsSitemapXml),
      fetchPage: async () => ({ status: 200, body: '<html><body>Empty</body></html>' }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      selection,
    });

    expect(partialResult.status).toBe('partial');
    expect(partialResult.isFullSnapshot).toBe(false);

    stored = products.all();
    expect(stored).toHaveLength(1);
    expect(stored[0]!.selectionVersion).toBe(1);
    expect(stored[0]!.selectionState).toBe('selected');
    expect(stored[0]!.consecutiveMissingSnapshots).toBe(0);

    // 3. Failed run (fatal adapter error throws)
    await expect(
      runCrawl({
        adapter: {
          ...coachAdapter,
          isProductUrl: () => {
            throw new Error('Fatal adapter error');
          },
        },
        fetchSitemap: sitemapOf(threeUrlsSitemapXml),
        fetchPage: async () => ({ status: 200, body: '' }),
        robots: openRobots,
        products,
        crawlRuns,
        rateLimiter: noRateDelayLimiter(),
        selection,
      }),
    ).rejects.toThrow('Fatal adapter error');

    stored = products.all();
    expect(stored).toHaveLength(1);
    expect(stored[0]!.selectionVersion).toBe(1);
    expect(stored[0]!.selectionState).toBe('selected');
    expect(stored[0]!.consecutiveMissingSnapshots).toBe(0);
  });

  it('end-to-end multi-run lifecycle: version change carries over and deselects without deactivating, then stable version applies 2-strike deactivation', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();

    // 100 items previously active at version 1
    const initial100: CatalogProductRecord[] = Array.from({ length: 100 }, (_, i) => ({
      ...seedRecord(`ITEM${i}`),
      canonicalUrl:
        i < 5
          ? `https://www.coach.com/products/tabby/ITEM${i}.html`
          : `https://www.coach.com/products/wristlet/ITEM${i}.html`,
      selectionState: 'selected',
      selectionVersion: 1,
      consecutiveMissingSnapshots: 0,
    }));
    products.seed(initial100);

    // Version 2 selection: includes only ITEM0 through ITEM4
    const v2Doc = parseSelectionDocument({
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: [
            { id: 'v2-items', kind: 'urlPattern', value: '/products/tabby/**' },
          ],
        },
      },
    }) as SelectionDocument;
    const v2Selection = compileSelection(v2Doc);

    const sitemapV2Xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://www.coach.com/products/tabby/ITEM0.html</loc></url>
  <url><loc>https://www.coach.com/products/tabby/ITEM1.html</loc></url>
  <url><loc>https://www.coach.com/products/tabby/ITEM2.html</loc></url>
  <url><loc>https://www.coach.com/products/tabby/ITEM3.html</loc></url>
  <url><loc>https://www.coach.com/products/tabby/ITEM4.html</loc></url>
</urlset>`;

    const pageFor = (id: string) =>
      tabbyHtml
        .replace('CEN52', id)
        .replace('/products/tabby-shoulder-bag-26/CEN52.html', `/products/tabby/${id}.html`);

    // --- RUN 1 (Version 2 first run): Version Bump ---
    const run1 = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(sitemapV2Xml),
      fetchPage: async (url) => {
        const match = /ITEM(\d+)\.html/i.exec(url);
        return { status: 200, body: pageFor(`ITEM${match![1]}`) };
      },
      robots: openRobots,
      products,
      crawlRuns,
      selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
      rateLimiter: noRateDelayLimiter(),
      selection: v2Selection,
    });

    expect(run1.isFullSnapshot).toBe(true);
    expect(run1.selectionVersion).toBe(2);
    expect(run1.newItems).toBe(0); // None genuinely new (all were in catalog)
    expect(run1.deselectedItems).toBe(95);
    expect(run1.missingItems).toBe(0); // Zero missing from v2 baseline
    expect(run1.inactiveItems).toBe(0); // Zero deactivated

    // All 100 products remain active!
    const allActiveAfterRun1 = await products.getActiveProducts('coach_us');
    expect(allActiveAfterRun1).toHaveLength(100);

    const selectedV2 = await products.getSelectedActiveProducts('coach_us', 2);
    expect(selectedV2).toHaveLength(5);

    // --- RUN 2 (Version 2 second run): Stable Version Full Crawl ---
    const run2 = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(sitemapV2Xml),
      fetchPage: async (url) => {
        const match = /ITEM(\d+)\.html/i.exec(url);
        return { status: 200, body: pageFor(`ITEM${match![1]}`) };
      },
      robots: openRobots,
      products,
      crawlRuns,
      selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
      rateLimiter: noRateDelayLimiter(),
      selection: v2Selection,
    });

    expect(run2.isFullSnapshot).toBe(true);
    expect(run2.selectionVersion).toBe(2);
    expect(run2.deselectedItems).toBe(0);
    expect(run2.missingItems).toBe(0);
    expect(run2.inactiveItems).toBe(0);

    // --- RUN 3 (Version 2 third run): ITEM4 missing once from sitemap ---
    const sitemapMissingItem4 = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://www.coach.com/products/tabby/ITEM0.html</loc></url>
  <url><loc>https://www.coach.com/products/tabby/ITEM1.html</loc></url>
  <url><loc>https://www.coach.com/products/tabby/ITEM2.html</loc></url>
  <url><loc>https://www.coach.com/products/tabby/ITEM3.html</loc></url>
</urlset>`;

    const run3 = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(sitemapMissingItem4),
      fetchPage: async (url) => {
        const match = /ITEM(\d+)\.html/i.exec(url);
        return { status: 200, body: pageFor(`ITEM${match![1]}`) };
      },
      robots: openRobots,
      products,
      crawlRuns,
      selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
      rateLimiter: noRateDelayLimiter(),
      selection: v2Selection,
    });

    expect(run3.isFullSnapshot).toBe(true);
    expect(run3.missingItems).toBe(1); // ITEM4 missing
    expect(run3.inactiveItems).toBe(0); // Not deactivated yet (1 miss < 2)

    const item4AfterRun3 = (await products.getActiveProducts('coach_us')).find((p) => p.externalId === 'ITEM4');
    expect(item4AfterRun3).toBeDefined();
    expect(item4AfterRun3!.consecutiveMissingSnapshots).toBe(1);
    expect(item4AfterRun3!.isActive).toBe(true);

    // --- RUN 4 (Version 2 fourth run): ITEM4 missing a second time ---
    const run4 = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(sitemapMissingItem4),
      fetchPage: async (url) => {
        const match = /ITEM(\d+)\.html/i.exec(url);
        return { status: 200, body: pageFor(`ITEM${match![1]}`) };
      },
      robots: openRobots,
      products,
      crawlRuns,
      selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
      rateLimiter: noRateDelayLimiter(),
      selection: v2Selection,
    });

    expect(run4.isFullSnapshot).toBe(true);
    expect(run4.missingItems).toBe(1);
    expect(run4.inactiveItems).toBe(1); // Deactivated after 2 consecutive misses!

    const item4AfterRun4 = products.all().find((p) => p.externalId === 'ITEM4');
    expect(item4AfterRun4!.isActive).toBe(false);
    expect(item4AfterRun4!.consecutiveMissingSnapshots).toBe(2);

    // Check crawl run records in DB
    const runs = await crawlRuns.recentRuns('coach_us', 4);
    expect(runs[0]!.selectionVersion).toBe(2);
    expect(runs[0]!.inactiveItems).toBe(1);
    expect(runs[3]!.selectionVersion).toBe(2);
    expect(runs[3]!.deselectedItems).toBe(95);
  });

  it('atomic selected-reconciliation failure rolls back cleanly and leaves product state byte-for-byte unchanged', async () => {
    // 1. Seed selected version-1 rows:
    // Row A: will match version 2 and would be stamped/upserted to version 2
    // Row B: will NOT match version 2 and would be deselected
    const initialRows: CatalogProductRecord[] = [
      {
        ...seedRecord('TABBYRETAINED'),
        canonicalUrl: 'https://www.coach.com/products/tabby/TABBYRETAINED.html',
        selectionState: 'selected',
        selectionVersion: 1,
        consecutiveMissingSnapshots: 0,
      },
      {
        ...seedRecord('WRISTLET001'),
        canonicalUrl: 'https://www.coach.com/products/wristlet/WRISTLET001.html',
        selectionState: 'selected',
        selectionVersion: 1,
        consecutiveMissingSnapshots: 0,
      },
    ];

    class FailingDuringApplyProductRepository extends InMemoryProductRepository {
      override async applySelectionSnapshot(diff: SelectionSnapshotPersistence): Promise<void> {
        // Assert that diff contains both deselections and upserts/stamps
        expect(diff.toDeselect.length).toBeGreaterThan(0);
        expect(diff.toUpsert.length).toBeGreaterThan(0);
        // Simulate a database failure / constraint violation during the atomic operation
        throw new Error('Database transaction abort / constraint violation');
      }
    }

    const products = new FailingDuringApplyProductRepository();
    products.seed(initialRows);

    // Capture serialized snapshot of initial product state
    const beforeState = JSON.stringify(products.all());

    const crawlRuns = new InMemoryCrawlRunRepository();

    // Version 2 selection: includes only /products/tabby/**
    const v2Doc = parseSelectionDocument({
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: [
            { id: 'tabby-rule', kind: 'urlPattern', value: '/products/tabby/**' },
          ],
        },
      },
    }) as SelectionDocument;
    const v2Selection = compileSelection(v2Doc);

    const sitemapXml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://www.coach.com/products/tabby/TABBYRETAINED.html</loc></url>
</urlset>`;

    const tabbyPageHtml = tabbyHtml
      .replace('CEN52', 'TABBYRETAINED')
      .replace('/products/tabby-shoulder-bag-26/CEN52.html', '/products/tabby/TABBYRETAINED.html');

    // 2. Execute crawl and assert it rejects with the error
    await expect(
      runCrawl({
        adapter: coachAdapter,
        fetchSitemap: sitemapOf(sitemapXml),
        fetchPage: async () => ({ status: 200, body: tabbyPageHtml }),
        robots: openRobots,
        products,
        crawlRuns,
        selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
        rateLimiter: noRateDelayLimiter(),
        selection: v2Selection,
      }),
    ).rejects.toThrow('Database transaction abort / constraint violation');

    // 3. Assert the crawl was recorded as failed with selection version
    const runs = await crawlRuns.recentRuns('coach_us', 1);
    expect(runs).toHaveLength(1);
    expect(runs[0]!.status).toBe('failed');
    expect(runs[0]!.isFullSnapshot).toBe(false);
    expect(runs[0]!.selectionVersion).toBe(2);

    // 4. Assert product state is byte-for-byte unchanged:
    // - no deselections (WRISTLET_DESELECTED is still selected at v1)
    // - no selection-version stamps (TABBY_RETAINED is still selected at v1)
    // - no missing-count changes (consecutiveMissingSnapshots is still 0)
    // - no inactive rows (both remain isActive: true)
    // - no new rows (total length remains 2)
    const afterState = JSON.stringify(products.all());
    expect(afterState).toBe(beforeState);
    expect(products.all()).toEqual(initialRows);
  });

  it('rolls back selected product state when successful run finalization fails', async () => {
    const initialRows: CatalogProductRecord[] = [{
      ...seedRecord('TABBYRETAINED'),
      canonicalUrl: 'https://www.coach.com/products/tabby/TABBYRETAINED.html',
      selectionState: 'selected',
      selectionVersion: 1,
      consecutiveMissingSnapshots: 0,
    }];
    const products = new InMemoryProductRepository();
    products.seed(initialRows);
    const beforeState = JSON.stringify(products.all());

    class FailsSuccessfulFinalization extends InMemoryCrawlRunRepository {
      override async finish(
        runId: number,
        params: Parameters<InMemoryCrawlRunRepository['finish']>[1],
      ): Promise<void> {
        if (params.status === 'success') {
          throw new Error('simulated successful finalization failure');
        }
        await super.finish(runId, params);
      }
    }
    const crawlRuns = new FailsSuccessfulFinalization();

    const selection = compileSelection(parseSelectionDocument({
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: [{ id: 'tabby-rule', kind: 'urlPattern', value: '/products/tabby/**' }],
        },
      },
    }) as SelectionDocument);
    const sitemapXml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://www.coach.com/products/tabby/TABBYRETAINED.html</loc></url>
</urlset>`;
    const tabbyPageHtml = tabbyHtml
      .replace('CEN52', 'TABBYRETAINED')
      .replace('/products/tabby-shoulder-bag-26/CEN52.html', '/products/tabby/TABBYRETAINED.html');

    await expect(
      runCrawl({
        adapter: coachAdapter,
        fetchSitemap: sitemapOf(sitemapXml),
        fetchPage: async () => ({ status: 200, body: tabbyPageHtml }),
        robots: openRobots,
        products,
        crawlRuns,
        selectionSnapshotCommitter: new InMemorySelectionSnapshotCommitter(products, crawlRuns),
        rateLimiter: noRateDelayLimiter(),
        selection,
      }),
    ).rejects.toThrow('simulated successful finalization failure');

    expect(JSON.stringify(products.all())).toBe(beforeState);
    expect(products.all()).toEqual(initialRows);

    const runs = await crawlRuns.recentRuns('coach_us', 1);
    expect(runs).toHaveLength(1);
    expect(runs[0]!.status).toBe('failed');
    expect(runs[0]!.isFullSnapshot).toBe(false);
    expect(runs[0]!.selectionVersion).toBe(2);
  });
});

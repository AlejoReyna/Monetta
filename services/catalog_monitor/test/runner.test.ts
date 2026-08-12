import { describe, expect, it } from 'vitest';
import { runCrawl, type PageFetchResult } from '../src/crawl/runner.js';
import { coachAdapter } from '../src/adapters/coach.js';
import { DomainRateLimiter } from '../src/crawl/rateLimiter.js';
import {
  InMemoryCrawlRunRepository,
  InMemoryProductRepository,
} from './support/inMemoryRepositories.js';
import { readFixture } from './support/fixtures.js';
import type { ExtractedProduct } from '../src/domain/types.js';
import type { ProductRepository } from '../src/crawl/ports.js';
import type { SitemapFetcher } from '../src/discovery/sitemap.js';

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
    expect(result.pagesFetched).toBe(2);
    expect(result.successfulParses).toBe(2);
    expect(result.newItems).toBe(2);

    const stored = await products.getActiveProducts('coach_us');
    expect(stored).toHaveLength(2);

    const runs = await crawlRuns.recentRuns('coach_us', 1);
    expect(runs[0]!.status).toBe('success');
    expect(runs[0]!.isFullSnapshot).toBe(true);
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

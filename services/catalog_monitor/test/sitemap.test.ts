import { describe, expect, it } from 'vitest';
import { discoverProductUrls, parseSitemapXml, type SitemapFetcher } from '../src/discovery/sitemap.js';
import { readFixture } from './support/fixtures.js';

const FIXTURES: Record<string, string> = {
  'https://www.coach.com/sitemap_index.xml': readFixture('coach/sitemap_index.xml'),
  'https://www.coach.com/sitemap_index_products.xml': readFixture(
    'coach/sitemap_index_products.xml',
  ),
  'https://www.coach.com/sitemap_products_1.xml': readFixture('coach/sitemap_products_1.xml'),
  'https://www.coach.com/sitemap_products_2.xml': readFixture('coach/sitemap_products_2.xml'),
  'https://www.coach.com/sitemap_categories.xml': readFixture('coach/sitemap_categories.xml'),
};

function okFetcher(overrides: Record<string, string> = {}): SitemapFetcher {
  return async (url: string) => {
    const body = overrides[url] ?? FIXTURES[url];
    if (body === undefined) throw new Error(`unexpected fetch: ${url}`);
    return { status: 200, body };
  };
}

describe('parseSitemapXml', () => {
  it('recognizes a sitemap index', () => {
    const parsed = parseSitemapXml(FIXTURES['https://www.coach.com/sitemap_index.xml']!);
    expect(parsed.kind).toBe('index');
    expect(parsed.urls).toHaveLength(2);
  });

  it('recognizes a urlset', () => {
    const parsed = parseSitemapXml(FIXTURES['https://www.coach.com/sitemap_products_1.xml']!);
    expect(parsed.kind).toBe('urlset');
    expect(parsed.urls).toContain('https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html');
  });
});

describe('discoverProductUrls', () => {
  it('recurses through nested sitemap indexes to collect every urlset URL', async () => {
    const result = await discoverProductUrls('https://www.coach.com/sitemap_index.xml', okFetcher());

    // 7 URLs total across sitemap_products_1 (3), sitemap_products_2 (2) and
    // sitemap_categories (2) — discovery does not classify, it just collects.
    expect(result.productUrls).toHaveLength(7);
    expect(result.productUrls).toContain('https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html');
    expect(result.productUrls).toContain('https://www.coach.com/products/rowan-satchel/C4295.html');
    expect(result.productUrls).toContain('https://www.coach.com/handbags');
    expect(result.errors).toHaveLength(0);
    expect(result.truncated).toBe(false);
    expect(result.sitemapUrlsVisited).toEqual(
      expect.arrayContaining([
        'https://www.coach.com/sitemap_index.xml',
        'https://www.coach.com/sitemap_index_products.xml',
        'https://www.coach.com/sitemap_products_1.xml',
        'https://www.coach.com/sitemap_products_2.xml',
        'https://www.coach.com/sitemap_categories.xml',
      ]),
    );
  });

  it('records a fetch failure for one sitemap without aborting the whole walk', async () => {
    const result = await discoverProductUrls(
      'https://www.coach.com/sitemap_index.xml',
      async (url) => {
        if (url === 'https://www.coach.com/sitemap_categories.xml') {
          throw new Error('simulated 500');
        }
        const body = FIXTURES[url];
        if (body === undefined) throw new Error(`unexpected fetch: ${url}`);
        return { status: 200, body };
      },
    );

    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]!.url).toBe('https://www.coach.com/sitemap_categories.xml');
    // The other branch of the recursion still completed.
    expect(result.productUrls).toContain('https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html');
  });

  it('treats a non-2xx sitemap response as an error, not an empty sitemap', async () => {
    const result = await discoverProductUrls(
      'https://www.coach.com/sitemap_index.xml',
      async (url) => {
        if (url === 'https://www.coach.com/sitemap_categories.xml') {
          return { status: 503, body: '' };
        }
        const body = FIXTURES[url];
        if (body === undefined) throw new Error(`unexpected fetch: ${url}`);
        return { status: 200, body };
      },
    );

    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]!.url).toBe('https://www.coach.com/sitemap_categories.xml');
    expect(result.errors[0]!.message).toBe('HTTP 503');
    // The categories urlset was never parsed as if it were empty — its
    // sibling branch still completed normally.
    expect(result.productUrls).toContain('https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html');
  });

  it('never visits more than maxSitemaps sitemaps and reports truncated when work remains queued', async () => {
    let calls = 0;
    const result = await discoverProductUrls(
      'https://www.coach.com/sitemap_index.xml',
      async (url) => {
        calls++;
        const body = FIXTURES[url];
        if (body === undefined) throw new Error(`unexpected fetch: ${url}`);
        return { status: 200, body };
      },
      { maxSitemaps: 1 },
    );
    expect(calls).toBe(1);
    expect(result.productUrls).toHaveLength(0);
    expect(result.truncated).toBe(true);
  });

  it('is not truncated when maxSitemaps is never reached', async () => {
    const result = await discoverProductUrls('https://www.coach.com/sitemap_index.xml', okFetcher(), {
      maxSitemaps: 500,
    });
    expect(result.truncated).toBe(false);
  });
});

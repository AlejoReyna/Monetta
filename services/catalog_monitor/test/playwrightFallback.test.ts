import { describe, expect, it, vi } from 'vitest';
import { runCrawl } from '../src/crawl/runner.js';
import { coachAdapter } from '../src/adapters/coach.js';
import { DomainRateLimiter } from '../src/crawl/rateLimiter.js';
import {
  InMemoryCrawlRunRepository,
  InMemoryProductRepository,
} from './support/inMemoryRepositories.js';
import { readFixture } from './support/fixtures.js';

const SITEMAP = `<?xml version="1.0"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html</loc></url>
</urlset>`;

const PRODUCT_URL = 'https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html';
const INCOMPLETE_HTML = readFixture('coach/product_missing_fields.html');
const COMPLETE_HTML = readFixture('coach/product_jsonld.html');

const noRateDelayLimiter = () => new DomainRateLimiter(0);
const openRobots = { disallow: [], allow: [] };
const sitemapOf = (xml: string) => async () => ({ status: 200, body: xml });

describe('runCrawl Playwright rendered fallback', () => {
  it('is invoked only when static extraction is incomplete, and its success completes the page', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();
    const renderWithPlaywright = vi.fn(async () => COMPLETE_HTML);

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP),
      fetchPage: async () => ({ status: 200, body: INCOMPLETE_HTML }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      playwrightFallbackEnabled: true,
      renderWithPlaywright,
    });

    expect(renderWithPlaywright).toHaveBeenCalledTimes(1);
    expect(renderWithPlaywright).toHaveBeenCalledWith(PRODUCT_URL);
    expect(result.successfulParses).toBe(1);
    expect(result.status).toBe('success');
  });

  it('is never invoked when static extraction already produced a complete record', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();
    const renderWithPlaywright = vi.fn(async () => COMPLETE_HTML);

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP),
      fetchPage: async () => ({ status: 200, body: COMPLETE_HTML }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      playwrightFallbackEnabled: true,
      renderWithPlaywright,
    });

    expect(renderWithPlaywright).not.toHaveBeenCalled();
    expect(result.successfulParses).toBe(1);
  });

  it('is never invoked when playwrightFallbackEnabled is false, even if extraction is incomplete', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();
    const renderWithPlaywright = vi.fn(async () => COMPLETE_HTML);

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP),
      fetchPage: async () => ({ status: 200, body: INCOMPLETE_HTML }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      playwrightFallbackEnabled: false,
      renderWithPlaywright,
    });

    expect(renderWithPlaywright).not.toHaveBeenCalled();
    expect(result.successfulParses).toBe(0);
  });

  it('a browser launch/render failure is recorded explicitly and leaves the page incomplete, not silently swallowed', async () => {
    const products = new InMemoryProductRepository();
    const crawlRuns = new InMemoryCrawlRunRepository();
    const renderWithPlaywright = vi.fn(async () => {
      throw new Error('Executable doesn\'t exist at /root/.cache/ms-playwright/chromium/headless_shell');
    });

    const result = await runCrawl({
      adapter: coachAdapter,
      fetchSitemap: sitemapOf(SITEMAP),
      fetchPage: async () => ({ status: 200, body: INCOMPLETE_HTML }),
      robots: openRobots,
      products,
      crawlRuns,
      rateLimiter: noRateDelayLimiter(),
      playwrightFallbackEnabled: true,
      renderWithPlaywright,
    });

    expect(renderWithPlaywright).toHaveBeenCalledTimes(1);
    // The failure is visible in the run's metrics under its own error type...
    expect(result.errorsByType.render_failed).toBe(1);
    // ...and the page is still counted as an incomplete parse, not a success.
    expect(result.successfulParses).toBe(0);
    expect(result.errorsByType.parse_missing_fields).toBe(1);
    expect(result.status).toBe('partial'); // coverage 0% — below the 98% bar
  });
});

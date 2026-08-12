import { describe, expect, it, vi } from 'vitest';
import { fetchRobotsRules, robotsUserAgentToken } from '../src/robots/fetchRobots.js';
import { crawlSourceWithRobotsGate } from '../src/crawl/guardedCrawl.js';
import { coachAdapter } from '../src/adapters/coach.js';
import { InMemoryCrawlRunRepository, InMemoryProductRepository } from './support/inMemoryRepositories.js';
import { readFixture } from './support/fixtures.js';

const VALID_ROBOTS = readFixture('michael_kors/robots.txt');

describe('fetchRobotsRules', () => {
  it('fails closed on a non-200 response', async () => {
    const outcome = await fetchRobotsRules('https://www.coach.com', async () => ({
      status: 503,
      body: '',
    }));
    expect(outcome.ok).toBe(false);
  });

  it('fails closed on a network/timeout error', async () => {
    const outcome = await fetchRobotsRules('https://www.coach.com', async () => {
      throw new Error('ETIMEDOUT');
    });
    expect(outcome.ok).toBe(false);
  });

  it('fails closed on a malformed 200 response instead of defaulting to empty allow/disallow lists', async () => {
    const outcome = await fetchRobotsRules('https://www.coach.com', async () => ({
      status: 200,
      body: '<html><body>Access Denied</body></html>',
    }));
    expect(outcome.ok).toBe(false);
    if (!outcome.ok) {
      // Never silently treated as "no restrictions."
      expect(outcome.reason).toMatch(/malformed|empty/i);
    }
  });

  it('fails closed on an empty 200 response body', async () => {
    const outcome = await fetchRobotsRules('https://www.coach.com', async () => ({
      status: 200,
      body: '',
    }));
    expect(outcome.ok).toBe(false);
  });

  it('parses a valid robots.txt on a clean 200 response', async () => {
    const outcome = await fetchRobotsRules('https://www.michaelkors.com', async () => ({
      status: 200,
      body: VALID_ROBOTS,
    }));
    expect(outcome.ok).toBe(true);
    if (outcome.ok) {
      expect(outcome.rules.disallow).toContain('/account/');
    }
  });

  it('derives the robots.txt group-matching token from a descriptive user agent string', () => {
    expect(
      robotsUserAgentToken('MonettaCatalogMonitor/0.1 (+https://monetta.mx; contact: crawler-contact@example.invalid)'),
    ).toBe('MonettaCatalogMonitor');
  });
});

describe('crawlSourceWithRobotsGate', () => {
  it('never fetches sitemap or product pages after a robots-fetch failure, and records a failed run', async () => {
    const crawlRuns = new InMemoryCrawlRunRepository();
    const products = new InMemoryProductRepository();
    const fetchSitemap = vi.fn(async () => ({ status: 200, body: '<urlset></urlset>' }));
    const fetchPage = vi.fn(async () => ({ status: 200, body: '' }));

    const outcome = await crawlSourceWithRobotsGate({
      adapter: coachAdapter,
      fetchRobots: async () => ({ status: 500, body: '' }),
      userAgent: 'MonettaCatalogMonitor/0.1 (+https://monetta.mx)',
      fetchSitemap,
      fetchPage,
      products,
      crawlRuns,
    });

    expect(outcome.robotsOk).toBe(false);
    expect(fetchSitemap).not.toHaveBeenCalled();
    expect(fetchPage).not.toHaveBeenCalled();

    const runs = await crawlRuns.recentRuns('coach_us', 10);
    expect(runs).toHaveLength(1);
    expect(runs[0]!.status).toBe('failed');
    expect(runs[0]!.errorsByType.robots_unavailable).toBe(1);
  });

  it('does not record a run when robots fails during a --dry-run attempt', async () => {
    const crawlRuns = new InMemoryCrawlRunRepository();
    const products = new InMemoryProductRepository();

    const outcome = await crawlSourceWithRobotsGate({
      adapter: coachAdapter,
      fetchRobots: async () => ({ status: 500, body: '' }),
      userAgent: 'MonettaCatalogMonitor/0.1',
      fetchSitemap: vi.fn(),
      fetchPage: vi.fn(),
      products,
      crawlRuns,
      dryRun: true,
    });

    expect(outcome.robotsOk).toBe(false);
    expect(await crawlRuns.recentRuns('coach_us', 10)).toHaveLength(0);
  });

  it('proceeds to crawl normally when robots.txt is fetched successfully', async () => {
    const crawlRuns = new InMemoryCrawlRunRepository();
    const products = new InMemoryProductRepository();

    const outcome = await crawlSourceWithRobotsGate({
      adapter: coachAdapter,
      fetchRobots: async () => ({ status: 200, body: 'User-agent: *\nDisallow: /cart/\n' }),
      userAgent: 'MonettaCatalogMonitor/0.1',
      fetchSitemap: async () => ({
        status: 200,
        body: '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>',
      }),
      fetchPage: vi.fn(async () => ({ status: 200, body: '' })),
      products,
      crawlRuns,
    });

    expect(outcome.robotsOk).toBe(true);
  });
});

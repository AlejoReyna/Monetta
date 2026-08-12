import { parseRobotsTxt, type RobotsRules } from './robotsTxt.js';
import { DomainRateLimiter, domainOf } from '../crawl/rateLimiter.js';
import { logger } from '../logger.js';
import type { CrawlRunRepository } from '../crawl/ports.js';
import type { SourceId } from '../domain/types.js';

/**
 * Shared by the scheduler and the manual CLI so there is exactly one place
 * that decides "did robots.txt actually load, and are these actually its
 * rules." A robots-fetch failure must never be silently replaced with an
 * empty allow/disallow list — that would read as "no restrictions" rather
 * than "we don't actually know."
 */
export type RobotsFetcher = (url: string) => Promise<{ status: number; body: string }>;

export type RobotsFetchOutcome =
  | { readonly ok: true; readonly rules: RobotsRules }
  | { readonly ok: false; readonly reason: string };

/**
 * Extracts the product token robots.txt group-matching expects (e.g.
 * `MonettaCatalogMonitor` out of `MonettaCatalogMonitor/0.1 (+https://...)`)
 * — the truthful, contactable descriptive string is not itself a robots.txt
 * user-agent token.
 */
export function robotsUserAgentToken(userAgent: string): string {
  const beforeSlashOrParen = userAgent.split(/[/\s(]/)[0]?.trim();
  return beforeSlashOrParen && beforeSlashOrParen.length > 0 ? beforeSlashOrParen : '*';
}

/** A 200 response whose body doesn't look like a robots.txt at all (e.g. an HTML error page) is malformed, not "no rules." */
function looksLikeRobotsTxt(body: string): boolean {
  return /^\s*#|user-agent\s*:/im.test(body);
}

export async function fetchRobotsRules(
  baseUrl: string,
  fetchRobots: RobotsFetcher,
  options: { userAgent?: string; rateLimiter?: DomainRateLimiter } = {},
): Promise<RobotsFetchOutcome> {
  const url = new URL('/robots.txt', baseUrl).toString();
  const doFetch = () => fetchRobots(url);

  let response: { status: number; body: string };
  try {
    response = options.rateLimiter
      ? await options.rateLimiter.schedule(domainOf(url), doFetch)
      : await doFetch();
  } catch (error) {
    return { ok: false, reason: error instanceof Error ? error.message : String(error) };
  }

  if (response.status !== 200) {
    return { ok: false, reason: `robots.txt fetch returned HTTP ${response.status}` };
  }
  if (typeof response.body !== 'string' || !looksLikeRobotsTxt(response.body)) {
    return { ok: false, reason: 'robots.txt response body was empty or malformed' };
  }

  const userAgentToken = options.userAgent ? robotsUserAgentToken(options.userAgent) : '*';
  const rules = parseRobotsTxt(response.body, userAgentToken);
  return { ok: true, rules };
}

/**
 * Persists a failed/partial crawl-run record describing a robots-fetch
 * failure, without ever calling `runCrawl` — no sitemap or product page is
 * fetched for this source on this attempt.
 */
export async function recordRobotsFailureRun(
  crawlRuns: CrawlRunRepository,
  sourceId: SourceId,
  reason: string,
  now: () => Date = () => new Date(),
): Promise<void> {
  const startedAt = now();
  const runId = await crawlRuns.start({ sourceId, startedAt });
  await crawlRuns.finish(runId, {
    endedAt: now(),
    status: 'failed',
    isFullSnapshot: false,
    urlsDiscovered: 0,
    pagesFetched: 0,
    successfulParses: 0,
    newItems: 0,
    changedItems: 0,
    missingItems: 0,
    inactiveItems: 0,
    errorsByType: { robots_unavailable: 1 },
  });
  logger.error('robots.txt unavailable — refusing to crawl this source', { sourceId, reason });
}

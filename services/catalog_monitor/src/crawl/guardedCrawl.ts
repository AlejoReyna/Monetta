import { runCrawl, type RunCrawlParams, type RunCrawlResult } from './runner.js';
import { fetchRobotsRules, recordRobotsFailureRun, type RobotsFetcher } from '../robots/fetchRobots.js';

export type GuardedCrawlOutcome =
  | { readonly robotsOk: true; readonly result: RunCrawlResult }
  | { readonly robotsOk: false; readonly reason: string };

export interface GuardedCrawlParams extends Omit<RunCrawlParams, 'robots'> {
  readonly fetchRobots: RobotsFetcher;
  readonly userAgent: string;
}

/**
 * The single entry point the scheduler and the manual CLI both call to crawl
 * one source. Fetches robots.txt through the shared fail-closed
 * implementation first; a robots-fetch failure (non-200, timeout, malformed
 * response, network error) records a failed run and returns without ever
 * calling `runCrawl` — no sitemap request, no product page request is made
 * for this source on this attempt.
 */
export async function crawlSourceWithRobotsGate(params: GuardedCrawlParams): Promise<GuardedCrawlOutcome> {
  const robots = await fetchRobotsRules(params.adapter.source.baseUrl, params.fetchRobots, {
    userAgent: params.userAgent,
    rateLimiter: params.rateLimiter,
  });

  if (!robots.ok) {
    if (!params.dryRun) {
      await recordRobotsFailureRun(params.crawlRuns, params.adapter.source.id, robots.reason, params.now);
    }
    return { robotsOk: false, reason: robots.reason };
  }

  const { fetchRobots: _fetchRobots, userAgent: _userAgent, ...runParams } = params;
  const result = await runCrawl({ ...runParams, robots: robots.rules });
  return { robotsOk: true, result };
}

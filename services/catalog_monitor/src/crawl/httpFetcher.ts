import { loadConfig } from '../config.js';
import { NonRetryableError } from './retry.js';

/**
 * The single choke point for real outbound HTTP in this service. Every
 * live-network code path (scheduler, manual CLI without `--dry-run`) must
 * fetch through this function, because this is where the
 * `LIVE_CRAWL_ENABLED` gate lives. Tests and `--dry-run` never call it — they
 * inject a fixture-backed fetcher instead (see `test/support/fixtureFetcher.ts`).
 */
export interface FetchResult {
  readonly status: number;
  readonly body: string;
  readonly headers: Readonly<Record<string, string>>;
  /** URL after the HTTP client followed any redirects. */
  readonly finalUrl: string;
}

const DEFAULT_TIMEOUT_MS = 15_000;

export async function liveFetch(url: string): Promise<FetchResult> {
  const config = loadConfig();
  if (!config.liveCrawlEnabled) {
    throw new NonRetryableError(
      'Live crawling is disabled (LIVE_CRAWL_ENABLED=false). Refusing to fetch ' + url,
    );
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': config.userAgent,
        'Accept-Language': 'en-US,en;q=0.9',
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
      redirect: 'follow',
      signal: controller.signal,
    });
    const body = await response.text();
    const headers: Record<string, string> = {};
    response.headers.forEach((value, key) => (headers[key] = value));
    return { status: response.status, body, headers, finalUrl: response.url };
  } finally {
    clearTimeout(timeout);
  }
}

export function isRetryableFetchError(error: unknown): boolean {
  if (error instanceof NonRetryableError) return false;
  if (error instanceof Error) {
    if (error.name === 'AbortError') return true; // timeout
    if (/ECONNRESET|ETIMEDOUT|ENOTFOUND|EAI_AGAIN|ECONNREFUSED/.test(error.message)) return true;
  }
  return true;
}

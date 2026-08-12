import * as cheerio from 'cheerio';

/** Injected so discovery is testable with fixtures and never opens a socket in tests. */
export interface SitemapFetchResult {
  readonly status: number;
  readonly body: string;
}
export type SitemapFetcher = (url: string) => Promise<SitemapFetchResult>;

export interface SitemapDiscoveryResult {
  readonly productUrls: readonly string[];
  readonly sitemapUrlsVisited: readonly string[];
  readonly errors: readonly { url: string; message: string }[];
  /**
   * True when `maxSitemaps` was reached while sitemaps remained queued —
   * the discovered URL set is known-incomplete, not "that's everything."
   * Callers must never treat a truncated run as a full snapshot.
   */
  readonly truncated: boolean;
}

/**
 * Recursively walks a sitemap index: `<sitemapindex>` entries are followed,
 * `<urlset>` entries are collected as candidate product URLs (classification
 * into "is this actually a product page" is the adapter's job, not
 * discovery's — see `adapters/*.ts`).
 *
 * Bounded by `maxSitemaps` so a misconfigured or hostile sitemap graph cannot
 * cause unbounded recursion or an unbounded number of requests. A non-2xx
 * response is always recorded as an error — it is never parsed as if it were
 * an empty sitemap, since "the server refused this sitemap" and "this
 * sitemap legitimately has zero entries" are very different situations.
 */
export async function discoverProductUrls(
  indexUrl: string,
  fetchSitemap: SitemapFetcher,
  options: { maxSitemaps?: number } = {},
): Promise<SitemapDiscoveryResult> {
  const maxSitemaps = options.maxSitemaps ?? 500;
  const visited = new Set<string>();
  const productUrls = new Set<string>();
  const errors: { url: string; message: string }[] = [];
  const queue: string[] = [indexUrl];

  while (queue.length > 0 && visited.size < maxSitemaps) {
    const url = queue.shift();
    if (!url || visited.has(url)) continue;
    visited.add(url);

    let result: SitemapFetchResult;
    try {
      result = await fetchSitemap(url);
    } catch (error) {
      errors.push({ url, message: error instanceof Error ? error.message : String(error) });
      continue;
    }

    if (result.status < 200 || result.status >= 300) {
      errors.push({ url, message: `HTTP ${result.status}` });
      continue;
    }

    let parsed: ParsedSitemap;
    try {
      parsed = parseSitemapXml(result.body);
    } catch (error) {
      errors.push({ url, message: error instanceof Error ? error.message : String(error) });
      continue;
    }

    if (parsed.kind === 'index') {
      for (const childUrl of parsed.urls) {
        if (!visited.has(childUrl)) queue.push(childUrl);
      }
    } else {
      for (const productUrl of parsed.urls) productUrls.add(productUrl);
    }
  }

  return {
    productUrls: [...productUrls],
    sitemapUrlsVisited: [...visited],
    errors,
    truncated: queue.length > 0 && visited.size >= maxSitemaps,
  };
}

export type ParsedSitemap =
  | { kind: 'index'; urls: readonly string[] }
  | { kind: 'urlset'; urls: readonly string[] };

/** Parses either a `<sitemapindex>` or a `<urlset>` document. */
export function parseSitemapXml(xml: string): ParsedSitemap {
  const $ = cheerio.load(xml, { xmlMode: true });

  if ($('sitemapindex').length > 0) {
    const urls = $('sitemapindex > sitemap > loc')
      .map((_, el) => $(el).text().trim())
      .get()
      .filter(Boolean);
    return { kind: 'index', urls };
  }

  const urls = $('urlset > url > loc')
    .map((_, el) => $(el).text().trim())
    .get()
    .filter(Boolean);
  return { kind: 'urlset', urls };
}

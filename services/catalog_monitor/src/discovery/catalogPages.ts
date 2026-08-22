import * as cheerio from 'cheerio';
import type { SitemapDiscoveryResult, SitemapFetcher } from './sitemap.js';

/**
 * Discovers product links from a small, explicit set of public catalog pages.
 * Only same-page `?p=N` pagination is followed, so a navigation menu cannot
 * turn this into a whole-site crawl. This is used for GP McAllen because its
 * robots-advertised Magento sitemap currently returns 404.
 */
export async function discoverProductUrlsFromCatalogPages(
  seedUrls: readonly string[],
  fetchPage: SitemapFetcher,
  isProductUrl: (url: string) => boolean,
  options: { maxPages?: number } = {},
): Promise<SitemapDiscoveryResult> {
  const maxPages = options.maxPages ?? 40;
  const seedPaths = new Set(seedUrls.map((url) => new URL(url).pathname));
  const allowedHosts = new Set(seedUrls.map((url) => new URL(url).hostname.toLowerCase()));
  const queue = [...seedUrls];
  const visited = new Set<string>();
  const products = new Set<string>();
  const errors: { url: string; message: string }[] = [];

  while (queue.length > 0 && visited.size < maxPages) {
    const url = queue.shift();
    if (!url || visited.has(url)) continue;
    visited.add(url);

    let response: Awaited<ReturnType<SitemapFetcher>>;
    try {
      response = await fetchPage(url);
    } catch (error) {
      errors.push({ url, message: error instanceof Error ? error.message : String(error) });
      continue;
    }

    if (response.status < 200 || response.status >= 300) {
      errors.push({ url, message: `HTTP ${response.status}` });
      continue;
    }

    const $ = cheerio.load(response.body);
    for (const rawHref of $('a[href]').map((_, element) => $(element).attr('href')).get()) {
      if (!rawHref) continue;
      let candidate: URL;
      try {
        candidate = new URL(rawHref, url);
      } catch {
        continue;
      }
      if (candidate.protocol !== 'https:' || !allowedHosts.has(candidate.hostname.toLowerCase())) {
        continue;
      }
      candidate.hash = '';
      const normalized = candidate.toString();
      if (isProductUrl(normalized)) {
        products.add(normalized);
        continue;
      }

      const pageNumber = candidate.searchParams.get('p');
      if (
        pageNumber !== null &&
        /^\d+$/.test(pageNumber) &&
        Number(pageNumber) > 1 &&
        seedPaths.has(candidate.pathname) &&
        !visited.has(normalized) &&
        !queue.includes(normalized)
      ) {
        queue.push(normalized);
      }
    }
  }

  return {
    productUrls: [...products],
    sitemapUrlsVisited: [...visited],
    errors,
    truncated: queue.length > 0 && visited.size >= maxPages,
  };
}

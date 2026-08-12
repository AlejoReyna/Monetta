import { loadConfig } from '../config.js';
import type { RenderedPage } from './runner.js';

/**
 * Renders a page with a headless browser for the small number of product
 * pages that need client-side rendering to expose JSON-LD/metadata/DOM. This
 * is a last resort: slower, heavier, and only invoked when
 * `PLAYWRIGHT_FALLBACK_ENABLED=true` *and* the static extraction tiers
 * (JSON-LD, Open Graph, selectors) all failed to produce every required
 * field — see `parsing/productExtractor.ts` and `crawl/runner.ts`.
 *
 * `playwright` is imported dynamically so that nothing in the normal test
 * suite, `npm install`, or a `PLAYWRIGHT_FALLBACK_ENABLED=false` deploy ever
 * needs the browser binaries installed.
 */
export async function renderWithPlaywright(url: string): Promise<RenderedPage> {
  const config = loadConfig();
  if (!config.liveCrawlEnabled) {
    throw new Error('Live crawling is disabled (LIVE_CRAWL_ENABLED=false). Refusing to render ' + url);
  }
  const { chromium } = await import('playwright');
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ userAgent: config.userAgent });
    await page.goto(url, { waitUntil: 'networkidle', timeout: 20_000 });
    return { html: await page.content(), finalUrl: page.url() };
  } finally {
    await browser.close();
  }
}

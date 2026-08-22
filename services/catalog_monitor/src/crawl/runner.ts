import { discoverProductUrls, type SitemapFetcher } from '../discovery/sitemap.js';
import { discoverProductUrlsFromCatalogPages } from '../discovery/catalogPages.js';
import { isAllowedByRobots, type RobotsRules } from '../robots/robotsTxt.js';
import { extractProduct } from '../parsing/productExtractor.js';
import { looksLikeCaptchaOrBlock } from './blockDetection.js';
import { diffFullSnapshot } from './snapshotDiff.js';
import { withRetry, type RetryOptions } from './retry.js';
import { DomainRateLimiter, domainOf } from './rateLimiter.js';
import { MIN_REQUIRED_FIELD_COVERAGE } from '../monitor/health.js';
import { validateFetchedMarket } from './marketGuard.js';
import type { BrandAdapter } from '../adapters/types.js';
import type { CrawlRunRepository, ProductRepository } from './ports.js';
import type {
  CrawlRunStatus,
  ErrorType,
  ExtractedProduct,
  ExtractedProductVariant,
} from '../domain/types.js';

export interface PageFetchResult {
  readonly status: number;
  readonly body: string;
  /** Optional for fixture fetchers; live fetchers must provide it. */
  readonly finalUrl?: string;
}

export type PageFetcher = (url: string) => Promise<PageFetchResult>;

export interface RunCrawlParams {
  readonly adapter: BrandAdapter;
  readonly fetchSitemap: SitemapFetcher;
  readonly fetchPage: PageFetcher;
  readonly robots: RobotsRules;
  readonly products: ProductRepository;
  readonly crawlRuns: CrawlRunRepository;
  readonly now?: () => Date;
  /** Caps the number of product pages fetched — used by `--limit` and capped smoke tests. Forces `isFullSnapshot: false`. */
  readonly limit?: number;
  /** Bounds sitemap traversal — see `discovery/sitemap.ts`. Reaching this cap with work still queued forces a partial run. */
  readonly maxSitemaps?: number;
  readonly rateLimiter?: DomainRateLimiter;
  readonly retryOptions?: RetryOptions;
  readonly renderWithPlaywright?: (url: string) => Promise<string | RenderedPage>;
  readonly playwrightFallbackEnabled?: boolean;
  /** When true, nothing is written to the database — used by `--dry-run`. */
  readonly dryRun?: boolean;
}

export interface RenderedPage {
  readonly html: string;
  readonly finalUrl: string;
}

export interface RunCrawlResult {
  readonly status: CrawlRunStatus;
  readonly isFullSnapshot: boolean;
  readonly urlsDiscovered: number;
  readonly pagesFetched: number;
  readonly successfulParses: number;
  readonly newItems: number;
  readonly changedItems: number;
  readonly missingItems: number;
  readonly inactiveItems: number;
  readonly errorsByType: Partial<Record<ErrorType, number>>;
  readonly items: readonly ExtractedProduct[];
}

/**
 * Coach can list one sitemap URL per color while MK usually exposes all
 * swatches from one parent page. Reconcile both shapes into one parent
 * product and a de-duplicated variant collection before snapshot diffing.
 */
function mergeProductVariants(
  previous: ExtractedProduct,
  next: ExtractedProduct,
): ExtractedProduct {
  const variants = new Map<string, ExtractedProductVariant>();
  for (const variant of [...(previous.variants ?? []), ...(next.variants ?? [])]) {
    variants.set(variant.variantId, variant);
  }
  const prices = [previous.priceUsd, next.priceUsd].filter(
    (price): price is number => price !== null,
  );
  return {
    ...previous,
    imageUrl: previous.imageUrl ?? next.imageUrl,
    priceUsd: prices.length === 0 ? null : Math.min(...prices),
    availability:
      previous.availability === 'inStock' || next.availability === 'inStock'
        ? 'inStock'
        : previous.availability === 'outOfStock' && next.availability === 'outOfStock'
          ? 'outOfStock'
          : 'unknown',
    variants: [...variants.values()].sort((a, b) =>
      a.variantId.localeCompare(b.variantId),
    ),
  };
}

/** Thrown internally so `withRetry` treats a 429/5xx response as a retryable failure. */
class RetryableHttpError extends Error {
  constructor(readonly status: number) {
    super(`HTTP ${status}`);
  }
}

const EMPTY_FINISH_METRICS = {
  urlsDiscovered: 0,
  pagesFetched: 0,
  successfulParses: 0,
  newItems: 0,
  changedItems: 0,
  missingItems: 0,
  inactiveItems: 0,
} as const;

export async function runCrawl(params: RunCrawlParams): Promise<RunCrawlResult> {
  const now = params.now ?? (() => new Date());
  const rateLimiter = params.rateLimiter ?? new DomainRateLimiter(1000);
  const startedAt = now();

  const runId = params.dryRun
    ? null
    : await params.crawlRuns.start({
        sourceId: params.adapter.source.id,
        startedAt,
      });

  const errorsByType: Partial<Record<ErrorType, number>> = {};
  const recordError = (type: ErrorType) => {
    errorsByType[type] = (errorsByType[type] ?? 0) + 1;
  };

  // Tracked outside the try block so a fatal exception can still finalize the
  // run record with whatever real progress was made, rather than all zeros.
  let urlsDiscoveredCount = 0;
  let pagesFetched = 0;
  let successfulParses = 0;

  try {
    const fetchSitemapRateLimited: SitemapFetcher = (url) =>
      rateLimiter.schedule(domainOf(url), () => params.fetchSitemap(url));

    const discovery = params.adapter.source.catalogPageUrls.length > 0
      ? await discoverProductUrlsFromCatalogPages(
          params.adapter.source.catalogPageUrls,
          fetchSitemapRateLimited,
          (url) => params.adapter.isProductUrl(url),
          { maxPages: params.maxSitemaps },
        )
      : await discoverProductUrls(
          params.adapter.source.sitemapIndexUrl!,
          fetchSitemapRateLimited,
          { maxSitemaps: params.maxSitemaps },
        );
    // A sitemap that failed to fetch, returned a non-2xx status, or could not
    // be parsed must be visible in the run's metrics, not silently swallowed
    // into "0 URLs discovered" — those look identical otherwise, and only one
    // of them means "nothing to worry about."
    discovery.errors.forEach((error) => recordError(classifySitemapErrorMessage(error.message)));

    const classified = discovery.productUrls.filter((url) => params.adapter.isProductUrl(url));
    const robotsAllowed = classified.filter((url) => {
      const path = safePathname(url);
      return path !== null && isAllowedByRobots(params.robots, path);
    });
    urlsDiscoveredCount = robotsAllowed.length;

    const limited = params.limit !== undefined && robotsAllowed.length > params.limit;
    const toFetch = params.limit !== undefined ? robotsAllowed.slice(0, params.limit) : robotsAllowed;

    const itemsById = new Map<string, ExtractedProduct>();
    let blocked = false;

    for (const url of toFetch) {
      if (blocked) break;
      const domain = domainOf(url);

      let outcome: PageFetchResult | null = null;
      try {
        outcome = await rateLimiter.schedule(domain, () =>
          withRetry(
            async () => {
              const result = await params.fetchPage(url);
              if (result.status === 429 || result.status >= 500) {
                throw new RetryableHttpError(result.status);
              }
              return result;
            },
            {
              maxRetries: 3,
              isRetryable: (error) => isRetryableStatusOrError(error),
              ...params.retryOptions,
            },
          ),
        );
      } catch (error) {
        pagesFetched++;
        recordError(classifyThrownError(error));
        continue;
      }

      pagesFetched++;

      if (looksLikeCaptchaOrBlock(outcome)) {
        recordError('captcha_or_block');
        blocked = true;
        break;
      }
      if (outcome.status >= 500) {
        recordError('http_5xx');
        continue;
      }
      if (outcome.status >= 400) {
        recordError('http_4xx');
        continue;
      }

      const market = validateFetchedMarket(params.adapter, url, outcome.finalUrl);
      if (!market.ok) {
        recordError('wrong_market');
        continue;
      }

      const externalId = params.adapter.externalIdFromUrl(market.finalUrl);
      if (!externalId) {
        recordError('parse_malformed');
        continue;
      }

      let extraction = extractProduct(outcome.body, {
        canonicalUrl: market.finalUrl,
        externalId,
        fallbackBrand: params.adapter.source.brand,
        selectors: params.adapter.selectors,
      });

      if (!extraction.complete && params.playwrightFallbackEnabled && params.renderWithPlaywright) {
        try {
          const rendered = await rateLimiter.schedule(domain, () => params.renderWithPlaywright!(url));
          const renderedPage: RenderedPage =
            typeof rendered === 'string'
              ? { html: rendered, finalUrl: market.finalUrl }
              : rendered;
          const renderedMarket = validateFetchedMarket(
            params.adapter,
            url,
            renderedPage.finalUrl,
          );
          if (!renderedMarket.ok) {
            recordError('wrong_market');
            continue;
          }
          extraction = extractProduct(renderedPage.html, {
            canonicalUrl: renderedMarket.finalUrl,
            externalId,
            fallbackBrand: params.adapter.source.brand,
            selectors: params.adapter.selectors,
          });
        } catch {
          // Playwright failing must not throw the whole run — but it must not
          // be silently invisible either. Recorded explicitly below; the page
          // falls through to whatever the static extraction tiers found
          // (which, by construction of this branch, was incomplete).
          recordError('render_failed');
        }
      }

      if (extraction.complete && extraction.product) {
        successfulParses++;
        const previous = itemsById.get(extraction.product.externalId);
        itemsById.set(
          extraction.product.externalId,
          previous
            ? mergeProductVariants(previous, extraction.product)
            : extraction.product,
        );
      } else {
        recordError('parse_missing_fields');
      }
    }

    const items = [...itemsById.values()];
    const allAttempted = !blocked && pagesFetched === toFetch.length;
    const coverage = pagesFetched > 0 ? successfulParses / pagesFetched : 0;
    const coverageOk = pagesFetched > 0 && coverage >= MIN_REQUIRED_FIELD_COVERAGE;

    let status: CrawlRunStatus;
    let isFullSnapshot: boolean;

    if (blocked) {
      status = 'blocked';
      isFullSnapshot = false;
    } else if (discovery.errors.length > 0) {
      // A sitemap that failed to fetch/parse/status-check means the
      // discovered URL set is incomplete by construction — diffing against
      // it would read as "every other item disappeared."
      status = 'partial';
      isFullSnapshot = false;
    } else if (discovery.truncated) {
      // maxSitemaps was hit with sitemaps still queued — same reasoning as
      // above: the discovered set is known-incomplete.
      status = 'partial';
      isFullSnapshot = false;
    } else if (classified.length === 0 || robotsAllowed.length === 0) {
      // Zero classified/allowed product URLs is never a legitimate "full
      // snapshot of an empty catalog" — it is far more likely an adapter or
      // sitemap-shape regression, and must not be read as "0 products now."
      status = 'partial';
      isFullSnapshot = false;
    } else if (limited) {
      status = 'success';
      isFullSnapshot = false;
    } else if (!allAttempted) {
      status = 'partial';
      isFullSnapshot = false;
    } else if (!coverageOk) {
      status = 'partial';
      isFullSnapshot = false;
    } else {
      status = 'success';
      isFullSnapshot = true;
    }

    let newItems = 0;
    let changedItems = 0;
    let missingItems = 0;
    let inactiveItems = 0;

    // `--dry-run` touches the repositories not at all — no read, no write —
    // so it can run against a live site with zero database infrastructure.
    // It reports raw extraction stats only; new/changed/missing/inactive
    // counts require comparing against stored state, which a true dry run
    // does not do. Runs below the coverage/attempt/discovery bar never reach
    // this branch because `isFullSnapshot` is already false for them.
    if (isFullSnapshot && !params.dryRun) {
      const previousActive = await params.products.getActiveProducts(params.adapter.source.id);
      const diff = diffFullSnapshot(params.adapter.source.id, previousActive, items, now());
      newItems = diff.newItemCount;
      changedItems = diff.changedItemCount;
      missingItems = diff.missingButStillActive.length + diff.newlyInactive.length;
      inactiveItems = diff.newlyInactive.length;
      await params.products.upsertMany([
        ...diff.toUpsert,
        ...diff.missingButStillActive,
        ...diff.newlyInactive,
      ]);
    }

    if (runId !== null) {
      await params.crawlRuns.finish(runId, {
        endedAt: now(),
        status,
        isFullSnapshot,
        urlsDiscovered: robotsAllowed.length,
        pagesFetched,
        successfulParses,
        newItems,
        changedItems,
        missingItems,
        inactiveItems,
        errorsByType,
      });
    }

    return {
      status,
      isFullSnapshot,
      urlsDiscovered: robotsAllowed.length,
      pagesFetched,
      successfulParses,
      newItems,
      changedItems,
      missingItems,
      inactiveItems,
      errorsByType,
      items,
    };
  } catch (error) {
    // An unexpected exception (extraction throwing, a persistence error from
    // upsertMany, etc.) must never leave the run row stuck as `running`
    // forever — finalize it as `failed` with whatever real progress had been
    // made, then propagate so the caller (CLI/scheduler) still sees the
    // failure.
    if (runId !== null) {
      await params.crawlRuns.finish(runId, {
        endedAt: now(),
        status: 'failed',
        isFullSnapshot: false,
        ...EMPTY_FINISH_METRICS,
        urlsDiscovered: urlsDiscoveredCount,
        pagesFetched,
        successfulParses,
        errorsByType,
      });
    }
    throw error;
  }
}

function classifySitemapErrorMessage(message: string): ErrorType {
  const httpMatch = /^HTTP (\d{3})$/.exec(message);
  if (httpMatch) {
    const code = Number.parseInt(httpMatch[1]!, 10);
    return code >= 500 ? 'http_5xx' : 'http_4xx';
  }
  if (/timeout/i.test(message)) return 'timeout';
  if (/ECONNRESET|ETIMEDOUT|ENOTFOUND|EAI_AGAIN|ECONNREFUSED/.test(message)) return 'network';
  return 'network';
}

function safePathname(url: string): string | null {
  try {
    return new URL(url).pathname;
  } catch {
    return null;
  }
}

function isRetryableStatusOrError(error: unknown): boolean {
  if (error && typeof error === 'object' && 'status' in error) {
    const status = (error as { status: number }).status;
    return status === 429 || status >= 500;
  }
  return true;
}

function classifyThrownError(error: unknown): ErrorType {
  if (error instanceof RetryableHttpError) {
    return error.status >= 500 ? 'http_5xx' : 'http_4xx';
  }
  if (error instanceof Error) {
    if (error.name === 'AbortError' || /timeout/i.test(error.message)) return 'timeout';
    if (/ECONNRESET|ETIMEDOUT|ENOTFOUND|EAI_AGAIN|ECONNREFUSED/.test(error.message)) {
      return 'network';
    }
  }
  return 'other';
}

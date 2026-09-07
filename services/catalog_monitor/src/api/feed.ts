import { computeEtag } from './etag.js';
import { SOURCE_IDS, type SourceId } from '../domain/types.js';
import type { CatalogProductRecord } from '../domain/types.js';
import type { SourceHealth } from '../monitor/health.js';
import {
  MINIMUM_PRODUCTS_PER_SOURCE,
  withMinimumUsCatalog,
} from '../catalog/curatedUsCatalog.js';
import {
  curateCatalog,
  DEFAULT_CURATION_POLICY,
  type CatalogCurationPolicy,
} from '../catalog/curation.js';
import {
  DEFAULT_RETAIL_PRICING_POLICY,
  type RetailPricingPolicy,
} from '../pricing/commission.js';
import { buildExternalCatalogResponse } from './schema.js';

/**
 * Shared feed builder (WP-62). `GET /v1/external-catalog` and
 * `GET /admin/feed-preview` both render through this function with the same
 * inputs, so the preview is byte-identical to the public feed for the same
 * state at the same instant — the browser never needs a second token.
 *
 * One honest limit: per-source `freshnessHours` are request-time derived and
 * tick forward as data ages, so feed ETags change over time even with no new
 * crawl. The dashboard client treats a 304 as "cached copy still valid" and
 * repopulates from cache, so the ticking ETag never blanks a screen.
 *
 * `generatedAt` derives from the data itself (see `schema.ts`), never from
 * `Date.now()`, so two renders of an unchanged catalog are byte-identical
 * and the ETag is stable.
 */
export interface CatalogFeedOptions {
  readonly activeProducts: readonly CatalogProductRecord[];
  readonly healthBySource: ReadonlyMap<SourceId, SourceHealth>;
  readonly enabledSourceIds?: readonly SourceId[];
  readonly minimumProductsPerSource?: number;
  readonly curationPolicy?: CatalogCurationPolicy;
  readonly pricingPolicy?: RetailPricingPolicy;
}

export function renderCatalogFeedBody(options: CatalogFeedOptions): {
  json: string;
  etag: string;
} {
  const enabledSourceIds = options.enabledSourceIds ?? SOURCE_IDS;
  const enabledSources = new Set<SourceId>(enabledSourceIds);
  const presentableProducts = withMinimumUsCatalog(
    options.activeProducts.filter((record) => enabledSources.has(record.sourceId)),
    options.minimumProductsPerSource ?? MINIMUM_PRODUCTS_PER_SOURCE,
  ).filter((record) => enabledSources.has(record.sourceId));
  const curatedProducts = curateCatalog(
    presentableProducts,
    options.curationPolicy ?? DEFAULT_CURATION_POLICY,
  );
  const body = buildExternalCatalogResponse(
    curatedProducts,
    options.healthBySource,
    options.pricingPolicy ?? DEFAULT_RETAIL_PRICING_POLICY,
    enabledSourceIds,
  );
  const json = JSON.stringify(body);
  return { json, etag: computeEtag(json) };
}

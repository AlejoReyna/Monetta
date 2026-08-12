import type { Availability, SourceId } from '../domain/types.js';
import type { SourceHealth } from '../monitor/health.js';
import { SOURCES } from '../domain/types.js';
import type {
  CatalogDataOrigin,
  PresentedCatalogProduct,
} from '../catalog/curatedUsCatalog.js';

/**
 * The public, versioned response shape. `schemaVersion` bumps on any
 * breaking change to `items[]` or `sources[]` — additive fields do not
 * require a bump. This is deliberately a much narrower surface than the
 * internal `CatalogProductRecord`: no fingerprint, no internal counters, no
 * database identifiers.
 */
export interface ExternalCatalogItemV1 {
  readonly sourceScopedId: string;
  readonly source: SourceId;
  readonly merchant: string;
  readonly title: string;
  readonly brand: string;
  readonly category: string | null;
  readonly imageUrl: string | null;
  readonly price: { readonly amount: number; readonly currency: 'USD' } | null;
  readonly availability: Availability;
  readonly detailUrl: string;
  readonly lastObservedAt: string;
  /** Distinguishes a current crawl row from the dated US display fallback. */
  readonly dataOrigin: CatalogDataOrigin;
}

export interface ExternalCatalogSourceStatusV1 {
  readonly source: SourceId;
  readonly merchant: string;
  readonly lastSuccessfulRunAt: string | null;
  readonly freshnessHours: number | null;
  readonly itemCount: number;
  readonly liveItemCount: number;
  readonly snapshotItemCount: number;
}

export interface ExternalCatalogResponseV1 {
  readonly schemaVersion: 1;
  readonly generatedAt: string;
  readonly sources: readonly ExternalCatalogSourceStatusV1[];
  readonly items: readonly ExternalCatalogItemV1[];
}

function toItem(record: PresentedCatalogProduct): ExternalCatalogItemV1 {
  return {
    sourceScopedId: `${record.sourceId}:${record.externalId}`,
    source: record.sourceId,
    merchant: SOURCES[record.sourceId].merchant,
    title: record.title,
    brand: record.brand,
    category: record.category,
    imageUrl: record.imageUrl,
    price: record.priceUsd === null ? null : { amount: record.priceUsd, currency: 'USD' },
    availability: record.availability,
    detailUrl: record.canonicalUrl,
    lastObservedAt: record.lastSeenAt.toISOString(),
    dataOrigin: record.dataOrigin,
  };
}

/**
 * `generatedAt` is derived from the data itself (the freshest `lastSeenAt`
 * across active items, or the freshest source's `lastSuccessfulRunAt`) —
 * never from `Date.now()`. Two polls of an unchanged catalog then produce
 * byte-identical responses, which is what makes the ETag actually useful
 * instead of changing on every request.
 */
export function buildExternalCatalogResponse(
  activeProducts: readonly PresentedCatalogProduct[],
  healthBySource: ReadonlyMap<SourceId, SourceHealth>,
): ExternalCatalogResponseV1 {
  const items = activeProducts
    .map(toItem)
    .sort((a, b) => a.sourceScopedId.localeCompare(b.sourceScopedId));

  const sources: ExternalCatalogSourceStatusV1[] = Object.values(SOURCES).map((source) => {
    const health = healthBySource.get(source.id);
    return {
      source: source.id,
      merchant: source.merchant,
      lastSuccessfulRunAt: health?.lastSuccessfulRunAt?.toISOString() ?? null,
      freshnessHours: health?.freshnessHours ?? null,
      itemCount: items.filter((i) => i.source === source.id).length,
      liveItemCount: items.filter(
        (i) => i.source === source.id && i.dataOrigin === 'live_crawl',
      ).length,
      snapshotItemCount: items.filter(
        (i) => i.source === source.id && i.dataOrigin === 'curated_us_snapshot',
      ).length,
    };
  });

  const candidateTimestamps = [
    ...activeProducts.map((p) => p.lastSeenAt.getTime()),
    ...sources.map((s) => (s.lastSuccessfulRunAt ? Date.parse(s.lastSuccessfulRunAt) : 0)),
  ].filter((t) => t > 0);
  const generatedAt = new Date(
    candidateTimestamps.length > 0 ? Math.max(...candidateTimestamps) : 0,
  ).toISOString();

  return { schemaVersion: 1, generatedAt, sources, items };
}

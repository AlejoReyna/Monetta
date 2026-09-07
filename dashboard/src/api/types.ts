// Hand-written mirrors of the catalog-monitor admin API shapes
// (CATALOG_DASHBOARD § 7.4). Kept by hand on purpose — the server's
// `src/api/schema.ts` is hand-written for the same reason.

export interface SessionResponse {
  readonly token: string;
  readonly expiresAt: string;
}

export type ConnectionState = 'reachable' | 'degraded' | 'unreachable';

export interface SourceOverview {
  readonly source: string;
  readonly status: 'healthy' | 'unhealthy';
  readonly reasons: readonly string[];
  readonly freshness: {
    readonly discoveryHours: number | null;
    readonly watchHours: number | null;
  };
  readonly lastDiscoveryRun: RunSummary | null;
  readonly lastWatchRun: RunSummary | null;
  readonly counts: {
    readonly selected: number;
    readonly served: number;
    readonly deselected: number;
    readonly inactive: number;
  };
  readonly lastSuccessfulRunAt: string | null;
  readonly coverage: number | null;
}

export interface RunSummary {
  readonly id: string;
  readonly kind: 'discovery' | 'watch';
  readonly status: string;
  readonly startedAt: string;
  readonly endedAt: string | null;
}

export interface AdminRun {
  readonly id: string;
  readonly source: string;
  readonly kind: 'discovery' | 'watch';
  readonly status: string;
  readonly startedAt: string;
  readonly endedAt: string | null;
  readonly durationMs: number | null;
  readonly selectionVersion: number | null;
  readonly urlsDiscovered: number;
  readonly urlsSelected: number;
  readonly pagesFetched: number;
  readonly successfulParses: number;
  readonly coverage: number | null;
  readonly newItems: number;
  readonly changedItems: number;
  readonly missingItems: number;
  readonly inactiveItems: number;
  readonly deselectedItems: number;
  readonly errorsByType: Readonly<Record<string, number>>;
}

export interface SelectionMeta {
  readonly version: number;
  readonly hash: string;
  readonly appliedBy: string;
  readonly appliedAt: string;
  readonly note: string | null;
}

export interface AdminProduct {
  readonly sourceScopedId: string;
  readonly source: string;
  readonly title: string;
  readonly brand: string;
  readonly category: string | null;
  readonly imageUrl: string | null;
  readonly priceUsd: number | null;
  readonly availability: string;
  readonly selectionState: 'selected' | 'deselected';
  readonly isActive: boolean;
  readonly served: boolean;
  readonly watchTier: string;
  readonly placements: readonly string[];
  readonly matchedRuleId: string | null;
  readonly detailUrl: string;
  readonly firstSeenAt: string;
  readonly lastSeenAt: string;
  readonly lastChangedAt: string;
}

export interface FeedItem {
  readonly sourceScopedId: string;
  readonly source: string;
  readonly title: string;
  readonly brand: string;
  readonly price: { readonly amount: number; readonly currency: 'USD' } | null;
  readonly suggestedRetailPrice: { readonly amount: number; readonly currency: 'MXN' } | null;
  readonly availability: string;
  readonly detailUrl: string;
  readonly imageUrl: string | null;
  readonly lastObservedAt: string;
  readonly dataOrigin: 'live_crawl' | 'curated_us_snapshot';
}

export interface FeedPreviewBody {
  readonly generatedAt: string;
  readonly items: readonly FeedItem[];
  readonly sources: ReadonlyArray<{ readonly source: string; readonly merchant: string }>;
}

export interface CatalogEvent {
  readonly id: string;
  readonly kind: string;
  readonly source: string;
  readonly externalId: string;
  readonly sourceScopedId: string;
  readonly observedAt: string;
  readonly previous: Readonly<Record<string, unknown>> | null;
  readonly current: Readonly<Record<string, unknown>> | null;
}

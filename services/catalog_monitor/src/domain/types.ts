/** Shared domain types for the catalog monitor. Pure types, no I/O. */

export type SourceId =
  | 'coach_us'
  | 'michael_kors_us'
  | 'guess_us'
  | 'steve_madden_us';

export const SOURCE_IDS: readonly SourceId[] = [
  'coach_us',
  'michael_kors_us',
  'guess_us',
  'steve_madden_us',
];

export interface SourceDescriptor {
  readonly id: SourceId;
  readonly merchant: string;
  readonly brand: string;
  readonly baseUrl: string;
  readonly sitemapIndexUrl: string;
  /** HTTPS hostnames that belong to this source's intended market. */
  readonly allowedHosts: readonly string[];
}

export const SOURCES: Record<SourceId, SourceDescriptor> = {
  coach_us: {
    id: 'coach_us',
    merchant: 'Coach',
    brand: 'Coach',
    baseUrl: 'https://www.coach.com',
    sitemapIndexUrl: 'https://www.coach.com/sitemap_index.xml',
    allowedHosts: ['coach.com', 'www.coach.com'],
  },
  michael_kors_us: {
    id: 'michael_kors_us',
    merchant: 'Michael Kors',
    brand: 'Michael Kors',
    baseUrl: 'https://www.michaelkors.com',
    sitemapIndexUrl: 'https://www.michaelkors.com/sitemap_index.xml',
    allowedHosts: ['michaelkors.com', 'www.michaelkors.com'],
  },
  guess_us: {
    id: 'guess_us',
    merchant: 'GUESS',
    brand: 'GUESS',
    baseUrl: 'https://www.guess.com',
    sitemapIndexUrl: 'https://www.guess.com/sitemap_index.xml',
    allowedHosts: ['guess.com', 'www.guess.com'],
  },
  steve_madden_us: {
    id: 'steve_madden_us',
    merchant: 'Steve Madden',
    brand: 'Steve Madden',
    baseUrl: 'https://www.stevemadden.com',
    sitemapIndexUrl: 'https://www.stevemadden.com/sitemap.xml',
    allowedHosts: ['stevemadden.com', 'www.stevemadden.com'],
  },
};

export type Availability = 'inStock' | 'outOfStock' | 'unknown';

/**
 * One purchasable color of a merchant product. The parent product keeps the
 * shared title/category while this record tracks the fields that can change
 * independently per color (price, stock, image and destination URL).
 */
export interface ExtractedProductVariant {
  readonly variantId: string;
  readonly sku: string | null;
  readonly colorName: string | null;
  readonly colorCode: string | null;
  readonly imageUrl: string | null;
  readonly priceUsd: number | null;
  readonly availability: Availability;
  readonly detailUrl: string;
}

/**
 * One product as extracted from a single fetch. Not yet reconciled against
 * history — that is `SnapshotStore`'s job. `externalId` is scoped to the
 * source, never globally unique on its own.
 */
export interface ExtractedProduct {
  readonly externalId: string;
  readonly canonicalUrl: string;
  readonly title: string;
  readonly brand: string;
  readonly category: string | null;
  readonly imageUrl: string | null;
  readonly priceUsd: number | null;
  readonly availability: Availability;
  /** Empty/absent only for legacy rows created before variant tracking. */
  readonly variants?: readonly ExtractedProductVariant[];
}

/** A stored product row, reconciled with crawl history. */
export interface CatalogProductRecord extends ExtractedProduct {
  readonly sourceId: SourceId;
  readonly fingerprint: string;
  readonly firstSeenAt: Date;
  readonly lastSeenAt: Date;
  readonly lastChangedAt: Date;
  readonly isActive: boolean;
  readonly consecutiveMissingSnapshots: number;
}

export type ErrorType =
  | 'network'
  | 'timeout'
  | 'http_4xx'
  | 'http_5xx'
  | 'captcha_or_block'
  | 'parse_missing_fields'
  | 'parse_malformed'
  | 'render_failed'
  | 'wrong_market'
  | 'robots_unavailable'
  | 'other';

export type CrawlRunStatus = 'running' | 'success' | 'partial' | 'failed' | 'blocked';

export interface CrawlRunMetrics {
  readonly sourceId: SourceId;
  readonly startedAt: Date;
  readonly endedAt: Date | null;
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
}

/** Required, non-nullable fields for "parse coverage" purposes (health check). */
export const REQUIRED_FIELDS: readonly (keyof ExtractedProduct)[] = [
  'externalId',
  'canonicalUrl',
  'title',
  'brand',
  'priceUsd',
];

export function hasAllRequiredFields(product: ExtractedProduct): boolean {
  return REQUIRED_FIELDS.every((field) => {
    const value = product[field];
    return value !== null && value !== undefined && value !== '';
  });
}

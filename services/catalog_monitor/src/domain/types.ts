/** Shared domain types for the catalog monitor. Pure types, no I/O. */

export type SourceId =
  | 'coach_us'
  | 'michael_kors_us'
  | 'guess_us'
  | 'steve_madden_us'
  | 'marc_jacobs_us'
  | 'tory_burch_us'
  | 'kate_spade_us'
  | 'guess_factory_us'
  | 'gp_mcallen_perfumes';

export const SOURCE_IDS: readonly SourceId[] = [
  'coach_us',
  'michael_kors_us',
  'guess_us',
  'steve_madden_us',
  'marc_jacobs_us',
  'tory_burch_us',
  'kate_spade_us',
  'guess_factory_us',
  'gp_mcallen_perfumes',
];

export type CatalogVertical = 'bags_wallets' | 'perfumes';

export interface SourceDescriptor {
  readonly id: SourceId;
  readonly merchant: string;
  readonly brand: string;
  readonly vertical: CatalogVertical;
  readonly baseUrl: string;
  /** Most sources discover products through XML sitemaps. */
  readonly sitemapIndexUrl: string | null;
  /** Sources without a working sitemap may expose bounded catalog pages. */
  readonly catalogPageUrls: readonly string[];
  /** HTTPS hostnames that belong to this source's intended market. */
  readonly allowedHosts: readonly string[];
}

export const SOURCES: Record<SourceId, SourceDescriptor> = {
  coach_us: {
    id: 'coach_us',
    merchant: 'Coach',
    brand: 'Coach',
    vertical: 'bags_wallets',
    baseUrl: 'https://www.coach.com',
    sitemapIndexUrl: 'https://www.coach.com/sitemap_index.xml',
    catalogPageUrls: [],
    allowedHosts: ['coach.com', 'www.coach.com'],
  },
  michael_kors_us: {
    id: 'michael_kors_us',
    merchant: 'Michael Kors',
    brand: 'Michael Kors',
    vertical: 'bags_wallets',
    baseUrl: 'https://www.michaelkors.com',
    sitemapIndexUrl: 'https://www.michaelkors.com/sitemap_index.xml',
    catalogPageUrls: [],
    allowedHosts: ['michaelkors.com', 'www.michaelkors.com'],
  },
  guess_us: {
    id: 'guess_us',
    merchant: 'GUESS',
    brand: 'GUESS',
    vertical: 'bags_wallets',
    baseUrl: 'https://www.guess.com',
    sitemapIndexUrl: 'https://www.guess.com/sitemap_index.xml',
    catalogPageUrls: [],
    allowedHosts: ['guess.com', 'www.guess.com'],
  },
  steve_madden_us: {
    id: 'steve_madden_us',
    merchant: 'Steve Madden',
    brand: 'Steve Madden',
    vertical: 'bags_wallets',
    baseUrl: 'https://www.stevemadden.com',
    sitemapIndexUrl: 'https://www.stevemadden.com/sitemap.xml',
    catalogPageUrls: [],
    allowedHosts: ['stevemadden.com', 'www.stevemadden.com'],
  },
  marc_jacobs_us: {
    id: 'marc_jacobs_us',
    merchant: 'Marc Jacobs',
    brand: 'Marc Jacobs',
    vertical: 'bags_wallets',
    baseUrl: 'https://www.marcjacobs.com',
    sitemapIndexUrl: 'https://www.marcjacobs.com/sitemap_index.xml',
    catalogPageUrls: [],
    allowedHosts: ['marcjacobs.com', 'www.marcjacobs.com'],
  },
  tory_burch_us: {
    id: 'tory_burch_us',
    merchant: 'Tory Burch',
    brand: 'Tory Burch',
    vertical: 'bags_wallets',
    baseUrl: 'https://www.toryburch.com',
    sitemapIndexUrl: 'https://www.toryburch.com/sitemap_index.xml',
    catalogPageUrls: [],
    allowedHosts: ['toryburch.com', 'www.toryburch.com'],
  },
  kate_spade_us: {
    id: 'kate_spade_us',
    merchant: 'Kate Spade',
    brand: 'Kate Spade',
    vertical: 'bags_wallets',
    baseUrl: 'https://www.katespade.com',
    sitemapIndexUrl: 'https://www.katespade.com/sitemap_index.xml',
    catalogPageUrls: [],
    allowedHosts: ['katespade.com', 'www.katespade.com'],
  },
  guess_factory_us: {
    id: 'guess_factory_us',
    merchant: 'GUESS Factory',
    brand: 'GUESS Factory',
    vertical: 'bags_wallets',
    baseUrl: 'https://www.guessfactory.com',
    sitemapIndexUrl: 'https://www.guessfactory.com/sitemap_index.xml',
    catalogPageUrls: [],
    allowedHosts: ['guessfactory.com', 'www.guessfactory.com'],
  },
  gp_mcallen_perfumes: {
    id: 'gp_mcallen_perfumes',
    merchant: 'Gold Palace McAllen',
    brand: 'Perfumes',
    vertical: 'perfumes',
    baseUrl: 'https://www.gpmcallen.com',
    // robots.txt advertises a sitemap that currently returns 404, so this
    // source uses its bounded public fragrance category pages instead.
    sitemapIndexUrl: null,
    catalogPageUrls: [
      'https://www.gpmcallen.com/ladies-perfumes.html',
      'https://www.gpmcallen.com/mens-colognes.html',
      'https://www.gpmcallen.com/ladies-sets.html',
      'https://www.gpmcallen.com/mens-sets.html',
      'https://www.gpmcallen.com/unisex.html',
    ],
    allowedHosts: ['gpmcallen.com', 'www.gpmcallen.com'],
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

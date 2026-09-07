import { SOURCE_IDS, type SourceId } from '../domain/types.js';

export { SOURCE_IDS, type SourceId };

export function isSourceId(value: string): value is SourceId {
  return (SOURCE_IDS as readonly string[]).includes(value);
}

/** Valid watch tiers per § 4.1. Only Stage-A rules may be pinned. */
export type WatchTier = 'standard' | 'pinned';
export const WATCH_TIERS: readonly WatchTier[] = ['standard', 'pinned'];

export function isValidWatchTier(value: string): value is WatchTier {
  return value === 'standard' || value === 'pinned';
}

/** Valid product availability values. */
export type Availability = 'inStock' | 'outOfStock' | 'unknown';
export const AVAILABILITY_VALUES: readonly Availability[] = [
  'inStock',
  'outOfStock',
  'unknown',
];

export function isValidAvailability(value: string): value is Availability {
  return (AVAILABILITY_VALUES as readonly string[]).includes(value);
}

/** Standard visual surface placements and collection slug targeting. */
export type StandardPlacement = 'home_rail' | 'catalog_browse' | 'hidden';
export type CollectionPlacement = `collection:${string}`;
export type Placement = StandardPlacement | CollectionPlacement;

export const STANDARD_PLACEMENTS: readonly StandardPlacement[] = [
  'home_rail',
  'catalog_browse',
  'hidden',
];

export const COLLECTION_SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export function isValidPlacement(value: string): value is Placement {
  if ((STANDARD_PLACEMENTS as readonly string[]).includes(value)) {
    return true;
  }
  if (value.startsWith('collection:')) {
    const slug = value.slice('collection:'.length);
    return slug.length > 0 && COLLECTION_SLUG_RE.test(slug);
  }
  return false;
}

/** Supported rule kinds across evaluation stages A, B, and C. */
export type StageARuleKind = 'externalId' | 'urlExact' | 'urlPattern' | 'all';
export type StageBRuleKind = 'titleKeyword' | 'category' | 'priceUsdRange';
export type StageCRuleKind = 'availability';
export type SelectionRuleKind = StageARuleKind | StageBRuleKind | StageCRuleKind;

export const STAGE_A_RULE_KINDS: readonly StageARuleKind[] = [
  'externalId',
  'urlExact',
  'urlPattern',
  'all',
];

export const STAGE_B_RULE_KINDS: readonly StageBRuleKind[] = [
  'titleKeyword',
  'category',
  'priceUsdRange',
];

export const STAGE_C_RULE_KINDS: readonly StageCRuleKind[] = ['availability'];

export const ALL_RULE_KINDS: readonly SelectionRuleKind[] = [
  ...STAGE_A_RULE_KINDS,
  ...STAGE_B_RULE_KINDS,
  ...STAGE_C_RULE_KINDS,
];

export function isValidRuleKind(value: string): value is SelectionRuleKind {
  return (ALL_RULE_KINDS as readonly string[]).includes(value);
}

export function isStageARuleKind(kind: SelectionRuleKind): kind is StageARuleKind {
  return (STAGE_A_RULE_KINDS as readonly string[]).includes(kind);
}

export function isStageBRuleKind(kind: SelectionRuleKind): kind is StageBRuleKind {
  return (STAGE_B_RULE_KINDS as readonly string[]).includes(kind);
}

export function isStageCRuleKind(kind: SelectionRuleKind): kind is StageCRuleKind {
  return (STAGE_C_RULE_KINDS as readonly string[]).includes(kind);
}

export type PriceUsdRange = readonly [min: number, max: number];

export interface ExternalIdRulePayload {
  readonly kind: 'externalId';
  readonly value: string;
}

export interface UrlExactRulePayload {
  readonly kind: 'urlExact';
  readonly value: string;
}

export interface UrlPatternRulePayload {
  readonly kind: 'urlPattern';
  readonly value: string;
}

export interface AllRulePayload {
  readonly kind: 'all';
}

export interface TitleKeywordRulePayload {
  readonly kind: 'titleKeyword';
  readonly value: string;
}

export interface CategoryRulePayload {
  readonly kind: 'category';
  readonly value: string;
}

export interface PriceUsdRangeRulePayload {
  readonly kind: 'priceUsdRange';
  readonly value: PriceUsdRange;
}

export interface AvailabilityRulePayload {
  readonly kind: 'availability';
  readonly value: Availability;
}

export type StageAPayload =
  | ExternalIdRulePayload
  | UrlExactRulePayload
  | UrlPatternRulePayload
  | AllRulePayload;

export type StageBPayload =
  | TitleKeywordRulePayload
  | CategoryRulePayload
  | PriceUsdRangeRulePayload;

export type StageCPayload = AvailabilityRulePayload;

export type SelectionRulePayload =
  | StageAPayload
  | StageBPayload
  | StageCPayload;

/** Stage A includes own the metadata for winning candidates. */
export type StageAIncludeRule = StageAPayload & {
  readonly id: string;
  readonly tier?: WatchTier;
  readonly placements?: readonly Placement[];
  readonly priority?: number;
};

/** Stage B rules are filters on Stage A; they cannot carry placement/tier metadata. */
export type StageBIncludeRule = StageBPayload & {
  readonly id: string;
};

/** Stage C rules are filters on Stage A; they cannot carry placement/tier metadata. */
export type StageCIncludeRule = StageCPayload & {
  readonly id: string;
};

export type SelectionIncludeRule =
  | StageAIncludeRule
  | StageBIncludeRule
  | StageCIncludeRule;

export type SelectionExcludeRule = SelectionRulePayload & {
  readonly id: string;
};

export type SelectionRule = SelectionIncludeRule | SelectionExcludeRule;

export interface SelectionSource {
  readonly enabled: boolean;
  readonly maxSelectedUrls?: number | null;
  readonly include: readonly SelectionIncludeRule[];
  readonly exclude: readonly SelectionExcludeRule[];
}

export interface SelectionDocument {
  readonly version: number;
  readonly note?: string;
  readonly sources: Readonly<Record<string, SelectionSource>>;
}

/** Minimal product input for matchProduct, decoupled from database or crawler types. */
export interface MinimalProduct {
  readonly externalId: string;
  readonly canonicalUrl: string;
  readonly title: string;
  readonly category: string | null;
  readonly priceUsd: number | null;
  readonly availability: Availability;
}

export interface SelectedDecision {
  readonly selected: true;
  readonly ruleId: string;
  readonly placements: readonly Placement[];
  readonly priority: number;
  readonly tier: WatchTier;
  readonly requiresProductEvaluation: boolean;
  readonly reason?: string;
}

export interface RejectedDecision {
  readonly selected: false;
  readonly ruleId?: string;
  readonly placements?: readonly Placement[];
  readonly priority?: number;
  readonly tier?: WatchTier;
  readonly requiresProductEvaluation?: boolean;
  readonly reason?: string;
}

export type SelectionDecision = SelectedDecision | RejectedDecision;

export type SelectionErrorCode =
  | 'selection_invalid'
  | 'invalid_source'
  | 'duplicate_rule_id'
  | 'invalid_placement'
  | 'invalid_price_range'
  | 'invalid_glob'
  | 'invalid_rule'
  | 'unknown_key';

export interface SelectionError {
  readonly error: string;
  readonly code: SelectionErrorCode;
  readonly message: string;
  readonly path?: string;
  readonly issues?: readonly string[];
}

export function isSelectionError(value: unknown): value is SelectionError {
  return (
    typeof value === 'object' &&
    value !== null &&
    'error' in value &&
    typeof (value as { error: unknown }).error === 'string' &&
    'code' in value
  );
}

export interface CompiledSelection {
  readonly version: number;
  readonly hash: string;
  readonly matchUrl: (sourceId: string, url: string) => SelectionDecision;
  readonly matchProduct: (sourceId: string, product: MinimalProduct) => SelectionDecision;
}

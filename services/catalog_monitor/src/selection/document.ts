import {
  ALL_RULE_KINDS,
  isSourceId,
  isStageARuleKind,
  isStageBRuleKind,
  isValidAvailability,
  isValidPlacement,
  isValidRuleKind,
  isValidWatchTier,
  SOURCE_IDS,
  type SelectionDocument,
  type SelectionError,
  type SelectionExcludeRule,
  type SelectionIncludeRule,
  type SelectionRule,
  type SelectionRuleKind,
  type SelectionRulePayload,
  type SelectionSource,
  type StageAIncludeRule,
} from './types.js';
import { validateGlobPattern } from './glob.js';

const ALLOWED_ROOT_KEYS = new Set(['version', 'sources', 'note']);
const ALLOWED_SOURCE_KEYS = new Set([
  'enabled',
  'maxSelectedUrls',
  'include',
  'exclude',
]);
const ALLOWED_STAGE_A_INCLUDE_KEYS = new Set([
  'id',
  'kind',
  'value',
  'placements',
  'priority',
  'tier',
]);
const ALLOWED_SIMPLE_RULE_KEYS = new Set(['id', 'kind', 'value']);

function makeError(
  code: SelectionError['code'],
  message: string,
  path?: string,
  issues?: readonly string[]
): SelectionError {
  return {
    error: 'selection_invalid',
    code,
    message,
    ...(path !== undefined ? { path } : {}),
    ...(issues !== undefined ? { issues } : {}),
  };
}

function isValidUrlExact(value: string): boolean {
  if (value.startsWith('/')) {
    return true;
  }
  try {
    const u = new URL(value);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
}

function validateRule(
  rawRule: unknown,
  sourceId: string,
  isInclude: boolean,
  index: number,
  seenRuleIds: Set<string>
): { rule: SelectionRule } | { error: SelectionError } {
  const rulePath = `sources.${sourceId}.${isInclude ? 'include' : 'exclude'}[${index}]`;

  if (typeof rawRule !== 'object' || rawRule === null || Array.isArray(rawRule)) {
    return {
      error: makeError(
        'invalid_rule',
        `Rule at ${rulePath} must be a non-null object`,
        rulePath
      ),
    };
  }

  const ruleObj = rawRule as Record<string, unknown>;

  // Validate ID
  const rawId = ruleObj.id;
  if (typeof rawId !== 'string' || rawId.trim().length === 0) {
    return {
      error: makeError(
        'invalid_rule',
        `Rule ID at ${rulePath}.id must be a non-empty string`,
        `${rulePath}.id`
      ),
    };
  }

  if (seenRuleIds.has(rawId)) {
    return {
      error: makeError(
        'duplicate_rule_id',
        `Duplicate rule ID "${rawId}" in source "${sourceId}"`,
        `${rulePath}.id`
      ),
    };
  }
  seenRuleIds.add(rawId);

  // Validate kind
  const rawKind = ruleObj.kind;
  if (typeof rawKind !== 'string' || !isValidRuleKind(rawKind)) {
    return {
      error: makeError(
        'invalid_rule',
        `Unsupported rule kind "${String(rawKind)}" on rule "${rawId}". Must be one of: ${ALL_RULE_KINDS.join(', ')}`,
        `${rulePath}.kind`
      ),
    };
  }

  const kind = rawKind as SelectionRuleKind;
  const isStageA = isStageARuleKind(kind);

  // Reject metadata on exclude rules or Stage B/C include rules
  if (!isInclude || !isStageA) {
    if ('tier' in ruleObj || 'priority' in ruleObj || 'placements' in ruleObj) {
      const targetDesc = !isInclude
        ? 'exclude'
        : `Stage-${isStageBRuleKind(kind) ? 'B' : 'C'} include`;
      return {
        error: makeError(
          'unknown_key',
          `Metadata fields ("tier", "priority", "placements") are only allowed on Stage-A include rules, but found on ${targetDesc} rule "${rawId}"`,
          `${rulePath}`
        ),
      };
    }
  }

  // Check allowed keys
  const allowedKeys = isInclude && isStageA
    ? ALLOWED_STAGE_A_INCLUDE_KEYS
    : ALLOWED_SIMPLE_RULE_KEYS;

  for (const key of Object.keys(ruleObj)) {
    if (!allowedKeys.has(key)) {
      return {
        error: makeError(
          'unknown_key',
          `Unknown property "${key}" on rule at ${rulePath}`,
          `${rulePath}.${key}`
        ),
      };
    }
  }

  // Validate Stage-A include metadata
  let tier: StageAIncludeRule['tier'];
  let priority: number | undefined;
  let placements: StageAIncludeRule['placements'];

  if (isInclude && isStageA) {
    if (ruleObj.tier !== undefined) {
      if (typeof ruleObj.tier !== 'string' || !isValidWatchTier(ruleObj.tier)) {
        return {
          error: makeError(
            'invalid_rule',
            `Invalid tier "${String(ruleObj.tier)}" on rule "${rawId}". Must be "standard" or "pinned"`,
            `${rulePath}.tier`
          ),
        };
      }
      tier = ruleObj.tier;
    }

    if (ruleObj.priority !== undefined) {
      if (
        typeof ruleObj.priority !== 'number' ||
        !Number.isFinite(ruleObj.priority)
      ) {
        return {
          error: makeError(
            'invalid_rule',
            `Priority on rule "${rawId}" must be a finite number`,
            `${rulePath}.priority`
          ),
        };
      }
      priority = ruleObj.priority;
    }

    if (ruleObj.placements !== undefined) {
      if (!Array.isArray(ruleObj.placements)) {
        return {
          error: makeError(
            'invalid_placement',
            `Placements on rule "${rawId}" must be an array`,
            `${rulePath}.placements`
          ),
        };
      }
      for (let pIdx = 0; pIdx < ruleObj.placements.length; pIdx++) {
        const p = ruleObj.placements[pIdx];
        if (typeof p !== 'string' || !isValidPlacement(p)) {
          return {
            error: makeError(
              'invalid_placement',
              `Invalid placement "${String(p)}" on rule "${rawId}". Must be "home_rail", "catalog_browse", "hidden", or "collection:<slug>"`,
              `${rulePath}.placements[${pIdx}]`
            ),
          };
        }
      }
      placements = [...ruleObj.placements];
    }
  }

  // Validate value based on kind
  if (kind === 'all') {
    if ('value' in ruleObj) {
      return {
        error: makeError(
          'unknown_key',
          `Rule kind "all" must not have a "value" property on rule "${rawId}"`,
          `${rulePath}.value`
        ),
      };
    }
    const base = { id: rawId, kind: 'all' as const };
    if (isInclude) {
      return {
        rule: {
          ...base,
          ...(tier !== undefined ? { tier } : {}),
          ...(priority !== undefined ? { priority } : {}),
          ...(placements !== undefined ? { placements } : {}),
        } as StageAIncludeRule,
      };
    }
    return { rule: base as SelectionExcludeRule };
  }

  if (!('value' in ruleObj)) {
    return {
      error: makeError(
        'invalid_rule',
        `Rule "${rawId}" of kind "${kind}" requires a "value" property`,
        `${rulePath}.value`
      ),
    };
  }

  const rawValue = ruleObj.value;

  switch (kind) {
    case 'externalId': {
      if (typeof rawValue !== 'string' || rawValue.trim().length === 0) {
        return {
          error: makeError(
            'invalid_rule',
            `externalId rule "${rawId}" requires a non-empty string value`,
            `${rulePath}.value`
          ),
        };
      }
      break;
    }
    case 'urlExact': {
      if (typeof rawValue !== 'string' || !isValidUrlExact(rawValue.trim())) {
        return {
          error: makeError(
            'invalid_rule',
            `urlExact rule "${rawId}" requires a valid absolute URL or a path starting with "/"`,
            `${rulePath}.value`
          ),
        };
      }
      break;
    }
    case 'urlPattern': {
      const globResult = validateGlobPattern(rawValue);
      if (!globResult.valid) {
        return {
          error: makeError(
            'invalid_glob',
            `urlPattern rule "${rawId}" has invalid glob: ${globResult.error}`,
            `${rulePath}.value`
          ),
        };
      }
      break;
    }
    case 'titleKeyword': {
      if (typeof rawValue !== 'string' || rawValue.trim().length === 0) {
        return {
          error: makeError(
            'invalid_rule',
            `titleKeyword rule "${rawId}" requires a non-empty string value`,
            `${rulePath}.value`
          ),
        };
      }
      break;
    }
    case 'category': {
      if (typeof rawValue !== 'string' || rawValue.trim().length === 0) {
        return {
          error: makeError(
            'invalid_rule',
            `category rule "${rawId}" requires a non-empty string value`,
            `${rulePath}.value`
          ),
        };
      }
      break;
    }
    case 'priceUsdRange': {
      if (
        !Array.isArray(rawValue) ||
        rawValue.length !== 2 ||
        typeof rawValue[0] !== 'number' ||
        typeof rawValue[1] !== 'number' ||
        !Number.isFinite(rawValue[0]) ||
        !Number.isFinite(rawValue[1]) ||
        rawValue[0] < 0 ||
        rawValue[1] < 0 ||
        rawValue[0] > rawValue[1]
      ) {
        return {
          error: makeError(
            'invalid_price_range',
            `priceUsdRange rule "${rawId}" requires exactly two finite non-negative numbers [min, max] with min <= max`,
            `${rulePath}.value`
          ),
        };
      }
      break;
    }
    case 'availability': {
      if (typeof rawValue !== 'string' || !isValidAvailability(rawValue)) {
        return {
          error: makeError(
            'invalid_rule',
            `availability rule "${rawId}" requires value to be "inStock", "outOfStock", or "unknown"`,
            `${rulePath}.value`
          ),
        };
      }
      break;
    }
  }

  const base = { id: rawId, kind, value: rawValue } as SelectionRulePayload & { id: string };

  if (isInclude) {
    if (isStageA) {
      return {
        rule: {
          ...base,
          ...(tier !== undefined ? { tier } : {}),
          ...(priority !== undefined ? { priority } : {}),
          ...(placements !== undefined ? { placements } : {}),
        } as StageAIncludeRule,
      };
    }
    // Stage B or Stage C include rule
    return { rule: base as SelectionIncludeRule };
  }

  return { rule: base as SelectionExcludeRule };
}

/**
 * Validates untrusted input into a strongly-typed SelectionDocument or returns
 * a typed SelectionError. This function never throws.
 */
export function parseSelectionDocument(
  value: unknown
): SelectionDocument | SelectionError {
  let docObj: unknown = value;

  if (typeof value === 'string') {
    try {
      docObj = JSON.parse(value);
    } catch (err) {
      return makeError(
        'selection_invalid',
        `Malformed JSON document: ${err instanceof Error ? err.message : String(err)}`
      );
    }
  }

  if (typeof docObj !== 'object' || docObj === null || Array.isArray(docObj)) {
    return makeError(
      'selection_invalid',
      'Selection document must be a non-null object'
    );
  }

  const rawDoc = docObj as Record<string, unknown>;

  // Check unknown root keys
  for (const key of Object.keys(rawDoc)) {
    if (!ALLOWED_ROOT_KEYS.has(key)) {
      return makeError(
        'unknown_key',
        `Unknown root property "${key}" in selection document`,
        key
      );
    }
  }

  // Validate version
  const rawVersion = rawDoc.version;
  if (
    typeof rawVersion !== 'number' ||
    !Number.isInteger(rawVersion) ||
    rawVersion < 0
  ) {
    return makeError(
      'selection_invalid',
      'Document "version" must be a non-negative integer',
      'version'
    );
  }

  // Validate note
  if (rawDoc.note !== undefined && typeof rawDoc.note !== 'string') {
    return makeError(
      'selection_invalid',
      'Document "note" must be a string if provided',
      'note'
    );
  }

  // Validate sources
  const rawSources = rawDoc.sources;
  if (
    typeof rawSources !== 'object' ||
    rawSources === null ||
    Array.isArray(rawSources)
  ) {
    return makeError(
      'selection_invalid',
      'Document "sources" must be a non-null object',
      'sources'
    );
  }

  const validatedSources: Record<string, SelectionSource> = {};

  for (const [sourceId, rawSource] of Object.entries(rawSources)) {
    const sourcePath = `sources.${sourceId}`;

    if (!isSourceId(sourceId)) {
      return makeError(
        'invalid_source',
        `Unknown source ID "${sourceId}". Supported sources are: ${SOURCE_IDS.join(', ')}`,
        sourcePath
      );
    }

    if (
      typeof rawSource !== 'object' ||
      rawSource === null ||
      Array.isArray(rawSource)
    ) {
      return makeError(
        'selection_invalid',
        `Source "${sourceId}" must be a non-null object`,
        sourcePath
      );
    }

    const sourceObj = rawSource as Record<string, unknown>;

    // Check unknown keys on source
    for (const key of Object.keys(sourceObj)) {
      if (!ALLOWED_SOURCE_KEYS.has(key)) {
        return makeError(
          'unknown_key',
          `Unknown property "${key}" in source "${sourceId}"`,
          `${sourcePath}.${key}`
        );
      }
    }

    // enabled
    if (typeof sourceObj.enabled !== 'boolean') {
      return makeError(
        'selection_invalid',
        `Source "${sourceId}.enabled" must be a boolean`,
        `${sourcePath}.enabled`
      );
    }

    // maxSelectedUrls
    let maxSelectedUrls: number | null = null;
    if (
      sourceObj.maxSelectedUrls !== undefined &&
      sourceObj.maxSelectedUrls !== null
    ) {
      if (
        typeof sourceObj.maxSelectedUrls !== 'number' ||
        !Number.isInteger(sourceObj.maxSelectedUrls) ||
        sourceObj.maxSelectedUrls <= 0
      ) {
        return makeError(
          'selection_invalid',
          `Source "${sourceId}.maxSelectedUrls" must be a positive integer`,
          `${sourcePath}.maxSelectedUrls`
        );
      }
      maxSelectedUrls = sourceObj.maxSelectedUrls;
    }

    // include
    if (!Array.isArray(sourceObj.include)) {
      return makeError(
        'selection_invalid',
        `Source "${sourceId}.include" must be an array`,
        `${sourcePath}.include`
      );
    }

    // exclude
    if (sourceObj.exclude !== undefined && !Array.isArray(sourceObj.exclude)) {
      return makeError(
        'selection_invalid',
        `Source "${sourceId}.exclude" must be an array if provided`,
        `${sourcePath}.exclude`
      );
    }

    const seenRuleIds = new Set<string>();
    const includeRules: SelectionIncludeRule[] = [];
    const excludeRules: SelectionExcludeRule[] = [];

    // Parse includes
    for (let i = 0; i < sourceObj.include.length; i++) {
      const res = validateRule(
        sourceObj.include[i],
        sourceId,
        true,
        i,
        seenRuleIds
      );
      if ('error' in res) {
        return res.error;
      }
      includeRules.push(res.rule as SelectionIncludeRule);
    }

    // Parse excludes
    const rawExcludes = (sourceObj.exclude as unknown[] | undefined) ?? [];
    for (let i = 0; i < rawExcludes.length; i++) {
      const res = validateRule(rawExcludes[i], sourceId, false, i, seenRuleIds);
      if ('error' in res) {
        return res.error;
      }
      excludeRules.push(res.rule as SelectionExcludeRule);
    }

    validatedSources[sourceId] = {
      enabled: sourceObj.enabled,
      maxSelectedUrls,
      include: includeRules,
      exclude: excludeRules,
    };
  }

  return {
    version: rawVersion,
    ...(rawDoc.note !== undefined ? { note: rawDoc.note as string } : {}),
    sources: validatedSources,
  };
}

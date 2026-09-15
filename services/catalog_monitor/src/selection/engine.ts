import { compileGlobToRegExp } from './glob.js';
import { hashSelectionDocument } from './hash.js';
import {
  isStageARuleKind,
  isStageBRuleKind,
  type CompiledSelection,
  type MinimalProduct,
  type SelectionDecision,
  type SelectionDocument,
  type SelectionRule,
  type StageAIncludeRule,
} from './types.js';

function escapeRegexLiteral(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/**
 * Matches an external ID against a URL in a source-adapter-independent manner.
 *
 * Exact behavior:
 * 1. The candidate URL is parsed with the WHATWG URL parser.
 * 2. URL.pathname + URL.search is decoded via decodeURIComponent (with fallback
 *    to un-decoded string if malformed percent-encoding is encountered).
 * 3. The target externalId is matched case-insensitively, requiring non-alphanumeric
 *    token boundaries ((^|[^a-zA-Z0-9]) on the left, ($|[^a-zA-Z0-9]) on the right).
 *
 * This ensures:
 * - Positive matches for path segments (/products/.../CU068.html), hyphen/underscore
 *   delimiters (/products/.../CU068-B4YDT.html), and query params (?sku=CU068).
 * - Boundary non-matches for identifier prefixes/suffixes (/products/.../CU0689.html
 *   and /products/.../MCU068.html will NOT match externalId "CU068").
 */
export function matchExternalIdInUrl(
  urlOrParsed: URL | string,
  externalId: string
): boolean {
  let parsed: URL;
  if (typeof urlOrParsed === 'string') {
    try {
      parsed = new URL(urlOrParsed);
    } catch {
      return false;
    }
  } else {
    parsed = urlOrParsed;
  }

  let target = parsed.pathname + parsed.search;
  try {
    target = decodeURIComponent(target);
  } catch {
    // Malformed URI components fallback
  }

  const trimmedId = externalId.trim();
  if (trimmedId.length === 0) {
    return false;
  }

  const escapedId = escapeRegexLiteral(trimmedId);
  const pattern = new RegExp(`(^|[^a-zA-Z0-9])${escapedId}($|[^a-zA-Z0-9])`, 'i');
  return pattern.test(target);
}

function matchUrlExact(parsedUrl: URL, expectedUrlOrPath: string): boolean {
  if (expectedUrlOrPath.startsWith('/')) {
    return parsedUrl.pathname === expectedUrlOrPath;
  }
  try {
    const expected = new URL(expectedUrlOrPath);
    return parsedUrl.href === expected.href;
  } catch {
    return false;
  }
}

interface CompiledRuleContext {
  readonly rule: SelectionRule;
  readonly globRegex?: RegExp;
}

interface CompiledSourceContext {
  readonly enabled: boolean;
  readonly stageAPinnedIncludes: readonly CompiledRuleContext[];
  readonly stageAStandardIncludes: readonly CompiledRuleContext[];
  readonly stageAExcludes: readonly CompiledRuleContext[];
  readonly stageBIncludes: readonly CompiledRuleContext[];
  readonly stageBExcludes: readonly CompiledRuleContext[];
  readonly stageCIncludes: readonly CompiledRuleContext[];
  readonly stageCExcludes: readonly CompiledRuleContext[];
  readonly totalIncludeCount: number;
  readonly stageAIncludeCount: number;
  readonly hasStageBOrCRules: boolean;
}

function compileRule(rule: SelectionRule): CompiledRuleContext {
  if (rule.kind === 'urlPattern') {
    return {
      rule,
      globRegex: compileGlobToRegExp(rule.value),
    };
  }
  return { rule };
}

function evaluateUrlRule(
  compiled: CompiledRuleContext,
  parsedUrl: URL
): boolean {
  const { rule } = compiled;
  switch (rule.kind) {
    case 'all':
      return true;
    case 'urlExact':
      return matchUrlExact(parsedUrl, rule.value);
    case 'urlPattern':
      return compiled.globRegex!.test(parsedUrl.pathname);
    case 'externalId':
      return matchExternalIdInUrl(parsedUrl, rule.value);
    // Stage B and C rules cannot be resolved from URL alone
    case 'titleKeyword':
    case 'category':
    case 'priceUsdRange':
    case 'availability':
      return false;
  }
}

function evaluateProductRule(
  compiled: CompiledRuleContext,
  product: MinimalProduct
): boolean {
  const { rule } = compiled;
  switch (rule.kind) {
    case 'all':
      return true;
    case 'externalId': {
      if (product.externalId.trim().toLowerCase() === rule.value.trim().toLowerCase()) {
        return true;
      }
      return matchExternalIdInUrl(product.canonicalUrl, rule.value);
    }
    case 'urlExact': {
      try {
        const parsed = new URL(product.canonicalUrl);
        return matchUrlExact(parsed, rule.value);
      } catch {
        return false;
      }
    }
    case 'urlPattern': {
      try {
        const parsed = new URL(product.canonicalUrl);
        return compiled.globRegex!.test(parsed.pathname);
      } catch {
        return false;
      }
    }
    case 'titleKeyword': {
      return product.title.toLowerCase().includes(rule.value.trim().toLowerCase());
    }
    case 'category': {
      if (product.category === null) {
        return false;
      }
      const catTrimmed = product.category.trim().toLowerCase();
      const ruleTrimmed = rule.value.trim().toLowerCase();
      return catTrimmed === ruleTrimmed || slugify(product.category) === slugify(rule.value);
    }
    case 'priceUsdRange': {
      if (product.priceUsd === null) {
        return false;
      }
      return product.priceUsd >= rule.value[0] && product.priceUsd <= rule.value[1];
    }
    case 'availability': {
      return product.availability === rule.value;
    }
  }
}

function buildSelectedDecision(
  rule: StageAIncludeRule,
  tier: 'pinned' | 'standard',
  reason: 'pinned_include' | 'include',
  requiresProductEvaluation: boolean
): SelectionDecision {
  return {
    selected: true,
    ruleId: rule.id,
    placements: Object.freeze([...(rule.placements ?? [])]),
    priority: rule.priority ?? 0,
    tier,
    requiresProductEvaluation,
    reason,
  };
}

/**
 * Compiles a validated SelectionDocument into a high-performance,
 * browser-compatible evaluation engine enforcing Stage-A gating and
 * Stage-B/C candidate filtering.
 */
export function compileSelection(document: SelectionDocument): CompiledSelection {
  const hash = hashSelectionDocument(document);
  const sourcesMap = new Map<string, CompiledSourceContext>();

  for (const [sourceId, source] of Object.entries(document.sources)) {
    const stageAPinnedIncludes: CompiledRuleContext[] = [];
    const stageAStandardIncludes: CompiledRuleContext[] = [];
    const stageAExcludes: CompiledRuleContext[] = [];
    const stageBIncludes: CompiledRuleContext[] = [];
    const stageBExcludes: CompiledRuleContext[] = [];
    const stageCIncludes: CompiledRuleContext[] = [];
    const stageCExcludes: CompiledRuleContext[] = [];

    for (const inc of source.include) {
      const compiled = compileRule(inc);
      if (isStageARuleKind(inc.kind)) {
        const stageAInc = inc as StageAIncludeRule;
        if (stageAInc.tier === 'pinned') {
          stageAPinnedIncludes.push(compiled);
        } else {
          stageAStandardIncludes.push(compiled);
        }
      } else if (isStageBRuleKind(inc.kind)) {
        stageBIncludes.push(compiled);
      } else {
        stageCIncludes.push(compiled);
      }
    }

    for (const exc of source.exclude) {
      const compiled = compileRule(exc);
      if (isStageARuleKind(exc.kind)) {
        stageAExcludes.push(compiled);
      } else if (isStageBRuleKind(exc.kind)) {
        stageBExcludes.push(compiled);
      } else {
        stageCExcludes.push(compiled);
      }
    }

    const hasStageBOrCRules =
      stageBIncludes.length +
        stageBExcludes.length +
        stageCIncludes.length +
        stageCExcludes.length >
      0;

    sourcesMap.set(sourceId, {
      enabled: source.enabled,
      stageAPinnedIncludes,
      stageAStandardIncludes,
      stageAExcludes,
      stageBIncludes,
      stageBExcludes,
      stageCIncludes,
      stageCExcludes,
      totalIncludeCount: source.include.length,
      stageAIncludeCount: stageAPinnedIncludes.length + stageAStandardIncludes.length,
      hasStageBOrCRules,
    });
  }

  function matchUrl(sourceId: string, url: string): SelectionDecision {
    const source = sourcesMap.get(sourceId);
    if (!source) {
      return { selected: false, reason: 'unknown_source' };
    }
    if (!source.enabled) {
      return { selected: false, reason: 'source_disabled' };
    }
    if (source.totalIncludeCount === 0) {
      return { selected: false, reason: 'zero_include_rules' };
    }
    // Stage A is the only fetch-candidate gate: source with zero Stage-A includes produces no candidates
    if (source.stageAIncludeCount === 0) {
      return { selected: false, reason: 'zero_stage_a_include_rules' };
    }

    let parsedUrl: URL;
    try {
      parsedUrl = new URL(url);
    } catch {
      return { selected: false, reason: 'malformed_url' };
    }

    // 1. Pinned Stage-A includes win over every exclusion
    for (const compiled of source.stageAPinnedIncludes) {
      if (evaluateUrlRule(compiled, parsedUrl)) {
        return buildSelectedDecision(
          compiled.rule as StageAIncludeRule,
          'pinned',
          'pinned_include',
          source.hasStageBOrCRules
        );
      }
    }

    // 2. Stage-A excludes reject URL candidates
    for (const compiled of source.stageAExcludes) {
      if (evaluateUrlRule(compiled, parsedUrl)) {
        return {
          selected: false,
          ruleId: compiled.rule.id,
          reason: 'exclude',
        };
      }
    }

    // 3. Normal Stage-A includes select as fetch candidates
    for (const compiled of source.stageAStandardIncludes) {
      if (evaluateUrlRule(compiled, parsedUrl)) {
        return buildSelectedDecision(
          compiled.rule as StageAIncludeRule,
          'standard',
          'include',
          source.hasStageBOrCRules
        );
      }
    }

    // 4. Fail-closed default
    return { selected: false, reason: 'no_match' };
  }

  function matchProduct(
    sourceId: string,
    product: MinimalProduct
  ): SelectionDecision {
    const source = sourcesMap.get(sourceId);
    if (!source) {
      return { selected: false, reason: 'unknown_source' };
    }
    if (!source.enabled) {
      return { selected: false, reason: 'source_disabled' };
    }
    if (source.totalIncludeCount === 0) {
      return { selected: false, reason: 'zero_include_rules' };
    }
    // A source with no Stage-A include produces no candidates
    if (source.stageAIncludeCount === 0) {
      return { selected: false, reason: 'zero_stage_a_include_rules' };
    }

    // 1. Pinned Stage-A include override: wins over excludes and B/C filters
    for (const compiled of source.stageAPinnedIncludes) {
      if (evaluateProductRule(compiled, product)) {
        return buildSelectedDecision(
          compiled.rule as StageAIncludeRule,
          'pinned',
          'pinned_include',
          false
        );
      }
    }

    // 2. Stage-A excludes reject
    for (const compiled of source.stageAExcludes) {
      if (evaluateProductRule(compiled, product)) {
        return {
          selected: false,
          ruleId: compiled.rule.id,
          reason: 'exclude',
        };
      }
    }

    // 3. Normal Stage-A include must match the product's URL / externalId
    let winningStageA: StageAIncludeRule | null = null;
    for (const compiled of source.stageAStandardIncludes) {
      if (evaluateProductRule(compiled, product)) {
        winningStageA = compiled.rule as StageAIncludeRule;
        break;
      }
    }

    if (!winningStageA) {
      return { selected: false, reason: 'no_match' };
    }

    // 4. Stage-B filtering:
    // 4a. Stage-B excludes reject
    for (const compiled of source.stageBExcludes) {
      if (evaluateProductRule(compiled, product)) {
        return {
          selected: false,
          ruleId: compiled.rule.id,
          reason: 'exclude',
        };
      }
    }

    // 4b. If source has Stage-B include rules, product must match at least one
    if (source.stageBIncludes.length > 0) {
      let matchedStageB = false;
      for (const compiled of source.stageBIncludes) {
        if (evaluateProductRule(compiled, product)) {
          matchedStageB = true;
          break;
        }
      }
      if (!matchedStageB) {
        return { selected: false, reason: 'no_match' };
      }
    }

    // 5. Stage-C filtering:
    // 5a. Stage-C excludes reject
    for (const compiled of source.stageCExcludes) {
      if (evaluateProductRule(compiled, product)) {
        return {
          selected: false,
          ruleId: compiled.rule.id,
          reason: 'exclude',
        };
      }
    }

    // 5b. If source has Stage-C include rules, product must match at least one
    if (source.stageCIncludes.length > 0) {
      let matchedStageC = false;
      for (const compiled of source.stageCIncludes) {
        if (evaluateProductRule(compiled, product)) {
          matchedStageC = true;
          break;
        }
      }
      if (!matchedStageC) {
        return { selected: false, reason: 'no_match' };
      }
    }

    // 6. Passed Stage A, B, and C; metadata is owned by the winning Stage-A include
    return buildSelectedDecision(
      winningStageA,
      winningStageA.tier ?? 'standard',
      'include',
      false
    );
  }

  return {
    version: document.version,
    hash,
    matchUrl,
    matchProduct,
  };
}

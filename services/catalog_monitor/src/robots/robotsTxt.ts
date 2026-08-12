/**
 * Minimal robots.txt parser: enough to answer "may our user agent fetch this
 * path" against `User-agent: *` and an exact-match user agent group. We do
 * not need wildcard-in-the-middle or `$` end-anchor support for the two
 * sites this service targets — both robots.txt files use simple prefix
 * disallows — so this stays small and testable rather than pulling in a
 * general-purpose robots parser package.
 */
export interface RobotsRules {
  readonly disallow: readonly string[];
  readonly allow: readonly string[];
}

export function parseRobotsTxt(text: string, userAgent = '*'): RobotsRules {
  const lines = text.split(/\r?\n/);
  const groups: { agents: string[]; rules: { type: 'allow' | 'disallow'; path: string }[] }[] =
    [];
  let current: { agents: string[]; rules: { type: 'allow' | 'disallow'; path: string }[] } | null =
    null;

  for (const rawLine of lines) {
    const line = rawLine.replace(/#.*$/, '').trim();
    if (!line) continue;
    const sepIndex = line.indexOf(':');
    if (sepIndex === -1) continue;
    const field = line.slice(0, sepIndex).trim().toLowerCase();
    const value = line.slice(sepIndex + 1).trim();

    if (field === 'user-agent') {
      if (!current || current.rules.length > 0) {
        current = { agents: [], rules: [] };
        groups.push(current);
      }
      current.agents.push(value.toLowerCase());
    } else if (field === 'disallow' && current) {
      if (value) current.rules.push({ type: 'disallow', path: value });
    } else if (field === 'allow' && current) {
      if (value) current.rules.push({ type: 'allow', path: value });
    }
  }

  const wanted = userAgent.toLowerCase();
  const applicable = groups.filter(
    (g) => g.agents.includes(wanted) || g.agents.includes('*'),
  );
  // Prefer a specific-agent group over the wildcard group, per the standard.
  const specific = applicable.filter((g) => g.agents.includes(wanted) && wanted !== '*');
  const chosen = specific.length > 0 ? specific : applicable;

  const disallow: string[] = [];
  const allow: string[] = [];
  for (const group of chosen) {
    for (const rule of group.rules) {
      (rule.type === 'disallow' ? disallow : allow).push(rule.path);
    }
  }
  return { disallow, allow };
}

/** Robots patterns use `*` as a wildcard and an optional trailing `$` anchor. */
function patternToRegExp(pattern: string): RegExp {
  const anchored = pattern.endsWith('$');
  const body = anchored ? pattern.slice(0, -1) : pattern;
  const escaped = body.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
  return new RegExp(`^${escaped}${anchored ? '$' : ''}`);
}

export function isAllowedByRobots(rules: RobotsRules, path: string): boolean {
  const matches = (patterns: readonly string[]): string | null =>
    patterns
      .filter((p) => patternToRegExp(p).test(path))
      .sort((a, b) => b.length - a.length)[0] ?? null;

  const bestDisallow = matches(rules.disallow);
  if (bestDisallow === null) return true;

  const bestAllow = matches(rules.allow);
  if (bestAllow === null) return false;

  // Longest matching rule wins (the standard's specificity rule).
  return bestAllow.length >= bestDisallow.length;
}

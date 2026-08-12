/**
 * Detects CAPTCHA challenges and broad bot-blocking so the crawl stops and
 * reports the source rather than retrying into a wall or, worse, attempting
 * to solve/bypass the challenge.
 */
export interface FetchOutcome {
  readonly status: number;
  readonly body?: string;
}

const CAPTCHA_MARKERS = [
  /captcha/i,
  /are you a human/i,
  /verify you are a (human|person)/i,
  /unusual traffic/i,
  /px-captcha/i,
  /perimeterx/i,
  /datadome/i,
  /cf-challenge/i,
  /just a moment\.\.\./i, // Cloudflare interstitial
];

export function looksLikeCaptchaOrBlock(outcome: FetchOutcome): boolean {
  if (outcome.status === 403 || outcome.status === 429 || outcome.status === 503) {
    if (outcome.body && CAPTCHA_MARKERS.some((re) => re.test(outcome.body!))) return true;
    // A 403/429 alone is not automatically a block — could be one bad URL —
    // callers track a *rate* of these across a run to decide "widespread."
    return false;
  }
  if (outcome.body && CAPTCHA_MARKERS.some((re) => re.test(outcome.body!))) return true;
  return false;
}

/**
 * A run-level signal: even without an explicit CAPTCHA marker, a high rate
 * of 403s across many distinct URLs in a short run is "broad blocking," not
 * a handful of unlucky pages.
 */
export function isWidespreadBlocking(params: {
  readonly total: number;
  readonly blockedOrForbidden: number;
}): boolean {
  if (params.total < 5) return false;
  return params.blockedOrForbidden / params.total >= 0.5;
}

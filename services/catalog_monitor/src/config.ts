import { SOURCE_IDS, type SourceId } from './domain/types.js';

/**
 * All environment configuration in one place, parsed once and validated
 * eagerly so a misconfigured deploy fails at startup, not mid-crawl.
 *
 * `liveCrawlEnabled` defaults to `false`. Nothing in this codebase performs a
 * real HTTP request to a merchant site unless this is explicitly `true` —
 * see `src/crawl/httpFetcher.ts`, which reads it directly before opening a
 * socket.
 */
export interface CatalogMonitorConfig {
  readonly databaseUrl: string;
  readonly port: number;
  readonly catalogCron: string;
  readonly liveCrawlEnabled: boolean;
  readonly userAgent: string;
  readonly requestDelayMs: number;
  readonly playwrightFallbackEnabled: boolean;
  readonly fashionItemsPerSource: number;
  readonly perfumeItemsPerSource: number;
  readonly maximumCatalogItems: number;
  readonly usdToMxnRate: number | null;
  readonly defaultCommissionBps: number;
  readonly highValueThresholdMxn: number;
  readonly highValueCommissionBps: number;
  readonly sourceCommissionBps: Readonly<Record<string, number>>;
  readonly productCommissionBps: Readonly<Record<string, number>>;
  readonly enabledSourceIds: readonly SourceId[];
  readonly notificationEventsUrl: string | null;
  readonly notificationEventsSecret: string | null;
  readonly internalServiceSecret: string | null;
}

function bool(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined || value === '') return fallback;
  return value.trim().toLowerCase() === 'true';
}

function int(value: string | undefined, fallback: number): number {
  if (value === undefined || value === '') return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function positiveNumber(value: string | undefined, fallback: number | null): number | null {
  if (value === undefined || value.trim() === '') return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`Expected a positive number, got "${value}"`);
  }
  return parsed;
}

function basisPoints(value: string | undefined, fallback: number): number {
  const parsed = int(value, fallback);
  if (parsed < 0 || parsed > 10_000) {
    throw new Error(`Commission basis points must be between 0 and 10000, got "${value}"`);
  }
  return parsed;
}

function rateMap(value: string | undefined, name: string): Readonly<Record<string, number>> {
  if (value === undefined || value.trim() === '') return {};
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    throw new Error(`${name} must be a JSON object`);
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new Error(`${name} must be a JSON object`);
  }
  const result: Record<string, number> = {};
  for (const [key, raw] of Object.entries(parsed)) {
    if (!Number.isInteger(raw) || (raw as number) < 0 || (raw as number) > 10_000) {
      throw new Error(`${name}.${key} must be integer basis points between 0 and 10000`);
    }
    result[key] = raw as number;
  }
  return result;
}

function enabledSources(value: string | undefined): readonly SourceId[] {
  const requested = (value ?? SOURCE_IDS.join(','))
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  const valid = new Set<string>(SOURCE_IDS);
  const invalid = requested.filter((item) => !valid.has(item));
  if (invalid.length > 0) {
    throw new Error(`ENABLED_SOURCE_IDS contains unknown sources: ${invalid.join(', ')}`);
  }
  return [...new Set(requested)] as SourceId[];
}

// A placeholder domain (RFC 2606) so no real personal contact address ships
// as a default in source control. It is deliberately *not* a valid contact
// for an operational crawl — see the check below.
const PLACEHOLDER_CONTACT_USER_AGENT =
  'MonettaCatalogMonitor/0.1 (+https://monetta.mx; internal research prototype; contact: crawler-contact@example.invalid)';

const CONTACT_EMAIL_RE = /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/;
const PLACEHOLDER_CONTACT_DOMAIN_RE = /@[\w-]+\.(invalid|example|test|localhost)$/i;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): CatalogMonitorConfig {
  const liveCrawlEnabled = bool(env.LIVE_CRAWL_ENABLED, false);
  const userAgent = env.USER_AGENT ?? PLACEHOLDER_CONTACT_USER_AGENT;
  const notificationEventsUrl = nonEmpty(env.NOTIFICATION_EVENTS_URL);
  const notificationEventsSecret = nonEmpty(env.NOTIFICATION_EVENTS_SECRET);
  const internalServiceSecret = nonEmpty(env.CATALOG_MONITOR_SERVICE_SECRET);

  if (notificationEventsUrl !== null) {
    const parsed = new URL(notificationEventsUrl);
    if (!['https:', 'http:'].includes(parsed.protocol)) {
      throw new Error('NOTIFICATION_EVENTS_URL must use HTTP or HTTPS');
    }
    if (notificationEventsSecret === null || notificationEventsSecret.length < 32) {
      throw new Error('NOTIFICATION_EVENTS_SECRET must be at least 32 characters');
    }
  }
  if (internalServiceSecret !== null && internalServiceSecret.length < 32) {
    throw new Error('CATALOG_MONITOR_SERVICE_SECRET must be at least 32 characters');
  }

  if (/mozilla|chrome|safari|webkit|gecko/i.test(userAgent) && !/monetta/i.test(userAgent)) {
    throw new Error(
      'USER_AGENT looks like a browser-impersonation string. This project requires a ' +
        'truthful, contactable user agent — see .env.example.',
    );
  }

  // Operational (live) crawling must never run under a placeholder or
  // missing contact address — a site operator who wants to reach out about
  // this crawler needs a real address to reach.
  if (liveCrawlEnabled) {
    const contactMatch = CONTACT_EMAIL_RE.exec(userAgent);
    if (!contactMatch || PLACEHOLDER_CONTACT_DOMAIN_RE.test(contactMatch[0])) {
      throw new Error(
        'USER_AGENT must include a real, reachable contact email address before ' +
          'LIVE_CRAWL_ENABLED=true. The default placeholder contact (crawler-contact@example.invalid) ' +
          'is not sufficient for an operational crawl — set USER_AGENT explicitly. See .env.example.',
      );
    }
  }

  return {
    databaseUrl:
      env.DATABASE_URL ??
      'postgres://catalog_monitor:catalog_monitor@localhost:5433/catalog_monitor',
    port: int(env.PORT, 8081),
    catalogCron: env.CATALOG_CRON ?? '17 3 * * *',
    liveCrawlEnabled,
    userAgent,
    requestDelayMs: Math.max(int(env.REQUEST_DELAY_MS, 1000), 1000),
    playwrightFallbackEnabled: bool(env.PLAYWRIGHT_FALLBACK_ENABLED, false),
    fashionItemsPerSource: Math.max(int(env.FASHION_ITEMS_PER_SOURCE, 8), 0),
    perfumeItemsPerSource: Math.max(int(env.PERFUME_ITEMS_PER_SOURCE, 12), 0),
    maximumCatalogItems: Math.max(int(env.MAXIMUM_CATALOG_ITEMS, 52), 0),
    usdToMxnRate: positiveNumber(env.USD_TO_MXN_RATE, null),
    defaultCommissionBps: basisPoints(env.COMMISSION_DEFAULT_BPS, 2200),
    highValueThresholdMxn: positiveNumber(env.COMMISSION_HIGH_VALUE_THRESHOLD_MXN, 4000)!,
    highValueCommissionBps: basisPoints(env.COMMISSION_HIGH_VALUE_BPS, 1400),
    sourceCommissionBps: rateMap(env.COMMISSION_SOURCE_RATES_JSON, 'COMMISSION_SOURCE_RATES_JSON'),
    productCommissionBps: rateMap(env.COMMISSION_PRODUCT_RATES_JSON, 'COMMISSION_PRODUCT_RATES_JSON'),
    enabledSourceIds: enabledSources(env.ENABLED_SOURCE_IDS),
    notificationEventsUrl,
    notificationEventsSecret,
    internalServiceSecret,
  };
}

function nonEmpty(value: string | undefined): string | null {
  const trimmed = value?.trim() ?? '';
  return trimmed === '' ? null : trimmed;
}

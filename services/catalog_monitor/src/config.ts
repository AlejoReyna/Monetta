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
  };
}

import type { NextFunction, Request, Response } from 'express';

export const DASHBOARD_ALLOW_METHODS = 'GET, POST, PUT, DELETE, OPTIONS';
export const DASHBOARD_ALLOW_HEADERS = 'Authorization, Content-Type, If-None-Match, X-Applied-By';
export const DASHBOARD_EXPOSE_HEADERS = 'ETag';
export const DASHBOARD_MAX_AGE = '600';

/**
 * Parses `DASHBOARD_ORIGINS` (comma-separated exact origins).
 *
 * Never `*`, never `*.vercel.app` — anyone with a Vercel account can deploy
 * to `*.vercel.app`. Each entry must be a bare origin (`scheme://host[:port]`
 * with no path, query, or wildcard).
 */
export function parseDashboardOrigins(raw: string | undefined | null): string[] {
  if (!raw || raw.trim() === '') return [];
  const origins = raw
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
  const seen = new Set<string>();
  for (const origin of origins) {
    if (origin === '*' || origin.includes('*.') || origin.includes('*')) {
      throw new Error(`DASHBOARD_ORIGINS must be exact origins, got wildcard "${origin}"`);
    }
    let parsed: URL;
    try {
      parsed = new URL(origin);
    } catch {
      throw new Error(`DASHBOARD_ORIGINS entry is not a valid origin: "${origin}"`);
    }
    if ((parsed.protocol !== 'https:' && parsed.protocol !== 'http:') || parsed.pathname !== '/' || parsed.search !== '' || parsed.hash !== '') {
      throw new Error(`DASHBOARD_ORIGINS entry must be a bare origin (scheme://host[:port]): "${origin}"`);
    }
    // Canonical form: scheme://host[:port] with no trailing slash.
    const canonical = `${parsed.protocol}//${parsed.host}`;
    seen.add(canonical);
  }
  return [...seen];
}

/**
 * Exact-allowlist CORS per CATALOG_DASHBOARD.md § 4.
 *
 * - Allowlisted `Origin` is echoed with `Allow-Methods/Headers`,
 *   `Expose-Headers: ETag`, `Max-Age: 600`.
 * - `Vary: Origin` is always set so caches partition by origin.
 * - Credentials mode stays off (bearer header, not cookie).
 * - A non-matching `Origin` gets no CORS headers at all — not a 403. The
 *   browser blocks it; curl and the CLI keep working.
 * - `OPTIONS` preflight on an allowlisted origin answers 204 directly.
 */
export function dashboardCors(allowedOrigins: readonly string[]) {
  const allowlist = new Set(allowedOrigins);
  return (req: Request, res: Response, next: NextFunction): void => {
    res.setHeader('Vary', 'Origin');
    const origin = req.header('Origin');
    const allowed = origin !== undefined && allowlist.has(origin);
    if (allowed && origin !== undefined) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Access-Control-Allow-Methods', DASHBOARD_ALLOW_METHODS);
      res.setHeader('Access-Control-Allow-Headers', DASHBOARD_ALLOW_HEADERS);
      res.setHeader('Access-Control-Expose-Headers', DASHBOARD_EXPOSE_HEADERS);
      res.setHeader('Access-Control-Max-Age', DASHBOARD_MAX_AGE);
      if (req.method === 'OPTIONS') {
        res.status(204).end();
        return;
      }
    }
    next();
  };
}

import { randomBytes } from 'node:crypto';
import type { Express, NextFunction, Request, Response } from 'express';
import { bearerTokenFromHeader, hashSessionToken, verifyPassphrase } from './auth.js';

export const DASHBOARD_SESSION_TTL_HOURS_DEFAULT = 12;
export const LOGIN_MAX_FAILED_ATTEMPTS = 5;
export const LOGIN_WINDOW_MS = 15 * 60 * 1_000;

export interface DashboardSessionRecord {
  readonly tokenSha256: string;
  readonly expiresAt: Date;
  readonly lastSeenAt: Date;
  readonly createdAt: Date;
  readonly label: string | null;
}

export interface DashboardSessionStore {
  create(params: { tokenSha256: string; expiresAt: Date; label?: string | null }): Promise<void>;
  findByTokenHash(tokenSha256: string): Promise<DashboardSessionRecord | null>;
  touch(tokenSha256: string, now: Date): Promise<void>;
  revoke(tokenSha256: string): Promise<void>;
  deleteExpired(now: Date): Promise<number>;
}

/** In-memory store for tests and local development without Postgres. */
export class InMemoryDashboardSessionStore implements DashboardSessionStore {
  private readonly rows = new Map<string, DashboardSessionRecord>();

  async create(params: { tokenSha256: string; expiresAt: Date; label?: string | null }): Promise<void> {
    const now = new Date();
    this.rows.set(params.tokenSha256, {
      tokenSha256: params.tokenSha256,
      expiresAt: params.expiresAt,
      lastSeenAt: now,
      createdAt: now,
      label: params.label ?? null,
    });
  }

  async findByTokenHash(tokenSha256: string): Promise<DashboardSessionRecord | null> {
    return this.rows.get(tokenSha256) ?? null;
  }

  async touch(tokenSha256: string, now: Date): Promise<void> {
    const existing = this.rows.get(tokenSha256);
    if (existing) this.rows.set(tokenSha256, { ...existing, lastSeenAt: now });
  }

  async revoke(tokenSha256: string): Promise<void> {
    this.rows.delete(tokenSha256);
  }

  async deleteExpired(now: Date): Promise<number> {
    let removed = 0;
    for (const [key, row] of this.rows) {
      if (row.expiresAt.getTime() <= now.getTime()) {
        this.rows.delete(key);
        removed += 1;
      }
    }
    return removed;
  }
}

/** Per-IP sliding-window counter for failed passphrase attempts. */
export class LoginRateLimiter {
  private readonly failures = new Map<string, number[]>();

  isBlocked(ip: string, nowMs: number): boolean {
    return this.prune(ip, nowMs).length >= LOGIN_MAX_FAILED_ATTEMPTS;
  }

  recordFailure(ip: string, nowMs: number): void {
    const kept = this.prune(ip, nowMs);
    kept.push(nowMs);
    this.failures.set(ip, kept);
  }

  clear(ip: string): void {
    this.failures.delete(ip);
  }

  private prune(ip: string, nowMs: number): number[] {
    const cutoff = nowMs - LOGIN_WINDOW_MS;
    const kept = (this.failures.get(ip) ?? []).filter((at) => at > cutoff);
    if (kept.length === 0) this.failures.delete(ip);
    else this.failures.set(ip, kept);
    return kept;
  }
}

export interface DashboardSessionDeps {
  readonly store: DashboardSessionStore;
  readonly passphraseVerifier: string | null;
  readonly ttlHours?: number;
  readonly now?: () => Date;
  readonly limiter?: LoginRateLimiter;
  /** Hook for the §3.3 hourly-failure alert (10 failures/hour → email). Defaults to no-op. */
  readonly onAuthFailure?: (info: { ip: string; at: Date }) => void;
}

function clientIp(req: Request): string {
  const forwarded = req.header('X-Forwarded-For');
  if (forwarded && forwarded.trim() !== '') return forwarded.split(',')[0]!.trim();
  return req.ip ?? req.socket?.remoteAddress ?? 'unknown';
}

function ttlHoursOf(deps: DashboardSessionDeps): number {
  const ttl = deps.ttlHours ?? DASHBOARD_SESSION_TTL_HOURS_DEFAULT;
  return Number.isFinite(ttl) && ttl > 0 ? ttl : DASHBOARD_SESSION_TTL_HOURS_DEFAULT;
}

export function requireDashboardSession(deps: Pick<DashboardSessionDeps, 'store' | 'now'>) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const token = bearerTokenFromHeader(req.header('Authorization'));
      if (token === null) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      const record = await deps.store.findByTokenHash(hashSessionToken(token));
      const now = (deps.now ?? (() => new Date()))();
      if (record === null || record.expiresAt.getTime() <= now.getTime()) {
        if (record !== null) {
          try {
            await deps.store.revoke(record.tokenSha256);
          } catch {
            // Best effort — the verdict is still 401.
          }
        }
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      try {
        await deps.store.touch(record.tokenSha256, now);
      } catch (error) {
        next(error);
        return;
      }
      (req as Request & { dashboardSession?: DashboardSessionRecord }).dashboardSession = record;
      next();
    } catch (error) {
      next(error);
    }
  };
}

export function registerDashboardSessionRoutes(app: Express, deps: DashboardSessionDeps): void {
  const limiter = deps.limiter ?? new LoginRateLimiter();

  app.post('/admin/session', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const ip = clientIp(req);
      const now = (deps.now ?? (() => new Date()))();
      if (limiter.isBlocked(ip, now.getTime())) {
        res.status(429).json({ error: 'too_many_attempts' });
        return;
      }
      const passphrase = (req.body as { passphrase?: unknown } | undefined)?.passphrase;
      const ok =
        typeof passphrase === 'string' &&
        passphrase !== '' &&
        (await verifyPassphrase(passphrase, deps.passphraseVerifier));
      if (!ok) {
        limiter.recordFailure(ip, now.getTime());
        try {
          deps.onAuthFailure?.({ ip, at: now });
        } catch {
          // Alerting must never break the auth verdict.
        }
        // Generic verdict — no detail about which part failed.
        res.status(401).json({ error: 'invalid_credentials' });
        return;
      }
      limiter.clear(ip);
      const token = randomBytes(32).toString('base64url');
      const expiresAt = new Date(now.getTime() + ttlHoursOf(deps) * 3_600_000);
      await deps.store.create({ tokenSha256: hashSessionToken(token), expiresAt });
      res.status(200).json({ token, expiresAt: expiresAt.toISOString() });
    } catch (error) {
      next(error);
    }
  });

  app.delete('/admin/session', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const token = bearerTokenFromHeader(req.header('Authorization'));
      if (token === null) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      const record = await deps.store.findByTokenHash(hashSessionToken(token));
      const now = (deps.now ?? (() => new Date()))();
      if (record === null || record.expiresAt.getTime() <= now.getTime()) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      await deps.store.revoke(record.tokenSha256);
      res.status(200).json({ status: 'ok' });
    } catch (error) {
      next(error);
    }
  });
}

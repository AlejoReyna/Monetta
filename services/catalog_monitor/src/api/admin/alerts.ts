import type { Express, NextFunction, Request, RequestHandler, Response } from 'express';
import { computeEtag } from '../etag.js';
import { clampLimit } from './runs.js';
import type { AdminDbClient } from './runs.js';

/**
 * WP-61 read endpoint: alert history + dedupe state.
 *
 * Backed by the `alert_state` table documented for migration 009
 * (`key`, `last_sent_at`). An alert is `suppressed` while its last send is
 * inside the dedupe window (`ALERT_MIN_INTERVAL_HOURS`, default 6) — the
 * same rule WP-23's sender enforces, surfaced here so the dashboard can
 * explain why a repeat failure sent no second email. Until 009 lands, the
 * Postgres store degrades to an empty list instead of a 500.
 */

export interface AdminAlertRecord {
  readonly key: string;
  readonly lastSentAt: string;
  /** True while inside the dedupe window — a repeat would not re-send. */
  readonly suppressed: boolean;
}

export interface AdminAlertStore {
  list(limit: number, now: Date): Promise<AdminAlertRecord[]>;
}

export const ALERT_DEDUPE_WINDOW_HOURS_DEFAULT = 6;

/** In-memory store: the seam tests seed directly. */
export class InMemoryAdminAlertStore implements AdminAlertStore {
  private readonly rows: Array<{ key: string; lastSentAt: string }> = [];
  constructor(private readonly dedupeWindowHours: number = ALERT_DEDUPE_WINDOW_HOURS_DEFAULT) {}

  seed(rows: ReadonlyArray<{ key: string; lastSentAt: Date | string }>): void {
    for (const row of rows) {
      this.rows.push({
        key: row.key,
        lastSentAt: typeof row.lastSentAt === 'string' ? row.lastSentAt : row.lastSentAt.toISOString(),
      });
    }
  }

  async list(limit: number, now: Date): Promise<AdminAlertRecord[]> {
    const windowMs = this.dedupeWindowHours * 3_600_000;
    return [...this.rows]
      .sort((a, b) => b.lastSentAt.localeCompare(a.lastSentAt) || a.key.localeCompare(b.key))
      .slice(0, limit)
      .map((row) => ({
        key: row.key,
        lastSentAt: row.lastSentAt,
        suppressed: now.getTime() - Date.parse(row.lastSentAt) < windowMs,
      }));
  }
}

/** Production store over the 009 `alert_state` table; empty when absent. */
export function createPgAdminAlertStore(
  db: AdminDbClient,
  dedupeWindowHours: number = ALERT_DEDUPE_WINDOW_HOURS_DEFAULT,
): AdminAlertStore {
  return {
    async list(limit: number, now: Date) {
      try {
        const { rows } = await db.query(
          `SELECT key, last_sent_at FROM alert_state ORDER BY last_sent_at DESC LIMIT $1`,
          [limit],
        );
        const windowMs = dedupeWindowHours * 3_600_000;
        const alerts: AdminAlertRecord[] = [];
        for (const row of rows) {
          const key = String(row.key ?? '');
          if (key === '') continue;
          const raw = row.last_sent_at;
          const lastSentAt = raw instanceof Date ? raw.toISOString() : String(raw ?? '');
          if (lastSentAt === '') continue;
          alerts.push({
            key,
            lastSentAt,
            suppressed: now.getTime() - Date.parse(lastSentAt) < windowMs,
          });
        }
        return alerts;
      } catch (error) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'code' in error &&
          (error as { code: unknown }).code === '42P01'
        ) {
          return [];
        }
        throw error;
      }
    },
  };
}

export const ADMIN_ALERTS_LIMIT_DEFAULT = 100;

function sendEtagged(req: Request, res: Response, body: unknown): void {
  const json = JSON.stringify(body);
  const etag = computeEtag(json);
  res.setHeader('ETag', etag);
  if (req.header('If-None-Match') === etag) {
    res.status(304).end();
    return;
  }
  res.status(200).json(body);
}

function asyncRoute(handler: (req: Request, res: Response) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction): void => {
    void handler(req, res).catch(next);
  };
}

export interface AdminAlertsRouteDeps {
  readonly gate: RequestHandler;
  readonly store: AdminAlertStore;
  readonly now?: () => Date;
}

export function registerAdminAlertsRoutes(app: Express, deps: AdminAlertsRouteDeps): void {
  app.get(
    '/admin/alerts',
    deps.gate,
    asyncRoute(async (req, res) => {
      const alerts = await deps.store.list(
        clampLimit(req.query.limit, ADMIN_ALERTS_LIMIT_DEFAULT),
        (deps.now ?? (() => new Date()))(),
      );
      sendEtagged(req, res, { alerts });
    }),
  );
}

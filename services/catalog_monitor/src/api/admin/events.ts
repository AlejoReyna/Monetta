import type { Express, NextFunction, Request, RequestHandler, Response } from 'express';
import { computeEtag } from '../etag.js';
import { clampLimit } from './runs.js';
import type { AdminDbClient } from './runs.js';

/**
 * WP-61 read endpoint: product change timeline.
 *
 * Backed by the `product_events` table documented for migration 009
 * (`kind` in `new_match, price_drop, price_rise, back_in_stock,
 * out_of_stock, deselected, inactive`). Until that migration lands, the
 * Postgres store degrades to an empty timeline instead of a 500; tests
 * seed the in-memory store directly.
 *
 * `previous`/`current` snapshots are passed through only after stripping
 * crawl-internal keys, so a future writer can never leak a fingerprint
 * into this feed.
 */

export type AdminEventKind =
  | 'new_match'
  | 'price_drop'
  | 'price_rise'
  | 'back_in_stock'
  | 'out_of_stock'
  | 'deselected'
  | 'inactive';

const EVENT_KINDS: readonly string[] = [
  'new_match',
  'price_drop',
  'price_rise',
  'back_in_stock',
  'out_of_stock',
  'deselected',
  'inactive',
];

export interface AdminEventRecord {
  readonly id: string;
  readonly kind: AdminEventKind;
  readonly source: string;
  readonly externalId: string;
  readonly sourceScopedId: string;
  readonly observedAt: string;
  readonly previous: Readonly<Record<string, unknown>> | null;
  readonly current: Readonly<Record<string, unknown>> | null;
}

export interface AdminEventSeed {
  readonly id?: string;
  readonly kind: AdminEventKind;
  readonly source: string;
  readonly externalId: string;
  readonly observedAt: Date | string;
  readonly previous?: Readonly<Record<string, unknown>> | null;
  readonly current?: Readonly<Record<string, unknown>> | null;
}

/** Keys that must never appear in an event snapshot served to the browser. */
const FORBIDDEN_SNAPSHOT_KEYS = new Set([
  'fingerprint',
  'consecutiveMissingSnapshots',
  'consecutive_missing_snapshots',
  'stack',
  'stackTrace',
  'rawHtml',
  'raw_html',
  'connectionDetails',
  'connection_details',
  'cookie',
  'authorization',
]);

export function sanitizeSnapshot(
  value: Readonly<Record<string, unknown>> | null | undefined,
): Readonly<Record<string, unknown>> | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'object' || Array.isArray(value)) return null;
  const clean: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value)) {
    if (FORBIDDEN_SNAPSHOT_KEYS.has(key)) continue;
    clean[key] = entry;
  }
  return clean;
}

export interface AdminEventStore {
  listSince(since: Date, limit: number): Promise<AdminEventRecord[]>;
}

/** In-memory store: the seam tests seed directly. */
export class InMemoryAdminEventStore implements AdminEventStore {
  private readonly events: AdminEventRecord[] = [];

  seed(seeds: readonly AdminEventSeed[]): void {
    for (const seed of seeds) {
      const observedAt =
        typeof seed.observedAt === 'string' ? seed.observedAt : seed.observedAt.toISOString();
      this.events.push({
        id: seed.id ?? `${seed.source}:${seed.externalId}:${seed.kind}:${observedAt}`,
        kind: seed.kind,
        source: seed.source,
        externalId: seed.externalId,
        sourceScopedId: `${seed.source}:${seed.externalId}`,
        observedAt,
        previous: sanitizeSnapshot(seed.previous),
        current: sanitizeSnapshot(seed.current),
      });
    }
  }

  async listSince(since: Date, limit: number): Promise<AdminEventRecord[]> {
    return this.events
      .filter((event) => Date.parse(event.observedAt) > since.getTime())
      .sort((a, b) => b.observedAt.localeCompare(a.observedAt) || b.id.localeCompare(a.id))
      .slice(0, limit);
  }
}

function parseSnapshot(value: unknown): Readonly<Record<string, unknown>> | null {
  if (value === null || value === undefined) return null;
  if (typeof value === 'string') {
    try {
      return sanitizeSnapshot(JSON.parse(value) as Record<string, unknown>);
    } catch {
      return null;
    }
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    return sanitizeSnapshot(value as Record<string, unknown>);
  }
  return null;
}

/** Production store over the 009 `product_events` table; empty when absent. */
export function createPgAdminEventStore(db: AdminDbClient): AdminEventStore {
  return {
    async listSince(since: Date, limit: number) {
      try {
        const { rows } = await db.query(
          `SELECT id, source_id, external_id, kind, observed_at, previous, current
             FROM product_events
            WHERE observed_at > $1
            ORDER BY observed_at DESC, id DESC
            LIMIT $2`,
          [since.toISOString(), limit],
        );
        const events: AdminEventRecord[] = [];
        for (const row of rows) {
          const kind = String(row.kind ?? '');
          if (!(EVENT_KINDS as readonly string[]).includes(kind)) continue;
          const source = String(row.source_id ?? '');
          const externalId = String(row.external_id ?? '');
          const observedRaw = row.observed_at;
          const observedAt = observedRaw instanceof Date ? observedRaw.toISOString() : String(observedRaw ?? '');
          if (observedAt === '') continue;
          events.push({
            id: String(row.id ?? `${source}:${externalId}:${kind}:${observedAt}`),
            kind: kind as AdminEventKind,
            source,
            externalId,
            sourceScopedId: `${source}:${externalId}`,
            observedAt,
            previous: parseSnapshot(row.previous),
            current: parseSnapshot(row.current),
          });
        }
        return events;
      } catch (error) {
        if (isUndefinedTable(error)) return [];
        throw error;
      }
    },
  };
}

function isUndefinedTable(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code: unknown }).code === '42P01'
  );
}

export const ADMIN_EVENTS_LIMIT_DEFAULT = 100;
const TWENTY_FOUR_HOURS_MS = 24 * 3_600_000;

export function parseSince(raw: unknown, now: Date): Date {
  if (typeof raw === 'string' && raw.trim() !== '') {
    const parsed = Date.parse(raw);
    if (Number.isFinite(parsed)) return new Date(parsed);
  }
  // Mirror WP-21: a missing or invalid `since` defaults to 24 h ago.
  return new Date(now.getTime() - TWENTY_FOUR_HOURS_MS);
}

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

export interface AdminEventsRouteDeps {
  readonly gate: RequestHandler;
  readonly store: AdminEventStore;
  readonly now?: () => Date;
}

export function registerAdminEventsRoutes(app: Express, deps: AdminEventsRouteDeps): void {
  app.get(
    '/admin/events',
    deps.gate,
    asyncRoute(async (req, res) => {
      const now = (deps.now ?? (() => new Date()))();
      const since = parseSince(req.query.since, now);
      const events = await deps.store.listSince(since, clampLimit(req.query.limit, ADMIN_EVENTS_LIMIT_DEFAULT));
      // `nextSince` lets the Events screen page forward without gaps.
      sendEtagged(req, res, { events, nextSince: now.toISOString() });
    }),
  );
}

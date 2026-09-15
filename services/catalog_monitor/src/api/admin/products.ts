import type { Express, NextFunction, Request, RequestHandler, Response } from 'express';
import { computeEtag } from '../etag.js';
import { SOURCE_IDS, type SourceId } from '../../domain/types.js';
import type { CatalogProductRecord } from '../../domain/types.js';
import type { ProductRepository } from '../../crawl/ports.js';
import { ADMIN_LIST_LIMIT_MAX, clampLimit } from './runs.js';
import type { AdminDbClient } from './runs.js';

/**
 * WP-61 read endpoint: server-filtered, cursor-paged product table.
 *
 * The view deliberately omits `fingerprint`, `variants`,
 * `consecutiveMissingSnapshots` and anything resembling raw HTML or
 * connection details — the Products screen needs merchant data, not crawl
 * internals.
 */

export type AdminProductState = 'selected' | 'deselected' | 'active' | 'inactive' | 'served' | 'all';
const PRODUCT_STATES: readonly string[] = ['selected', 'deselected', 'active', 'inactive', 'served', 'all'];

const PRODUCT_TIERS: readonly string[] = ['standard', 'pinned'];

export interface AdminProductView {
  readonly sourceScopedId: string;
  readonly source: SourceId;
  readonly title: string;
  readonly brand: string;
  readonly category: string | null;
  readonly imageUrl: string | null;
  readonly priceUsd: number | null;
  readonly availability: string;
  readonly selectionState: 'selected' | 'deselected';
  readonly isActive: boolean;
  /** Effective visibility for the app feed: selected, active, not hidden. */
  readonly served: boolean;
  readonly watchTier: string;
  readonly placements: readonly string[];
  readonly matchedRuleId: string | null;
  readonly detailUrl: string;
  readonly firstSeenAt: string;
  readonly lastSeenAt: string;
  readonly lastChangedAt: string;
}

export function toAdminProductView(record: CatalogProductRecord): AdminProductView {
  const placements = [...(record.placements ?? [])] as readonly string[];
  return {
    sourceScopedId: `${record.sourceId}:${record.externalId}`,
    source: record.sourceId,
    title: record.title,
    brand: record.brand,
    category: record.category,
    imageUrl: record.imageUrl,
    priceUsd: record.priceUsd,
    availability: record.availability,
    selectionState: record.selectionState,
    isActive: record.isActive,
    served:
      record.selectionState === 'selected' &&
      record.isActive &&
      !placements.includes('hidden'),
    watchTier: record.watchTier,
    placements,
    matchedRuleId: record.matchedRuleId,
    detailUrl: record.canonicalUrl,
    firstSeenAt: record.firstSeenAt.toISOString(),
    lastSeenAt: record.lastSeenAt.toISOString(),
    lastChangedAt: record.lastChangedAt.toISOString(),
  };
}

export interface AdminProductQuery {
  readonly source?: SourceId;
  readonly q?: string;
  readonly state: AdminProductState;
  readonly tier?: string;
  readonly placement?: string;
  readonly limit: number;
  readonly cursor?: string;
}

export interface AdminProductStore {
  query(options: AdminProductQuery): Promise<{ products: AdminProductView[]; nextCursor: string | null }>;
}

/** In-memory store: the seam tests seed with full `CatalogProductRecord`s. */
export class InMemoryAdminProductStore implements AdminProductStore {
  private readonly records: CatalogProductRecord[] = [];

  seed(records: readonly CatalogProductRecord[]): void {
    this.records.push(...records);
  }

  async query(options: AdminProductQuery): Promise<{ products: AdminProductView[]; nextCursor: string | null }> {
    const needle = options.q?.toLowerCase();
    const filtered = this.records
      .filter((record) => (options.source === undefined ? true : record.sourceId === options.source))
      .filter((record) => {
        switch (options.state) {
          case 'all':
            return true;
          case 'selected':
            return record.selectionState === 'selected';
          case 'deselected':
            return record.selectionState === 'deselected';
          case 'active':
            return record.isActive;
          case 'inactive':
            return !record.isActive;
          case 'served':
            return (
              record.selectionState === 'selected' &&
              record.isActive &&
              !(record.placements as readonly string[]).includes('hidden')
            );
        }
      })
      .filter((record) => (options.tier === undefined ? true : record.watchTier === options.tier))
      .filter((record) =>
        options.placement === undefined
          ? true
          : (record.placements as readonly string[]).includes(options.placement),
      )
      .filter((record) =>
        needle === undefined || needle === ''
          ? true
          : record.title.toLowerCase().includes(needle) ||
            record.externalId.toLowerCase().includes(needle),
      )
      .map(toAdminProductView)
      .sort((a, b) =>
        a.sourceScopedId.localeCompare(b.sourceScopedId),
      );
    let start = 0;
    if (options.cursor !== undefined) {
      const index = filtered.findIndex((item) => item.sourceScopedId === options.cursor);
      start = index === -1 ? filtered.length : index + 1;
    }
    const page = filtered.slice(start, start + options.limit);
    const hasMore = start + options.limit < filtered.length;
    return {
      products: page,
      nextCursor: hasMore && page.length > 0 ? page[page.length - 1]!.sourceScopedId : null,
    };
  }
}

function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}

/** Production store: filters in SQL so the table stays server-paged. */
export function createPgAdminProductStore(db: AdminDbClient): AdminProductStore {
  return {
    async query(options: AdminProductQuery) {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (options.source !== undefined) {
        params.push(options.source);
        conditions.push(`source_id = $${params.length}`);
      }
      switch (options.state) {
        case 'selected':
          conditions.push(`selection_state = 'selected'`);
          break;
        case 'deselected':
          conditions.push(`selection_state = 'deselected'`);
          break;
        case 'active':
          conditions.push(`is_active = TRUE`);
          break;
        case 'inactive':
          conditions.push(`is_active = FALSE`);
          break;
        case 'served':
          conditions.push(`selection_state = 'selected' AND is_active = TRUE AND NOT (placements ? 'hidden')`);
          break;
        case 'all':
          break;
      }
      if (options.tier !== undefined) {
        params.push(options.tier);
        conditions.push(`watch_tier = $${params.length}`);
      }
      if (options.placement !== undefined) {
        params.push(options.placement);
        conditions.push(`placements ? $${params.length}`);
      }
      if (options.q !== undefined && options.q !== '') {
        params.push(`%${escapeLike(options.q)}%`);
        conditions.push(`(title ILIKE $${params.length} ESCAPE '\\' OR external_id ILIKE $${params.length} ESCAPE '\\')`);
      }
      if (options.cursor !== undefined) {
        const [cursorSource, ...rest] = options.cursor.split(':');
        const cursorExternal = rest.join(':');
        if (cursorSource !== undefined && cursorExternal !== '') {
          params.push(cursorSource, cursorExternal);
          conditions.push(
            `(source_id, external_id) > ($${params.length - 1}, $${params.length})`,
          );
        }
      }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      params.push(options.limit + 1);
      const { rows } = await db.query(
        `SELECT source_id, external_id, canonical_url, title, brand, category,
                image_url, price_usd, availability, selection_state, is_active,
                watch_tier, placements, matched_rule_id,
                first_seen_at, last_seen_at, last_changed_at
           FROM products ${where}
          ORDER BY source_id ASC, external_id ASC
          LIMIT $${params.length}`,
        params,
      );
      const views = rows.flatMap((row): AdminProductView[] => {
        const source = String(row.source_id ?? '');
        if (!(SOURCE_IDS as readonly string[]).includes(source)) return [];
        const priceRaw = row.price_usd;
        const placementsRaw = row.placements;
        const placements: readonly string[] = Array.isArray(placementsRaw)
          ? (placementsRaw as unknown[]).filter((p): p is string => typeof p === 'string')
          : [];
        const toIso = (value: unknown): string =>
          value instanceof Date ? value.toISOString() : String(value ?? '');
        const selectionState = row.selection_state === 'deselected' ? 'deselected' : 'selected';
        const isActive = row.is_active === true;
        return [
          {
            sourceScopedId: `${source}:${String(row.external_id ?? '')}`,
            source: source as SourceId,
            title: String(row.title ?? ''),
            brand: String(row.brand ?? ''),
            category: typeof row.category === 'string' ? row.category : null,
            imageUrl: typeof row.image_url === 'string' ? row.image_url : null,
            priceUsd:
              priceRaw === null || priceRaw === undefined ? null : Number.parseFloat(String(priceRaw)),
            availability: String(row.availability ?? 'unknown'),
            selectionState,
            isActive,
            served: selectionState === 'selected' && isActive && !placements.includes('hidden'),
            watchTier: typeof row.watch_tier === 'string' ? row.watch_tier : 'standard',
            placements,
            matchedRuleId: typeof row.matched_rule_id === 'string' ? row.matched_rule_id : null,
            detailUrl: String(row.canonical_url ?? ''),
            firstSeenAt: toIso(row.first_seen_at),
            lastSeenAt: toIso(row.last_seen_at),
            lastChangedAt: toIso(row.last_changed_at),
          },
        ];
      });
      const page = views.slice(0, options.limit);
      const hasMore = views.length > page.length;
      return {
        products: page,
        nextCursor: hasMore && page.length > 0 ? page[page.length - 1]!.sourceScopedId : null,
      };
    },
  };
}

/**
 * Fallback over the crawl port, which only exposes active products — the
 * `inactive`/`all` states read empty here. Production wires the pg store.
 */
export function createRepositoryAdminProductStore(products: ProductRepository): AdminProductStore {
  const backing = new InMemoryAdminProductStore();
  let loaded = false;
  return {
    async query(options: AdminProductQuery) {
      if (!loaded) {
        backing.seed(await products.getAllActiveProducts());
        loaded = true;
      }
      return backing.query(options);
    },
  };
}

export const ADMIN_PRODUCTS_LIMIT_DEFAULT = 50;

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

export interface AdminProductsRouteDeps {
  readonly gate: RequestHandler;
  readonly store: AdminProductStore;
}

export function registerAdminProductsRoutes(app: Express, deps: AdminProductsRouteDeps): void {
  app.get(
    '/admin/products',
    deps.gate,
    asyncRoute(async (req, res) => {
      const sourceRaw = typeof req.query.source === 'string' && req.query.source !== '' ? req.query.source : undefined;
      if (sourceRaw !== undefined && !(SOURCE_IDS as readonly string[]).includes(sourceRaw)) {
        res.status(400).json({ error: 'invalid_source' });
        return;
      }
      const stateRaw =
        typeof req.query.state === 'string' && req.query.state !== '' ? req.query.state : 'all';
      if (!(PRODUCT_STATES as readonly string[]).includes(stateRaw)) {
        res.status(400).json({ error: 'invalid_state' });
        return;
      }
      const tierRaw = typeof req.query.tier === 'string' && req.query.tier !== '' ? req.query.tier : undefined;
      if (tierRaw !== undefined && !(PRODUCT_TIERS as readonly string[]).includes(tierRaw)) {
        res.status(400).json({ error: 'invalid_tier' });
        return;
      }
      const placementRaw =
        typeof req.query.placement === 'string' && req.query.placement !== '' ? req.query.placement : undefined;
      const cursorRaw =
        typeof req.query.cursor === 'string' && req.query.cursor !== '' ? req.query.cursor : undefined;
      const qRaw = typeof req.query.q === 'string' ? req.query.q : undefined;
      const { products, nextCursor } = await deps.store.query({
        source: sourceRaw as SourceId | undefined,
        q: qRaw,
        state: stateRaw as AdminProductState,
        tier: tierRaw,
        placement: placementRaw,
        limit: clampLimit(req.query.limit, ADMIN_PRODUCTS_LIMIT_DEFAULT),
        cursor: cursorRaw,
      });
      // Placement is validated structurally on write (008 CHECK); here it is
      // an opaque filter string, so no allowlist applies.
      sendEtagged(req, res, { products, nextCursor });
    }),
  );
}

export { ADMIN_LIST_LIMIT_MAX };

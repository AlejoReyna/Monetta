import type pg from 'pg';
import { createHash, randomUUID } from 'node:crypto';
import type { ProductRepository } from '../crawl/ports.js';
import type {
  Availability,
  CatalogProductRecord,
  ExtractedProductVariant,
  SourceId,
} from '../domain/types.js';

interface ProductRow {
  source_id: string;
  external_id: string;
  canonical_url: string;
  title: string;
  brand: string;
  category: string | null;
  image_url: string | null;
  price_usd: string | null;
  availability: Availability;
  variants: ExtractedProductVariant[] | null;
  fingerprint: string;
  first_seen_at: Date;
  last_seen_at: Date;
  last_changed_at: Date;
  is_active: boolean;
  consecutive_missing_snapshots: number;
}

function fromRow(row: ProductRow): CatalogProductRecord {
  return {
    sourceId: row.source_id as SourceId,
    externalId: row.external_id,
    canonicalUrl: row.canonical_url,
    title: row.title,
    brand: row.brand,
    category: row.category,
    imageUrl: row.image_url,
    priceUsd: row.price_usd === null ? null : Number.parseFloat(row.price_usd),
    availability: row.availability,
    variants: Array.isArray(row.variants) ? row.variants : [],
    fingerprint: row.fingerprint,
    firstSeenAt: row.first_seen_at,
    lastSeenAt: row.last_seen_at,
    lastChangedAt: row.last_changed_at,
    isActive: row.is_active,
    consecutiveMissingSnapshots: row.consecutive_missing_snapshots,
  };
}

export class PgProductRepository implements ProductRepository {
  constructor(private readonly pool: pg.Pool) {}

  async getActiveProducts(sourceId: SourceId): Promise<CatalogProductRecord[]> {
    const { rows } = await this.pool.query<ProductRow>(
      'SELECT * FROM products WHERE source_id = $1 AND is_active = TRUE',
      [sourceId],
    );
    return rows.map(fromRow);
  }

  async getAllActiveProducts(): Promise<CatalogProductRecord[]> {
    const { rows } = await this.pool.query<ProductRow>(
      'SELECT * FROM products WHERE is_active = TRUE',
    );
    return rows.map(fromRow);
  }

  async upsertMany(records: readonly CatalogProductRecord[]): Promise<void> {
    if (records.length === 0) return;
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      for (const r of records) {
        const previousResult = await client.query<ProductRow>(
          `SELECT * FROM products
            WHERE source_id = $1 AND external_id = $2
            FOR UPDATE`,
          [r.sourceId, r.externalId],
        );
        const previous = previousResult.rows[0] === undefined
          ? null
          : fromRow(previousResult.rows[0]);
        await client.query(
          `INSERT INTO products (
             source_id, external_id, canonical_url, title, brand, category, image_url,
             price_usd, availability, variants, fingerprint, first_seen_at, last_seen_at,
             last_changed_at, is_active, consecutive_missing_snapshots
           ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
           ON CONFLICT (source_id, external_id) DO UPDATE SET
             canonical_url = EXCLUDED.canonical_url,
             title = EXCLUDED.title,
             brand = EXCLUDED.brand,
             category = EXCLUDED.category,
             image_url = EXCLUDED.image_url,
             price_usd = EXCLUDED.price_usd,
             availability = EXCLUDED.availability,
             variants = EXCLUDED.variants,
             fingerprint = EXCLUDED.fingerprint,
             first_seen_at = EXCLUDED.first_seen_at,
             last_seen_at = EXCLUDED.last_seen_at,
             last_changed_at = EXCLUDED.last_changed_at,
             is_active = EXCLUDED.is_active,
             consecutive_missing_snapshots = EXCLUDED.consecutive_missing_snapshots`,
          [
            r.sourceId,
            r.externalId,
            r.canonicalUrl,
            r.title,
            r.brand,
            r.category,
            r.imageUrl,
            r.priceUsd,
            r.availability,
            JSON.stringify(r.variants ?? []),
            r.fingerprint,
            r.firstSeenAt,
            r.lastSeenAt,
            r.lastChangedAt,
            r.isActive,
            r.consecutiveMissingSnapshots,
          ],
        );
        for (const event of catalogEvents(previous, r)) {
          await client.query(
            `INSERT INTO notification_event_outbox
               (id, event_id, payload, status, next_attempt_at, created_at, updated_at)
             VALUES ($1, $2, $3::jsonb, 'pending', $4, $4, $4)
             ON CONFLICT (event_id) DO NOTHING`,
            [randomUUID(), event.eventId, JSON.stringify(event), r.lastChangedAt],
          );
        }
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}

type CatalogEventType =
  | 'catalog.product.created'
  | 'catalog.product.restocked'
  | 'catalog.product.price_dropped';

interface CatalogEventPayload {
  readonly eventId: string;
  readonly eventType: CatalogEventType;
  readonly source: string;
  readonly productKey: string;
  readonly occurredAt: string;
  readonly before: Record<string, unknown> | null;
  readonly after: Record<string, unknown>;
}

export function catalogEvents(
  previous: CatalogProductRecord | null,
  next: CatalogProductRecord,
): readonly CatalogEventPayload[] {
  if (!next.isActive) return [];
  const types: CatalogEventType[] = [];
  if (previous === null) {
    types.push('catalog.product.created');
  } else {
    if (previous.availability !== 'inStock' && next.availability === 'inStock') {
      types.push('catalog.product.restocked');
    }
    if (
      previous.priceUsd !== null &&
      next.priceUsd !== null &&
      next.priceUsd < previous.priceUsd
    ) {
      types.push('catalog.product.price_dropped');
    }
  }
  const productKey = `external:${next.sourceId}:${next.externalId}`;
  const transitionKey = [
    next.fingerprint,
    next.availability,
    next.priceUsd,
    next.lastChangedAt.toISOString(),
  ].join(':');
  return types.map((eventType) => ({
    eventId: createHash('sha256')
      .update(`${eventType}:${productKey}:${transitionKey}`)
      .digest('hex'),
    eventType,
    source: next.sourceId,
    productKey,
    occurredAt: next.lastChangedAt.toISOString(),
    before: previous === null ? null : eventView(previous),
    after: eventView(next),
  }));
}

function eventView(product: CatalogProductRecord): Record<string, unknown> {
  return {
    title: product.title,
    brand: slug(product.brand),
    category: product.category === null ? null : slug(product.category),
    imageUrl: product.imageUrl,
    price: product.priceUsd,
    availability: product.availability,
    detailUrl: product.canonicalUrl,
  };
}

function slug(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

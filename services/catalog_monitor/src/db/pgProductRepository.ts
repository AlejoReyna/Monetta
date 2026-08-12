import type pg from 'pg';
import type { ProductRepository } from '../crawl/ports.js';
import type { Availability, CatalogProductRecord, SourceId } from '../domain/types.js';

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
        await client.query(
          `INSERT INTO products (
             source_id, external_id, canonical_url, title, brand, category, image_url,
             price_usd, availability, fingerprint, first_seen_at, last_seen_at,
             last_changed_at, is_active, consecutive_missing_snapshots
           ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
           ON CONFLICT (source_id, external_id) DO UPDATE SET
             canonical_url = EXCLUDED.canonical_url,
             title = EXCLUDED.title,
             brand = EXCLUDED.brand,
             category = EXCLUDED.category,
             image_url = EXCLUDED.image_url,
             price_usd = EXCLUDED.price_usd,
             availability = EXCLUDED.availability,
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
            r.fingerprint,
            r.firstSeenAt,
            r.lastSeenAt,
            r.lastChangedAt,
            r.isActive,
            r.consecutiveMissingSnapshots,
          ],
        );
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

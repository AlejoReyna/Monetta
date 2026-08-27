import type pg from 'pg';
import type { ShopifyProductWebhookPayload } from '../../webhooks/payloads.js';
import { EngagementService } from '../application/engagementService.js';
import type { CatalogEventInput } from '../domain/types.js';

interface SnapshotRow {
  readonly product_key: string;
  readonly title: string;
  readonly brand: string | null;
  readonly category: string | null;
  readonly image_url: string | null;
  readonly price: string | null;
  readonly available: boolean;
  readonly updated_at: Date;
}

export class PgShopifyCatalogEventProcessor {
  constructor(
    private readonly pool: pg.Pool,
    private readonly engagement: EngagementService,
  ) {}

  async process(
    topic: 'products/create' | 'products/update',
    webhookId: string,
    payload: ShopifyProductWebhookPayload,
  ): Promise<void> {
    const next = snapshot(payload);
    const client = await this.pool.connect();
    let previous: SnapshotRow | null = null;
    try {
      await client.query('BEGIN');
      const existing = await client.query<SnapshotRow>(
        `SELECT * FROM shopify_product_notification_snapshots
          WHERE product_key = $1 FOR UPDATE`,
        [next.productKey],
      );
      previous = existing.rows[0] ?? null;
      await client.query(
        `INSERT INTO shopify_product_notification_snapshots
           (product_key, title, brand, category, image_url, price, available, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (product_key) DO UPDATE SET
           title = EXCLUDED.title,
           brand = EXCLUDED.brand,
           category = EXCLUDED.category,
           image_url = EXCLUDED.image_url,
           price = EXCLUDED.price,
           available = EXCLUDED.available,
           updated_at = EXCLUDED.updated_at`,
        [
          next.productKey,
          next.title,
          next.brand,
          next.category,
          next.imageUrl,
          next.price,
          next.available,
          next.occurredAt,
        ],
      );
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    const events = transitions(topic, webhookId, previous, next);
    for (const event of events) await this.engagement.ingestCatalogEvent(event);
  }
}

interface NextSnapshot {
  readonly productKey: string;
  readonly title: string;
  readonly brand: string | null;
  readonly category: string | null;
  readonly imageUrl: string | null;
  readonly price: number | null;
  readonly available: boolean;
  readonly occurredAt: Date;
}

function snapshot(payload: ShopifyProductWebhookPayload): NextSnapshot {
  const variants = payload.variants ?? [];
  const prices = variants
    .map((variant) => Number(variant.price))
    .filter((price) => Number.isFinite(price) && price >= 0);
  return {
    productKey: `shopify:${payload.id}`,
    title: nonEmpty(payload.title) ?? 'Producto Monetta',
    brand: slugOrNull(payload.vendor),
    category: slugOrNull(payload.product_type),
    imageUrl: nonEmpty(payload.image?.src) ??
      payload.images?.map((image) => nonEmpty(image.src)).find((url) => url !== null) ??
      null,
    price: prices.length === 0 ? null : Math.min(...prices),
    available: variants.some((variant) => (variant.inventory_quantity ?? 0) > 0),
    occurredAt: validDate(payload.updated_at) ?? new Date(),
  };
}

function transitions(
  topic: 'products/create' | 'products/update',
  webhookId: string,
  previous: SnapshotRow | null,
  next: NextSnapshot,
): readonly CatalogEventInput[] {
  const eventTypes: CatalogEventInput['eventType'][] = [];
  if (topic === 'products/create' || previous === null) {
    eventTypes.push('catalog.product.created');
  } else {
    if (!previous.available && next.available) {
      eventTypes.push('catalog.product.restocked');
    }
    const previousPrice = previous.price === null ? null : Number(previous.price);
    if (previousPrice !== null && next.price !== null && next.price < previousPrice) {
      eventTypes.push('catalog.product.price_dropped');
    }
  }
  const before = previous === null ? null : {
    title: previous.title,
    brand: previous.brand,
    category: previous.category,
    imageUrl: previous.image_url,
    price: previous.price === null ? null : Number(previous.price),
    available: previous.available,
  };
  const after = {
    title: next.title,
    brand: next.brand,
    category: next.category,
    imageUrl: next.imageUrl,
    price: next.price,
    available: next.available,
  };
  return eventTypes.map((eventType) => ({
    eventId: `shopify:${webhookId}:${eventType}`,
    eventType,
    source: 'shopify_webhook',
    productKey: next.productKey,
    occurredAt: next.occurredAt,
    before,
    after,
  }));
}

function nonEmpty(value: string | null | undefined): string | null {
  const trimmed = value?.trim() ?? '';
  return trimmed === '' ? null : trimmed;
}

function slugOrNull(value: string | null | undefined): string | null {
  const text = nonEmpty(value);
  if (text === null) return null;
  return text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function validDate(value: string | null | undefined): Date | null {
  if (value === null || value === undefined) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

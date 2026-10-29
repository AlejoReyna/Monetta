import { randomUUID } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import pg from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { EngagementService } from '../src/engagement/application/engagementService.js';
import { RegistrationCipher } from '../src/engagement/crypto/registrationCipher.js';
import type { OutboundMessage, SegmentDefinition } from '../src/engagement/domain/types.js';
import { PgEngagementRepository } from '../src/engagement/infrastructure/pgEngagementRepository.js';
import { PgShopifyCatalogEventProcessor } from '../src/engagement/infrastructure/pgShopifyCatalogEventProcessor.js';

const adminUrl = process.env.WP01_PG_ADMIN_URL ?? `postgres://${process.env.USER}@localhost:5432/postgres`;
const admin = new pg.Client({ connectionString: adminUrl });
let available = false;
try { await admin.connect(); available = true; } catch { /* optional local run */ }
if (!available && (process.env.CI || process.env.REQUIRE_POSTGRES_TESTS === '1')) {
  throw new Error('PostgreSQL required');
}
const database = `monetta_product_keys_${randomUUID().replaceAll('-', '')}`;
const migrations = new URL('../src/db/migrations/', import.meta.url);
const repairSql = readFileSync(new URL('017_notification_product_keys.sql', migrations), 'utf8');
const now = new Date('2026-10-29T12:00:00Z');
const key = (id: number) => `shopify:gid://shopify/Product/${id}`;

describe.skipIf(!available)('notification product keys in PostgreSQL', () => {
  let pool: pg.Pool;
  let repository: PgEngagementRepository;
  let service: EngagementService;
  let sent: OutboundMessage[];

  beforeAll(async () => {
    await admin.query(`CREATE DATABASE ${database}`);
    const url = new URL(adminUrl); url.pathname = `/${database}`;
    pool = new pg.Pool({ connectionString: url.toString() });
    for (const file of readdirSync(migrations).filter((f) => f.endsWith('.sql')).sort()) {
      await pool.query(readFileSync(new URL(file, migrations), 'utf8'));
    }
  }, 60_000);

  afterAll(async () => {
    if (pool) await pool.end();
    await admin.query(`DROP DATABASE IF EXISTS ${database}`);
    await admin.end();
  });

  beforeEach(async () => {
    await pool.query(`TRUNCATE device_installations, notification_campaigns,
      shopify_product_notification_snapshots, catalog_events CASCADE`);
    await pool.query('UPDATE automation_rules SET enabled = FALSE');
    repository = new PgEngagementRepository(pool, RegistrationCipher.fromSecret('local-product-key-test'));
    sent = [];
    service = new EngagementService(repository, {
      async validate() {},
      async send(_registrationId, message) {
        sent.push(message);
        return { outcome: 'accepted', providerMessageId: `test-${message.deliveryId}` };
      },
    }, () => now);
    await service.registerInstallation({
      deviceId: 'test-device', platform: 'ios', locale: 'es-MX', timezone: 'UTC',
      appVersion: '1.0', existingCredential: null,
    });
    await service.registerPushEndpoint({
      deviceId: 'test-device', registrationKind: 'token', registrationId: 'local-token', permissionState: 'granted',
    });
    await service.updatePreferences({
      deviceId: 'test-device', productAlerts: true, personalizedOffers: true, announcements: true,
      quietStart: 21, quietEnd: 9, policyVersion: 'test', source: 'settings',
    });
  });

  async function repair() {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(repairSql);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  it('previews each audience in PostgreSQL and excludes stale push endpoints', async () => {
    await service.syncInterestProfile({
      deviceId: 'test-device', profileVersion: 1, generatedAt: now,
      topBrands: [{ key: 'coach', score: 90 }], topCategories: [{ key: 'bolsas', score: 80 }],
      priceBand: null, intentTier: 'high', signalCountBucket: '10_24',
    });
    const segments: SegmentDefinition[] = [
      { kind: 'all' }, { kind: 'brand', value: 'coach', minimumScore: 60 },
      { kind: 'category', value: 'bolsas', minimumScore: 60 }, { kind: 'high_intent' },
      { kind: 'device', value: 'test-device' },
    ];
    for (const segment of segments) {
      expect(await repository.previewAudience(segment, 'personalized_offers', now)).toBe(1);
    }
    await pool.query("UPDATE push_endpoints SET token_updated_at = $1::timestamptz - interval '61 days'", [now]);
    expect(await repository.previewAudience({ kind: 'all' }, 'announcements', now)).toBe(0);
  });

  it('repairs legacy data, keeps the latest opt-outs/baselines, and fixes already queued links', async () => {
    await pool.query(`INSERT INTO shopify_product_notification_snapshots
      (product_key, title, price, available, updated_at) VALUES
      ('shopify:1', 'Old', 100, FALSE, '2026-10-28'),
      ($1, 'New canonical', 80, TRUE, '2026-10-29'),
      ('shopify:2', 'New legacy', 70, TRUE, '2026-10-29'),
      ($2, 'Old canonical', 100, FALSE, '2026-10-28'),
      ('shopify:3', 'Legacy only', 50, FALSE, '2026-10-29')`, [key(1), key(2)]);
    for (const id of [1, 2]) {
      for (const productKey of [`shopify:${id}`, key(id)]) {
        const latest = id === 1 ? productKey === key(id) : productKey === `shopify:${id}`;
        const alertId = await repository.upsertProductAlert({
          id: randomUUID(), deviceId: 'test-device', productKey, kind: 'restock',
          now: new Date(latest ? '2026-10-29T10:00:00Z' : '2026-10-28T10:00:00Z'),
        });
        if (latest) await pool.query('UPDATE product_alerts SET active = FALSE WHERE id = $1', [alertId]);
      }
    }
    const preservedAlertId = await repository.upsertProductAlert({
      id: randomUUID(), deviceId: 'test-device', productKey: 'shopify:3', kind: 'restock', now,
    });
    const campaign = await service.createCampaign({
      kind: 'restock', purpose: 'product_alerts', title: 'Volvió', body: 'Producto', imageUrl: null,
      route: { type: 'product', productKey: 'shopify:3' },
      segment: { kind: 'product_alert', value: 'shopify:3', alertKind: 'restock' }, createdBy: 'test',
    });
    await repository.scheduleCampaign(campaign.id, now, 'test', now);
    expect(await repository.materializeDueCampaigns(now)).toBe(1);
    await repository.recordCatalogEvent({
      eventId: 'legacy-event', eventType: 'catalog.product.restocked', source: 'shopify_webhook',
      productKey: 'shopify:3', occurredAt: now, before: { available: false }, after: { available: true },
    });

    await repair();
    await repair(); // Also safe to rerun during recovery.

    expect((await pool.query(`SELECT product_key, title FROM shopify_product_notification_snapshots
      ORDER BY product_key`)).rows).toEqual([
      { product_key: key(1), title: 'New canonical' },
      { product_key: key(2), title: 'New legacy' },
      { product_key: key(3), title: 'Legacy only' },
    ]);
    expect((await pool.query('SELECT product_key, active FROM product_alerts ORDER BY product_key')).rows).toEqual([
      { product_key: key(1), active: false }, { product_key: key(2), active: false },
      // Materializing the queued restock already consumed this one-shot alert.
      { product_key: key(3), active: false },
    ]);
    expect((await pool.query('SELECT id FROM product_alerts WHERE product_key = $1', [key(3)])).rows[0]?.id)
      .toBe(preservedAlertId);
    expect(await repository.getCampaign(campaign.id)).toMatchObject({
      route: { type: 'product', productKey: key(3) },
      segment: { kind: 'product_alert', value: key(3), alertKind: 'restock' },
    });
    expect((await pool.query('SELECT event_id, product_key FROM catalog_events')).rows).toEqual([
      { event_id: 'legacy-event', product_key: key(3) },
    ]);
    expect(await service.dispatchOnce()).toEqual({ materialized: 0, processed: 1 });
    expect(sent[0]?.route).toEqual({ type: 'product', productKey: key(3) });
  });

  it('matches a webhook restock to a GID subscription and sends Product GIDs for price drops too', async () => {
    await service.createProductAlert({ deviceId: 'test-device', productKey: key(123), kind: 'restock' });
    await service.syncInterestProfile({
      deviceId: 'test-device', profileVersion: 1, generatedAt: now,
      topBrands: [{ key: 'coach', score: 90 }], topCategories: [], priceBand: null,
      intentTier: 'high', signalCountBucket: '10_24',
    });
    await pool.query("UPDATE automation_rules SET enabled = TRUE WHERE key IN ('restock', 'price_drop')");
    const processor = new PgShopifyCatalogEventProcessor(pool, service);
    await processor.process('products/create', 'created', {
      id: 123, title: 'Bolsa Coach', vendor: 'Coach', updated_at: '2026-10-29T11:00:00Z',
      variants: [{ price: '100', inventory_quantity: 0 }],
    });
    await processor.process('products/update', 'updated', {
      id: 123, title: 'Bolsa Coach', vendor: 'Coach', updated_at: now.toISOString(),
      variants: [{ price: '80', inventory_quantity: 5 }],
    });

    expect(await service.dispatchOnce()).toEqual({ materialized: 2, processed: 2 });
    expect(sent.map((message) => message.source).sort()).toEqual(['price_drop', 'restock']);
    expect(sent.every((message) => message.route.type === 'product' && message.route.productKey === key(123))).toBe(true);
    expect((await pool.query('SELECT product_key FROM shopify_product_notification_snapshots')).rows)
      .toEqual([{ product_key: key(123) }]);
  });
});

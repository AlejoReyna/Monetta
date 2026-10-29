import { createHmac, randomUUID } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import type { Server } from 'node:http';
import pg from 'pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/api/server.js';
import { PgWebhookEventsRepository } from '../src/db/pgWebhookEventsRepository.js';
import { EngagementService } from '../src/engagement/application/engagementService.js';
import { RegistrationCipher } from '../src/engagement/crypto/registrationCipher.js';
import type { MessagingProvider } from '../src/engagement/domain/ports.js';
import type { OutboundMessage, SendResult } from '../src/engagement/domain/types.js';
import { PgEngagementRepository } from '../src/engagement/infrastructure/pgEngagementRepository.js';
import { PgShopifyCatalogEventProcessor } from '../src/engagement/infrastructure/pgShopifyCatalogEventProcessor.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
} from './support/inMemoryRepositories.js';

const adminUrl = process.env.WP01_PG_ADMIN_URL ?? `postgres://${process.env.USER}@localhost:5432/postgres`;
const admin = new pg.Client({ connectionString: adminUrl });
let available = false;
try { await admin.connect(); available = true; } catch { /* optional local run */ }
if (!available && (process.env.CI || process.env.REQUIRE_POSTGRES_TESTS === '1')) throw new Error('PostgreSQL required');

const migrationsDir = new URL('../src/db/migrations/', import.meta.url);
const migrationFiles = readdirSync(migrationsDir).filter((file) => file.endsWith('.sql')).sort();
const canonicalMigration = '016_canonical_shopify_product_keys.sql';
const webhookSecret = 'product-key-webhook-secret';
const gidKey = 'shopify:gid://shopify/Product/123';

class FakeMessagingProvider implements MessagingProvider {
  readonly sent: OutboundMessage[] = [];

  async validate(_message: OutboundMessage) {}

  async send(_registrationId: string, message: OutboundMessage): Promise<SendResult> {
    this.sent.push(message);
    return { outcome: 'accepted', providerMessageId: `fcm-${message.deliveryId}` };
  }
}

async function createDatabase(prefix: string): Promise<{ name: string; pool: pg.Pool }> {
  const name = `${prefix}_${randomUUID().replaceAll('-', '')}`;
  await admin.query(`CREATE DATABASE ${name}`);
  const url = new URL(adminUrl);
  url.pathname = `/${name}`;
  return { name, pool: new pg.Pool({ connectionString: url.toString() }) };
}

async function applyMigrations(pool: pg.Pool, files: readonly string[]): Promise<void> {
  for (const file of files) await pool.query(readFileSync(new URL(file, migrationsDir), 'utf8'));
}

describe.skipIf(!available)('Shopify product keys (PostgreSQL)', () => {
  const databases: Array<{ name: string; pool: pg.Pool }> = [];

  afterAll(async () => {
    for (const database of databases) {
      await database.pool.end();
      await admin.query(`DROP DATABASE IF EXISTS ${database.name}`);
    }
    await admin.end();
  });

  describe('restock from a numeric-id Shopify webhook', () => {
    let pool: pg.Pool;
    let server: Server;
    let baseUrl: string;
    let service: EngagementService;
    let messaging: FakeMessagingProvider;

    beforeAll(async () => {
      const database = await createDatabase('monetta_product_keys');
      databases.push(database);
      pool = database.pool;
      await applyMigrations(pool, migrationFiles);
      await pool.query(`UPDATE automation_rules SET enabled = TRUE WHERE key = 'restock'`);

      const now = () => new Date('2026-08-25T12:00:00Z');
      messaging = new FakeMessagingProvider();
      service = new EngagementService(
        new PgEngagementRepository(pool, RegistrationCipher.fromSecret('product-key-cipher-secret')),
        messaging,
        now,
      );
      const app = createApp({
        appAccounts: new InMemoryAppAccountsRepository(),
        customers: new InMemoryCustomersRepository(),
        orders: new InMemoryOrdersRepository(),
        pushTokens: new InMemoryPushTokensRepository(),
        webhookEvents: new PgWebhookEventsRepository(pool),
        webhookSecret,
        customerTokenVerifier: { resolveCustomerId: async () => null },
        catalogEvents: new PgShopifyCatalogEventProcessor(pool, service),
        engagement: {
          service,
          appCheck: { verify: async (token) => token === 'valid-app-check-token-value' },
          ownerAuthorizer: { authenticate: async () => null },
          internalCatalogEventSecret: '',
          now,
        },
      });
      await new Promise<void>((resolve) => {
        server = app.listen(0, '127.0.0.1', resolve);
      });
      const address = server.address();
      if (address === null || typeof address === 'string') throw new Error('no address');
      baseUrl = `http://127.0.0.1:${address.port}`;
    }, 60_000);

    afterAll(async () => {
      if (server) await new Promise<void>((resolve) => server.close(() => resolve()));
    });

    it('notifies a GID-form alert and routes the push to the GID key', async () => {
      await subscribedDevice(gidKey);

      expect((await productWebhook('products/create', 0)).status).toBe(200);
      expect((await productWebhook('products/update', 4)).status).toBe(200);

      const snapshots = await pool.query<{ product_key: string }>(
        'SELECT product_key FROM shopify_product_notification_snapshots',
      );
      expect(snapshots.rows).toEqual([{ product_key: gidKey }]);

      const campaigns = await pool.query<{
        id: string;
        route: unknown;
        segment_definition: unknown;
      }>(`SELECT id, route, segment_definition FROM notification_campaigns WHERE kind = 'restock'`);
      expect(campaigns.rows).toHaveLength(1);
      const campaign = campaigns.rows[0]!;
      expect(campaign.route).toEqual({ type: 'product', productKey: gidKey });
      expect(campaign.segment_definition).toEqual({
        kind: 'product_alert',
        value: gidKey,
        alertKind: 'restock',
      });
      expect(await service.repository.previewAudience(
        { kind: 'product_alert', value: gidKey, alertKind: 'restock' },
        'product_alerts',
        new Date('2026-08-25T12:00:00Z'),
      )).toBe(1);

      expect(await service.dispatchOnce()).toEqual({ materialized: 1, processed: 1 });
      expect(messaging.sent).toHaveLength(1);
      expect(messaging.sent[0]).toMatchObject({
        campaignId: campaign.id,
        source: 'restock',
        route: { type: 'product', productKey: gidKey },
      });
      const alerts = await pool.query<{ product_key: string; active: boolean }>(
        'SELECT product_key, active FROM product_alerts',
      );
      expect(alerts.rows).toEqual([{ product_key: gidKey, active: false }]);
    });

    async function subscribedDevice(productKey: string): Promise<void> {
      const registered = await fetch(`${baseUrl}/v1/device-installations`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Firebase-AppCheck': 'valid-app-check-token-value' },
        body: JSON.stringify({
          deviceId: 'device-gid',
          platform: 'ios',
          locale: 'es-MX',
          // 12:00Z stays outside the 21–9 quiet hours below.
          timezone: 'UTC',
          appVersion: '0.1.0',
        }),
      });
      expect(registered.status).toBe(201);
      const { credential } = await registered.json() as { credential: string };
      const headers = { Authorization: `Device ${credential}`, 'Content-Type': 'application/json' };
      expect((await fetch(`${baseUrl}/v1/device-installations/me/push-endpoint`, {
        method: 'PUT',
        headers,
        body: JSON.stringify({ registrationId: 'fcm-token-gid', permissionState: 'granted' }),
      })).status).toBe(200);
      expect((await fetch(`${baseUrl}/v1/device-installations/me/preferences`, {
        method: 'PUT',
        headers,
        body: JSON.stringify({
          productAlerts: true,
          personalizedOffers: false,
          announcements: false,
          quietStart: 21,
          quietEnd: 9,
          policyVersion: '2026-08-25',
          source: 'product_alert',
        }),
      })).status).toBe(200);
      const alert = await fetch(`${baseUrl}/v1/product-alerts`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ productKey, kind: 'restock' }),
      });
      expect(alert.status).toBe(201);
    }

    function productWebhook(topic: 'products/create' | 'products/update', inventory: number) {
      // Shopify REST webhooks carry the numeric product id, never the GID.
      const body = JSON.stringify({
        id: 123,
        title: 'Bolsa Coach',
        vendor: 'Coach',
        product_type: 'Crossbody',
        updated_at: '2026-08-25T11:30:00Z',
        variants: [{ price: '3200.00', inventory_quantity: inventory }],
      });
      return fetch(`${baseUrl}/webhooks/${topic}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Webhook-Id': randomUUID(),
          'X-Shopify-Hmac-Sha256': createHmac('sha256', webhookSecret).update(body).digest('base64'),
        },
        body,
      });
    }
  });

  describe(canonicalMigration, () => {
    it('rewrites stored numeric keys and keeps the latest row when both forms exist', async () => {
      const database = await createDatabase('monetta_product_key_migration');
      databases.push(database);
      const { pool } = database;
      await applyMigrations(pool, migrationFiles.filter((file) => file < canonicalMigration));

      await pool.query(
        `INSERT INTO device_installations (device_id, device_credential_hash, platform, app_version)
         VALUES ('device-a', 'hash-a', 'ios', '0.1.0'),
                ('device-b', 'hash-b', 'ios', '0.1.0'),
                ('device-c', 'hash-c', 'ios', '0.1.0')`,
      );
      await pool.query(
        `INSERT INTO product_alerts (id, device_id, product_key, kind, active, updated_at)
         VALUES ('00000000-0000-4000-8000-00000000000a', 'device-a', 'shopify:123', 'restock', TRUE, '2026-08-01'),
                ('00000000-0000-4000-8000-00000000000d', 'device-a', 'shopify:123', 'price_drop', TRUE, '2026-08-01'),
                ('00000000-0000-4000-8000-00000000000e', 'device-a', 'shopify:gid://shopify/Product/456', 'restock', TRUE, '2026-08-01'),
                ('00000000-0000-4000-8000-0000000000b1', 'device-b', 'shopify:123', 'restock', TRUE, '2026-08-02'),
                ('00000000-0000-4000-8000-0000000000b2', 'device-b', 'shopify:gid://shopify/Product/123', 'restock', FALSE, '2026-08-01'),
                ('00000000-0000-4000-8000-0000000000c1', 'device-c', 'shopify:123', 'restock', FALSE, '2026-08-01'),
                ('00000000-0000-4000-8000-0000000000c2', 'device-c', 'shopify:gid://shopify/Product/123', 'restock', TRUE, '2026-08-03')`,
      );
      await pool.query(
        `INSERT INTO shopify_product_notification_snapshots (product_key, title, available, updated_at)
         VALUES ('shopify:123', 'Numeric newer', TRUE, '2026-08-02'),
                ('shopify:gid://shopify/Product/123', 'GID older', FALSE, '2026-08-01'),
                ('shopify:789', 'Numeric only', FALSE, '2026-08-01')`,
      );
      await pool.query(
        `INSERT INTO catalog_events (event_id, event_type, source, product_key, payload, occurred_at)
         VALUES ('shopify:webhook-1:catalog.product.restocked', 'catalog.product.restocked',
                 'shopify_webhook', 'shopify:123', '{}'::jsonb, '2026-08-01')`,
      );
      await pool.query(
        `INSERT INTO notification_campaigns
           (id, kind, purpose, status, title, body, route, segment_definition, created_by)
         VALUES ('00000000-0000-4000-8000-000000000101', 'restock', 'product_alerts', 'complete', 't', 'b',
                 '{"type": "product", "productKey": "shopify:123"}',
                 '{"kind": "product_alert", "value": "shopify:123", "alertKind": "restock"}', 'automation:restock'),
                ('00000000-0000-4000-8000-000000000102', 'manual', 'announcements', 'draft', 't', 'b',
                 '{"type": "home"}', '{"kind": "all"}', 'owner:1')`,
      );

      await applyMigrations(pool, [canonicalMigration]);

      const alerts = await pool.query<{ id: string; device_id: string; product_key: string; kind: string; active: boolean }>(
        'SELECT id, device_id, product_key, kind, active FROM product_alerts ORDER BY id',
      );
      expect(alerts.rows).toEqual([
        { id: '00000000-0000-4000-8000-00000000000a', device_id: 'device-a', product_key: gidKey, kind: 'restock', active: true },
        { id: '00000000-0000-4000-8000-00000000000d', device_id: 'device-a', product_key: gidKey, kind: 'price_drop', active: true },
        {
          id: '00000000-0000-4000-8000-00000000000e',
          device_id: 'device-a',
          product_key: 'shopify:gid://shopify/Product/456',
          kind: 'restock',
          active: true,
        },
        { id: '00000000-0000-4000-8000-0000000000b1', device_id: 'device-b', product_key: gidKey, kind: 'restock', active: true },
        { id: '00000000-0000-4000-8000-0000000000c2', device_id: 'device-c', product_key: gidKey, kind: 'restock', active: true },
      ]);
      const snapshots = await pool.query<{ product_key: string; title: string }>(
        'SELECT product_key, title FROM shopify_product_notification_snapshots ORDER BY product_key',
      );
      expect(snapshots.rows).toEqual([
        { product_key: gidKey, title: 'Numeric newer' },
        { product_key: 'shopify:gid://shopify/Product/789', title: 'Numeric only' },
      ]);
      const events = await pool.query<{ product_key: string }>('SELECT product_key FROM catalog_events');
      expect(events.rows).toEqual([{ product_key: gidKey }]);
      const campaigns = await pool.query<{ route: unknown; segment_definition: unknown }>(
        'SELECT route, segment_definition FROM notification_campaigns ORDER BY id',
      );
      expect(campaigns.rows).toEqual([
        {
          route: { type: 'product', productKey: gidKey },
          segment_definition: { kind: 'product_alert', value: gidKey, alertKind: 'restock' },
        },
        { route: { type: 'home' }, segment_definition: { kind: 'all' } },
      ]);
    }, 60_000);
  });
});

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createHash, createHmac, randomUUID } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import pg from 'pg';
import { PgWebhookEventsRepository, WebhookBusyError } from '../src/db/pgWebhookEventsRepository.js';
import { createApp } from '../src/api/server.js';
import { PgAppAccountsRepository } from '../src/db/pgAppAccountsRepository.js';
import { PgOrdersRepository } from '../src/db/pgOrdersRepository.js';
import { PgCustomersRepository } from '../src/db/pgCustomersRepository.js';
import { handleOrdersWebhook } from '../src/webhooks/handlers.js';
import { InMemoryPushTokensRepository } from './support/inMemoryRepositories.js';

const adminUrl = process.env.WP01_PG_ADMIN_URL ?? `postgres://${process.env.USER}@localhost:5432/postgres`;
const admin = new pg.Client({connectionString: adminUrl});
let available = false;
try { await admin.connect(); available = true; } catch { /* optional local run */ }
if (!available && (process.env.CI || process.env.REQUIRE_POSTGRES_TESTS === '1')) throw new Error('PostgreSQL required');
const name = `monetta_pr7_${randomUUID().replaceAll('-', '')}`;

describe.skipIf(!available)('R4 PostgreSQL recovery', () => {
  let pool: pg.Pool;
  let events: PgWebhookEventsRepository;
  beforeAll(async () => {
    await admin.query(`CREATE DATABASE ${name}`);
    const url = new URL(adminUrl); url.pathname = `/${name}`;
    pool = new pg.Pool({connectionString: url.toString()});
    const migrations = new URL('../src/db/migrations/', import.meta.url);
    for (const file of readdirSync(migrations).filter(f => f.endsWith('.sql')).sort()) {
      await pool.query(readFileSync(new URL(file, migrations), 'utf8'));
    }
    events = new PgWebhookEventsRepository(pool);
  }, 60_000);
  afterAll(async () => {
    if (pool) await pool.end();
    await admin.query(`DROP DATABASE IF EXISTS ${name}`);
    await admin.end();
  });

  it('busy signed HTTP delivery returns 503, completed delivery returns 200', async () => {
    const id = randomUUID();
    const payload = {id: 700, financial_status: 'paid'};
    const raw = Buffer.from(JSON.stringify(payload));
    const secret = 'local-test-webhook-secret';
    await events.tryClaim({webhookId:id,topic:'orders/create',shopifyResourceId:'700',payloadHash:createHash('sha256').update(raw).digest('hex'),shopDomain:'audit.myshopify.com'});
    const app = createApp({webhookEvents:new PgWebhookEventsRepository(pool),orders:new PgOrdersRepository(pool),
      customers:new PgCustomersRepository(pool),pushTokens:new InMemoryPushTokensRepository(),
      appAccounts:new PgAppAccountsRepository(pool),customerTokenVerifier:{async resolveCustomerId(){return null;}},
      webhookSecret:secret,expectedShopDomain:'audit.myshopify.com'});
    const server = await new Promise<import('node:http').Server>(resolve => {const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
    try {
      const address=server.address(); if (!address || typeof address === 'string') throw new Error('No listener');
      const deliver=()=>fetch(`http://127.0.0.1:${address.port}/webhooks/orders/create`,{method:'POST',body:raw,headers:{
        'Content-Type':'application/json','X-Shopify-Webhook-Id':id,'X-Shopify-Shop-Domain':'audit.myshopify.com',
        'X-Shopify-Hmac-Sha256':createHmac('sha256',secret).update(raw).digest('base64'),
      }});
      expect((await deliver()).status).toBe(503);
      await events.markFailed(id,'interrupted fixture');
      expect((await deliver()).status).toBe(200);
      expect((await deliver()).status).toBe(200);
      expect((await pool.query("SELECT count(*)::int AS n FROM orders_mirror WHERE shopify_order_id='700'")).rows[0].n).toBe(1);
    } finally { await new Promise<void>(resolve=>server.close(()=>resolve())); }
  });

  it('burst of deliveries does not exhaust the effects pool', async () => {
    const effectPool = new pg.Pool({...pool.options,max:1});
    try {
      const deps={webhookEvents:new PgWebhookEventsRepository(effectPool),orders:new PgOrdersRepository(effectPool),
        customers:new PgCustomersRepository(effectPool),pushTokens:new InMemoryPushTokensRepository()};
      await Promise.all(Array.from({length:8},(_,i)=>{
        const payload={id:800+i,financial_status:'paid'};
        return handleOrdersWebhook(deps,randomUUID(),'orders/create',payload,Buffer.from(JSON.stringify(payload)));
      }));
      expect((await effectPool.query("SELECT count(*)::int AS n FROM orders_mirror WHERE shopify_order_id IN ('800','801','802','803','804','805','806','807')")).rows[0].n).toBe(8);
    } finally {await effectPool.end();}
  });

  it('crashed claim: immediate retry fails, disconnect recovers, completed retry has one effect', async () => {
    const id = randomUUID();
    const payload = {id: 701, financial_status: 'paid', updated_at: '2026-09-07T12:00:00Z'};
    const body = Buffer.from(JSON.stringify(payload));
    expect(await events.tryClaim({webhookId: id, topic: 'orders/create', shopifyResourceId: '701', payloadHash: createHash('sha256').update(body).digest('hex')})).toBe(true);
    const deps = {webhookEvents: new PgWebhookEventsRepository(pool), orders: new PgOrdersRepository(pool),
      customers: new PgCustomersRepository(pool), pushTokens: new InMemoryPushTokensRepository()};
    await expect(handleOrdersWebhook(deps, id, 'orders/create', payload, body)).rejects.toBeInstanceOf(WebhookBusyError);
    expect((await pool.query("SELECT count(*)::int AS n FROM orders_mirror WHERE shopify_order_id='701'")).rows[0].n).toBe(0);
    // Terminate the actual PG session holding this event's advisory lock.
    await pool.query(`SELECT pg_terminate_backend(pid, 5000) FROM pg_locks WHERE locktype = 'advisory' AND database = (SELECT oid FROM pg_database WHERE datname = current_database())`);
    await handleOrdersWebhook(deps, id, 'orders/create', payload, body);
    await handleOrdersWebhook(deps, id, 'orders/create', payload, body);
    expect((await pool.query("SELECT count(*)::int AS n FROM orders_mirror WHERE shopify_order_id = '701'")).rows[0].n).toBe(1);
    expect((await pool.query('SELECT status FROM webhook_events WHERE webhook_id=$1', [id])).rows[0].status).toBe('completed');
    // The interrupted worker cannot complete through its dead connection.
    await expect(events.markCompleted(id)).rejects.toThrow();
  });

  it('concurrent duplicates, effect failure, retry and stale order update', async () => {
    const id = randomUUID();
    const payload = {id: 702, financial_status: 'refunded', updated_at: '2026-09-07T12:00:00Z'};
    const body = Buffer.from(JSON.stringify(payload));
    const orders = new PgOrdersRepository(pool);
    let release!: () => void;
    const gate = new Promise<void>(r => {release = r;});
    let entered!: () => void;
    const ready = new Promise<void>(r => {entered = r;});
    const deps = {webhookEvents: events, orders, customers: new PgCustomersRepository(pool), pushTokens: new InMemoryPushTokensRepository()};
    const original = orders.upsertByShopifyOrderId.bind(orders);
    orders.upsertByShopifyOrderId = async () => {entered(); await gate; throw new Error('effect failure');};
    const first = handleOrdersWebhook(deps, id, 'orders/updated', payload, body);
    const failed = expect(first).rejects.toThrow('effect failure');
    await ready;
    await expect(handleOrdersWebhook(deps, id, 'orders/updated', payload, body)).rejects.toBeInstanceOf(WebhookBusyError);
    release(); await failed;
    orders.upsertByShopifyOrderId = original;
    await handleOrdersWebhook(deps, id, 'orders/updated', payload, body);
    const old = {...payload, financial_status: 'paid', updated_at: '2026-09-06T12:00:00Z'};
    await handleOrdersWebhook(deps, randomUUID(), 'orders/updated', old, Buffer.from(JSON.stringify(old)));
    expect((await pool.query("SELECT financial_status FROM orders_mirror WHERE shopify_order_id='702'")).rows[0].financial_status).toBe('refunded');
    await handleOrdersWebhook(deps, id, 'orders/updated', payload, body);
    expect((await pool.query("SELECT count(*)::int AS n FROM orders_mirror WHERE shopify_order_id='702'")).rows[0].n).toBe(1);
  });

  it('persists checkout and cart tokens for the owning customer and keeps them across a later webhook', async () => {
    const indexes = await pool.query<{ indexname: string }>(
      `SELECT indexname FROM pg_indexes
       WHERE tablename = 'orders_mirror'
         AND indexname IN ('idx_orders_mirror_checkout_token', 'idx_orders_mirror_cart_token')`,
    );
    expect(indexes.rows.map((row) => row.indexname).sort()).toEqual([
      'idx_orders_mirror_cart_token',
      'idx_orders_mirror_checkout_token',
    ]);

    const orders = new PgOrdersRepository(pool);
    const customers = new PgCustomersRepository(pool);
    const deps = {
      webhookEvents: new PgWebhookEventsRepository(pool),
      orders,
      customers,
      pushTokens: new InMemoryPushTokensRepository(),
    };
    const checkoutToken = 'chk_pgowner77';
    const cartToken = 'crt_pgowner77';
    const otherCheckout = 'chk_pgother88';
    await handleOrdersWebhook(
      deps,
      randomUUID(),
      'orders/create',
      {
        id: 910,
        created_at: '2026-08-03T00:00:00Z',
        updated_at: '2026-08-03T00:00:00Z',
        checkout_token: `${checkoutToken}?key=not-a-stored-key`,
        cart_token: cartToken,
        customer: { id: 77, email: 'c@example.com' },
      },
      Buffer.from('pg-token-create'),
    );
    await handleOrdersWebhook(
      deps,
      randomUUID(),
      'orders/create',
      {
        id: 911,
        created_at: '2026-08-04T00:00:00Z',
        updated_at: '2026-08-04T00:00:00Z',
        checkout_token: otherCheckout,
        cart_token: 'crt_pgother88',
        customer: { id: 88, email: 'other@example.com' },
      },
      Buffer.from('pg-token-other'),
    );
    await handleOrdersWebhook(
      deps,
      randomUUID(),
      'orders/updated',
      {
        id: 910,
        financial_status: 'paid',
        updated_at: '2026-08-03T01:00:00Z',
        customer: { id: 77, email: 'c@example.com' },
      },
      Buffer.from('pg-token-update'),
    );

    const stored = await pool.query<{ checkout_token: string | null; cart_token: string | null }>(
      `SELECT checkout_token, cart_token FROM orders_mirror WHERE shopify_order_id = '910'`,
    );
    expect(stored.rows[0]).toEqual({ checkout_token: checkoutToken, cart_token: cartToken });
    const owned = await orders.listForCustomer('77');
    expect(owned.map((order) => order.shopifyOrderId)).toEqual(['910']);
    expect(owned[0]?.checkoutToken).toBe(checkoutToken);
    expect(owned[0]?.cartToken).toBe(cartToken);
    expect(JSON.stringify(owned)).not.toContain(otherCheckout);
    expect(JSON.stringify(stored.rows)).not.toContain('not-a-stored-key');
  });
});

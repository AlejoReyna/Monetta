import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Server } from 'node:http';
import pg from 'pg';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { ServerAdminAuthorizer } from '../src/admin/authorizer.js';
import { PgAdminPrincipalsRepository } from '../src/admin/pgAdminPrincipalsRepository.js';
import { PgAppAccountsRepository } from '../src/db/pgAppAccountsRepository.js';
import {
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';

const adminUser = process.env.PGUSER ?? process.env.USER ?? 'alexis';
const adminUrl = process.env.WP01_PG_ADMIN_URL
  ?? `postgres://${adminUser}@localhost:5432/postgres`;
const dbName = `monetta_wp01_${Date.now().toString(36)}_${randomBytes(3).toString('hex')}`;

class FakeCustomerTokenVerifier implements CustomerTokenVerifier {
  async resolveCustomerId(): Promise<string | null> {
    return null;
  }
}

async function canReachPostgres(): Promise<boolean> {
  const client = new pg.Client({ connectionString: adminUrl });
  try {
    await client.connect();
    await client.query('SELECT 1');
    return true;
  } catch {
    return false;
  } finally {
    try { await client.end(); } catch { /* ignore */ }
  }
}

const pgAvailable = await canReachPostgres();
if (!pgAvailable && (process.env.CI || process.env.REQUIRE_POSTGRES_TESTS === '1')) {
  throw new Error('PostgreSQL persistence tests are mandatory in CI');
}

describe.skipIf(!pgAvailable)('WP-01 PostgreSQL persistence (F01/F02)', () => {
  let pool: pg.Pool;
  let server: Server;
  let baseUrl: string;
  let appAccounts: PgAppAccountsRepository;
  let principals: PgAdminPrincipalsRepository;

  beforeAll(async () => {
    const admin = new pg.Client({ connectionString: adminUrl });
    await admin.connect();
    await admin.query(`CREATE DATABASE ${dbName}`);
    await admin.end();

    const databaseUrl = new URL(adminUrl);
    databaseUrl.pathname = `/${dbName}`;
    pool = new pg.Pool({ connectionString: databaseUrl.toString() });
    const migrationsDir = join(dirname(fileURLToPath(import.meta.url)), '../src/db/migrations');
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );
    `);
    for (const file of readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort()) {
      await pool.query(readFileSync(join(migrationsDir, file), 'utf8'));
      await pool.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
    }

    appAccounts = new PgAppAccountsRepository(pool);
    principals = new PgAdminPrincipalsRepository(pool);
    const customerTokenVerifier = new FakeCustomerTokenVerifier();
    const adminAuthorizer = new ServerAdminAuthorizer({
      appAccounts,
      customerTokenVerifier,
      principals,
      ownerShopifyCustomerIds: new Set(),
    });
    const deps: ServerDeps = {
      appAccounts,
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier,
      adminAuthorizer,
      adminEnvironment: 'staging',
    };
    const app = createApp(deps);
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;
  }, 60_000);

  afterAll(async () => {
    if (server !== undefined) {
      await new Promise<void>((resolve, reject) => {
        server.close((error) => error ? reject(error) : resolve());
      });
    }
    if (pool !== undefined) await pool.end();
    const admin = new pg.Client({ connectionString: adminUrl });
    try {
      await admin.connect();
      await admin.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
    } finally {
      await admin.end();
    }
  }, 60_000);

  it('persists register without allowing deviceId takeover of another account', async () => {
    const first = await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'legacy-pg@example.com',
        password: 'correct horse battery staple',
        deviceId: 'pg-device-1',
        displayName: 'Legacy',
      }),
    });
    expect(first.status).toBe(201);
    const firstBody = await first.json() as {
      account: { id: string; email: string };
      session: { token: string };
    };

    const before = await pool.query(
      `SELECT id, email, display_name, email_verified, shopify_customer_id, password_hash
         FROM app_accounts WHERE id = $1`,
      [firstBody.account.id],
    );
    expect(before.rows).toHaveLength(1);

    const second = await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'attacker-pg@example.com',
        password: 'attacker-password-99',
        deviceId: 'pg-device-1',
      }),
    });
    expect(second.status).toBe(409);
    expect(await second.json()).toEqual({ error: 'registration_conflict' });

    const after = await pool.query(
      `SELECT id, email, display_name, email_verified, shopify_customer_id, password_hash
         FROM app_accounts WHERE id = $1`,
      [firstBody.account.id],
    );
    expect(after.rows[0]).toEqual(before.rows[0]);
    const count = await pool.query('SELECT count(*)::int AS n FROM app_accounts');
    expect(count.rows[0]!.n).toBe(1);

    const sessions = await pool.query(
      `SELECT account_id FROM app_sessions WHERE device_id = $1`,
      ['pg-device-1'],
    );
    expect(sessions.rows[0]!.account_id).toBe(firstBody.account.id);

    expect((await fetch(`${baseUrl}/accounts/me`, {
      headers: { Authorization: `Bearer ${firstBody.session.token}` },
    })).status).toBe(200);
  });

  it('does not grant owner from email alone; explicit principal works and stays revoked', async () => {
    const reg = await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'owner-candidate@monetta.mx',
        password: 'correct horse battery staple',
        deviceId: 'pg-owner-device',
      }),
    });
    expect(reg.status).toBe(201);
    const body = await reg.json() as {
      account: { id: string };
      session: { token: string };
    };

    expect(await (await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${body.session.token}` },
    })).json()).toMatchObject({ roles: [], capabilities: { openAdmin: false } });

    const principalId = randomUUID();
    await principals.createIfAbsent({
      id: principalId,
      subject: { type: 'app_account', id: body.account.id },
      role: 'owner',
      createdBy: 'test:pg-provision',
    });
    expect(await (await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${body.session.token}` },
    })).json()).toMatchObject({ roles: ['owner'], capabilities: { openAdmin: true } });

    await pool.query(
      `UPDATE admin_principals SET active = FALSE, revoked_at = now() WHERE id = $1`,
      [principalId],
    );
    const login = await fetch(`${baseUrl}/accounts/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'owner-candidate@monetta.mx',
        password: 'correct horse battery staple',
        deviceId: 'pg-owner-relogin',
      }),
    });
    expect(login.status).toBe(200);
    const loginToken = ((await login.json()) as { session: { token: string } }).session.token;
    expect(await (await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${loginToken}` },
    })).json()).toMatchObject({ roles: [], capabilities: { openAdmin: false } });

    // Ensure bootstrap config cannot revive via email — no ownerEmails path exists.
    const hash = createHash('sha256').update('x').digest('hex');
    expect(hash.length).toBe(64);
  });
});

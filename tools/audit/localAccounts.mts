/** Disposable PostgreSQL personas using the real registration/login HTTP path.
 * Run with services/accounts_orders/node_modules/.bin/tsx tools/audit/localAccounts.mts
 * Never reads services/accounts_orders/.env or connects to shared databases.
 */
import { createRequire } from 'node:module';
import { randomBytes, randomUUID } from 'node:crypto';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { createApp } from '../../services/accounts_orders/src/api/server.js';
import { PgAppAccountsRepository } from '../../services/accounts_orders/src/db/pgAppAccountsRepository.js';
import { PgCustomersRepository } from '../../services/accounts_orders/src/db/pgCustomersRepository.js';
import { PgOrdersRepository } from '../../services/accounts_orders/src/db/pgOrdersRepository.js';
import { PgPushTokensRepository } from '../../services/accounts_orders/src/db/pgPushTokensRepository.js';
import { PgWebhookEventsRepository } from '../../services/accounts_orders/src/db/pgWebhookEventsRepository.js';
import { PgAdminPrincipalsRepository } from '../../services/accounts_orders/src/admin/pgAdminPrincipalsRepository.js';
import { ServerAdminAuthorizer } from '../../services/accounts_orders/src/admin/authorizer.js';
import { generateAuditRunId, resourcePrefix } from './lib/runId.mjs';
import { emptyManifest, writeManifest, ensureRunDir } from './lib/manifest.mjs';
const require = createRequire(new URL('../../services/accounts_orders/package.json', import.meta.url));
const {default: pg} = await import(require.resolve('pg'));
const url = new URL(process.env.WP01_PG_ADMIN_URL ?? `postgres://${process.env.USER}@localhost:5432/postgres`);
if (!['localhost','127.0.0.1','[::1]'].includes(url.hostname)) throw new Error('Local PostgreSQL only');
const runId = generateAuditRunId();
const dbName = `monetta_audit_${runId.replaceAll('-', '_')}`;
const admin = new pg.Client({connectionString: url.toString()});
await admin.connect();
await admin.query(`CREATE DATABASE ${dbName}`);
url.pathname = `/${dbName}`;
const pool = new pg.Pool({connectionString: url.toString()});
let server;
try {
  const dir = new URL('../../services/accounts_orders/src/db/migrations/', import.meta.url);
  for (const name of (await readdir(dir)).filter(n => n.endsWith('.sql')).sort()) await pool.query(await readFile(new URL(name, dir), 'utf8'));
  const accounts = new PgAppAccountsRepository(pool);
  const principals = new PgAdminPrincipalsRepository(pool);
  const customerTokenVerifier = {async resolveCustomerId() {return null;}};
  const authorizer = new ServerAdminAuthorizer({appAccounts: accounts, principals, customerTokenVerifier, ownerShopifyCustomerIds: new Set()});
  const app = createApp({appAccounts: accounts, customers: new PgCustomersRepository(pool), orders: new PgOrdersRepository(pool),
    pushTokens: new PgPushTokensRepository(pool), webhookEvents: new PgWebhookEventsRepository(pool),
    webhookSecret: randomBytes(32).toString('hex'), customerTokenVerifier, adminAuthorizer: authorizer,
    adminEnvironment: 'staging', legacyAccountRegistrationEnabled: true});
  server = await new Promise<any>(resolve => {const s = app.listen(0, '127.0.0.1', () => resolve(s));});
  const base = `http://127.0.0.1:${server.address().port}`;
  const manifest = emptyManifest({runId, prefix: resourcePrefix(runId), environment: 'local-disposable-pg', expectedShopId: null});
  for (const code of ['L','U','E','O','R']) {
    const email = `${code.toLowerCase()}-${runId}@example.invalid`;
    const password = randomBytes(24).toString('base64url');
    const deviceId = `${runId}-${code}`;
    const register = await fetch(`${base}/accounts/register`, {method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({email,password,deviceId})});
    if (register.status !== 201) throw new Error(`Registration failed for ${code}: ${register.status}`);
    const account = (await register.json()).account;
    const login = await fetch(`${base}/accounts/login`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({email,password,deviceId})});
    if (!login.ok) throw new Error(`Login failed for ${code}`);
    const session = (await login.json()).session;
    if (['O','R'].includes(code)) {
      await pool.query("INSERT INTO admin_principals (id,subject_type,subject_id,role,active,created_by) VALUES ($1,'app_account',$2,'owner',true,$3)", [randomUUID(), account.id, runId]);
    }
    const adminRequest = () => fetch(`${base}/admin/me`, {headers:{Authorization:`Bearer ${session.token}`}});
    const before = await adminRequest();
    if (before.status !== 200 || (await before.json()).capabilities.manageProducts !== ['O','R'].includes(code)) throw new Error(`Incorrect capabilities for ${code}`);
    if (!['O','R'].includes(code) && (await fetch(`${base}/admin/products`, {headers:{Authorization:`Bearer ${session.token}`}})).status !== 403) throw new Error('Ordinary user accessed admin products');
    if (code === 'R') {
      await pool.query('UPDATE admin_principals SET active=false, revoked_at=now() WHERE subject_id=$1 AND created_by=$2', [account.id,runId]);
      if ((await (await adminRequest()).json()).capabilities.manageProducts !== false) throw new Error('Revocation failed');
      if ((await fetch(`${base}/admin/products`, {headers:{Authorization:`Bearer ${session.token}`}})).status !== 403) throw new Error('Revoked owner accessed admin products');
    }
    manifest.resources.push({id:`persona:${code}`, kind:'persona', status:'created', local_id:account.id,
      meta:{registration:'HTTP 201',login:'HTTP 200',admin:code === 'O' ? 200 : 403}});
  }
  manifest.notes.push({event:'verified-local-registration-login-admin-revocation', hosted_shopify_auth:'NOT RUN', shopify_token_verifier:'disabled for isolated legacy path'});
  await writeManifest(runId,manifest);
  // Credentials are deliberately not persisted: these are disposable local journeys.
  console.log(JSON.stringify({runId,personas:5,registrationLogin:'PASS',authorizationRevocation:'PASS',environment:'local-disposable-pg'}));
} finally {
  if (server) await new Promise<void>(r => server.close(() => r()));
  await pool.end();
  await admin.query(`DROP DATABASE ${dbName}`);
  await admin.end();
}

import type { Server } from 'node:http';
import express from 'express';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { ServerAdminAuthorizer } from '../src/admin/authorizer.js';
import { ShopifySessionTokenVerifier } from '../src/admin/shopifySessionToken.js';
import type { AdminPrincipalRecord } from '../src/admin/types.js';
import { EngagementService } from '../src/engagement/application/engagementService.js';
import { registerShopifyAdminPanel } from '../src/shopifyAdmin/routes.js';
import { InMemoryAdminPrincipalsRepository } from './support/inMemoryAdminPrincipalsRepository.js';
import { InMemoryEngagementRepository } from './support/inMemoryEngagementRepository.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import {
  signSessionToken,
  testClientId,
  testClientSecret,
  testShop,
} from './support/shopifySessionTokens.js';

const allowListedStaff = '74218901';

const campaignBody = {
  kind: 'manual',
  purpose: 'announcements',
  title: 'Nuevas llegadas',
  body: 'Conoce lo nuevo de Coach.',
  imageUrl: null,
  route: { type: 'home' },
  segment: { kind: 'all' },
};

function principal(type: AdminPrincipalRecord['type'], id: string, active: boolean): AdminPrincipalRecord {
  return {
    principalId: `principal-${type}-${id}`,
    type,
    id,
    role: 'owner',
    active,
    createdAt: new Date('2026-10-01T00:00:00Z'),
    createdBy: 'operator:test',
    revokedAt: active ? null : new Date('2026-10-02T00:00:00Z'),
  };
}

describe('Shopify Admin staff in the notifications panel', () => {
  let server: Server;
  let baseUrl: string;
  let principals: InMemoryAdminPrincipalsRepository;
  let appAccounts: InMemoryAppAccountsRepository;

  beforeEach(async () => {
    principals = new InMemoryAdminPrincipalsRepository();
    appAccounts = new InMemoryAppAccountsRepository();
    const adminAuthorizer = new ServerAdminAuthorizer({
      appAccounts,
      customerTokenVerifier: { resolveCustomerId: async () => null },
      principals,
      ownerShopifyCustomerIds: new Set(),
      shopifySessionTokens: new ShopifySessionTokenVerifier({
        clientId: testClientId,
        clientSecret: testClientSecret,
        shopDomain: testShop,
      }),
      ownerShopifyStaffIds: new Set([allowListedStaff]),
    });
    const deps: ServerDeps = {
      appAccounts,
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: testClientSecret,
      customerTokenVerifier: { resolveCustomerId: async () => null },
      adminAuthorizer,
      adminEnvironment: 'staging',
      engagement: {
        service: new EngagementService(new InMemoryEngagementRepository(), null),
        appCheck: { verify: async () => false },
        ownerAuthorizer: { authenticate: async () => null },
        adminAuthorizer,
        internalCatalogEventSecret: 'internal-catalog-test-secret-at-least-32',
      },
      shopifyAdminPanel: { clientId: testClientId, shopDomain: `https://${testShop}/` },
    };
    const app = createApp(deps);
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;
  });

  afterEach(async () => {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  });

  function createCampaign(token: string) {
    return fetch(`${baseUrl}/admin/notification-campaigns`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(campaignBody),
    });
  }

  function me(token: string) {
    return fetch(`${baseUrl}/admin/me`, { headers: { Authorization: `Bearer ${token}` } });
  }

  it('lets an allow-listed staff member send notifications and nothing else', async () => {
    const token = signSessionToken({ sub: allowListedStaff });

    const identity = await me(token);
    expect(identity.status).toBe(200);
    expect(await identity.json()).toMatchObject({
      actor: { provider: 'shopify_admin' },
      roles: ['owner'],
      capabilities: {
        openAdmin: false,
        manageProducts: false,
        manageStorefront: false,
        manageFeaturedCatalog: false,
        manageExternalSources: false,
        manageNotifications: true,
      },
      environment: 'staging',
    });
    expect(principals.rows.get(`shopify_staff:${allowListedStaff}`)).toMatchObject({
      active: true,
      createdBy: 'bootstrap:server-config',
    });

    const created = await createCampaign(token);
    expect(created.status).toBe(201);
    const { campaign } = await created.json() as { campaign: { id: string; createdBy: string } };
    expect(campaign.createdBy).toBe(principals.rows.get(`shopify_staff:${allowListedStaff}`)!.principalId);

    expect((await fetch(`${baseUrl}/admin/notification-campaigns/${campaign.id}/preview`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    })).status).toBe(200);
    expect((await fetch(`${baseUrl}/admin/notifications/overview`, {
      headers: { Authorization: `Bearer ${token}` },
    })).status).toBe(200);

    // The full control plane stays owner-only for this credential.
    expect((await fetch(`${baseUrl}/admin/audit`, {
      headers: { Authorization: `Bearer ${token}` },
    })).status).toBe(403);
    expect((await fetch(`${baseUrl}/admin/control-plane`, {
      headers: { Authorization: `Bearer ${token}` },
    })).status).toBe(403);
  });

  it('admits an explicitly provisioned staff member outside the allow-list', async () => {
    principals.rows.set('shopify_staff:555', principal('shopify_staff', '555', true));
    expect((await createCampaign(signSessionToken({ sub: '555' }))).status).toBe(201);
  });

  it('shows an unknown staff member their id without granting anything', async () => {
    const token = signSessionToken({ sub: '555' });
    const identity = await me(token);
    expect(identity.status).toBe(200);
    expect(await identity.json()).toMatchObject({
      actor: { id: 'shopify_staff:555', provider: 'shopify_admin' },
      roles: [],
      capabilities: { manageNotifications: false },
    });
    expect((await createCampaign(token)).status).toBe(403);
    expect(principals.rows.has('shopify_staff:555')).toBe(false);
  });

  it('never revives a revoked staff principal from the allow-list', async () => {
    principals.rows.set(
      `shopify_staff:${allowListedStaff}`,
      principal('shopify_staff', allowListedStaff, false),
    );
    expect((await createCampaign(signSessionToken({ sub: allowListedStaff }))).status).toBe(403);
    expect(principals.rows.get(`shopify_staff:${allowListedStaff}`)!.active).toBe(false);
  });

  it('rejects session tokens for another shop, another app, or past expiry', async () => {
    const tokens = [
      signSessionToken({
        sub: allowListedStaff,
        dest: 'https://monetta-2.myshopify.com',
        iss: 'https://monetta-2.myshopify.com/admin',
      }),
      signSessionToken({ sub: allowListedStaff, aud: 'another-app' }),
      signSessionToken({ sub: allowListedStaff }, { now: new Date(Date.now() - 5 * 60_000) }),
      signSessionToken({ sub: allowListedStaff }, { secret: 'not-the-app-secret' }),
    ];
    for (const token of tokens) {
      expect((await me(token)).status).toBe(401);
      expect((await createCampaign(token)).status).toBe(403);
    }
    expect(principals.rows.size).toBe(0);
  });

  it('serves the embedded page, framable only by this shop in Shopify Admin', async () => {
    const page = await fetch(`${baseUrl}/shopify/app?embedded=1&shop=${testShop}&host=abc`);
    expect(page.status).toBe(200);
    expect(page.headers.get('content-type')).toMatch(/^text\/html/);
    expect(page.headers.get('content-security-policy'))
      .toBe(`frame-ancestors https://${testShop} https://admin.shopify.com`);
    expect(page.headers.get('x-frame-options')).toBeNull();
    expect(page.headers.get('cache-control')).toBe('no-store');
    const html = await page.text();
    expect(html).toContain(`<meta name="shopify-api-key" content="${testClientId}">`);
    // App Bridge has to be the first script so it can hand out session tokens.
    expect(html.indexOf('app-bridge.js')).toBeLessThan(html.indexOf('panel.js'));

    const script = await fetch(`${baseUrl}/shopify/app/panel.js`);
    expect(script.status).toBe(200);
    expect(script.headers.get('content-type')).toMatch(/javascript/);
    expect(await script.text()).toContain('/admin/notification-campaigns');
    const styles = await fetch(`${baseUrl}/shopify/app/panel.css`);
    expect(styles.headers.get('content-type')).toMatch(/^text\/css/);
  });

  it('escapes the client id and refuses to serve without configuration', async () => {
    const app = express();
    registerShopifyAdminPanel(app, { clientId: '"><script>x</script>', shopDomain: testShop });
    const local = app.listen(0, '127.0.0.1');
    await new Promise<void>((resolve) => local.once('listening', resolve));
    const address = local.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    const html = await (await fetch(`http://127.0.0.1:${address.port}/shopify/app`)).text();
    await new Promise<void>((resolve) => local.close(() => resolve()));
    expect(html).toContain('content="&quot;&gt;&lt;script&gt;x&lt;/script&gt;"');
    expect(html).not.toContain('<script>x</script>');

    expect(() => registerShopifyAdminPanel(express(), { clientId: '', shopDomain: testShop })).toThrow();
    expect(() => registerShopifyAdminPanel(express(), {
      clientId: testClientId,
      shopDomain: 'shop.myshopify.com\r\nX-Injected: 1',
    })).toThrow();
  });

  it('keeps full access for a Monetta account owner', async () => {
    const registered = await fetch(`${baseUrl}/accounts/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'duena@example.com', password: 'owner-password-1', deviceId: 'owner-device' }),
    });
    expect(registered.status).toBe(201);
    const { account, session } = await registered.json() as {
      account: { id: string };
      session: { token: string };
    };
    principals.rows.set(`app_account:${account.id}`, principal('app_account', account.id, true));

    expect(await (await me(session.token)).json()).toMatchObject({
      actor: { provider: 'monetta' },
      capabilities: { openAdmin: true, manageNotifications: true },
    });
    expect((await createCampaign(session.token)).status).toBe(201);
    expect((await fetch(`${baseUrl}/admin/audit`, {
      headers: { Authorization: `Bearer ${session.token}` },
    })).status).not.toBe(403);
  });
});

import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp } from '../src/api/server.js';
import { ownerAdminCapabilities } from '../src/admin/authorizer.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';
import { InMemoryAdminAuditLogger } from './support/inMemoryMutationRepositories.js';

describe('admin audit projection', () => {
  let server: Server;
  let baseUrl: string;
  let audit: InMemoryAdminAuditLogger;

  beforeEach(async () => {
    audit = new InMemoryAdminAuditLogger();
    const app = createApp({
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier: { resolveCustomerId: async () => null },
      adminAuthorizer: {
        resolve: async () => null,
        authenticate: async (token: string) => token === 'owner-token'
          ? {
              id: 'principal-1',
              provider: 'monetta' as const,
              subject: { type: 'app_account' as const, id: 'account-1' },
              role: 'owner' as const,
            }
          : null,
      },
      audit,
      adminEnvironment: 'staging',
    });
    await audit.record({
      actor: {
        id: 'principal-1',
        provider: 'monetta',
        subject: { type: 'app_account', id: 'account-1' },
        role: 'owner',
      },
      requestId: 'req_audit_1',
      action: 'product.title.update',
      targetType: 'shopify_product',
      targetId: 'gid://shopify/Product/1',
      outcome: 'success',
    });
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

  it('returns bounded, opaque-cursor audit records only to owners', async () => {
    const denied = await fetch(`${baseUrl}/admin/audit`, {
      headers: { Authorization: 'Bearer shopper-token' },
    });
    expect(denied.status).toBe(403);

    const response = await fetch(`${baseUrl}/admin/audit?limit=1`, {
      headers: { Authorization: 'Bearer owner-token' },
    });
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.events).toHaveLength(1);
    expect(body.events[0]).toMatchObject({
      action: 'product.title.update',
      targetType: 'shopify_product',
      targetId: 'gid://shopify/Product/1',
      requestId: 'req_audit_1',
      outcome: 'success',
    });
    expect(body.events[0].id).not.toBe('1');
    expect(body.nextCursor).toBeTruthy();

    const page = await fetch(`${baseUrl}/admin/audit?cursor=${body.nextCursor}`, {
      headers: { Authorization: 'Bearer owner-token' },
    });
    expect(page.status).toBe(200);
    expect(await page.json()).toMatchObject({ events: [] });
  });
});

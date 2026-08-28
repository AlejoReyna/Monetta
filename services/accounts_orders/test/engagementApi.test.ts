import { createHmac } from 'node:crypto';
import type { Server } from 'node:http';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
import { EngagementService } from '../src/engagement/application/engagementService.js';
import type { MessagingProvider } from '../src/engagement/domain/ports.js';
import type { OutboundMessage, SendResult } from '../src/engagement/domain/types.js';
import { InMemoryEngagementRepository } from './support/inMemoryEngagementRepository.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

const internalSecret = 'internal-catalog-test-secret-at-least-32';

class FakeMessagingProvider implements MessagingProvider {
  readonly sent: Array<{ registrationId: string; message: OutboundMessage }> = [];

  async validate(_message: OutboundMessage) {}

  async send(registrationId: string, message: OutboundMessage): Promise<SendResult> {
    this.sent.push({ registrationId, message });
    return { outcome: 'accepted', providerMessageId: `fcm-${message.deliveryId}` };
  }
}

describe('engagement API', () => {
  let server: Server;
  let baseUrl: string;
  let repository: InMemoryEngagementRepository;
  let messaging: FakeMessagingProvider;
  let service: EngagementService;

  beforeEach(async () => {
    repository = new InMemoryEngagementRepository();
    messaging = new FakeMessagingProvider();
    service = new EngagementService(repository, messaging, () => new Date('2026-08-25T12:00:00Z'));
    const deps: ServerDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shopify-test-secret',
      customerTokenVerifier: { resolveCustomerId: async () => null },
      engagement: {
        service,
        appCheck: { verify: async (token) => token === 'valid-app-check-token-value' },
        ownerAuthorizer: {
          authenticate: async (token) => token === 'owner-token' ? { actorId: 'owner:1' } : null,
        },
        internalCatalogEventSecret: internalSecret,
        now: () => new Date('2026-08-25T12:00:00Z'),
      },
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

  it('requires App Check, issues a device credential, and prevents takeover', async () => {
    const denied = await registerDevice(null);
    expect(denied.status).toBe(401);

    const created = await registerDevice('valid-app-check-token-value');
    expect(created.status).toBe(201);
    const body = await created.json() as { credential: string };
    expect(body.credential.length).toBeGreaterThan(20);

    const takeover = await registerDevice('valid-app-check-token-value');
    expect(takeover.status).toBe(409);

    const refreshed = await registerDevice('valid-app-check-token-value', body.credential);
    expect(refreshed.status).toBe(200);
    const refreshedBody = await refreshed.json() as { credential: string };
    expect(refreshedBody.credential).not.toBe(body.credential);
  });

  it('registers permission, preferences, a reduced profile, and an explicit product alert', async () => {
    const credential = await deviceCredential();
    const authorization = { Authorization: `Device ${credential}`, 'Content-Type': 'application/json' };

    expect((await fetch(`${baseUrl}/v1/device-installations/me/push-endpoint`, {
      method: 'PUT',
      headers: authorization,
      body: JSON.stringify({
        registrationId: 'fcm-registration-token',
        registrationKind: 'token',
        permissionState: 'granted',
      }),
    })).status).toBe(200);

    expect((await fetch(`${baseUrl}/v1/device-installations/me/preferences`, {
      method: 'PUT',
      headers: authorization,
      body: JSON.stringify({
        productAlerts: true,
        personalizedOffers: true,
        announcements: false,
        quietStart: 21,
        quietEnd: 9,
        policyVersion: '2026-08-25',
        source: 'settings',
      }),
    })).status).toBe(200);

    const profile = await fetch(`${baseUrl}/v1/device-installations/me/interest-profile`, {
      method: 'PUT',
      headers: authorization,
      body: JSON.stringify({
        profileVersion: 1,
        generatedAt: '2026-08-25T12:00:00Z',
        topBrands: [{ key: 'coach', score: 82 }],
        topCategories: [{ key: 'crossbody', score: 71 }],
        priceBand: '2000_4000_mxn',
        intentTier: 'high',
        signalCountBucket: '10_24',
      }),
    });
    expect(profile.status).toBe(200);
    expect(repository.profiles.get('device-1')?.topBrands[0]).toEqual({ key: 'coach', score: 82 });

    const alert = await fetch(`${baseUrl}/v1/product-alerts`, {
      method: 'POST',
      headers: authorization,
      body: JSON.stringify({ productKey: 'shopify:123', kind: 'restock' }),
    });
    expect(alert.status).toBe(201);
    expect([...repository.alerts.values()][0]).toMatchObject({ productKey: 'shopify:123', active: true });
  });

  it('lets only the owner create, preview, schedule, and dispatch a campaign', async () => {
    const credential = await configuredDevice();
    expect(credential).not.toBe('');
    const campaignBody = {
      kind: 'manual',
      purpose: 'personalized_offers',
      title: 'Coach para ti',
      body: 'Descubre la nueva selección.',
      imageUrl: null,
      route: { type: 'product', productKey: 'shopify:123' },
      segment: { kind: 'brand', value: 'coach', minimumScore: 60 },
    };
    expect((await fetch(`${baseUrl}/admin/notification-campaigns`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer shopper-token' },
      body: JSON.stringify(campaignBody),
    })).status).toBe(403);

    const created = await fetch(`${baseUrl}/admin/notification-campaigns`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner-token' },
      body: JSON.stringify(campaignBody),
    });
    expect(created.status).toBe(201);
    const createdBody = await created.json() as { campaign: { id: string } };
    const id = createdBody.campaign.id;

    const preview = await fetch(`${baseUrl}/admin/notification-campaigns/${id}/preview`, {
      method: 'POST',
      headers: { Authorization: 'Bearer owner-token' },
    });
    expect(await preview.json()).toMatchObject({ eligible: 1 });

    expect((await fetch(`${baseUrl}/admin/notification-campaigns/${id}/schedule`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner-token' },
      body: JSON.stringify({ scheduledAt: '2026-08-25T12:00:00Z' }),
    })).status).toBe(202);

    expect(await service.dispatchOnce()).toEqual({ materialized: 1, processed: 1 });
    expect(messaging.sent).toHaveLength(1);
    expect(messaging.sent[0]).toMatchObject({ registrationId: 'fcm-token-1' });
  });

  it('verifies and deduplicates signed catalog events before creating restock campaigns', async () => {
    repository.rules.set('restock', { enabled: true, configuration: {} });
    await configuredDevice();
    const payload = JSON.stringify({
      eventId: 'event-1',
      eventType: 'catalog.product.restocked',
      source: 'shopify',
      productKey: 'shopify:123',
      occurredAt: '2026-08-25T12:00:00Z',
      before: { available: false },
      after: { available: true, title: 'Bolsa Coach' },
    });
    const timestamp = '2026-08-25T12:00:00.000Z';
    const signature = createHmac('sha256', internalSecret)
      .update(timestamp)
      .update('.')
      .update(payload)
      .digest('hex');
    const send = () => fetch(`${baseUrl}/internal/catalog-events`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Monetta-Timestamp': timestamp,
        'X-Monetta-Signature': signature,
      },
      body: payload,
    });
    expect((await send()).status).toBe(202);
    expect((await send()).status).toBe(200);
    expect([...repository.campaigns.values()].filter((item) => item.kind === 'restock')).toHaveLength(1);
  });

  function registerDevice(appCheck: string | null, credential?: string) {
    return fetch(`${baseUrl}/v1/device-installations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(appCheck === null ? {} : { 'X-Firebase-AppCheck': appCheck }),
        ...(credential === undefined ? {} : { Authorization: `Device ${credential}` }),
      },
      body: JSON.stringify({
        deviceId: 'device-1',
        platform: 'ios',
        locale: 'es-MX',
        timezone: 'America/Monterrey',
        appVersion: '0.1.0',
      }),
    });
  }

  async function deviceCredential() {
    const response = await registerDevice('valid-app-check-token-value');
    return (await response.json() as { credential: string }).credential;
  }

  async function configuredDevice() {
    const credential = await deviceCredential();
    const headers = { Authorization: `Device ${credential}`, 'Content-Type': 'application/json' };
    await fetch(`${baseUrl}/v1/device-installations/me/push-endpoint`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({ registrationId: 'fcm-token-1', permissionState: 'granted' }),
    });
    await fetch(`${baseUrl}/v1/device-installations/me/preferences`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        productAlerts: true,
        personalizedOffers: true,
        announcements: true,
        quietStart: 21,
        quietEnd: 9,
        policyVersion: '2026-08-25',
        source: 'settings',
      }),
    });
    await fetch(`${baseUrl}/v1/device-installations/me/interest-profile`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        profileVersion: 1,
        generatedAt: '2026-08-25T12:00:00Z',
        topBrands: [{ key: 'coach', score: 82 }],
        topCategories: [],
        priceBand: null,
        intentTier: 'high',
        signalCountBucket: '10_24',
      }),
    });
    await fetch(`${baseUrl}/v1/product-alerts`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ productKey: 'shopify:123', kind: 'restock' }),
    });
    return credential;
  }
});

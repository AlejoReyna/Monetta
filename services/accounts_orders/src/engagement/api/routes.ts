import type { Express, NextFunction, Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { EngagementService, parsePermissionState } from '../application/engagementService.js';
import type { AppCheckVerifier, OwnerAuthorizer } from '../domain/ports.js';
import type { AdminAuthorizer } from '../../admin/authorizer.js';
import type {
  CampaignKind,
  ConsentPurpose,
  InterestAffinity,
  IntentTier,
  NotificationRoute,
  ProductAlertKind,
  SegmentDefinition,
  SignalCountBucket,
} from '../domain/types.js';

export interface EngagementRouteDeps {
  readonly service: EngagementService;
  readonly appCheck: AppCheckVerifier;
  readonly ownerAuthorizer: OwnerAuthorizer;
  /** Shared control-plane authorization. The legacy field remains for callers not yet on WP-1. */
  readonly adminAuthorizer?: AdminAuthorizer;
  readonly now?: () => Date;
}

export function registerEngagementRoutes(app: Express, deps: EngagementRouteDeps): void {
  const now = deps.now ?? (() => new Date());

  app.post('/v1/device-installations', asyncRoute(async (req, res) => {
    if (!await deps.appCheck.verify(req.header('X-Firebase-AppCheck') ?? null)) {
      res.status(401).json({ error: 'invalid_app_attestation' });
      return;
    }
    const body = objectBody(req);
    const deviceId = shortString(body.deviceId, 200);
    const platform = body.platform === 'ios' || body.platform === 'android' ? body.platform : null;
    const locale = normalizedLocale(body.locale);
    const timezone = normalizedTimezone(body.timezone);
    const appVersion = shortString(body.appVersion, 40);
    if (deviceId === null || platform === null || appVersion === null) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const result = await deps.service.registerInstallation({
      deviceId,
      platform,
      locale,
      timezone,
      appVersion,
      existingCredential: deviceCredential(req),
    });
    if (result.outcome === 'conflict') {
      res.status(409).json({ error: 'installation_already_registered' });
      return;
    }
    res.status(result.outcome === 'created' ? 201 : 200).json({
      deviceId,
      credential: result.credential,
    });
  }));

  app.put('/v1/device-installations/me/push-endpoint', deviceRoute(deps, async (req, res, deviceId) => {
    const body = objectBody(req);
    const registrationId = shortString(body.registrationId, 4096);
    const permissionState = parsePermissionState(body.permissionState);
    const registrationKind = body.registrationKind === 'fid' ? 'fid' : 'token';
    if (registrationId === null || permissionState === null) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    await deps.service.registerPushEndpoint({
      deviceId,
      registrationKind,
      registrationId,
      permissionState,
    });
    res.status(200).json({ status: 'ok' });
  }));

  app.put('/v1/device-installations/me/preferences', deviceRoute(deps, async (req, res, deviceId) => {
    const body = objectBody(req);
    const productAlerts = booleanValue(body.productAlerts);
    const personalizedOffers = booleanValue(body.personalizedOffers);
    const announcements = booleanValue(body.announcements);
    const quietStart = integerInRange(body.quietStart, 0, 23);
    const quietEnd = integerInRange(body.quietEnd, 0, 23);
    const policyVersion = shortString(body.policyVersion, 40);
    const source = body.source === 'permission_prompt' || body.source === 'product_alert'
      ? body.source
      : body.source === 'settings'
        ? 'settings'
        : null;
    if (
      productAlerts === null || personalizedOffers === null || announcements === null ||
      quietStart === null || quietEnd === null || policyVersion === null || source === null
    ) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    await deps.service.updatePreferences({
      deviceId,
      productAlerts,
      personalizedOffers,
      announcements,
      quietStart,
      quietEnd,
      policyVersion,
      source,
    });
    res.status(200).json({ status: 'ok' });
  }));

  app.put('/v1/device-installations/me/interest-profile', deviceRoute(deps, async (req, res, deviceId) => {
    const body = objectBody(req);
    const profileVersion = safeInteger(body.profileVersion);
    const topBrands = affinityList(body.topBrands, 3);
    const topCategories = affinityList(body.topCategories, 2);
    const generatedAt = dateValue(body.generatedAt);
    const priceBand = body.priceBand === null ? null : shortString(body.priceBand, 60);
    const intentTier = intentValue(body.intentTier);
    const signalCountBucket = bucketValue(body.signalCountBucket);
    if (
      profileVersion === null || topBrands === null || topCategories === null ||
      generatedAt === null || intentTier === null || signalCountBucket === null ||
      (body.priceBand !== null && priceBand === null)
    ) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const applied = await deps.service.syncInterestProfile({
      deviceId,
      profileVersion,
      topBrands,
      topCategories,
      priceBand,
      intentTier,
      signalCountBucket,
      generatedAt,
    });
    res.status(200).json({ status: applied ? 'updated' : 'stale_ignored' });
  }));

  app.get('/v1/notification-config', asyncRoute(async (_req, res) => {
    const rules = await deps.service.repository.listAutomationRules();
    const localRule = rules.find((rule) => rule.key === 'local_cart_reminder');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.status(200).json({
      localCartReminder: {
        enabled: localRule?.enabled ?? false,
        delayHours: numericField(localRule?.configuration.delayHours, 20),
        title: 'Tu selección sigue aquí',
        body: 'Vuelve a Monetta cuando estés lista para continuar.',
      },
    });
  }));

  app.post('/v1/product-alerts', deviceRoute(deps, async (req, res, deviceId) => {
    const body = objectBody(req);
    const productKey = productKeyValue(body.productKey);
    const kind = productAlertKind(body.kind);
    if (productKey === null || kind === null) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const id = await deps.service.createProductAlert({ deviceId, productKey, kind });
    res.status(201).json({ alert: { id, productKey, kind } });
  }));

  app.delete('/v1/product-alerts/:id', deviceRoute(deps, async (req, res, deviceId) => {
    const id = uuidValue(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const deleted = await deps.service.repository.deleteProductAlert(deviceId, id);
    res.status(deleted ? 200 : 404).json(deleted ? { status: 'ok' } : { error: 'not_found' });
  }));

  app.post('/v1/notification-interactions', deviceRoute(deps, async (req, res, deviceId) => {
    const body = objectBody(req);
    const deliveryId = uuidValue(body.deliveryId);
    const event = interactionEvent(body.event);
    const occurredAt = dateValue(body.occurredAt);
    const idempotencyKey = shortString(req.header('Idempotency-Key'), 200);
    if (deliveryId === null || event === null || occurredAt === null || idempotencyKey === null) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const recorded = await deps.service.repository.recordInteraction({
      deviceId,
      deliveryId,
      event,
      occurredAt,
      idempotencyKey,
    });
    res.status(recorded ? 201 : 200).json({ status: recorded ? 'recorded' : 'duplicate_or_unknown' });
  }));

  app.get('/admin/notifications/overview', ownerRoute(deps, async (_req, res) => {
    res.status(200).json(await deps.service.repository.getOverview());
  }));

  app.post('/admin/notification-campaigns', ownerRoute(deps, async (req, res, actorId) => {
    const body = objectBody(req);
    const kind = campaignKind(body.kind);
    const purpose = consentPurpose(body.purpose);
    const title = shortString(body.title, 80);
    const messageBody = shortString(body.body, 180);
    const imageUrl = nullableHttpsUrl(body.imageUrl);
    const route = notificationRoute(body.route);
    const segment = segmentDefinition(body.segment);
    if (
      kind === null || purpose === null || title === null || messageBody === null ||
      imageUrl === undefined || route === null || segment === null
    ) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const campaign = await deps.service.createCampaign({
      kind,
      purpose,
      title,
      body: messageBody,
      imageUrl,
      route,
      segment,
      createdBy: actorId,
    });
    res.status(201).json({ campaign });
  }));

  app.post('/admin/notification-campaigns/:id/preview', ownerRoute(deps, async (req, res) => {
    const id = uuidValue(req.params.id);
    const campaign = id === null ? null : await deps.service.repository.getCampaign(id);
    if (campaign === null) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    const count = await deps.service.repository.previewAudience(campaign.segment, campaign.purpose, now());
    res.status(200).json({ eligible: count, evaluatedAt: now().toISOString() });
  }));

  app.post('/admin/notification-campaigns/:id/test', ownerRoute(deps, async (req, res, actorId) => {
    const id = uuidValue(req.params.id);
    const campaign = id === null ? null : await deps.service.repository.getCampaign(id);
    const deviceId = shortString(objectBody(req).deviceId, 200);
    if (campaign === null || deviceId === null) {
      res.status(campaign === null ? 404 : 400).json({ error: campaign === null ? 'not_found' : 'invalid_request' });
      return;
    }
    const testCampaign = await deps.service.createCampaign({
      kind: 'test',
      purpose: campaign.purpose,
      title: campaign.title,
      body: campaign.body,
      imageUrl: campaign.imageUrl,
      route: campaign.route,
      segment: { kind: 'device', value: deviceId },
      createdBy: actorId,
    });
    await deps.service.repository.scheduleCampaign(testCampaign.id, now(), actorId, now());
    res.status(202).json({ campaignId: testCampaign.id, status: 'queued' });
  }));

  app.post('/admin/notification-campaigns/:id/schedule', ownerRoute(deps, async (req, res, actorId) => {
    const id = uuidValue(req.params.id);
    const requested = dateValue(objectBody(req).scheduledAt) ?? now();
    if (id === null || requested.getTime() < now().getTime() - 60_000) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const scheduled = await deps.service.repository.scheduleCampaign(id, requested, actorId, now());
    res.status(scheduled ? 202 : 409).json(scheduled ? { status: 'scheduled' } : { error: 'invalid_state' });
  }));

  app.post('/admin/notification-campaigns/:id/cancel', ownerRoute(deps, async (req, res, actorId) => {
    const id = uuidValue(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const cancelled = await deps.service.repository.cancelCampaign(id, actorId, now());
    res.status(cancelled ? 200 : 409).json(cancelled ? { status: 'cancelled' } : { error: 'invalid_state' });
  }));

  app.get('/admin/notification-campaigns/:id/report', ownerRoute(deps, async (req, res) => {
    const id = uuidValue(req.params.id);
    const report = id === null ? null : await deps.service.repository.getCampaignReport(id);
    res.status(report === null ? 404 : 200).json(report === null ? { error: 'not_found' } : { campaign: report });
  }));

  app.get('/admin/notification-rules', ownerRoute(deps, async (_req, res) => {
    res.status(200).json({ rules: await deps.service.repository.listAutomationRules() });
  }));

  app.patch('/admin/notification-rules/:key', ownerRoute(deps, async (req, res, actorId) => {
    const key = automationKey(req.params.key);
    const body = objectBody(req);
    const enabled = booleanValue(body.enabled);
    const configuration = plainObject(body.configuration);
    if (key === null || enabled === null || configuration === null) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    await deps.service.repository.updateAutomationRule(key, enabled, configuration, actorId);
    res.status(200).json({ status: 'ok' });
  }));
}

type AsyncHandler = (req: Request, res: Response) => Promise<void>;
type DeviceHandler = (req: Request, res: Response, deviceId: string) => Promise<void>;
type OwnerHandler = (req: Request, res: Response, actorId: string) => Promise<void>;

function asyncRoute(handler: AsyncHandler) {
  return (req: Request, res: Response, next: NextFunction) => {
    handler(req, res).catch(next);
  };
}

function deviceRoute(deps: EngagementRouteDeps, handler: DeviceHandler) {
  return asyncRoute(async (req, res) => {
    const installation = await deps.service.authenticateDevice(deviceCredential(req));
    if (installation === null) {
      res.status(401).json({ error: 'unauthorized_device' });
      return;
    }
    await handler(req, res, installation.deviceId);
  });
}

function ownerRoute(deps: EngagementRouteDeps, handler: OwnerHandler) {
  return asyncRoute(async (req, res) => {
    const token = bearerCredential(req);
    const owner = token === null
      ? null
      : deps.adminAuthorizer !== undefined
        ? await deps.adminAuthorizer.authenticate(token)
        : await deps.ownerAuthorizer.authenticate(token);
    if (owner === null) {
      res.status(403).json({ error: 'owner_forbidden' });
      return;
    }
    await handler(
      req,
      res,
      'actorId' in owner ? owner.actorId : owner.id,
    );
  });
}

function objectBody(req: Request): Record<string, unknown> {
  return plainObject(req.body) ?? {};
}

function plainObject(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function deviceCredential(req: Request): string | null {
  const authorization = req.header('Authorization');
  if (authorization?.startsWith('Device ') !== true) return null;
  const value = authorization.slice('Device '.length).trim();
  return value === '' ? null : value;
}

function bearerCredential(req: Request): string | null {
  const authorization = req.header('Authorization');
  if (authorization?.startsWith('Bearer ') !== true) return null;
  const value = authorization.slice('Bearer '.length).trim();
  return value === '' || value.length > 8192 ? null : value;
}

function shortString(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' || trimmed.length > max ? null : trimmed;
}

function normalizedLocale(value: unknown): string {
  const locale = shortString(value, 20) ?? 'es-MX';
  return /^[a-z]{2,3}(?:-[A-Z]{2})?$/.test(locale) ? locale : 'es-MX';
}

function normalizedTimezone(value: unknown): string {
  const timezone = shortString(value, 80) ?? 'UTC';
  try {
    Intl.DateTimeFormat('en-US', { timeZone: timezone });
    return timezone;
  } catch {
    return 'UTC';
  }
}

function booleanValue(value: unknown): boolean | null {
  return typeof value === 'boolean' ? value : null;
}

function integerInRange(value: unknown, min: number, max: number): number | null {
  return Number.isInteger(value) && Number(value) >= min && Number(value) <= max ? Number(value) : null;
}

function safeInteger(value: unknown): number | null {
  return Number.isSafeInteger(value) && Number(value) >= 0 ? Number(value) : null;
}

function dateValue(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function affinityList(value: unknown, max: number): readonly InterestAffinity[] | null {
  if (!Array.isArray(value) || value.length > max) return null;
  const output: InterestAffinity[] = [];
  for (const item of value) {
    const record = plainObject(item);
    const key = shortString(record?.key, 80);
    const score = integerInRange(record?.score, 0, 100);
    if (key === null || score === null) return null;
    output.push({ key, score });
  }
  return output;
}

function intentValue(value: unknown): IntentTier | null {
  return value === 'low' || value === 'medium' || value === 'high' ? value : null;
}

function bucketValue(value: unknown): SignalCountBucket | null {
  return value === '0_4' || value === '5_9' || value === '10_24' || value === '25_plus'
    ? value
    : null;
}
function productKeyValue(value: unknown): string | null {
  const key = shortString(value, 300);
  // External-catalog product keys are retired (F03/F28). Only Shopify keys
  // may drive alerts, campaigns, or deep links.
  return key !== null && /^shopify:/.test(key) ? key : null;
}

function productAlertKind(value: unknown): ProductAlertKind | null {
  return value === 'restock' || value === 'price_drop' ? value : null;
}

function uuidValue(value: unknown): string | null {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    ? value
    : null;
}

function interactionEvent(value: unknown) {
  return value === 'opened' || value === 'product_viewed' || value === 'add_to_cart' ||
    value === 'checkout_started' || value === 'purchased'
    ? value
    : null;
}

function numericField(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function campaignKind(value: unknown): CampaignKind | null {
  return value === 'manual' || value === 'restock' || value === 'price_drop' || value === 'new_arrival'
    ? value
    : null;
}

function consentPurpose(value: unknown): ConsentPurpose | null {
  return value === 'product_alerts' || value === 'personalized_offers' || value === 'announcements'
    ? value
    : null;
}

function nullableHttpsUrl(value: unknown): string | null | undefined {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value !== 'string' || value.length > 2048) return undefined;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? url.toString() : undefined;
  } catch {
    return undefined;
  }
}

function notificationRoute(value: unknown): NotificationRoute | null {
  const route = plainObject(value);
  if (route === null) return null;
  if (route.type === 'home') return { type: 'home' };
  if (route.type === 'wishlist') return { type: 'wishlist' };
  if (route.type === 'orders') return { type: 'orders' };
  if (route.type === 'collection') {
    const handle = shortString(route.handle, 120);
    return handle === null ? null : { type: 'collection', handle };
  }
  if (route.type === 'product') {
    const productKey = productKeyValue(route.productKey);
    return productKey === null ? null : { type: 'product', productKey };
  }
  return null;
}

function segmentDefinition(value: unknown): SegmentDefinition | null {
  const segment = plainObject(value);
  if (segment === null) return null;
  if (segment.kind === 'all') return { kind: 'all' };
  if (segment.kind === 'high_intent') return { kind: 'high_intent' };
  if (segment.kind === 'brand' || segment.kind === 'category') {
    const trait = shortString(segment.value, 80);
    const minimumScore = integerInRange(segment.minimumScore, 1, 100);
    return trait === null || minimumScore === null
      ? null
      : { kind: segment.kind, value: trait, minimumScore };
  }
  return null;
}

function automationKey(value: unknown): string | null {
  return value === 'restock' || value === 'price_drop' || value === 'new_arrival' || value === 'local_cart_reminder'
    ? value
    : null;
}

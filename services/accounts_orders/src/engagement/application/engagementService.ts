import { createHash, randomBytes, randomUUID } from 'node:crypto';
import type { EngagementRepository, MessagingProvider } from '../domain/ports.js';
import type {
  CampaignInput,
  CatalogEventInput,
  InterestProfileInput,
  NotificationPreferencesInput,
  OutboundMessage,
  PermissionState,
  ProductAlertKind,
  PushEndpointInput,
  RegisterInstallationInput,
  SendResult,
} from '../domain/types.js';

export class EngagementService {
  constructor(
    readonly repository: EngagementRepository,
    private readonly messaging: MessagingProvider | null,
    private readonly now: () => Date = () => new Date(),
  ) {}

  static hashCredential(raw: string): string {
    return createHash('sha256').update(raw).digest('hex');
  }

  async registerInstallation(input: Omit<RegisterInstallationInput, 'credentialHash' | 'existingCredentialHash' | 'now'> & {
    existingCredential: string | null;
  }): Promise<{ outcome: 'created' | 'refreshed'; credential: string } | { outcome: 'conflict' }> {
    const credential = randomBytes(32).toString('base64url');
    const result = await this.repository.registerInstallation({
      ...input,
      credentialHash: EngagementService.hashCredential(credential),
      existingCredentialHash: input.existingCredential === null
        ? null
        : EngagementService.hashCredential(input.existingCredential),
      now: this.now(),
    });
    return result === 'conflict' ? { outcome: 'conflict' } : { outcome: result, credential };
  }

  async authenticateDevice(rawCredential: string | null) {
    if (rawCredential === null || rawCredential.length < 20 || rawCredential.length > 512) return null;
    const installation = await this.repository.findInstallationByCredentialHash(
      EngagementService.hashCredential(rawCredential),
    );
    return installation?.disabledAt === null ? installation : null;
  }

  async registerPushEndpoint(input: Omit<PushEndpointInput, 'id' | 'now'>): Promise<void> {
    await this.repository.upsertPushEndpoint({
      ...input,
      id: randomUUID(),
      now: this.now(),
    });
  }

  updatePreferences(input: Omit<NotificationPreferencesInput, 'now'>): Promise<void> {
    return this.repository.updatePreferences({ ...input, now: this.now() });
  }

  syncInterestProfile(input: Omit<InterestProfileInput, 'expiresAt'>): Promise<boolean> {
    return this.repository.upsertInterestProfile({
      ...input,
      expiresAt: new Date(input.generatedAt.getTime() + 30 * 24 * 60 * 60 * 1000),
    });
  }

  async createProductAlert(input: {
    deviceId: string;
    productKey: string;
    kind: ProductAlertKind;
  }): Promise<string> {
    await this.repository.grantProductAlerts(input.deviceId, '2026-08-25', this.now());
    return this.repository.upsertProductAlert({
      id: randomUUID(),
      ...input,
      now: this.now(),
    });
  }

  async createCampaign(input: Omit<CampaignInput, 'id' | 'now'>): Promise<CampaignInput & { status: 'draft' }> {
    const created = await this.repository.createCampaign({
      ...input,
      id: randomUUID(),
      now: this.now(),
    });
    return { ...created, status: 'draft' };
  }

  async ingestCatalogEvent(event: CatalogEventInput): Promise<{ accepted: boolean; campaignId: string | null }> {
    const accepted = await this.repository.recordCatalogEvent(event);
    if (!accepted) return { accepted: false, campaignId: null };

    const automationKey = event.eventType === 'catalog.product.restocked'
      ? 'restock'
      : event.eventType === 'catalog.product.price_dropped'
        ? 'price_drop'
        : 'new_arrival';
    const rule = (await this.repository.listAutomationRules())
      .find((candidate) => candidate.key === automationKey);
    if (rule?.enabled !== true) {
      return { accepted: true, campaignId: null };
    }
    const ttlHours = positiveNumber(rule.configuration.ttlHours, 24);
    if (this.now().getTime() - event.occurredAt.getTime() > ttlHours * 60 * 60 * 1000) {
      return { accepted: true, campaignId: null };
    }
    if (event.eventType === 'catalog.product.price_dropped') {
      const beforePrice = positiveNumber(event.before?.price, null);
      const afterPrice = positiveNumber(event.after.price, null);
      const minimumPercent = positiveNumber(rule.configuration.minimumPercent, 10);
      if (
        beforePrice === null || afterPrice === null || afterPrice >= beforePrice ||
        ((beforePrice - afterPrice) / beforePrice) * 100 < minimumPercent
      ) {
        return { accepted: true, campaignId: null };
      }
    }

    const titleFromPayload = stringValue(event.after.title);
    const title = event.eventType === 'catalog.product.restocked'
      ? 'Volvió a estar disponible'
      : event.eventType === 'catalog.product.price_dropped'
        ? 'Bajó de precio'
        : 'Hay algo nuevo para ti';
    const body = titleFromPayload === null
      ? 'Abre Monetta para verlo.'
      : `${titleFromPayload} ya está disponible en Monetta.`;
    const purpose = event.eventType === 'catalog.product.restocked'
      ? 'product_alerts' as const
      : 'personalized_offers' as const;
    const kind = event.eventType === 'catalog.product.restocked'
      ? 'restock' as const
      : event.eventType === 'catalog.product.price_dropped'
        ? 'price_drop' as const
        : 'new_arrival' as const;
    const segment = event.eventType === 'catalog.product.restocked'
      ? { kind: 'product_alert' as const, value: event.productKey, alertKind: 'restock' as const }
      : traitSegment(
          event,
          positiveNumber(rule.configuration.minimumScore, 60),
        );
    if (segment === null) return { accepted: true, campaignId: null };

    const campaign = await this.repository.createCampaign({
      id: randomUUID(),
      kind,
      purpose,
      title,
      body,
      imageUrl: httpsUrl(event.after.imageUrl),
      route: { type: 'product', productKey: event.productKey },
      segment,
      createdBy: `automation:${automationKey}`,
      now: this.now(),
    });
    await this.repository.scheduleCampaign(campaign.id, this.now(), `automation:${automationKey}`, this.now());
    return { accepted: true, campaignId: campaign.id };
  }

  async dispatchOnce(limit = 100): Promise<{ materialized: number; processed: number }> {
    if (this.messaging === null) return { materialized: 0, processed: 0 };
    const now = this.now();
    const materialized = await this.repository.materializeDueCampaigns(now);
    const deliveries = await this.repository.claimDeliveries(now, limit);
    for (const delivery of deliveries) {
      const message: OutboundMessage = {
        deliveryId: delivery.id,
        campaignId: delivery.campaignId,
        title: delivery.title,
        body: delivery.body,
        imageUrl: delivery.imageUrl,
        route: delivery.route,
        source: delivery.kind,
      };
      let result: SendResult;
      try {
        result = await this.messaging.send(delivery.registrationId, message);
      } catch (error) {
        result = {
          outcome: 'retryable',
          errorCode: error instanceof Error ? error.name : 'unknown_provider_error',
          retryAfter: retryAfter(delivery.attemptCount, now),
        };
      }
      if (result.outcome === 'retryable' && result.retryAfter === undefined) {
        result = { ...result, retryAfter: retryAfter(delivery.attemptCount, now) };
      }
      await this.repository.markDeliveryResult(delivery.id, result, this.now());
    }
    return { materialized, processed: deliveries.length };
  }
}

export function parsePermissionState(value: unknown): PermissionState | null {
  return value === 'not_determined' || value === 'provisional' || value === 'granted' || value === 'denied'
    ? value
    : null;
}

function retryAfter(attempt: number, now: Date): Date {
  const seconds = Math.min(3600, 10 * 2 ** Math.min(attempt, 8));
  const jitter = Math.floor(Math.random() * Math.max(1, seconds / 4));
  return new Date(now.getTime() + (seconds + jitter) * 1000);
}

function stringValue(value: unknown): string | null {
  return typeof value === 'string' && value.trim() !== '' ? value.trim() : null;
}

function httpsUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'https:' ? parsed.toString() : null;
  } catch {
    return null;
  }
}

function positiveNumber(value: unknown, fallback: number): number;
function positiveNumber(value: unknown, fallback: null): number | null;
function positiveNumber(value: unknown, fallback: number | null): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value > 0
    ? value
    : fallback;
}

function traitSegment(event: CatalogEventInput, minimumScore: number) {
  const brand = stringValue(event.after.brand);
  if (brand !== null) return { kind: 'brand' as const, value: brand, minimumScore };
  const category = stringValue(event.after.category);
  if (category !== null) return { kind: 'category' as const, value: category, minimumScore };
  return null;
}

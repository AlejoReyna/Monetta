import type { EngagementRepository } from '../../src/engagement/domain/ports.js';
import type {
  CampaignInput,
  CampaignRecord,
  CampaignSummary,
  CatalogEventInput,
  ClaimedDelivery,
  ConsentPurpose,
  DeviceInstallation,
  EngagementOverview,
  InterestProfileInput,
  NotificationPreferencesInput,
  PushEndpointInput,
  RegisterInstallationInput,
  SegmentDefinition,
  SendResult,
} from '../../src/engagement/domain/types.js';

export class InMemoryEngagementRepository implements EngagementRepository {
  readonly installationByCredential = new Map<string, DeviceInstallation>();
  readonly credentialByDevice = new Map<string, string>();
  readonly endpoints = new Map<string, PushEndpointInput>();
  readonly preferences = new Map<string, NotificationPreferencesInput>();
  readonly profiles = new Map<string, InterestProfileInput>();
  readonly alerts = new Map<string, {
    id: string;
    deviceId: string;
    productKey: string;
    kind: 'restock' | 'price_drop';
    active: boolean;
  }>();
  readonly campaigns = new Map<string, CampaignRecord>();
  readonly deliveryResults = new Map<string, SendResult>();
  readonly interactions = new Set<string>();
  readonly catalogEvents = new Set<string>();
  readonly rules = new Map<string, { enabled: boolean; configuration: Record<string, unknown> }>([
    ['restock', { enabled: false, configuration: {} }],
    ['price_drop', { enabled: false, configuration: {} }],
    ['new_arrival', { enabled: false, configuration: {} }],
    ['local_cart_reminder', { enabled: false, configuration: { delayHours: 20 } }],
  ]);
  readonly deliveries: ClaimedDelivery[] = [];

  async registerInstallation(input: RegisterInstallationInput) {
    const existingHash = this.credentialByDevice.get(input.deviceId);
    if (existingHash !== undefined && existingHash !== input.existingCredentialHash) return 'conflict' as const;
    if (existingHash !== undefined) this.installationByCredential.delete(existingHash);
    const installation: DeviceInstallation = {
      deviceId: input.deviceId,
      platform: input.platform,
      locale: input.locale,
      timezone: input.timezone,
      appVersion: input.appVersion,
      disabledAt: null,
    };
    this.credentialByDevice.set(input.deviceId, input.credentialHash);
    this.installationByCredential.set(input.credentialHash, installation);
    return existingHash === undefined ? 'created' as const : 'refreshed' as const;
  }

  async findInstallationByCredentialHash(hash: string) {
    return this.installationByCredential.get(hash) ?? null;
  }

  async upsertPushEndpoint(input: PushEndpointInput) {
    this.endpoints.set(input.deviceId, input);
  }

  async updatePreferences(input: NotificationPreferencesInput) {
    this.preferences.set(input.deviceId, input);
  }

  async grantProductAlerts(deviceId: string, policyVersion: string, now: Date) {
    const current = this.preferences.get(deviceId);
    this.preferences.set(deviceId, {
      deviceId,
      productAlerts: true,
      personalizedOffers: current?.personalizedOffers ?? false,
      announcements: current?.announcements ?? false,
      quietStart: current?.quietStart ?? 21,
      quietEnd: current?.quietEnd ?? 9,
      policyVersion,
      source: 'product_alert',
      now,
    });
  }

  async upsertInterestProfile(input: InterestProfileInput) {
    const current = this.profiles.get(input.deviceId);
    if (current !== undefined && current.profileVersion >= input.profileVersion) return false;
    this.profiles.set(input.deviceId, input);
    return true;
  }

  async upsertProductAlert(input: {
    id: string;
    deviceId: string;
    productKey: string;
    kind: 'restock' | 'price_drop';
    now: Date;
  }) {
    const current = [...this.alerts.values()].find(
      (alert) => alert.deviceId === input.deviceId && alert.productKey === input.productKey && alert.kind === input.kind,
    );
    if (current !== undefined) {
      current.active = true;
      return current.id;
    }
    this.alerts.set(input.id, { ...input, active: true });
    return input.id;
  }

  async deleteProductAlert(deviceId: string, alertId: string) {
    const alert = this.alerts.get(alertId);
    if (alert === undefined || alert.deviceId !== deviceId || !alert.active) return false;
    alert.active = false;
    return true;
  }

  async createCampaign(input: CampaignInput) {
    const campaign: CampaignRecord = { ...input, status: 'draft', scheduledAt: null };
    this.campaigns.set(input.id, campaign);
    return campaign;
  }

  async getCampaign(id: string) {
    return this.campaigns.get(id) ?? null;
  }

  async previewAudience(segment: SegmentDefinition, purpose: ConsentPurpose, now: Date) {
    return this.eligibleDevices(segment, purpose, now).length;
  }

  async scheduleCampaign(id: string, scheduledAt: Date, _actorId: string, _now: Date) {
    const campaign = this.campaigns.get(id);
    if (campaign === undefined || campaign.status !== 'draft') return false;
    this.campaigns.set(id, { ...campaign, status: 'scheduled', scheduledAt });
    return true;
  }

  async cancelCampaign(id: string, _actorId: string, _now: Date) {
    const campaign = this.campaigns.get(id);
    if (campaign === undefined || campaign.status === 'complete' || campaign.status === 'cancelled') return false;
    this.campaigns.set(id, { ...campaign, status: 'cancelled' });
    return true;
  }

  async getOverview(): Promise<EngagementOverview> {
    return {
      activeEndpoints: this.endpoints.size,
      grantedEndpoints: [...this.endpoints.values()].filter((item) => item.permissionState === 'granted').length,
      personalizedProfiles: this.profiles.size,
      queuedDeliveries: this.deliveries.length,
      recentCampaigns: [...this.campaigns.values()].map(toSummary),
    };
  }

  async getCampaignReport(id: string): Promise<CampaignSummary | null> {
    const campaign = this.campaigns.get(id);
    return campaign === undefined ? null : toSummary(campaign);
  }

  async materializeDueCampaigns(now: Date) {
    let count = 0;
    for (const [id, campaign] of this.campaigns) {
      if (campaign.status !== 'scheduled' || (campaign.scheduledAt?.getTime() ?? Infinity) > now.getTime()) continue;
      for (const deviceId of this.eligibleDevices(campaign.segment, campaign.purpose, now)) {
        const endpoint = this.endpoints.get(deviceId)!;
        this.deliveries.push({
          id: `delivery-${id}-${deviceId}`,
          campaignId: id,
          registrationId: endpoint.registrationId,
          platform: this.installation(deviceId)!.platform,
          title: campaign.title,
          body: campaign.body,
          imageUrl: campaign.imageUrl,
          route: campaign.route,
          kind: campaign.kind,
          attemptCount: 1,
        });
      }
      this.campaigns.set(id, {
        ...campaign,
        status: this.deliveries.some((item) => item.campaignId === id) ? 'sending' : 'complete',
      });
      count++;
    }
    return count;
  }

  async claimDeliveries(_now: Date, limit: number) {
    return this.deliveries.splice(0, limit);
  }

  async markDeliveryResult(deliveryId: string, result: SendResult, _now: Date) {
    this.deliveryResults.set(deliveryId, result);
  }

  async recordInteraction(input: {
    deviceId: string;
    deliveryId: string;
    event: 'opened' | 'product_viewed' | 'add_to_cart' | 'checkout_started' | 'purchased';
    occurredAt: Date;
    idempotencyKey: string;
  }) {
    const key = `${input.deliveryId}:${input.event}:${input.idempotencyKey}`;
    if (this.interactions.has(key)) return false;
    this.interactions.add(key);
    return true;
  }

  async recordCatalogEvent(event: CatalogEventInput) {
    if (this.catalogEvents.has(event.eventId)) return false;
    this.catalogEvents.add(event.eventId);
    return true;
  }

  async isAutomationEnabled(key: string) {
    return this.rules.get(key)?.enabled ?? false;
  }

  async updateAutomationRule(key: string, enabled: boolean, configuration: Record<string, unknown>, _actorId: string) {
    this.rules.set(key, { enabled, configuration });
  }

  async listAutomationRules() {
    return [...this.rules].map(([key, value]) => ({ key, ...value }));
  }

  private installation(deviceId: string): DeviceInstallation | null {
    const hash = this.credentialByDevice.get(deviceId);
    return hash === undefined ? null : (this.installationByCredential.get(hash) ?? null);
  }

  private eligibleDevices(segment: SegmentDefinition, purpose: ConsentPurpose, now: Date): string[] {
    return [...this.endpoints.keys()].filter((deviceId) => {
      const endpoint = this.endpoints.get(deviceId)!;
      const preferences = this.preferences.get(deviceId);
      const consent = purpose === 'product_alerts'
        ? preferences?.productAlerts
        : purpose === 'personalized_offers'
          ? preferences?.personalizedOffers
          : preferences?.announcements;
      if (endpoint.permissionState !== 'granted' || consent !== true) return false;
      if (segment.kind === 'device') return segment.value === deviceId;
      if (segment.kind === 'all') return true;
      if (segment.kind === 'product_alert') {
        return [...this.alerts.values()].some(
          (alert) => alert.active && alert.deviceId === deviceId && alert.productKey === segment.value && alert.kind === segment.alertKind,
        );
      }
      const profile = this.profiles.get(deviceId);
      if (profile === undefined || profile.expiresAt <= now) return false;
      if (segment.kind === 'high_intent') return profile.intentTier === 'high';
      const affinities = segment.kind === 'brand' ? profile.topBrands : profile.topCategories;
      return affinities.some((item) => item.key === segment.value && item.score >= segment.minimumScore);
    });
  }
}

function toSummary(campaign: CampaignRecord): CampaignSummary {
  return {
    id: campaign.id,
    kind: campaign.kind,
    status: campaign.status,
    title: campaign.title,
    scheduledAt: campaign.scheduledAt,
    createdAt: campaign.now,
    eligibleCount: 0,
    acceptedCount: 0,
    openedCount: 0,
    failedCount: 0,
  };
}

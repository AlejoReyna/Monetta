import type {
  CampaignInput,
  CampaignRecord,
  CampaignSummary,
  CatalogEventInput,
  ClaimedDelivery,
  ConsentPurpose,
  DeviceInstallation,
  EngagementOverview,
  InstallationRegistrationResult,
  InterestProfileInput,
  NotificationPreferencesInput,
  OutboundMessage,
  ProductAlertKind,
  PushEndpointInput,
  RegisterInstallationInput,
  SegmentDefinition,
  SendResult,
} from './types.js';

export interface EngagementRepository {
  registerInstallation(input: RegisterInstallationInput): Promise<InstallationRegistrationResult>;
  findInstallationByCredentialHash(credentialHash: string): Promise<DeviceInstallation | null>;
  upsertPushEndpoint(input: PushEndpointInput): Promise<void>;
  updatePreferences(input: NotificationPreferencesInput): Promise<void>;
  grantProductAlerts(deviceId: string, policyVersion: string, now: Date): Promise<void>;
  upsertInterestProfile(input: InterestProfileInput): Promise<boolean>;
  upsertProductAlert(input: {
    id: string;
    deviceId: string;
    productKey: string;
    kind: ProductAlertKind;
    now: Date;
  }): Promise<string>;
  deleteProductAlert(deviceId: string, alertId: string): Promise<boolean>;
  createCampaign(input: CampaignInput): Promise<CampaignRecord>;
  getCampaign(id: string): Promise<CampaignRecord | null>;
  previewAudience(segment: SegmentDefinition, purpose: ConsentPurpose, now: Date): Promise<number>;
  scheduleCampaign(id: string, scheduledAt: Date, actorId: string, now: Date): Promise<boolean>;
  cancelCampaign(id: string, actorId: string, now: Date): Promise<boolean>;
  getOverview(): Promise<EngagementOverview>;
  getCampaignReport(id: string): Promise<CampaignSummary | null>;
  materializeDueCampaigns(now: Date): Promise<number>;
  claimDeliveries(now: Date, limit: number): Promise<readonly ClaimedDelivery[]>;
  markDeliveryResult(deliveryId: string, result: SendResult, now: Date): Promise<void>;
  recordInteraction(input: {
    deviceId: string;
    deliveryId: string;
    event: 'opened' | 'product_viewed' | 'add_to_cart' | 'checkout_started' | 'purchased';
    occurredAt: Date;
    idempotencyKey: string;
  }): Promise<boolean>;
  recordCatalogEvent(event: CatalogEventInput): Promise<boolean>;
  isAutomationEnabled(key: string): Promise<boolean>;
  updateAutomationRule(key: string, enabled: boolean, configuration: Record<string, unknown>, actorId: string): Promise<void>;
  listAutomationRules(): Promise<readonly { key: string; enabled: boolean; configuration: Record<string, unknown> }[]>;
}

export interface MessagingProvider {
  validate(message: OutboundMessage): Promise<void>;
  send(registrationId: string, message: OutboundMessage): Promise<SendResult>;
}

export interface AppCheckVerifier {
  verify(token: string | null): Promise<boolean>;
}

export interface OwnerAuthorizer {
  authenticate(bearerToken: string): Promise<{ readonly actorId: string } | null>;
}

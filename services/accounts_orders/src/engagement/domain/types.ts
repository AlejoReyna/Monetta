import type { Platform } from '../../domain/types.js';

export type PermissionState = 'not_determined' | 'provisional' | 'granted' | 'denied';
export type ConsentPurpose = 'product_alerts' | 'personalized_offers' | 'announcements';
export type ConsentSource = 'settings' | 'permission_prompt' | 'product_alert';
export type IntentTier = 'low' | 'medium' | 'high';
export type SignalCountBucket = '0_4' | '5_9' | '10_24' | '25_plus';
export type ProductAlertKind = 'restock' | 'price_drop';
export type CampaignKind = 'manual' | 'restock' | 'price_drop' | 'new_arrival' | 'test';
export type CampaignStatus =
  | 'draft'
  | 'scheduled'
  | 'targeting'
  | 'sending'
  | 'complete'
  | 'cancelled';

export interface DeviceInstallation {
  readonly deviceId: string;
  readonly platform: Platform;
  readonly locale: string;
  readonly timezone: string;
  readonly appVersion: string;
  readonly disabledAt: Date | null;
}

export interface RegisterInstallationInput {
  readonly deviceId: string;
  readonly credentialHash: string;
  readonly existingCredentialHash: string | null;
  readonly platform: Platform;
  readonly locale: string;
  readonly timezone: string;
  readonly appVersion: string;
  readonly now: Date;
}

export type InstallationRegistrationResult = 'created' | 'refreshed' | 'conflict';

export interface PushEndpointInput {
  readonly id: string;
  readonly deviceId: string;
  readonly registrationKind: 'token' | 'fid';
  readonly registrationId: string;
  readonly permissionState: PermissionState;
  readonly now: Date;
}

export interface InterestAffinity {
  readonly key: string;
  readonly score: number;
}

export interface InterestProfileInput {
  readonly deviceId: string;
  readonly profileVersion: number;
  readonly topBrands: readonly InterestAffinity[];
  readonly topCategories: readonly InterestAffinity[];
  readonly priceBand: string | null;
  readonly intentTier: IntentTier;
  readonly signalCountBucket: SignalCountBucket;
  readonly generatedAt: Date;
  readonly expiresAt: Date;
}

export interface NotificationPreferencesInput {
  readonly deviceId: string;
  readonly productAlerts: boolean;
  readonly personalizedOffers: boolean;
  readonly announcements: boolean;
  readonly quietStart: number;
  readonly quietEnd: number;
  readonly policyVersion: string;
  readonly source: ConsentSource;
  readonly now: Date;
}

export type SegmentDefinition =
  | { readonly kind: 'all' }
  | { readonly kind: 'brand'; readonly value: string; readonly minimumScore: number }
  | { readonly kind: 'category'; readonly value: string; readonly minimumScore: number }
  | { readonly kind: 'high_intent' }
  | { readonly kind: 'product_alert'; readonly value: string; readonly alertKind: ProductAlertKind }
  | { readonly kind: 'device'; readonly value: string };

export type NotificationRoute =
  | { readonly type: 'home' }
  | { readonly type: 'wishlist' }
  | { readonly type: 'orders' }
  | { readonly type: 'collection'; readonly handle: string }
  | { readonly type: 'product'; readonly productKey: string };

export interface CampaignInput {
  readonly id: string;
  readonly kind: CampaignKind;
  readonly purpose: ConsentPurpose;
  readonly title: string;
  readonly body: string;
  readonly imageUrl: string | null;
  readonly route: NotificationRoute;
  readonly segment: SegmentDefinition;
  readonly createdBy: string;
  readonly now: Date;
}

export interface CampaignRecord extends CampaignInput {
  readonly status: CampaignStatus;
  readonly scheduledAt: Date | null;
}

export interface CampaignSummary {
  readonly id: string;
  readonly kind: CampaignKind;
  readonly status: CampaignStatus;
  readonly title: string;
  readonly scheduledAt: Date | null;
  readonly createdAt: Date;
  readonly eligibleCount: number;
  readonly acceptedCount: number;
  readonly openedCount: number;
  readonly failedCount: number;
}

export interface EngagementOverview {
  readonly activeEndpoints: number;
  readonly grantedEndpoints: number;
  readonly personalizedProfiles: number;
  readonly queuedDeliveries: number;
  readonly recentCampaigns: readonly CampaignSummary[];
}

export interface ClaimedDelivery {
  readonly id: string;
  readonly campaignId: string;
  readonly registrationId: string;
  readonly platform: Platform;
  readonly title: string;
  readonly body: string;
  readonly imageUrl: string | null;
  readonly route: NotificationRoute;
  readonly kind: CampaignKind;
  readonly attemptCount: number;
}

export interface CatalogEventInput {
  readonly eventId: string;
  readonly eventType: 'catalog.product.created' | 'catalog.product.restocked' | 'catalog.product.price_dropped';
  readonly source: string;
  readonly productKey: string;
  readonly occurredAt: Date;
  readonly before: Record<string, unknown> | null;
  readonly after: Record<string, unknown>;
}

export interface SendResult {
  readonly outcome: 'accepted' | 'invalid' | 'retryable' | 'failed';
  readonly providerMessageId?: string;
  readonly errorCode?: string;
  readonly retryAfter?: Date;
}

export interface OutboundMessage {
  readonly deliveryId: string;
  readonly campaignId: string;
  readonly title: string;
  readonly body: string;
  readonly imageUrl: string | null;
  readonly route: NotificationRoute;
  readonly source: CampaignKind;
}

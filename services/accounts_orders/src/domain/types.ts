/** The mirrored shapes this service persists — not Shopify's own payload shapes (see webhooks/payloads.ts for those). */

export interface CustomerRecord {
  readonly shopifyCustomerId: string;
  readonly email: string | null;
  readonly firstName: string | null;
  readonly lastName: string | null;
  readonly phone: string | null;
  readonly marketingConsent: boolean;
}

export type OrderSource = 'shopify_checkout' | 'whatsapp_apartado';

export interface OrderRecord {
  readonly shopifyOrderId: string | null;
  readonly customerId: string | null;
  readonly source: OrderSource;
  readonly attributionCode: string | null;
  readonly tags: readonly string[];
  readonly financialStatus: string | null;
  readonly fulfillmentStatus: string | null;
  readonly totalAmount: number | null;
  readonly currencyCode: string | null;
  readonly attributionDeviceId: string | null;
  readonly attributionRecoSource: string | null;
  readonly placedAt: Date | null;
}

/** A row as read back out — `OrderRecord` plus the fields only the database assigns. */
export interface MirroredOrder extends OrderRecord {
  readonly id: number;
  readonly updatedAt: Date;
}

export interface WebhookEventRecord {
  readonly webhookId: string;
  readonly topic: string;
  readonly shopifyResourceId: string | null;
  readonly payloadHash: string;
}

export type Platform = 'ios' | 'android';

export interface PushTokenRecord {
  readonly deviceId: string;
  readonly customerId: string | null;
  readonly fcmToken: string;
  readonly platform: Platform;
}

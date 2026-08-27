import { createHash } from 'node:crypto';
import type {
  CustomersRepository,
  OrdersRepository,
  PushTokensRepository,
  WebhookEventsRepository,
} from '../domain/ports.js';
import { logger } from '../logger.js';
import {
  noteAttribute,
  parseTags,
  type ShopifyCustomerDataRequestWebhookPayload,
  type ShopifyCustomerRedactWebhookPayload,
  type ShopifyOrderWebhookPayload,
  type ShopifyProductWebhookPayload,
  type ShopifyShopRedactWebhookPayload,
} from './payloads.js';

export interface HandlerDeps {
  readonly customers: CustomersRepository;
  readonly orders: OrdersRepository;
  readonly webhookEvents: WebhookEventsRepository;
  readonly pushTokens: PushTokensRepository;
  readonly catalogEvents?: {
    process(
      topic: 'products/create' | 'products/update',
      webhookId: string,
      payload: ShopifyProductWebhookPayload,
    ): Promise<void>;
  };
  readonly engagementPrivacy?: {
    deleteForShopifyCustomer(shopifyCustomerId: string): Promise<void>;
    deleteAll(): Promise<void>;
  };
}

export async function handleProductsWebhook(
  deps: HandlerDeps,
  webhookId: string,
  topic: 'products/create' | 'products/update',
  payload: ShopifyProductWebhookPayload,
  rawBody: Buffer,
): Promise<void> {
  const productId = String(payload.id);
  const isNew = await claimDelivery(deps, {
    webhookId,
    topic,
    shopifyResourceId: productId,
    rawBody,
  });
  if (!isNew) return;
  await deps.catalogEvents?.process(topic, webhookId, payload);
  await deps.webhookEvents.markProcessed(webhookId);
  logger.info('Shopify catalog transition evaluated', { productId, topic });
}

/**
 * `AttributionCodeGenerator`'s alphabet
 * (`lib/data/shopify/cart_attribution.dart`) — deliberately excludes vowels
 * and `0/O/1/I`. Matched here, not just prefix-checked, so a coincidental
 * "MN-" in an unrelated tag can't be mistaken for an apartado code.
 */
const APARTADO_CODE = /^MN-[23456789BCDFGHJKLMNPQRSTVWXYZ]{4}$/;

function payloadHash(rawBody: Buffer): string {
  return createHash('sha256').update(rawBody).digest('hex');
}

/**
 * `webhookId` is Shopify's `X-Shopify-Webhook-Id` header — stable across
 * retries of the same delivery. Returns `false` (already handled) for a
 * duplicate so the caller can still respond 200 without reprocessing.
 */
async function claimDelivery(
  deps: Pick<HandlerDeps, 'webhookEvents'>,
  args: { webhookId: string; topic: string; shopifyResourceId: string | null; rawBody: Buffer },
): Promise<boolean> {
  const isNew = await deps.webhookEvents.recordIfNew({
    webhookId: args.webhookId,
    topic: args.topic,
    shopifyResourceId: args.shopifyResourceId,
    payloadHash: payloadHash(args.rawBody),
  });
  if (!isNew) {
    logger.info('duplicate webhook delivery ignored', {
      webhookId: args.webhookId,
      topic: args.topic,
    });
  }
  return isNew;
}

export async function handleOrdersWebhook(
  deps: HandlerDeps,
  webhookId: string,
  topic: 'orders/create' | 'orders/updated',
  payload: ShopifyOrderWebhookPayload,
  rawBody: Buffer,
): Promise<void> {
  const shopifyOrderId = String(payload.id);
  const isNew = await claimDelivery(deps, {
    webhookId,
    topic,
    shopifyResourceId: shopifyOrderId,
    rawBody,
  });
  if (!isNew) return;

  const tags = parseTags(payload.tags);
  const attributionCode = tags.find((t) => APARTADO_CODE.test(t)) ?? null;
  const customerId = payload.customer ? String(payload.customer.id) : null;

  if (payload.customer) {
    await deps.customers.upsert({
      shopifyCustomerId: String(payload.customer.id),
      email: payload.customer.email ?? null,
      firstName: payload.customer.first_name ?? null,
      lastName: payload.customer.last_name ?? null,
      phone: payload.customer.phone ?? null,
      // The order webhook doesn't carry marketing consent — a
      // `customers/update` webhook (not yet subscribed here) would be the
      // source for that field; never fabricate `true`.
      marketingConsent: false,
    });
  }

  await deps.orders.upsertByShopifyOrderId({
    shopifyOrderId,
    customerId,
    // An apartado order still arrives through this same webhook once the
    // owner manually enters it in Shopify — the MN- tag is what tells us
    // its *originating channel* was WhatsApp, not the app's checkout.
    source: attributionCode ? 'whatsapp_apartado' : 'shopify_checkout',
    attributionCode,
    tags,
    financialStatus: payload.financial_status ?? null,
    fulfillmentStatus: payload.fulfillment_status ?? null,
    totalAmount: payload.current_total_price ? Number.parseFloat(payload.current_total_price) : null,
    currencyCode: payload.currency ?? null,
    attributionDeviceId: noteAttribute(payload, '_device_id'),
    attributionRecoSource: noteAttribute(payload, '_rec_source'),
    placedAt: payload.created_at ? new Date(payload.created_at) : null,
  });

  await deps.webhookEvents.markProcessed(webhookId);
  logger.info('order mirrored', { shopifyOrderId, source: attributionCode ? 'whatsapp_apartado' : 'shopify_checkout' });
}

/**
 * GDPR-style compliance topic: a shopper asked what data this app holds
 * about them. Shopify requires only that the request be acknowledged
 * (200) and acted on within 30 days — not a synchronous data dump in the
 * webhook response — so this records the request for manual follow-up
 * rather than trying to assemble and return a data export inline.
 */
export async function handleCustomersDataRequest(
  deps: HandlerDeps,
  webhookId: string,
  payload: ShopifyCustomerDataRequestWebhookPayload,
  rawBody: Buffer,
): Promise<void> {
  const shopifyCustomerId = String(payload.customer.id);
  const isNew = await claimDelivery(deps, {
    webhookId,
    topic: 'customers/data_request',
    shopifyResourceId: shopifyCustomerId,
    rawBody,
  });
  if (!isNew) return;

  logger.warn('customer data request received — manual fulfillment required within 30 days', {
    shopifyCustomerId,
  });
  await deps.webhookEvents.markProcessed(webhookId);
}

export async function handleCustomersRedact(
  deps: HandlerDeps,
  webhookId: string,
  payload: ShopifyCustomerRedactWebhookPayload,
  rawBody: Buffer,
): Promise<void> {
  const shopifyCustomerId = String(payload.customer.id);
  const isNew = await claimDelivery(deps, {
    webhookId,
    topic: 'customers/redact',
    shopifyResourceId: shopifyCustomerId,
    rawBody,
  });
  if (!isNew) return;

  // Explicit detach before delete, even though the FK's ON DELETE SET NULL
  // (see db/migrations/001_init.sql) would do this anyway — compliance
  // deletion should not depend solely on an implicit cascade for its
  // correctness to be visible/auditable in this code.
  await deps.orders.detachCustomer(shopifyCustomerId);
  await deps.pushTokens.deleteAllForCustomer(shopifyCustomerId);
  await deps.engagementPrivacy?.deleteForShopifyCustomer(shopifyCustomerId);
  await deps.customers.delete(shopifyCustomerId);

  await deps.webhookEvents.markProcessed(webhookId);
  logger.info('customer redacted', { shopifyCustomerId });
}

/** Fires ~48h after the app is uninstalled. Single-tenant service: this wipes everything. */
export async function handleShopRedact(
  deps: HandlerDeps,
  webhookId: string,
  payload: ShopifyShopRedactWebhookPayload,
  rawBody: Buffer,
): Promise<void> {
  const isNew = await claimDelivery(deps, {
    webhookId,
    topic: 'shop/redact',
    shopifyResourceId: String(payload.shop_id),
    rawBody,
  });
  if (!isNew) return;

  await deps.pushTokens.deleteAll();
  await deps.engagementPrivacy?.deleteAll();
  await deps.orders.deleteAll();
  await deps.customers.deleteAll();

  await deps.webhookEvents.markProcessed(webhookId);
  logger.warn('shop redact processed — all mirrored data wiped', { shopId: payload.shop_id });
}

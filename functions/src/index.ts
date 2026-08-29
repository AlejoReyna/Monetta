import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret, defineString } from "firebase-functions/params";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { isPublicProduct, toCatalogProduct } from "./catalog.js";
import { verifyShopifyHmac } from "./hmac.js";
import {
  ShopifyAdminClient,
  inventoryItemGid,
  productGid,
} from "./shopifyAdmin.js";
import type {
  AdminProduct,
  CatalogProductDocument,
  CatalogWebhookTopic,
  InventoryLevelWebhookPayload,
  ProductWebhookPayload,
} from "./types.js";
import { parseWebhookObject } from "./webhookPayload.js";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const clientSecret = defineSecret("SHOPIFY_APP_CLIENT_SECRET");
const adminAccessToken = defineSecret("SHOPIFY_ADMIN_ACCESS_TOKEN");
const shopDomain = defineString("SHOPIFY_SHOP_DOMAIN");
const apiVersion = defineString("SHOPIFY_API_VERSION", { default: "2026-07" });

const allowedTopics = new Set<CatalogWebhookTopic>([
  "products/create",
  "products/update",
  "products/delete",
  "inventory_levels/update",
]);
const deliveryTtlMs = 30 * 24 * 60 * 60 * 1_000;

function header(request: { get(name: string): string | undefined }, name: string): string | undefined {
  return request.get(name)?.trim();
}

function parseTopic(value: string | undefined): CatalogWebhookTopic | null {
  return value !== undefined && allowedTopics.has(value as CatalogWebhookTopic)
    ? (value as CatalogWebhookTopic)
    : null;
}

function validWebhookId(value: string | undefined): value is string {
  return value !== undefined && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

function numericId(value: unknown, name: string): string {
  if ((typeof value === "number" && Number.isSafeInteger(value) && value > 0) ||
      (typeof value === "string" && /^\d+$/.test(value))) {
    return String(value);
  }
  throw new Error(`Invalid ${name}`);
}

function productPayload(payload: Record<string, unknown>): ProductWebhookPayload {
  const id = numericId(payload.id, "product id");
  const gid = payload.admin_graphql_api_id;
  if (gid !== undefined && (typeof gid !== "string" || gid !== productGid(id))) {
    throw new Error("Mismatched product ids");
  }
  return { id, ...(typeof gid === "string" ? { admin_graphql_api_id: gid } : {}) };
}

function inventoryPayload(payload: Record<string, unknown>): InventoryLevelWebhookPayload {
  const available = payload.available;
  if (available !== null && (typeof available !== "number" || !Number.isFinite(available))) {
    throw new Error("Invalid inventory quantity");
  }
  const updatedAt = payload.updated_at;
  if (updatedAt !== undefined &&
      (typeof updatedAt !== "string" || Number.isNaN(Date.parse(updatedAt)))) {
    throw new Error("Invalid inventory timestamp");
  }
  return {
    inventory_item_id: numericId(payload.inventory_item_id, "inventory item id"),
    location_id: numericId(payload.location_id, "location id"),
    available,
    ...(typeof updatedAt === "string" ? { updated_at: updatedAt } : {}),
  };
}

function adminClient(): ShopifyAdminClient {
  return new ShopifyAdminClient(
    shopDomain.value().toLowerCase(),
    adminAccessToken.value(),
    apiVersion.value(),
  );
}

function isAlreadyExists(error: unknown): boolean {
  if (error === null || typeof error !== "object") return false;
  const code = (error as { readonly code?: unknown }).code;
  return code === 6 || code === "already-exists";
}

export const shopifyCatalogWebhook = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
    secrets: [clientSecret],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.set("Allow", "POST").status(405).json({ error: "method_not_allowed" });
      return;
    }

    const rawBody = request.rawBody;
    if (!Buffer.isBuffer(rawBody) || rawBody.length === 0 || rawBody.length > 2_000_000) {
      response.status(413).json({ error: "invalid_body" });
      return;
    }
    if (!verifyShopifyHmac(rawBody, header(request, "X-Shopify-Hmac-Sha256"), clientSecret.value())) {
      response.status(401).json({ error: "invalid_signature" });
      return;
    }

    // Only inspect routing and tenant headers after authenticating the body.
    const topic = parseTopic(header(request, "X-Shopify-Topic"));
    const webhookId = header(request, "X-Shopify-Webhook-Id");
    const incomingShop = header(request, "X-Shopify-Shop-Domain")?.toLowerCase();
    const expectedShop = shopDomain.value().toLowerCase();
    if (topic === null || !validWebhookId(webhookId) || incomingShop !== expectedShop) {
      response.status(400).json({ error: "invalid_webhook_metadata" });
      return;
    }

    try {
      const payload = parseWebhookObject(rawBody);
      let resourceId: string;
      let resourceGid: string;

      if (topic === "products/delete") {
        const allowedDeleteKeys = new Set(["id", "admin_graphql_api_id"]);
        if (Object.keys(payload).some((key) => !allowedDeleteKeys.has(key))) {
          throw new Error("Unexpected product delete payload");
        }
        const parsed = productPayload(payload);
        resourceId = parsed.id;
        resourceGid = parsed.admin_graphql_api_id ?? productGid(parsed.id);
      } else if (topic === "products/create" || topic === "products/update") {
        const parsed = productPayload(payload);
        resourceId = parsed.id;
        resourceGid = parsed.admin_graphql_api_id ?? productGid(parsed.id);
      } else {
        const parsed = inventoryPayload(payload);
        resourceId = parsed.inventory_item_id;
        resourceGid = inventoryItemGid(parsed.inventory_item_id);
      }

      const triggeredAt = header(request, "X-Shopify-Triggered-At");
      try {
        await db.collection("_shopifyWebhookDeliveries").doc(webhookId).create({
          status: "pending",
          topic,
          shop: incomingShop,
          resourceId,
          resourceGid,
          ...(triggeredAt === undefined ? {} : { triggeredAt }),
          receivedAt: FieldValue.serverTimestamp(),
          expiresAt: Timestamp.fromMillis(Date.now() + deliveryTtlMs),
        });
      } catch (error) {
        if (isAlreadyExists(error)) {
          response.status(200).json({ status: "duplicate" });
          return;
        }
        throw error;
      }
      response.status(200).json({ status: "accepted" });
    } catch (error) {
      const isBadPayload = error instanceof SyntaxError ||
        (error instanceof Error && /^(Invalid|Mismatched|Unexpected|Webhook)/.test(error.message));
      logger.error("Shopify catalog webhook receipt failed", {
        topic,
        webhookId,
        errorType: error instanceof Error ? error.name : typeof error,
      });
      response.status(isBadPayload ? 400 : 500).json({
        error: isBadPayload ? "invalid_payload" : "receipt_failed",
      });
    }
  },
);

interface QueuedDelivery {
  readonly status: string;
  readonly topic: CatalogWebhookTopic;
  readonly shop: string;
  readonly resourceId: string;
  readonly resourceGid: string;
}

function queuedDelivery(value: FirebaseFirestore.DocumentData): QueuedDelivery {
  const topic = parseTopic(typeof value.topic === "string" ? value.topic : undefined);
  const status = value.status;
  const shop = value.shop;
  const resourceId = value.resourceId;
  const resourceGid = value.resourceGid;
  if (topic === null || status !== "pending" || shop !== shopDomain.value().toLowerCase() ||
      typeof resourceId !== "string" || !/^\d+$/.test(resourceId) ||
      typeof resourceGid !== "string") {
    throw new Error("Invalid queued Shopify delivery");
  }
  return { status, topic, shop, resourceId, resourceGid };
}

/**
 * Processes the durable receipt outside Shopify's five-second HTTPS deadline.
 * `retry: true` plus an atomic product/status transaction makes failures safe.
 */
export const processShopifyCatalogWebhook = onDocumentCreated(
  {
    document: "_shopifyWebhookDeliveries/{webhookId}",
    region: "us-central1",
    timeoutSeconds: 60,
    memory: "256MiB",
    retry: true,
    secrets: [adminAccessToken],
  },
  async (event) => {
    const snapshot = event.data;
    if (snapshot === undefined) return;
    const delivery = queuedDelivery(snapshot.data());
    const webhookId = event.params.webhookId;
    const shopify = adminClient();

    let product: AdminProduct | null = null;
    let productResourceId: string | null = delivery.resourceId;
    if (delivery.topic === "products/create" || delivery.topic === "products/update") {
      product = await shopify.getProduct(delivery.resourceGid);
      if (product !== null && product.legacyResourceId !== delivery.resourceId) {
        throw new Error("Shopify returned a mismatched product");
      }
    } else if (delivery.topic === "inventory_levels/update") {
      product = await shopify.getProductForInventoryItem(delivery.resourceGid);
      productResourceId = product?.legacyResourceId ?? null;
    }

    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(snapshot.ref);
      if (!current.exists || current.get("status") !== "pending") return;

      if (productResourceId !== null) {
        const productRef = db.collection("products").doc(productResourceId);
        if (product !== null && isPublicProduct(product)) {
          const document: CatalogProductDocument = toCatalogProduct(product);
          transaction.set(productRef, {
            ...document,
            syncedAt: FieldValue.serverTimestamp(),
            lastWebhookId: webhookId,
            lastWebhookTopic: delivery.topic,
          });
        } else {
          // Deleting unpublished/archived products from the public mirror is
          // intentional: no draft can leak through the public read rule.
          transaction.delete(productRef);
        }
      }

      transaction.update(snapshot.ref, {
        status: productResourceId === null ? "ignored" : "processed",
        processedAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info("Shopify catalog webhook processed", {
      topic: delivery.topic,
      webhookId,
      status: productResourceId === null ? "ignored" : "processed",
    });
  },
);

/**
 * Daily repair pass. Webhooks provide low latency; reconciliation provides
 * completeness after a prolonged outage and performs the initial catalog seed.
 */
export const reconcileShopifyCatalog = onSchedule(
  {
    schedule: "17 3 * * *",
    timeZone: "America/Monterrey",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
    retryCount: 3,
    secrets: [adminAccessToken],
  },
  async () => {
    const startedAt = Timestamp.now();
    const shopify = adminClient();
    const seen = new Set<string>();
    let after: string | null = null;

    do {
      const page = await shopify.listProducts(after);
      const batch = db.batch();
      for (const product of page.nodes) {
        const id = product.legacyResourceId;
        seen.add(id);
        const ref = db.collection("products").doc(id);
        if (isPublicProduct(product)) {
          batch.set(ref, {
            ...toCatalogProduct(product),
            syncedAt: FieldValue.serverTimestamp(),
            lastWebhookTopic: "reconciliation",
          });
        } else {
          batch.delete(ref);
        }
      }
      if (page.nodes.length > 0) await batch.commit();
      after = page.pageInfo.hasNextPage ? page.pageInfo.endCursor : null;
      if (page.pageInfo.hasNextPage && after === null) {
        throw new Error("Shopify returned an invalid pagination cursor");
      }
    } while (after !== null);

    // Don't delete a document written by a webhook after this pass began.
    const mirrored = await db.collection("products").where("source", "==", "shopify").get();
    const stale = mirrored.docs.filter((document) => {
      if (seen.has(document.id)) return false;
      const syncedAt = document.get("syncedAt");
      return !(syncedAt instanceof Timestamp) || syncedAt.toMillis() <= startedAt.toMillis();
    });
    for (let offset = 0; offset < stale.length; offset += 400) {
      const batch = db.batch();
      for (const document of stale.slice(offset, offset + 400)) batch.delete(document.ref);
      await batch.commit();
    }

    logger.info("Shopify catalog reconciliation complete", {
      productsSeen: seen.size,
      staleProductsDeleted: stale.length,
    });
  },
);

import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { isPublicProduct, toCatalogProduct } from "../server/catalog/catalog.js";
import {
  ConfigurationError,
  requiredEnvironment,
  shopDomain,
  shopifyApiVersion,
} from "../server/catalog/environment.js";
import { firestore } from "../server/catalog/firebaseAdmin.js";
import { verifyShopifyHmac } from "../server/catalog/hmac.js";
import {
  ShopifyAdminClient,
  inventoryItemGid,
  productGid,
} from "../server/catalog/shopifyAdmin.js";
import type {
  AdminProduct,
  CatalogProductDocument,
  CatalogWebhookTopic,
  InventoryLevelWebhookPayload,
  ProductWebhookPayload,
} from "../server/catalog/types.js";
import { parseWebhookObject } from "../server/catalog/webhookPayload.js";
import {
  RequestBodyTooLargeError,
  sendWebResponse,
  toWebRequest,
  type VercelRequest,
  type VercelResponse,
} from "../server/catalog/vercelAdapter.js";

const allowedTopics = new Set<CatalogWebhookTopic>([
  "products/create",
  "products/update",
  "products/delete",
  "inventory_levels/update",
]);
const deliveryTtlMs = 30 * 24 * 60 * 60 * 1_000;
const maximumBodyBytes = 2_000_000;

export const maxDuration = 10;

function json(status: number, body: Readonly<Record<string, string>>): Response {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
    },
  });
}

function parseTopic(value: string | null): CatalogWebhookTopic | null {
  return value !== null && allowedTopics.has(value as CatalogWebhookTopic)
    ? (value as CatalogWebhookTopic)
    : null;
}

function validWebhookId(value: string | null): value is string {
  return value !== null && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

function numericId(value: unknown, name: string): string {
  if (
    (typeof value === "number" && Number.isSafeInteger(value) && value > 0) ||
    (typeof value === "string" && /^\d+$/.test(value))
  ) {
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
  let parsedAvailable: number | null;
  if (available === null) {
    parsedAvailable = null;
  } else if (typeof available === "number" && Number.isFinite(available)) {
    parsedAvailable = available;
  } else {
    throw new Error("Invalid inventory quantity");
  }
  const updatedAt = payload.updated_at;
  if (
    updatedAt !== undefined &&
    (typeof updatedAt !== "string" || Number.isNaN(Date.parse(updatedAt)))
  ) {
    throw new Error("Invalid inventory timestamp");
  }
  return {
    inventory_item_id: numericId(payload.inventory_item_id, "inventory item id"),
    location_id: numericId(payload.location_id, "location id"),
    available: parsedAvailable,
    ...(typeof updatedAt === "string" ? { updated_at: updatedAt } : {}),
  };
}

function isBadPayload(error: unknown): boolean {
  return error instanceof SyntaxError ||
    (error instanceof Error && /^(Invalid|Mismatched|Unexpected|Webhook)/.test(error.message));
}

let cachedShopifyClient: ShopifyAdminClient | null = null;

function shopifyClient(expectedShop: string): ShopifyAdminClient {
  cachedShopifyClient ??= new ShopifyAdminClient(
    expectedShop,
    requiredEnvironment("SHOPIFY_APP_CLIENT_ID"),
    requiredEnvironment("SHOPIFY_APP_CLIENT_SECRET"),
    shopifyApiVersion(),
  );
  return cachedShopifyClient;
}

/**
 * Shopify webhook endpoint at POST /api.
 *
 * The raw body is authenticated before any payload-controlled data is used.
 * Product and delivery-ledger writes share one transaction, so Shopify retries
 * cannot leave a delivery marked complete without its catalog mutation.
 */
export async function POST(request: Request): Promise<Response> {
  let secret: string;
  let expectedShop: string;
  try {
    secret = requiredEnvironment("SHOPIFY_APP_CLIENT_SECRET");
    expectedShop = shopDomain();
  } catch (error) {
    console.error("Shopify webhook configuration failed", {
      errorType: error instanceof Error ? error.name : typeof error,
    });
    return json(503, { error: "service_not_configured" });
  }

  const contentLength = Number.parseInt(request.headers.get("content-length") ?? "0", 10);
  if (Number.isFinite(contentLength) && contentLength > maximumBodyBytes) {
    return json(413, { error: "invalid_body" });
  }

  const rawBody = Buffer.from(await request.arrayBuffer());
  if (rawBody.length === 0 || rawBody.length > maximumBodyBytes) {
    return json(413, { error: "invalid_body" });
  }
  if (!verifyShopifyHmac(rawBody, request.headers.get("x-shopify-hmac-sha256") ?? undefined, secret)) {
    return json(401, { error: "invalid_signature" });
  }

  // Routing and tenant headers are trusted only after HMAC authentication.
  const topic = parseTopic(request.headers.get("x-shopify-topic"));
  const webhookId = request.headers.get("x-shopify-webhook-id")?.trim() ?? null;
  const incomingShop = request.headers.get("x-shopify-shop-domain")?.trim().toLowerCase() ?? null;
  if (topic === null || !validWebhookId(webhookId) || incomingShop !== expectedShop) {
    return json(400, { error: "invalid_webhook_metadata" });
  }

  try {
    const db = firestore();
    const deliveryRef = db.collection("_shopifyWebhookDeliveries").doc(webhookId);
    if ((await deliveryRef.get()).exists) {
      return json(200, { status: "duplicate" });
    }

    const payload = parseWebhookObject(rawBody);
    let resourceId: string;
    let resourceGid: string;
    let product: AdminProduct | null = null;
    let productResourceId: string | null;

    if (topic === "products/delete") {
      const allowedDeleteKeys = new Set(["id", "admin_graphql_api_id"]);
      if (Object.keys(payload).some((key) => !allowedDeleteKeys.has(key))) {
        throw new Error("Unexpected product delete payload");
      }
      const parsed = productPayload(payload);
      resourceId = parsed.id;
      resourceGid = parsed.admin_graphql_api_id ?? productGid(parsed.id);
      productResourceId = resourceId;
    } else if (topic === "products/create" || topic === "products/update") {
      const parsed = productPayload(payload);
      resourceId = parsed.id;
      resourceGid = parsed.admin_graphql_api_id ?? productGid(parsed.id);
      productResourceId = resourceId;
      product = await shopifyClient(expectedShop).getProduct(resourceGid);
      if (product !== null && product.legacyResourceId !== resourceId) {
        throw new Error("Shopify returned a mismatched product");
      }
    } else {
      const parsed = inventoryPayload(payload);
      resourceId = parsed.inventory_item_id;
      resourceGid = inventoryItemGid(parsed.inventory_item_id);
      product = await shopifyClient(expectedShop).getProductForInventoryItem(resourceGid);
      productResourceId = product?.legacyResourceId ?? null;
    }

    const status = productResourceId === null ? "ignored" : "processed";
    const triggeredAt = request.headers.get("x-shopify-triggered-at")?.trim();
    let duplicate = false;

    await db.runTransaction(async (transaction) => {
      if ((await transaction.get(deliveryRef)).exists) {
        duplicate = true;
        return;
      }

      if (productResourceId !== null) {
        const productRef = db.collection("products").doc(productResourceId);
        if (product !== null && isPublicProduct(product)) {
          const document: CatalogProductDocument = toCatalogProduct(product);
          transaction.set(productRef, {
            ...document,
            syncedAt: FieldValue.serverTimestamp(),
            lastWebhookId: webhookId,
            lastWebhookTopic: topic,
          });
        } else {
          // Deleted, unpublished, archived, and draft products do not belong in
          // the public mirror.
          transaction.delete(productRef);
        }
      }

      transaction.create(deliveryRef, {
        status,
        topic,
        shop: incomingShop,
        resourceId,
        resourceGid,
        ...(triggeredAt ? { triggeredAt } : {}),
        receivedAt: FieldValue.serverTimestamp(),
        processedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(Date.now() + deliveryTtlMs),
      });
    });

    console.info("Shopify catalog webhook processed", {
      topic,
      webhookId,
      status: duplicate ? "duplicate" : status,
    });
    return json(200, { status: duplicate ? "duplicate" : status });
  } catch (error) {
    const badPayload = isBadPayload(error);
    console.error("Shopify catalog webhook failed", {
      topic,
      webhookId,
      errorType: error instanceof Error ? error.name : typeof error,
    });
    return json(badPayload ? 400 : error instanceof ConfigurationError ? 503 : 500, {
      error: badPayload
        ? "invalid_payload"
        : error instanceof ConfigurationError
          ? "service_not_configured"
          : "processing_failed",
    });
  }
}

export function GET(): Response {
  return new Response(null, { status: 405, headers: { allow: "POST" } });
}

export default async function handler(
  request: VercelRequest,
  response: VercelResponse,
): Promise<void> {
  try {
    const webRequest = await toWebRequest(request, maximumBodyBytes);
    await sendWebResponse(response, webRequest.method === "POST" ? await POST(webRequest) : GET());
  } catch (error) {
    if (error instanceof RequestBodyTooLargeError) {
      response.status(413).json({ error: "invalid_body" });
      return;
    }
    console.error("Unable to read Shopify webhook request", {
      errorType: error instanceof Error ? error.name : typeof error,
    });
    response.status(400).json({ error: "invalid_request" });
  }
}

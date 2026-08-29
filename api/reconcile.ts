import { timingSafeEqual } from "node:crypto";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { isPublicProduct, toCatalogProduct } from "../server/catalog/catalog.js";
import {
  ConfigurationError,
  requiredEnvironment,
  shopDomain,
  shopifyApiVersion,
} from "../server/catalog/environment.js";
import {
  catalogFirebaseProjectId,
  firestore,
} from "../server/catalog/firebaseAdmin.js";
import { ShopifyAdminClient } from "../server/catalog/shopifyAdmin.js";
import {
  sendWebResponse,
  toWebRequest,
  type VercelRequest,
  type VercelResponse,
} from "../server/catalog/vercelAdapter.js";

export const maxDuration = 60;

function json(status: number, body: Readonly<Record<string, number | string>>): Response {
  return Response.json(body, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

function authorized(request: Request, secret: string): boolean {
  const actual = Buffer.from(request.headers.get("authorization") ?? "", "utf8");
  const expected = Buffer.from(`Bearer ${secret}`, "utf8");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

/**
 * Daily repair and initial seed endpoint, invoked by Vercel Cron.
 * Webhooks provide low latency; this pass repairs deliveries missed during an
 * outage and removes documents for products that no longer exist.
 */
export async function GET(request: Request): Promise<Response> {
  try {
    const cronSecret = requiredEnvironment("CRON_SECRET");
    if (cronSecret.length < 32) throw new ConfigurationError("CRON_SECRET is too short");
    if (!authorized(request, cronSecret)) return json(401, { error: "unauthorized" });

    const db = firestore();
    const startedAt = Timestamp.now();
    const shopify = new ShopifyAdminClient(
      shopDomain(),
      requiredEnvironment("SHOPIFY_APP_CLIENT_ID"),
      requiredEnvironment("SHOPIFY_APP_CLIENT_SECRET"),
      shopifyApiVersion(),
    );
    const seen = new Set<string>();
    let after: string | null = null;
    let pages = 0;

    do {
      const page = await shopify.listProducts(after);
      pages += 1;
      for (const product of page.nodes) seen.add(product.legacyResourceId);

      if (page.nodes.length > 0) {
        await db.runTransaction(async (transaction) => {
          const entries = await Promise.all(page.nodes.map(async (product) => {
            const ref = db.collection("products").doc(product.legacyResourceId);
            return { product, ref, current: await transaction.get(ref) };
          }));

          for (const { product, ref, current } of entries) {
            const syncedAt = current.get("syncedAt");
            if (syncedAt instanceof Timestamp && syncedAt.toMillis() > startedAt.toMillis()) {
              continue;
            }
            if (isPublicProduct(product)) {
              transaction.set(ref, {
                ...toCatalogProduct(product),
                syncedAt: FieldValue.serverTimestamp(),
                lastWebhookTopic: "reconciliation",
              });
            } else {
              transaction.delete(ref);
            }
          }
        });
      }

      after = page.pageInfo.hasNextPage ? page.pageInfo.endCursor : null;
      if (page.pageInfo.hasNextPage && after === null) {
        throw new Error("Shopify returned an invalid pagination cursor");
      }
    } while (after !== null);

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

    console.info("Shopify catalog reconciliation complete", {
      productsSeen: seen.size,
      staleProductsDeleted: stale.length,
      pages,
    });
    return json(200, {
      status: "complete",
      firebaseProjectId: catalogFirebaseProjectId,
      productsSeen: seen.size,
      staleProductsDeleted: stale.length,
      pages,
    });
  } catch (error) {
    console.error("Shopify catalog reconciliation failed", {
      errorType: error instanceof Error ? error.name : typeof error,
    });
    return json(error instanceof ConfigurationError ? 503 : 500, {
      error: error instanceof ConfigurationError ? "service_not_configured" : "reconciliation_failed",
    });
  }
}

export function POST(): Response {
  return new Response(null, { status: 405, headers: { allow: "GET" } });
}

export default async function handler(
  request: VercelRequest,
  response: VercelResponse,
): Promise<void> {
  const webRequest = await toWebRequest(request, 1_024);
  await sendWebResponse(response, webRequest.method === "GET" ? await GET(webRequest) : POST());
}

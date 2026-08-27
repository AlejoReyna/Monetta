import JSONbigFactory from "json-bigint";

const losslessJson = JSONbigFactory({ storeAsString: true, strict: true });

export function parseWebhookObject(rawBody: Buffer): Record<string, unknown> {
  let parsed: unknown;
  try {
    // Shopify legacy resource ids can be larger than Number.MAX_SAFE_INTEGER.
    // Keeping large integers as decimal strings is required for exact delete
    // document ids; native JSON.parse() can silently round them.
    parsed = losslessJson.parse(rawBody.toString("utf8")) as unknown;
  } catch {
    throw new Error("Invalid webhook JSON");
  }
  if (parsed === null || Array.isArray(parsed) || typeof parsed !== "object") {
    throw new Error("Webhook payload must be a JSON object");
  }
  return parsed as Record<string, unknown>;
}

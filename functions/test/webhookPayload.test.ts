import { describe, expect, it } from "vitest";
import { parseWebhookObject } from "../src/webhookPayload.js";

describe("parseWebhookObject", () => {
  it("preserves Shopify ids larger than JavaScript's safe integer range", () => {
    const payload = parseWebhookObject(
      Buffer.from('{"id":788032119674292922,"available":10}'),
    );
    expect(payload.id).toBe("788032119674292922");
    expect(payload.available).toBe(10);
  });

  it.each(["null", "[]", "not-json"])("rejects a non-object payload: %s", (body) => {
    expect(() => parseWebhookObject(Buffer.from(body))).toThrow();
  });
});

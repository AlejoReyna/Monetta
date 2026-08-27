import { createHmac } from "node:crypto";
import { describe, expect, it } from "vitest";
import { verifyShopifyHmac } from "../src/hmac.js";

describe("verifyShopifyHmac", () => {
  const secret = "test-client-secret";
  const body = Buffer.from('{"id":123,"title":"Bolsa"}');
  const valid = createHmac("sha256", secret).update(body).digest("base64");

  it("accepts the exact signed raw bytes", () => {
    expect(verifyShopifyHmac(body, valid, secret)).toBe(true);
  });

  it("rejects tampered bytes", () => {
    expect(verifyShopifyHmac(Buffer.from('{"id":124}'), valid, secret)).toBe(false);
  });

  it.each([undefined, "", "not-base64", `${valid}extra`])(
    "rejects a missing or malformed signature: %s",
    (signature) => {
      expect(verifyShopifyHmac(body, signature, secret)).toBe(false);
    },
  );

  it("fails closed when the client secret is missing", () => {
    expect(verifyShopifyHmac(body, valid, "")).toBe(false);
  });
});

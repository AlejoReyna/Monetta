import { afterEach, describe, expect, it, vi } from "vitest";
import { ShopifyAdminClient } from "../src/shopifyAdmin.js";

afterEach(() => vi.unstubAllGlobals());
describe("mobile producer variant metadata query", () => {
  it("requests only authoritative options and variant image on all product paths", async () => {
    const requests: string[] = [];
    vi.stubGlobal("fetch", vi.fn(async (_url, options: RequestInit) => {
      const body = JSON.parse(options.body as string) as { query: string };
      requests.push(body.query);
      return Response.json({ data: {
        product: null, inventoryItem: { variant: { product: null } },
        products: { nodes: [], pageInfo: { hasNextPage: false, endCursor: null } },
      } });
    }));
    const client = new ShopifyAdminClient("fixture.myshopify.com", "fixture-admin-token", "2026-07");
    await client.getProduct("gid://shopify/Product/1");
    await client.getProductForInventoryItem("gid://shopify/InventoryItem/1");
    await client.listProducts(null);
    expect(requests).toHaveLength(3);
    for (const query of requests) {
      expect(query).toContain("selectedOptions { name value }");
      expect(query).toContain("image { url }");
    }
  });
});

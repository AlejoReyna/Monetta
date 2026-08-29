import { afterEach, describe, expect, it, vi } from "vitest";
import { GET, POST } from "../../api/reconcile.js";

const previousCronSecret = process.env.CRON_SECRET;

afterEach(() => {
  vi.restoreAllMocks();
  if (previousCronSecret === undefined) {
    delete process.env.CRON_SECRET;
  } else {
    process.env.CRON_SECRET = previousCronSecret;
  }
});

describe("api/reconcile", () => {
  it("returns 401 for a GET without the configured bearer credential", async () => {
    process.env.CRON_SECRET = "c".repeat(32);

    const response = await GET(
      new Request("https://staging.example/api/reconcile"),
    );

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
  });

  it("returns 405 for POST and advertises GET", () => {
    const response = POST();

    expect(response.status).toBe(405);
    expect(response.headers.get("allow")).toBe("GET");
  });

  it.each([
    ["missing", undefined],
    ["too short", "short"],
  ])("returns 503 when CRON_SECRET is %s", async (_label, value) => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    if (value === undefined) {
      delete process.env.CRON_SECRET;
    } else {
      process.env.CRON_SECRET = value;
    }

    const response = await GET(
      new Request("https://staging.example/api/reconcile"),
    );

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "service_not_configured" });
  });
});

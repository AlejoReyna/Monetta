export class ConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConfigurationError";
  }
}

export function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (value === undefined || value.length === 0) {
    throw new ConfigurationError(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function shopDomain(): string {
  const value = requiredEnvironment("SHOPIFY_SHOP_DOMAIN").toLowerCase();
  if (!/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/.test(value)) {
    throw new ConfigurationError("SHOPIFY_SHOP_DOMAIN must be a permanent myshopify.com hostname");
  }
  return value;
}

export function shopifyApiVersion(): string {
  const value = process.env.SHOPIFY_API_VERSION?.trim() || "2026-07";
  if (!/^20\d{2}-(01|04|07|10)$/.test(value)) {
    throw new ConfigurationError("SHOPIFY_API_VERSION is invalid");
  }
  return value;
}

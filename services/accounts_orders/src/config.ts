/**
 * All environment configuration in one place, parsed once and validated
 * eagerly so a misconfigured deploy fails at startup — same shape as
 * `services/catalog_monitor/src/config.ts`.
 */
export interface AccountsOrdersConfig {
  readonly databaseUrl: string;
  readonly port: number;
  readonly nodeEnv: string;

  /**
   * The Shopify app's API secret key — NOT the Customer Account API mobile
   * client's id (that client is public and has no secret; see
   * `lib/data/customer_auth/README.md`). This is a *different* credential,
   * from the same Partner-dashboard app registration, used only to verify
   * the `X-Shopify-Hmac-Sha256` header on incoming webhooks.
   */
  readonly webhookSecret: string;
}

function int(value: string | undefined, fallback: number): number {
  if (value === undefined || value === '') return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AccountsOrdersConfig {
  const nodeEnv = env.NODE_ENV ?? 'development';
  const webhookSecret = env.SHOPIFY_APP_CLIENT_SECRET ?? '';

  // Fail fast in production rather than silently rejecting every webhook —
  // an empty secret in dev/test just means verifyHmac() always returns
  // false, which is the safe (closed) direction to fail in.
  if (nodeEnv === 'production' && webhookSecret === '') {
    throw new Error(
      'SHOPIFY_APP_CLIENT_SECRET is required in production — webhook HMAC verification ' +
        'cannot run without it. See .env.example.',
    );
  }

  return {
    databaseUrl:
      env.DATABASE_URL ??
      'postgres://accounts_orders:accounts_orders@localhost:5434/accounts_orders',
    port: int(env.PORT, 8082),
    nodeEnv,
    webhookSecret,
  };
}

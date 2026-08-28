/**
 * All environment configuration in one place, parsed once and validated
 * eagerly so a misconfigured deploy fails at startup — same shape as
 * `services/catalog_monitor/src/config.ts`.
 */
export interface AccountsOrdersConfig {
  readonly databaseUrl: string;
  readonly port: number;
  readonly nodeEnv: string;
  readonly shopDomain: string;

  /**
   * The Shopify app's API secret key — NOT the Customer Account API mobile
   * client's id (that client is public and has no secret; see
   * `lib/data/customer_auth/README.md`). This is a *different* credential,
   * from the same Partner-dashboard app registration, used only to verify
   * the `X-Shopify-Hmac-Sha256` header on incoming webhooks.
  */
  readonly webhookSecret: string;
  readonly notificationsEnabled: boolean;
  readonly firebaseProjectId: string;
  readonly firebaseClientEmail: string;
  readonly firebasePrivateKey: string;
  readonly pushTokenEncryptionSecret: string;
  readonly internalCatalogEventSecret: string;
  readonly ownerEmails: ReadonlySet<string>;
  readonly ownerShopifyCustomerIds: ReadonlySet<string>;
}

function int(value: string | undefined, fallback: number): number {
  if (value === undefined || value === '') return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function csv(value: string | undefined): ReadonlySet<string> {
  return new Set(
    (value ?? '')
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .filter((item) => item !== ''),
  );
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AccountsOrdersConfig {
  const nodeEnv = env.NODE_ENV ?? 'development';
  const webhookSecret = env.SHOPIFY_APP_CLIENT_SECRET ?? '';
  const notificationsEnabled = env.NOTIFICATIONS_ENABLED === 'true';
  const firebasePrivateKey = (env.FIREBASE_PRIVATE_KEY ?? '').replace(/\\n/g, '\n');
  const firebaseProjectId = (env.FIREBASE_PROJECT_ID ?? '').trim();
  const firebaseClientEmail = (env.FIREBASE_CLIENT_EMAIL ?? '').trim();
  const pushTokenEncryptionSecret = env.PUSH_TOKEN_ENCRYPTION_SECRET ?? '';

  if (
    nodeEnv === 'production' && notificationsEnabled &&
    (
      firebaseProjectId === '' || firebaseClientEmail === '' || firebasePrivateKey === '' ||
      pushTokenEncryptionSecret.length < 32
    )
  ) {
    throw new Error(
      'Notifications require FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, '
      + 'FIREBASE_PRIVATE_KEY, and a 32+ character PUSH_TOKEN_ENCRYPTION_SECRET',
    );
  }

  // Shopify integration is optional while first-party Monetta accounts are
  // the active identity system. An empty secret keeps every Shopify webhook
  // route closed (401) without preventing the accounts API from starting.

  return {
    databaseUrl:
      env.DATABASE_URL ??
      'postgres://accounts_orders:accounts_orders@localhost:5434/accounts_orders',
    port: int(env.PORT, 8082),
    nodeEnv,
    shopDomain: (env.SHOPIFY_STORE_DOMAIN ?? '').trim(),
    webhookSecret,
    notificationsEnabled,
    firebaseProjectId,
    firebaseClientEmail,
    firebasePrivateKey,
    pushTokenEncryptionSecret:
      pushTokenEncryptionSecret || 'monetta-development-registration-cipher',
    internalCatalogEventSecret: env.INTERNAL_CATALOG_EVENT_SECRET ?? '',
    ownerEmails: csv(env.OWNER_ADMIN_EMAILS),
    ownerShopifyCustomerIds: csv(env.OWNER_SHOPIFY_CUSTOMER_IDS),
  };
}

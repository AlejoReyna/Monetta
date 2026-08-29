import type {
  AppAccountRecord,
  AppAccountCredentials,
  AppAccountRegistration,
  AppSessionCreation,
  CustomerRecord,
  MirroredOrder,
  OrderRecord,
  PushTokenRecord,
  WebhookEventRecord,
} from './types.js';

export interface AppAccountsRepository {
  /** Creates an account, or updates the account already bound to this device. */
  register(record: AppAccountRegistration): Promise<AppAccountRecord>;

  /** Reads the password verifier used by first-party email login. */
  findCredentialsByEmail(email: string): Promise<AppAccountCredentials | null>;

  /** Creates or replaces the session bound to a device. */
  createSession(record: AppSessionCreation): Promise<void>;

  /** Resolves a bearer session. Expired sessions must behave as missing. */
  findByTokenHash(tokenHash: string): Promise<AppAccountRecord | null>;

  revokeToken(tokenHash: string): Promise<void>;
}

export interface CustomersRepository {
  /** Creates the identity row without overwriting richer webhook-sourced PII. */
  ensureExists(shopifyCustomerId: string): Promise<void>;

  upsert(record: CustomerRecord): Promise<void>;

  /** `customers/redact` — deletes the mirrored PII entirely. */
  delete(shopifyCustomerId: string): Promise<void>;

  /** `shop/redact` — this service is single-tenant, so this wipes every customer. */
  deleteAll(): Promise<void>;
}

export interface OrdersRepository {
  /**
   * Upserts by `shopifyOrderId` when present. For an apartado order with no
   * `shopifyOrderId` yet, matches on `attributionCode` instead — see
   * `webhooks/handlers.ts#handleOrdersWebhook`'s apartado-linking step.
   */
  upsertByShopifyOrderId(order: OrderRecord): Promise<void>;

  /** Links a not-yet-Shopify-recorded apartado row once its real order arrives. */
  linkApartadoByAttributionCode(attributionCode: string, shopifyOrderId: string): Promise<boolean>;

  /** Newest first — what "Mis pedidos" (`lib/features/account/`) renders. */
  listForCustomer(shopifyCustomerId: string): Promise<MirroredOrder[]>;

  /** `customers/redact` — the order itself is a business record and stays; only the PII link is dropped. */
  detachCustomer(shopifyCustomerId: string): Promise<void>;

  /** `shop/redact`. */
  deleteAll(): Promise<void>;
}

export interface WebhookEventsRepository {
  /** False when `webhookId` was already recorded — a retried delivery of the same event. */
  recordIfNew(event: WebhookEventRecord): Promise<boolean>;
  markProcessed(webhookId: string): Promise<void>;
}

export interface PushTokensRepository {
  /**
   * Inserts or refreshes a device token without allowing one customer to
   * overwrite a device already owned by another. False means ownership
   * conflict.
   */
  upsert(token: PushTokenRecord): Promise<boolean>;
  deleteAllForCustomer(shopifyCustomerId: string): Promise<void>;
  deleteAll(): Promise<void>;
}

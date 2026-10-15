import { fileURLToPath } from 'node:url';
import { randomBytes, randomUUID, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import express, { type Express, type NextFunction, type Request, type Response } from 'express';
import {
  ShopifyCustomerTokenVerifier,
  type CustomerTokenVerifier,
} from '../auth/customerTokenVerifier.js';
import { loadConfig } from '../config.js';
import { getPool, closePool } from '../db/pool.js';
import { PgCustomersRepository } from '../db/pgCustomersRepository.js';
import { PgAppAccountsRepository } from '../db/pgAppAccountsRepository.js';
import { PgOrdersRepository } from '../db/pgOrdersRepository.js';
import { PgPushTokensRepository } from '../db/pgPushTokensRepository.js';
import { PgWebhookEventsRepository, WebhookBusyError } from '../db/pgWebhookEventsRepository.js';
import { PgPrivacyRequestsRepository } from '../db/pgPrivacyRequestsRepository.js';
import { EngagementService } from '../engagement/application/engagementService.js';
import { registerEngagementRoutes, type EngagementRouteDeps } from '../engagement/api/routes.js';
import { registerInternalCatalogRoute } from '../engagement/api/internalCatalogRoute.js';
import { RegistrationCipher } from '../engagement/crypto/registrationCipher.js';
import { FirebaseAppCheckVerifier } from '../engagement/infrastructure/firebaseAppCheckVerifier.js';
import { FcmMessagingProvider } from '../engagement/infrastructure/fcmMessagingProvider.js';
import { GoogleAccessTokenProvider } from '../engagement/infrastructure/googleAccessTokenProvider.js';
import { PgEngagementRepository } from '../engagement/infrastructure/pgEngagementRepository.js';
import { PgShopifyCatalogEventProcessor } from '../engagement/infrastructure/pgShopifyCatalogEventProcessor.js';
import { PgEngagementPrivacyRepository } from '../engagement/infrastructure/pgEngagementPrivacyRepository.js';
import { ServerAdminAuthorizer, hashAdminBearerToken } from '../admin/authorizer.js';
import { registerAdminRoutes } from '../admin/routes.js';
import { resumeInterruptedSyncJobs } from '../admin/routes.js';
import { PgAdminPrincipalsRepository } from '../admin/pgAdminPrincipalsRepository.js';
import type { AdminAuthorizer } from '../admin/authorizer.js';
import { ShopifyAdminClient } from '../admin/shopifyAdminClient.js';
import type { ShopifyAdminWriteClient } from '../admin/shopifyAdminClient.js';
import type {
  AdminAuditLogger,
  AdminAuditReader,
  AdminIdempotencyRepository,
  AdminMutationRateLimiter,
} from '../admin/mutationPorts.js';
import { PgAdminAuditLogger, PgAdminIdempotencyRepository } from '../admin/pgMutationRepositories.js';
import { PgAdminFeaturedJobRepository } from '../admin/pgFeaturedJobRepository.js';
import type { AdminFeaturedJobRepository } from '../admin/featuredPorts.js';
import { PgAdminSyncJobRepository } from '../admin/pgSyncJobRepository.js';
import type { AdminSyncJobRepository } from '../admin/syncPorts.js';
import { SlidingWindowAdminRateLimiter } from '../admin/rateLimiter.js';
import {
  HttpExternalCatalogAdminClient,
  type ExternalCatalogAdminClient,
} from '../admin/externalCatalogClient.js';
import { logger } from '../logger.js';
import { PgRewardsRepository } from '../rewards/pgRewardsRepository.js';
import { loadRewardsEnv } from '../rewards/rewardsConfig.js';
import { registerRewardsRoutes } from '../rewards/routes.js';
import { RewardsService } from '../rewards/service.js';
import { DisabledDiscountAdapter } from '../rewards/shopifyDiscountAdapter.js';
import { bridgeDelivery, bridgeOrderPaid, refundReverseCents } from '../rewards/webhookBridge.js';
import { verifyShopifyWebhookHmac } from '../webhooks/verifyHmac.js';
import {
  handleCustomersDataRequest,
  handleCustomersRedact,
  handleOrdersWebhook,
  handleProductsWebhook,
  handleShopRedact,
  type HandlerDeps,
} from '../webhooks/handlers.js';
import type {
  ShopifyCustomerDataRequestWebhookPayload,
  ShopifyCustomerRedactWebhookPayload,
  ShopifyOrderWebhookPayload,
  ShopifyProductWebhookPayload,
  ShopifyShopRedactWebhookPayload,
} from '../webhooks/payloads.js';
import type { Platform } from '../domain/types.js';
import { AccountRegistrationConflictError } from '../domain/accountErrors.js';
import { AccountDeletionService } from '../privacy/accountDeletionService.js';
import { FirebaseAppDataEraser } from '../privacy/firebaseAppData.js';
import { ShopifyFreshLoginVerifier } from '../privacy/freshLogin.js';
import {
  PgAccountDeletionAuditRepository,
  PgAccountDeletionStateRepository,
} from '../privacy/pgAccountDeletionRepository.js';
import { PgCustomerDataEraser } from '../privacy/pgCustomerErasure.js';
import { registerAccountDeletionRoutes } from '../privacy/routes.js';
import { CustomerAccountOrderLookup } from '../privacy/shopifyOrderCheck.js';
import { ShopifyCustomerDataErasureClient } from '../privacy/shopifyErasure.js';

export interface ServerDeps extends HandlerDeps {
  readonly webhookSecret: string;
  /** When set, webhooks must present matching X-Shopify-Shop-Domain (F15). */
  readonly expectedShopDomain?: string;
  /** Optional readiness probe against PostgreSQL (F29). */
  readonly checkDatabase?: () => Promise<boolean>;
  readonly appAccounts: import('../domain/ports.js').AppAccountsRepository;
  readonly customerTokenVerifier: CustomerTokenVerifier;
  readonly adminAuthorizer?: AdminAuthorizer;
  readonly adminEnvironment?: 'staging' | 'production';
  readonly shopifyAdmin?: ShopifyAdminWriteClient;
  readonly featuredJobs?: AdminFeaturedJobRepository;
  readonly idempotency?: AdminIdempotencyRepository;
  readonly audit?: AdminAuditLogger;
  readonly auditReader?: AdminAuditReader;
  readonly rateLimiter?: AdminMutationRateLimiter;
  /** Sliding-window limiter for /accounts/register and /accounts/login. */
  readonly authRateLimiter?: AdminMutationRateLimiter;
  /** When false, first-party registration is closed; login remains for legacy users. */
  readonly legacyAccountRegistrationEnabled?: boolean;
  readonly mutationsEnabled?: boolean;
  readonly shopifyWritesEnabled?: boolean;
  readonly externalCatalog?: ExternalCatalogAdminClient;
  readonly externalWritesEnabled?: boolean;
  readonly syncJobs?: AdminSyncJobRepository;
  readonly engagement?: EngagementRouteDeps & { readonly internalCatalogEventSecret: string };
  /** Paquete F: Rewards. Ausente = programa no montado (rutas 404). */
  readonly rewards?: { readonly service: RewardsService };
  /** In-app account deletion. Absent in tests that do not exercise the route. */
  readonly accountDeletion?: AccountDeletionService;
}

const appSessionLifetimeMs = 180 * 24 * 60 * 60 * 1000;
const scryptAsync = promisify(scrypt);

function clientKey(req: Request): string {
  const forwarded = req.header('x-forwarded-for');
  if (typeof forwarded === 'string' && forwarded.trim() !== '') {
    return forwarded.split(',')[0]!.trim().slice(0, 128);
  }
  return (req.socket.remoteAddress ?? 'unknown').slice(0, 128);
}

function asNonEmptyString(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (trimmed === '' || trimmed.length > max) return null;
  return trimmed;
}

function allowAuth(deps: ServerDeps, req: Request, operation: string, res: Response): boolean {
  if (deps.authRateLimiter === undefined) return true;
  if (deps.authRateLimiter.allow(clientKey(req), operation)) return true;
  res.status(429).json({ error: 'rate_limited' });
  return false;
}

function hashToken(token: string): string {
  return hashAdminBearerToken(token);
}

function bearerToken(req: Request): string | null {
  const authorization = req.header('Authorization');
  if (!authorization?.startsWith('Bearer ')) return null;
  const token = authorization.slice('Bearer '.length).trim();
  return token === '' || token.length > 8192 || /\s/.test(token) ? null : token;
}

/**
 * Resolves customer identity server-side. Legacy Monetta sessions are accepted
 * only after they have an explicit Shopify customer linkage; every other
 * credential is verified by asking Shopify's Customer Account API who it
 * represents. No route trusts a customer id supplied by the caller.
 */
async function authenticatedCustomerId(
  deps: ServerDeps,
  req: Request,
  res: Response,
): Promise<string | null> {
  const token = bearerToken(req);
  if (token === null) {
    res.status(401).json({ error: 'unauthorized' });
    return null;
  }

  const appAccount = await deps.appAccounts.findByTokenHash(hashToken(token));
  if (appAccount !== null) {
    const customerId = canonicalShopifyCustomerId(appAccount.shopifyCustomerId);
    if (customerId === null) {
      res.status(403).json({ error: 'shopify_customer_not_linked' });
      return null;
    }
    return customerId;
  }

  try {
    const verifiedId = await deps.customerTokenVerifier.resolveCustomerId(token);
    if (verifiedId === null) {
      res.status(401).json({ error: 'unauthorized' });
      return null;
    }
    const customerId = canonicalShopifyCustomerId(verifiedId);
    if (customerId === null) {
      res.status(503).json({ error: 'authentication_unavailable' });
      return null;
    }
    return customerId;
  } catch (error) {
    // The verifier deliberately never places a token in its errors. Log only
    // the error class anyway, keeping that invariant even for injected code.
    logger.warn('customer authentication unavailable', {
      errorType: error instanceof Error ? error.name : typeof error,
    });
    res.status(503).json({ error: 'authentication_unavailable' });
    return null;
  }
}

function canonicalShopifyCustomerId(value: string | null): string | null {
  if (value === null) return null;
  if (/^[0-9]+$/.test(value)) return value;
  const gid = /^gid:\/\/shopify\/Customer\/([0-9]+)$/.exec(value);
  return gid?.[1] ?? null;
}

async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const derived = await scryptAsync(password, salt, 64) as Buffer;
  return `scrypt$${salt.toString('base64url')}$${derived.toString('base64url')}`;
}

async function passwordMatches(password: string, encoded: string): Promise<boolean> {
  const [algorithm, saltText, hashText] = encoded.split('$');
  if (algorithm !== 'scrypt' || !saltText || !hashText) return false;
  try {
    const expected = Buffer.from(hashText, 'base64url');
    const actual = await scryptAsync(password, Buffer.from(saltText, 'base64url'), expected.length) as Buffer;
    return expected.length === actual.length && timingSafeEqual(expected, actual);
  } catch {
    return false;
  }
}

function normalizeShopDomain(value: string): string {
  return value.trim().toLowerCase().replace(/^https?:\/\//, '').replace(/\/$/, '');
}

/**
 * Wraps a webhook route: verifies the HMAC against the *raw* body (captured
 * by `express.raw()` below — a JSON body-parser would already have
 * consumed and re-encoded it, and re-serializing is not guaranteed to
 * reproduce the exact bytes Shopify signed), validates the expected shop
 * when configured, extracts the required `X-Shopify-Webhook-Id` header,
 * and only then parses JSON and hands off to `handler`. A missing/invalid
 * signature, unexpected shop, or missing webhook id gets a 401/400 and
 * never reaches application logic.
 */
function shopifyWebhookRoute<Payload>(
  deps: ServerDeps,
  handler: (
    deps: ServerDeps,
    webhookId: string,
    payload: Payload,
    rawBody: Buffer,
    shopDomain: string | null,
  ) => Promise<void>,
) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const rawBody = req.body as Buffer;
      const signature = req.header('X-Shopify-Hmac-Sha256');
      if (!verifyShopifyWebhookHmac(rawBody, signature, deps.webhookSecret)) {
        res.status(401).json({ error: 'invalid_signature' });
        return;
      }

      const shopHeader = req.header('X-Shopify-Shop-Domain') ?? null;
      if (deps.expectedShopDomain && deps.expectedShopDomain.trim() !== '') {
        const expected = normalizeShopDomain(deps.expectedShopDomain);
        const received = shopHeader ? normalizeShopDomain(shopHeader) : '';
        if (received !== expected) {
          res.status(401).json({ error: 'unexpected_shop' });
          return;
        }
      }

      const webhookId = req.header('X-Shopify-Webhook-Id');
      if (!webhookId) {
        res.status(400).json({ error: 'missing_webhook_id' });
        return;
      }

      const payload = JSON.parse(rawBody.toString('utf8')) as Payload;
      await handler(deps, webhookId, payload, rawBody, shopHeader);
      res.status(200).json({ status: 'ok' });
    } catch (error) {
      next(error);
    }
  };
}

/**
 * Si el pedido llega pagado, alimenta Rewards (pendiente; mayoreo excluido).
 * Solo 'paid' genera; parciales/autorizados no. Idempotente por evento.
 */
async function bridgePaidIfApplicable(
  deps: ServerDeps,
  webhookId: string,
  topic: string,
  payload: ShopifyOrderWebhookPayload,
): Promise<void> {
  if (!deps.rewards) return;
  if ((payload.financial_status ?? '').toLowerCase() !== 'paid') return;
  try {
    await bridgeOrderPaid({
      service: deps.rewards.service,
      webhookId,
      topic,
      order: {
        id: payload.id,
        tags: payload.tags,
        customer: payload.customer,
        currency: payload.currency,
        note_attributes: payload.note_attributes
          ? [...payload.note_attributes]
          : undefined,
      },
    });
  } catch (error) {
    // El espejo ya quedo; Rewards reintenta por inbox. Nunca romper el 200 del mirror.
    logger.warn('rewards paid bridge failed', { error: String(error) });
  }
}

async function claimRewardsInbox(deps: ServerDeps, eventId: string): Promise<boolean> {
  // La idempotencia de negocio vive en el servicio; aqui solo se evita el
  // doble despacho dentro del mismo proceso ante reintentos inmediatos.
  void deps;
  void eventId;
  return true;
}

export function createApp(deps: ServerDeps): Express {
  const app = express();
  app.disable('x-powered-by');
  app.use((_req: Request, res: Response, next: NextFunction) => {
    const requestId = `req_${randomUUID()}`;
    res.locals.requestId = requestId;
    res.setHeader('X-Request-Id', requestId);
    next();
  });
  app.use((req: Request, res: Response, next: NextFunction) => {
    const startedAt = Date.now();
    res.once('finish', () => {
      logger.info('http request completed', {
        requestId: res.locals.requestId,
        method: req.method,
        path: req.path,
        status: res.statusCode,
        latencyMs: Date.now() - startedAt,
      });
    });
    next();
  });

  app.get('/livez', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/healthz', (_req: Request, res: Response) => {
    // Liveness only, deliberately — this service has no crawl/data-freshness
    // dimension the way catalog_monitor does; being able to accept
    // connections is the whole health story.
    res.status(200).json({ status: 'ok' });
  });

  app.get('/readyz', async (_req: Request, res: Response) => {
    if (!deps.checkDatabase) {
      res.status(200).json({ status: 'ok', database: 'unchecked' });
      return;
    }
    try {
      const ok = await deps.checkDatabase();
      if (!ok) {
        res.status(503).json({ status: 'not_ready', database: 'down' });
        return;
      }
      res.status(200).json({ status: 'ok', database: 'up' });
    } catch {
      res.status(503).json({ status: 'not_ready', database: 'down' });
    }
  });

  const raw = express.raw({ type: 'application/json', limit: '2mb' });

  app.post(
    '/webhooks/orders/create',
    raw,
    shopifyWebhookRoute(deps, async (d, id, payload: ShopifyOrderWebhookPayload, body, shop) => {
      await handleOrdersWebhook(d, id, 'orders/create', payload, body, shop);
      await bridgePaidIfApplicable(d, id, 'orders/create', payload);
    }),
  );
  app.post(
    '/webhooks/orders/updated',
    raw,
    shopifyWebhookRoute(deps, async (d, id, payload: ShopifyOrderWebhookPayload, body, shop) => {
      await handleOrdersWebhook(d, id, 'orders/updated', payload, body, shop);
      await bridgePaidIfApplicable(d, id, 'orders/updated', payload);
    }),
  );
  // Paquete F: cancelaciones, reembolsos y evidencia de entrega para Rewards.
  // Firma, tienda e id de webhook se verifican igual que el resto (wrapper).
  // La entrega solo libera con evidencia DELIVERED verificable (ver webhookBridge).
  app.post(
    '/webhooks/orders/cancelled',
    raw,
    shopifyWebhookRoute(deps, async (d, id, payload: ShopifyOrderWebhookPayload, body, shop) => {
      await handleOrdersWebhook(d, id, 'orders/updated', payload, body, shop);
      if (d.rewards) {
        const eventId = `orders/cancelled:${id}:cancelled:${String(payload.id)}`;
        const claimed = await claimRewardsInbox(d, eventId);
        if (claimed) {
          try {
            await d.rewards.service.onOrderCancelled({
              eventId,
              orderShopifyId: String(payload.id),
              reason: 'orders/cancelled',
            });
          } catch (error) {
            logger.warn('rewards cancel bridge failed', { error: String(error) });
          }
        }
      }
    }),
  );
  app.post(
    '/webhooks/refunds/create',
    raw,
    shopifyWebhookRoute(deps, async (d, id, payload: Record<string, unknown>, body, shop) => {
      void body;
      void shop;
      if (d.rewards) {
        const refund = payload as {
          order_id?: number;
          refund_line_items?: { line_item?: { price?: string | null }; quantity?: number }[];
        };
        const orderId = refund.order_id != null ? String(refund.order_id) : null;
        if (orderId !== null) {
          const eventId = `refunds/create:${id}:refund:${orderId}`;
          const claimed = await claimRewardsInbox(d, eventId);
          if (claimed) {
            try {
              const policy = d.rewards.service.policy();
              await d.rewards.service.onRefund({
                eventId,
                orderShopifyId: orderId,
                reverseCents: refundReverseCents(refund, policy.earnBps),
                reason: 'refunds/create',
              });
            } catch (error) {
              logger.warn('rewards refund bridge failed', { error: String(error) });
            }
          }
        }
      }
    }),
  );
  app.post(
    '/webhooks/fulfillment_events/create',
    raw,
    shopifyWebhookRoute(deps, async (d, id, payload: Record<string, unknown>, body, shop) => {
      void body;
      void shop;
      if (d.rewards) {
        const event = payload as { order_id?: number; status?: string | null; happened_at?: string | null };
        const orderId = event.order_id != null ? String(event.order_id) : null;
        if (orderId !== null) {
          try {
            await bridgeDelivery({
              service: d.rewards.service,
              webhookId: id,
              orderId,
              eventStatus: event.status ?? null,
              occurredAt: event.happened_at ?? null,
            });
          } catch (error) {
            logger.warn('rewards delivery bridge failed', { error: String(error) });
          }
        }
      }
    }),
  );
  app.post(
    '/webhooks/products/create',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyProductWebhookPayload, body, shop) =>
      handleProductsWebhook(d, id, 'products/create', payload, body, shop),
    ),
  );
  app.post(
    '/webhooks/products/update',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyProductWebhookPayload, body, shop) =>
      handleProductsWebhook(d, id, 'products/update', payload, body, shop),
    ),
  );
  app.post(
    '/webhooks/customers/data_request',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyCustomerDataRequestWebhookPayload, body, shop) =>
      handleCustomersDataRequest(d, id, payload, body, shop),
    ),
  );
  app.post(
    '/webhooks/customers/redact',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyCustomerRedactWebhookPayload, body, shop) =>
      handleCustomersRedact(d, id, payload, body, shop),
    ),
  );
  app.post(
    '/webhooks/shop/redact',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyShopRedactWebhookPayload, body, shop) =>
      handleShopRedact(d, id, payload, body, shop),
    ),
  );

  if (deps.engagement !== undefined) {
    registerInternalCatalogRoute(
      app,
      deps.engagement.service,
      deps.engagement.internalCatalogEventSecret,
      deps.engagement.now,
    );
  }

  app.use(express.json());

  if (deps.adminAuthorizer !== undefined) {
    registerAdminRoutes(app, {
      authorizer: deps.adminAuthorizer,
      environment: deps.adminEnvironment ?? 'staging',
      shopify: deps.shopifyAdmin,
      shopifyWrites: deps.shopifyAdmin,
      idempotency: deps.idempotency,
      audit: deps.audit,
      auditReader: deps.auditReader,
      rateLimiter: deps.rateLimiter,
      mutationsEnabled: deps.mutationsEnabled,
      shopifyWritesEnabled: deps.shopifyWritesEnabled,
      externalCatalog: deps.externalCatalog,
      externalWritesEnabled: deps.externalWritesEnabled,
      featuredJobs: deps.featuredJobs,
      syncJobs: deps.syncJobs,
      privacyRequests: deps.privacyRequests,
    });
  }

  if (deps.engagement !== undefined) {
    registerEngagementRoutes(app, deps.engagement);
  }

  if (deps.rewards !== undefined) {
    registerRewardsRoutes(app, {
      service: deps.rewards.service,
      authenticate: (req, res) => authenticatedCustomerId(deps, req, res),
    });
  }

  // First-party Monetta registration. Email is unverified profile metadata
  // only — never a claim of ownership and never an admin bootstrap signal.
  // Registration creates a new account; it never mutates an existing one via
  // deviceId (F02). Set legacyAccountRegistrationEnabled=false to close new
  // signups while preserving login for existing users (F19).
  app.post('/accounts/register', async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (deps.legacyAccountRegistrationEnabled === false) {
        res.status(403).json({ error: 'registration_disabled' });
        return;
      }
      if (!allowAuth(deps, req, 'accounts.register', res)) return;

      if (req.body === null || typeof req.body !== 'object' || Array.isArray(req.body)) {
        res.status(400).json({ error: 'invalid_request' });
        return;
      }
      const body = req.body as Record<string, unknown>;
      const emailRaw = asNonEmptyString(body.email, 254);
      const password = typeof body.password === 'string' ? body.password : null;
      const deviceId = asNonEmptyString(body.deviceId, 200);
      const displayNameRaw = body.displayName;
      const normalizedName = displayNameRaw === undefined || displayNameRaw === null
        ? null
        : asNonEmptyString(displayNameRaw, 120);
      if (
        displayNameRaw !== undefined && displayNameRaw !== null &&
        typeof displayNameRaw !== 'string'
      ) {
        res.status(400).json({ error: 'invalid_request' });
        return;
      }
      const normalizedEmail = emailRaw?.toLowerCase() ?? '';
      const emailLooksValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail);
      if (
        !emailLooksValid ||
        password === null || password.length < 8 || password.length > 128 ||
        deviceId === null ||
        (displayNameRaw !== undefined && displayNameRaw !== null && normalizedName === null)
      ) {
        res.status(400).json({ error: 'invalid_request' });
        return;
      }

      const token = randomBytes(32).toString('base64url');
      const expiresAt = new Date(Date.now() + appSessionLifetimeMs);
      const account = await deps.appAccounts.register({
        accountId: randomUUID(),
        email: normalizedEmail,
        displayName: normalizedName,
        passwordHash: await hashPassword(password),
        deviceId,
        tokenHash: hashToken(token),
        expiresAt,
      });
      res.status(201).json({
        account: {
          id: account.id,
          email: account.email,
          displayName: account.displayName,
          emailVerified: account.emailVerified,
        },
        session: { token, expiresAt: expiresAt.toISOString() },
      });
    } catch (error) {
      if (error instanceof AccountRegistrationConflictError) {
        // Same response for device and email conflicts: avoid account enumeration.
        res.status(409).json({ error: 'registration_conflict' });
        return;
      }
      if (typeof error === 'object' && error !== null && 'code' in error && error.code === '23505') {
        res.status(409).json({ error: 'registration_conflict' });
        return;
      }
      next(error);
    }
  });

  app.post('/accounts/login', async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!allowAuth(deps, req, 'accounts.login', res)) return;

      if (req.body === null || typeof req.body !== 'object' || Array.isArray(req.body)) {
        res.status(400).json({ error: 'invalid_request' });
        return;
      }
      const body = req.body as Record<string, unknown>;
      const emailRaw = asNonEmptyString(body.email, 254);
      const password = typeof body.password === 'string' ? body.password : null;
      const deviceId = asNonEmptyString(body.deviceId, 200);
      const normalizedEmail = emailRaw?.toLowerCase() ?? '';
      if (
        normalizedEmail === '' || password === null || password.length === 0 ||
        password.length > 128 || deviceId === null
      ) {
        res.status(400).json({ error: 'invalid_request' });
        return;
      }

      const credentials = await deps.appAccounts.findCredentialsByEmail(normalizedEmail);
      if (credentials === null || !await passwordMatches(password, credentials.passwordHash)) {
        res.status(401).json({ error: 'invalid_credentials' });
        return;
      }

      const token = randomBytes(32).toString('base64url');
      const expiresAt = new Date(Date.now() + appSessionLifetimeMs);
      await deps.appAccounts.createSession({
        accountId: credentials.id,
        deviceId,
        tokenHash: hashToken(token),
        expiresAt,
      });
      res.status(200).json({
        account: {
          id: credentials.id,
          email: credentials.email,
          displayName: credentials.displayName,
          emailVerified: credentials.emailVerified,
        },
        session: { token, expiresAt: expiresAt.toISOString() },
      });
    } catch (error) {
      next(error);
    }
  });

  app.get('/accounts/me', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const token = bearerToken(req);
      if (token === null) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      const account = await deps.appAccounts.findByTokenHash(hashToken(token));
      if (account === null) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      res.status(200).json({
        account: {
          id: account.id,
          email: account.email,
          displayName: account.displayName,
          emailVerified: account.emailVerified,
        },
      });
    } catch (error) {
      next(error);
    }
  });

  app.post('/accounts/logout', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const token = bearerToken(req);
      if (token === null) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      await deps.appAccounts.revokeToken(hashToken(token));
      res.status(200).json({ status: 'ok' });
    } catch (error) {
      next(error);
    }
  });

  app.post('/push-tokens', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const customerId = await authenticatedCustomerId(deps, req, res);
      if (customerId === null) return;

      const { deviceId, fcmToken, platform } = req.body as {
        deviceId?: string;
        fcmToken?: string;
        platform?: Platform;
      };
      if (
        !deviceId || deviceId.length > 200 ||
        !fcmToken || fcmToken.length > 4096 ||
        (platform !== 'ios' && platform !== 'android')
      ) {
        res.status(400).json({ error: 'invalid_request' });
        return;
      }
      // A shopper can opt into notifications before placing their first
      // order, so the webhook-maintained customer mirror may not exist yet.
      // Create only the identity row; never overwrite richer webhook PII.
      await deps.customers.ensureExists(customerId);
      const stored = await deps.pushTokens.upsert({
        deviceId,
        customerId,
        fcmToken,
        platform,
      });
      if (!stored) {
        res.status(409).json({ error: 'device_owned_by_another_customer' });
        return;
      }
      res.status(200).json({ status: 'ok' });
    } catch (error) {
      next(error);
    }
  });

  // "Mis pedidos" derives the customer from the bearer credential. There is
  // deliberately no /customers/:id/orders compatibility route: keeping a
  // caller-controlled id in the contract makes an authorization regression
  // far too easy.
  app.get('/customers/me/orders', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const customerId = await authenticatedCustomerId(deps, req, res);
      if (customerId === null) return;

      const orders = await deps.orders.listForCustomer(customerId);
      res.status(200).json({
        orders: orders.map((o) => ({
          id: o.id,
          shopifyOrderId: o.shopifyOrderId,
          source: o.source,
          attributionCode: o.attributionCode,
          financialStatus: o.financialStatus,
          fulfillmentStatus: o.fulfillmentStatus,
          totalAmount: o.totalAmount,
          currencyCode: o.currencyCode,
          placedAt: o.placedAt?.toISOString() ?? null,
        })),
      });
    } catch (error) {
      next(error);
    }
  });

  if (deps.accountDeletion !== undefined) {
    registerAccountDeletionRoutes(app, {
      deletion: deps.accountDeletion,
      authenticate: (req, res) => authenticatedCustomerId(deps, req, res),
    });
  }

  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (error instanceof WebhookBusyError) {
      res.setHeader('Retry-After', '5');
      res.status(503).json({ error: 'webhook_busy' });
      return;
    }
    logger.error('unhandled request error', { error: String(error) });
    res.status(500).json({ error: 'internal_error' });
  });

  return app;
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  const config = loadConfig();
  const pool = getPool();
  const appAccounts = new PgAppAccountsRepository(pool);
  const adminPrincipals = new PgAdminPrincipalsRepository(pool);
  const adminIdempotency = new PgAdminIdempotencyRepository(pool);
  const adminAudit = new PgAdminAuditLogger(pool);
  const adminFeaturedJobs = new PgAdminFeaturedJobRepository(pool);
  const adminSyncJobs = new PgAdminSyncJobRepository(pool);
  const adminRateLimiter = new SlidingWindowAdminRateLimiter();
  const customerTokenVerifier = new ShopifyCustomerTokenVerifier({
    shopDomain: config.shopDomain,
  });
  const adminAuthorizer = new ServerAdminAuthorizer({
    appAccounts,
    customerTokenVerifier,
    principals: adminPrincipals,
    ownerShopifyCustomerIds: config.ownerShopifyCustomerIds,
  });
  const authRateLimiter = new SlidingWindowAdminRateLimiter(20, 60_000);
  let shopifyAdmin: ShopifyAdminClient | undefined;
  if (
    config.shopDomain !== '' && config.shopifyAppClientId !== '' &&
    config.webhookSecret !== '' && config.shopifyHeadlessPublicationId !== ''
  ) {
    try {
      shopifyAdmin = new ShopifyAdminClient({
        shopDomain: config.shopDomain,
        clientId: config.shopifyAppClientId,
        clientSecret: config.webhookSecret,
        apiVersion: config.shopifyAdminApiVersion,
        headlessPublicationId: config.shopifyHeadlessPublicationId,
        featuredCollectionId: config.shopifyFeaturedCollectionId,
      });
    } catch (error) {
      logger.warn('Shopify Admin read integration unavailable', {
        errorType: error instanceof Error ? error.name : typeof error,
      });
    }
  }
  let externalCatalog: ExternalCatalogAdminClient | undefined;
  if (config.catalogMonitorBaseUrl !== '' && config.catalogMonitorServiceSecret !== '') {
    try {
      externalCatalog = new HttpExternalCatalogAdminClient({
        baseUrl: config.catalogMonitorBaseUrl,
        serviceSecret: config.catalogMonitorServiceSecret,
      });
    } catch (error) {
      logger.warn('External catalog admin integration unavailable', {
        errorType: error instanceof Error ? error.name : typeof error,
      });
    }
  }
  let engagement: ServerDeps['engagement'];
  let catalogEvents: HandlerDeps['catalogEvents'];
  if (config.notificationsEnabled) {
    const googleTokens = new GoogleAccessTokenProvider(
      config.firebaseClientEmail,
      config.firebasePrivateKey,
    );
    const engagementService = new EngagementService(
      new PgEngagementRepository(
        pool,
        RegistrationCipher.fromSecret(config.pushTokenEncryptionSecret),
      ),
      new FcmMessagingProvider(config.firebaseProjectId, googleTokens),
    );
    engagement = {
      service: engagementService,
      appCheck: new FirebaseAppCheckVerifier(config.firebaseProjectId, googleTokens),
      ownerAuthorizer: {
        authenticate: async (token) => {
          const actor = await adminAuthorizer.authenticate(token);
          return actor === null ? null : { actorId: actor.id };
        },
      },
      adminAuthorizer,
      internalCatalogEventSecret: config.internalCatalogEventSecret,
    };
    catalogEvents = new PgShopifyCatalogEventProcessor(pool, engagementService);
  }
  const firebaseDeletionReady = config.firebaseProjectId !== ''
    && config.firebaseClientEmail !== ''
    && config.firebasePrivateKey !== '';
  const shopifyErasureReady = config.shopDomain !== '' && (
    config.shopifyAdminAccessToken.length >= 16
    || (config.shopifyAppClientId !== '' && config.webhookSecret.length >= 16)
  );
  const deletionTokens = firebaseDeletionReady
    ? new GoogleAccessTokenProvider(config.firebaseClientEmail, config.firebasePrivateKey)
    : null;
  const accountDeletion = new AccountDeletionService({
    orders: new PgOrdersRepository(pool),
    state: new PgAccountDeletionStateRepository(pool),
    audit: new PgAccountDeletionAuditRepository(pool),
    appData: new FirebaseAppDataEraser({
      projectId: config.firebaseProjectId,
      accessToken: async () => {
        if (deletionTokens === null) throw new Error('firebase_not_configured');
        return deletionTokens.accessToken();
      },
    }),
    customerData: new PgCustomerDataEraser(pool),
    shopifyErasure: new ShopifyCustomerDataErasureClient({
      shopDomain: config.shopDomain,
      apiVersion: config.shopifyAdminApiVersion,
      adminAccessToken: config.shopifyAdminAccessToken,
      clientId: config.shopifyAppClientId,
      clientSecret: config.webhookSecret,
    }),
    shopifyOrders: new CustomerAccountOrderLookup({ shopDomain: config.shopDomain }),
    freshLogin: new ShopifyFreshLoginVerifier({
      shopDomain: config.shopDomain,
      customerTokens: customerTokenVerifier,
      customerAccountClientId: config.customerAccountClientId,
      maxAgeMs: config.accountDeletionReauthMaxAgeSeconds * 1000,
    }),
    ready: firebaseDeletionReady && shopifyErasureReady,
  });
  const rewardsEnv = loadRewardsEnv();
  const rewardsService = new RewardsService({
    rewards: new PgRewardsRepository(pool),
    env: rewardsEnv,
    discounts: new DisabledDiscountAdapter(),
    shopDomain: config.shopDomain !== '' ? config.shopDomain : null,
  });
  const app = createApp({
    appAccounts,
    customers: new PgCustomersRepository(pool),
    orders: new PgOrdersRepository(pool),
    webhookEvents: new PgWebhookEventsRepository(pool),
    pushTokens: new PgPushTokensRepository(pool),
    privacyRequests: new PgPrivacyRequestsRepository(pool),
    rewards: rewardsEnv.rewardsEnabled ? { service: rewardsService } : undefined,
    webhookSecret: config.webhookSecret,
    expectedShopDomain: config.shopDomain !== '' ? config.shopDomain : undefined,
    checkDatabase: async () => {
      const result = await pool.query('SELECT 1 AS ok');
      return (result.rowCount ?? 0) > 0;
    },
    customerTokenVerifier,
    adminAuthorizer,
    adminEnvironment: config.adminEnvironment,
    // Undefined is an intentional degraded state until all staging ids and
    // server-only credentials are configured.
    ...(shopifyAdmin === undefined ? {} : { shopifyAdmin }),
    idempotency: adminIdempotency,
    audit: adminAudit,
    auditReader: adminAudit,
    featuredJobs: adminFeaturedJobs,
    syncJobs: adminSyncJobs,
    rateLimiter: adminRateLimiter,
    authRateLimiter,
    legacyAccountRegistrationEnabled: config.legacyAccountRegistrationEnabled,
    mutationsEnabled: config.adminMutationsEnabled,
    shopifyWritesEnabled: config.adminShopifyWritesEnabled,
    ...(externalCatalog === undefined ? {} : { externalCatalog }),
    externalWritesEnabled: config.adminExternalWritesEnabled,
    engagement,
    catalogEvents,
    engagementPrivacy: config.notificationsEnabled
      ? new PgEngagementPrivacyRepository(pool)
      : undefined,
    accountDeletion,
  });
  const server = app.listen(config.port, () => {
    logger.info('accounts & orders API listening', { port: config.port });
  });

  // Phase F / F22: resume durable admin sync jobs left pending/running after restart.
  void resumeInterruptedSyncJobs({
    deps: {
      authorizer: adminAuthorizer,
      environment: config.adminEnvironment,
      ...(shopifyAdmin === undefined ? {} : { shopify: shopifyAdmin }),
      syncJobs: adminSyncJobs,
      audit: adminAudit,
    },
    olderThanMs: 2_000,
  }).then((count) => {
    if (count > 0) logger.info('resumed interrupted admin sync jobs', { count });
  }).catch((error) => {
    logger.warn('failed to resume interrupted admin sync jobs', {
      error: error instanceof Error ? error.message : String(error),
    });
  });

  let shuttingDown = false;
  const shutdown = (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info('API shutting down', { signal });
    server.close(async () => {
      await closePool();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.once('SIGTERM', () => shutdown('SIGTERM'));
  process.once('SIGINT', () => shutdown('SIGINT'));
}

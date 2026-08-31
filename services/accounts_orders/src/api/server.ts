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
import { PgWebhookEventsRepository } from '../db/pgWebhookEventsRepository.js';
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

export interface ServerDeps extends HandlerDeps {
  readonly webhookSecret: string;
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
  readonly mutationsEnabled?: boolean;
  readonly shopifyWritesEnabled?: boolean;
  readonly externalCatalog?: ExternalCatalogAdminClient;
  readonly externalWritesEnabled?: boolean;
  readonly syncJobs?: AdminSyncJobRepository;
  readonly engagement?: EngagementRouteDeps & { readonly internalCatalogEventSecret: string };
}

const appSessionLifetimeMs = 180 * 24 * 60 * 60 * 1000;
const scryptAsync = promisify(scrypt);

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

/**
 * Wraps a webhook route: verifies the HMAC against the *raw* body (captured
 * by `express.raw()` below — a JSON body-parser would already have
 * consumed and re-encoded it, and re-serializing is not guaranteed to
 * reproduce the exact bytes Shopify signed), extracts the required
 * `X-Shopify-Webhook-Id` header, and only then parses JSON and hands off to
 * `handler`. A missing/invalid signature or webhook id gets a 401/400 and
 * never reaches application logic.
 */
function shopifyWebhookRoute<Payload>(
  deps: ServerDeps,
  handler: (deps: ServerDeps, webhookId: string, payload: Payload, rawBody: Buffer) => Promise<void>,
) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const rawBody = req.body as Buffer;
      const signature = req.header('X-Shopify-Hmac-Sha256');
      if (!verifyShopifyWebhookHmac(rawBody, signature, deps.webhookSecret)) {
        res.status(401).json({ error: 'invalid_signature' });
        return;
      }

      const webhookId = req.header('X-Shopify-Webhook-Id');
      if (!webhookId) {
        res.status(400).json({ error: 'missing_webhook_id' });
        return;
      }

      const payload = JSON.parse(rawBody.toString('utf8')) as Payload;
      await handler(deps, webhookId, payload, rawBody);
      res.status(200).json({ status: 'ok' });
    } catch (error) {
      next(error);
    }
  };
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

  const raw = express.raw({ type: 'application/json', limit: '2mb' });

  app.post(
    '/webhooks/orders/create',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyOrderWebhookPayload, body) =>
      handleOrdersWebhook(d, id, 'orders/create', payload, body),
    ),
  );
  app.post(
    '/webhooks/orders/updated',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyOrderWebhookPayload, body) =>
      handleOrdersWebhook(d, id, 'orders/updated', payload, body),
    ),
  );
  app.post(
    '/webhooks/products/create',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyProductWebhookPayload, body) =>
      handleProductsWebhook(d, id, 'products/create', payload, body),
    ),
  );
  app.post(
    '/webhooks/products/update',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyProductWebhookPayload, body) =>
      handleProductsWebhook(d, id, 'products/update', payload, body),
    ),
  );
  app.post(
    '/webhooks/customers/data_request',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyCustomerDataRequestWebhookPayload, body) =>
      handleCustomersDataRequest(d, id, payload, body),
    ),
  );
  app.post(
    '/webhooks/customers/redact',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyCustomerRedactWebhookPayload, body) =>
      handleCustomersRedact(d, id, payload, body),
    ),
  );
  app.post(
    '/webhooks/shop/redact',
    raw,
    shopifyWebhookRoute(deps, (d, id, payload: ShopifyShopRedactWebhookPayload, body) =>
      handleShopRedact(d, id, payload, body),
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
    });
  }

  if (deps.engagement !== undefined) {
    registerEngagementRoutes(app, deps.engagement);
  }

  // First-party, device-bound Monetta registration. Email is intentionally
  // unverified and is profile metadata only: this endpoint does not claim
  // email ownership or provide cross-device recovery. The opaque bearer
  // token is the credential and only its SHA-256 hash is stored.
  app.post('/accounts/register', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { email, password, displayName, deviceId } = req.body as {
        email?: string;
        password?: string;
        displayName?: string | null;
        deviceId?: string;
      };
      const normalizedEmail = email?.trim().toLowerCase() ?? '';
      const normalizedName = displayName?.trim() || null;
      const emailLooksValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail);
      if (
        !emailLooksValid || normalizedEmail.length > 254 ||
        !password || password.length < 8 || password.length > 128 ||
        !deviceId || deviceId.length > 200 ||
        (normalizedName !== null && normalizedName.length > 120)
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
      if (typeof error === 'object' && error !== null && 'code' in error && error.code === '23505') {
        res.status(409).json({ error: 'email_already_registered' });
        return;
      }
      next(error);
    }
  });

  app.post('/accounts/login', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { email, password, deviceId } = req.body as {
        email?: string;
        password?: string;
        deviceId?: string;
      };
      const normalizedEmail = email?.trim().toLowerCase() ?? '';
      if (!normalizedEmail || !password || password.length > 128 || !deviceId || deviceId.length > 200) {
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

  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
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
    ownerEmails: config.ownerEmails,
    ownerShopifyCustomerIds: config.ownerShopifyCustomerIds,
  });
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
  const app = createApp({
    appAccounts,
    customers: new PgCustomersRepository(pool),
    orders: new PgOrdersRepository(pool),
    webhookEvents: new PgWebhookEventsRepository(pool),
    pushTokens: new PgPushTokensRepository(pool),
    webhookSecret: config.webhookSecret,
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
    mutationsEnabled: config.adminMutationsEnabled,
    shopifyWritesEnabled: config.adminShopifyWritesEnabled,
    ...(externalCatalog === undefined ? {} : { externalCatalog }),
    externalWritesEnabled: config.adminExternalWritesEnabled,
    engagement,
    catalogEvents,
    engagementPrivacy: config.notificationsEnabled
      ? new PgEngagementPrivacyRepository(pool)
      : undefined,
  });
  const server = app.listen(config.port, () => {
    logger.info('accounts & orders API listening', { port: config.port });
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

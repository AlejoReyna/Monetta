import { fileURLToPath } from 'node:url';
import { createHash, randomBytes, randomUUID, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import express, { type Express, type NextFunction, type Request, type Response } from 'express';
import { loadConfig } from '../config.js';
import { getPool, closePool } from '../db/pool.js';
import { PgCustomersRepository } from '../db/pgCustomersRepository.js';
import { PgAppAccountsRepository } from '../db/pgAppAccountsRepository.js';
import { PgOrdersRepository } from '../db/pgOrdersRepository.js';
import { PgPushTokensRepository } from '../db/pgPushTokensRepository.js';
import { PgWebhookEventsRepository } from '../db/pgWebhookEventsRepository.js';
import { logger } from '../logger.js';
import { verifyShopifyWebhookHmac } from '../webhooks/verifyHmac.js';
import {
  handleCustomersDataRequest,
  handleCustomersRedact,
  handleOrdersWebhook,
  handleShopRedact,
  type HandlerDeps,
} from '../webhooks/handlers.js';
import type {
  ShopifyCustomerDataRequestWebhookPayload,
  ShopifyCustomerRedactWebhookPayload,
  ShopifyOrderWebhookPayload,
  ShopifyShopRedactWebhookPayload,
} from '../webhooks/payloads.js';
import type { Platform } from '../domain/types.js';

export interface ServerDeps extends HandlerDeps {
  readonly webhookSecret: string;
  readonly appAccounts: import('../domain/ports.js').AppAccountsRepository;
}

const appSessionLifetimeMs = 180 * 24 * 60 * 60 * 1000;
const scryptAsync = promisify(scrypt);

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function bearerToken(req: Request): string | null {
  const authorization = req.header('Authorization');
  if (!authorization?.startsWith('Bearer ')) return null;
  const token = authorization.slice('Bearer '.length).trim();
  return token === '' ? null : token;
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

  // Push-token registration. Deliberately unauthenticated for now — see
  // README.md § "Known limitations". Internal/prototype status only, the
  // same posture services/catalog_monitor ships its live-crawl gate with.
  app.use(express.json());

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
      const { deviceId, customerId, fcmToken, platform } = req.body as {
        deviceId?: string;
        customerId?: string | null;
        fcmToken?: string;
        platform?: Platform;
      };
      if (!deviceId || !fcmToken || (platform !== 'ios' && platform !== 'android')) {
        res.status(400).json({ error: 'invalid_request' });
        return;
      }
      await deps.pushTokens.upsert({
        deviceId,
        customerId: customerId ?? null,
        fcmToken,
        platform,
      });
      res.status(200).json({ status: 'ok' });
    } catch (error) {
      next(error);
    }
  });

  // "Mis pedidos" (lib/features/account/) — unifies real Shopify checkout
  // orders and hand-entered WhatsApp apartado orders, since both land in
  // orders_mirror the same way (§ 7 of README.md). Deliberately
  // unauthenticated for now — same prototype-status caveat as
  // POST /push-tokens above, see README.md § "Known limitations": a
  // shopifyCustomerId in the URL is trusted as-is rather than verified
  // against the caller's own access token.
  app.get('/customers/:shopifyCustomerId/orders', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { shopifyCustomerId } = req.params;
      if (!shopifyCustomerId) {
        res.status(400).json({ error: 'missing_shopify_customer_id' });
        return;
      }
      const orders = await deps.orders.listForCustomer(shopifyCustomerId);
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
  const app = createApp({
    appAccounts: new PgAppAccountsRepository(pool),
    customers: new PgCustomersRepository(pool),
    orders: new PgOrdersRepository(pool),
    webhookEvents: new PgWebhookEventsRepository(pool),
    pushTokens: new PgPushTokensRepository(pool),
    webhookSecret: config.webhookSecret,
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

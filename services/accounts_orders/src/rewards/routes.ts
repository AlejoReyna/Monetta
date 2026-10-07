import type { Express, NextFunction, Request, Response } from 'express';
import type { RewardsService } from './service.js';

export interface RewardsRouteDeps {
  readonly service: RewardsService;
  /** Resuelve identidad verificada (Shopify customer id canonico) o responde 401/403/503. */
  readonly authenticate: (req: Request, res: Response) => Promise<string | null>;
}

function asyncRoute(handler: (req: Request, res: Response) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction) => {
    handler(req, res).catch(next);
  };
}

function errorCode(error: unknown): string {
  if (typeof error === 'object' && error !== null && 'code' in error && typeof error.code === 'string') {
    return error.code;
  }
  return 'internal_error';
}

function errorStatus(code: string): number {
  switch (code) {
    case 'quote_not_found':
    case 'not_found': return 404;
    case 'invalid_cart':
    case 'invalid_amount':
    case 'invalid_idempotency_key':
    case 'invalid_quantity':
    case 'invalid_price': return 400;
    case 'quote_expired':
    case 'already_settled':
    case 'discount_already_used': return 409;
    case 'redemption_disabled':
    case 'wholesale_redeem_undecided': return 409;
    case 'exceeds_limit':
    case 'insufficient_balance': return 422;
    case 'reconciliation_required': return 409;
    default: return 500;
  }
}

/** Accepts a numeric order id or an Order GID and returns the stored numeric id, or null. */
function canonicalShopifyOrderId(value: string): string | null {
  if (/^[0-9]+$/.test(value)) return value;
  const gid = /^gid:\/\/shopify\/Order\/([0-9]+)$/.exec(value);
  return gid?.[1] ?? null;
}

/** Rutas cliente Rewards V1. Identidad siempre del credential; jamas customer id del body. */
export function registerRewardsRoutes(app: Express, deps: RewardsRouteDeps): void {
  app.get('/customers/me/rewards', asyncRoute(async (req, res) => {
    const customerId = await deps.authenticate(req, res);
    if (customerId === null) return;
    res.status(200).json(await deps.service.summary(customerId));
  }));

  app.get('/customers/me/rewards/activity', asyncRoute(async (req, res) => {
    const customerId = await deps.authenticate(req, res);
    if (customerId === null) return;
    const limitRaw = typeof req.query.limit === 'string' ? Number.parseInt(req.query.limit, 10) : 20;
    const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 100) : 20;
    const cursor = typeof req.query.cursor === 'string' ? req.query.cursor : null;
    // Acceso via servicio: reutiliza summary.ensure + repositorio interno.
    const service = deps.service as unknown as {
      deps: { rewards: {
        ensureAccount(id: string): Promise<void>;
        activity(id: string, limit: number, cursor?: string | null): Promise<unknown>;
      } };
    };
    await service.deps.rewards.ensureAccount(customerId);
    res.status(200).json(await service.deps.rewards.activity(customerId, limit, cursor));
  }));

  app.get('/customers/me/orders/:id/rewards', asyncRoute(async (req, res) => {
    const customerId = await deps.authenticate(req, res);
    if (customerId === null) return;
    const rawOrderId = String(req.params.id ?? '').trim();
    if (rawOrderId === '' || rawOrderId.length > 64) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const orderId = canonicalShopifyOrderId(rawOrderId);
    if (orderId === null) {
      res.status(400).json({ error: 'invalid_request' });
      return;
    }
    const service = deps.service as unknown as {
      deps: { rewards: {
        orderRewards(a: string, o: string): Promise<unknown>;
      } };
    };
    const view = await service.deps.rewards.orderRewards(customerId, orderId);
    if (view === null) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    res.status(200).json(view);
  }));

  app.post('/customers/me/rewards/quotes', asyncRoute(async (req, res) => {
    const customerId = await deps.authenticate(req, res);
    if (customerId === null) return;
    try {
      const body = (req.body ?? {}) as Record<string, unknown>;
      const result = await deps.service.quote(customerId, {
        cartRevision: typeof body.cartRevision === 'string' ? body.cartRevision : '',
        lines: Array.isArray(body.lines) ? (body.lines as never[]) : [],
        isWholesaleCart: body.isWholesaleCart === true,
      });
      res.status(201).json(result);
    } catch (error) {
      const code = errorCode(error);
      res.status(errorStatus(code)).json({ error: code });
    }
  }));

  app.post('/customers/me/rewards/redemptions', asyncRoute(async (req, res) => {
    const customerId = await deps.authenticate(req, res);
    if (customerId === null) return;
    try {
      const body = (req.body ?? {}) as Record<string, unknown>;
      const amount = typeof body.amountCents === 'number' ? body.amountCents : Number.NaN;
      const result = await deps.service.redeem({
        accountId: customerId,
        quoteId: typeof body.quoteId === 'string' ? body.quoteId : '',
        amountCents: amount,
        isWholesaleCart: body.isWholesaleCart === true,
        idempotencyKey: body.idempotencyKey,
      });
      res.status(result.reused ? 200 : 201).json(result);
    } catch (error) {
      const code = errorCode(error);
      const withMessage = error as { message?: string };
      res.status(errorStatus(code)).json(
        typeof withMessage?.message === 'string' && code !== 'internal_error'
          ? { error: code, message: withMessage.message }
          : { error: code },
      );
    }
  }));

  app.post('/customers/me/rewards/redemptions/:id/release', asyncRoute(async (req, res) => {
    const customerId = await deps.authenticate(req, res);
    if (customerId === null) return;
    try {
      const result = await deps.service.releaseRedemption(customerId, String(req.params.id));
      res.status(200).json(result);
    } catch (error) {
      const code = errorCode(error);
      res.status(errorStatus(code)).json({ error: code });
    }
  }));
}

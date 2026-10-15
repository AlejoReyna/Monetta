import type { Express, NextFunction, Request, Response } from 'express';
import { AccountDeletionService } from './accountDeletionService.js';
import type { DeletionCredential } from './ports.js';

export function registerAccountDeletionRoutes(
  app: Express,
  options: {
    readonly deletion: AccountDeletionService;
    readonly authenticate: (
      req: Request,
      res: Response,
    ) => Promise<{ readonly customerId: string; readonly credential: DeletionCredential } | null>;
  },
): void {
  app.post(
    '/customers/me/account-deletion/precheck',
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const shopper = await options.authenticate(req, res);
        if (shopper === null) return;
        const accessToken = bearer(req);
        if (accessToken === null) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }
        const outcome = await options.deletion.precheck(
          shopper.customerId,
          accessToken,
          shopper.credential,
        );
        const special = specialBody(outcome.result);
        if (special !== null) {
          res.status(special.status).json(special.body);
          return;
        }
        res.status(200).json(publicBody(outcome));
      } catch (error) {
        next(error);
      }
    },
  );

  app.post(
    '/customers/me/account-deletion',
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const accessToken = bearer(req);
        const idToken = headerToken(req, 'x-monetta-id-token');
        if (accessToken === null || idToken === null) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }
        const outcome = await options.deletion.execute(
          accessToken,
          idToken,
          headerToken(req, 'x-monetta-legacy-session'),
        );
        switch (outcome.result) {
          case 'deleted':
            res.status(200).json({
              result: 'deleted',
              shopifyDataErasure: 'requested',
            });
            return;
          case 'blocked_open_order':
            res.status(200).json(blockedBody(outcome.order));
            return;
          case 'too_many_orders':
            res.status(200).json({ result: 'too_many_orders' });
            return;
          case 'email_mismatch':
            res.status(200).json({
              result: 'email_mismatch',
              maskedEmail: outcome.maskedEmail,
            });
            return;
          case 'stale_reauthentication':
            res.status(401).json({ error: 'stale_reauthentication' });
            return;
          case 'unauthorized':
            res.status(401).json({ error: 'unauthorized' });
            return;
          case 'unavailable':
            res.status(503).json({ error: 'deletion_unavailable' });
            return;
          case 'order_check_unavailable':
            res.status(503).json({ error: 'order_check_unavailable' });
            return;
          case 'failed':
            res.status(503).json({ error: 'deletion_incomplete' });
            return;
          default:
            res.status(503).json({ error: 'deletion_incomplete' });
        }
      } catch (error) {
        next(error);
      }
    },
  );

  app.post(
    '/customers/me/account-deletion/email-match',
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const accessToken = bearer(req);
        const legacySession = headerToken(req, 'x-monetta-legacy-session');
        if (accessToken === null || legacySession === null) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }
        const outcome = await options.deletion.matchLegacyEmail(accessToken, legacySession);
        if (outcome.result === 'email_match') {
          res.status(200).json({ result: 'email_match' });
          return;
        }
        if (outcome.result === 'email_mismatch') {
          res.status(200).json({
            result: 'email_mismatch',
            maskedEmail: outcome.maskedEmail,
          });
          return;
        }
        if (outcome.result === 'unauthorized') {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }
        res.status(503).json({ error: 'deletion_unavailable' });
      } catch (error) {
        next(error);
      }
    },
  );
}

function publicBody(outcome: Awaited<ReturnType<AccountDeletionService['precheck']>>): unknown {
  if (outcome.result === 'blocked_open_order') return blockedBody(outcome.order);
  if (outcome.result === 'deleted') {
    return { result: 'deleted', shopifyDataErasure: 'requested' };
  }
  if (outcome.result !== 'clear') {
    throw new Error(outcome.result);
  }
  return { result: 'clear' };
}

function blockedBody(order: {
  readonly id: string;
  readonly shopifyOrderId: string | null;
  readonly reason: string;
  readonly orderName?: string;
}): unknown {
  return {
    result: 'blocked_open_order',
    order: {
      id: order.id,
      shopifyOrderId: order.shopifyOrderId,
      reason: publicReason(order.reason),
      ...(order.orderName ? { orderName: order.orderName } : {}),
    },
  };
}

function publicReason(reason: string): string {
  if (
    reason === 'refund_in_progress' ||
    reason === 'refund_review' ||
    reason === 'payment_review' ||
    reason === 'unpaid_or_pending' ||
    reason === 'unfulfilled'
  ) {
    return reason;
  }
  return 'unpaid_or_pending';
}

function specialBody(result: string): { readonly status: number; readonly body: unknown } | null {
  if (result === 'order_check_unavailable') {
    return { status: 503, body: { error: 'order_check_unavailable' } };
  }
  if (result === 'reauth_required') return { status: 200, body: { result: 'reauth_required' } };
  if (result === 'too_many_orders') return { status: 200, body: { result: 'too_many_orders' } };
  return null;
}

function bearer(req: Request): string | null {
  const authorization = req.header('Authorization');
  if (!authorization?.startsWith('Bearer ')) return null;
  const token = authorization.slice('Bearer '.length).trim();
  return token === '' || token.length > 8192 || /\s/.test(token) ? null : token;
}

function headerToken(req: Request, name: string): string | null {
  const value = req.header(name)?.trim() ?? '';
  return value === '' || value.length > 8192 || /\s/.test(value) ? null : value;
}

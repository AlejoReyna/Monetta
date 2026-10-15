import type { Express, NextFunction, Request, Response } from 'express';
import { AccountDeletionService } from './accountDeletionService.js';

export function registerAccountDeletionRoutes(
  app: Express,
  options: {
    readonly deletion: AccountDeletionService;
    readonly authenticate: (req: Request, res: Response) => Promise<string | null>;
  },
): void {
  app.post(
    '/customers/me/account-deletion/precheck',
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const customerId = await options.authenticate(req, res);
        if (customerId === null) return;
        const accessToken = bearer(req);
        if (accessToken === null) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }
        const outcome = await options.deletion.precheck(customerId, accessToken);
        if (outcome.result === 'order_check_unavailable') {
          res.status(503).json({ error: 'order_check_unavailable' });
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
        const outcome = await options.deletion.execute(accessToken, idToken);
        switch (outcome.result) {
          case 'deleted':
            res.status(200).json({
              result: 'deleted',
              shopifyDataErasure: 'requested',
            });
            return;
          case 'blocked_open_order':
            res.status(200).json({
              result: 'blocked_open_order',
              order: {
                id: outcome.order.id,
                shopifyOrderId: outcome.order.shopifyOrderId,
              },
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
}

function publicBody(outcome: Awaited<ReturnType<AccountDeletionService['precheck']>>): unknown {
  if (outcome.result === 'blocked_open_order') {
    return {
      result: 'blocked_open_order',
      order: {
        id: outcome.order.id,
        shopifyOrderId: outcome.order.shopifyOrderId,
      },
    };
  }
  if (outcome.result === 'deleted') {
    return { result: 'deleted', shopifyDataErasure: 'requested' };
  }
  if (outcome.result === 'order_check_unavailable') {
    throw new Error('order_check_unavailable');
  }
  return { result: 'clear' };
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

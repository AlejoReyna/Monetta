import { createHmac, timingSafeEqual } from 'node:crypto';
import express, { type Express, type NextFunction, type Request, type Response } from 'express';
import type { EngagementService } from '../application/engagementService.js';
import type { CatalogEventInput } from '../domain/types.js';

const replayWindowMs = 5 * 60 * 1000;

export function registerInternalCatalogRoute(
  app: Express,
  service: EngagementService,
  secret: string,
  now: () => Date = () => new Date(),
): void {
  const raw = express.raw({ type: 'application/json', limit: '256kb' });
  app.post(
    '/internal/catalog-events',
    raw,
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (secret.length < 32) {
          res.status(503).json({ error: 'catalog_event_ingress_not_configured' });
          return;
        }
        const timestamp = req.header('X-Monetta-Timestamp');
        const signature = req.header('X-Monetta-Signature');
        const instant = timestamp === undefined ? null : new Date(timestamp);
        if (
          instant === null || Number.isNaN(instant.getTime()) ||
          Math.abs(now().getTime() - instant.getTime()) > replayWindowMs ||
          !validSignature(req.body as Buffer, timestamp!, signature, secret)
        ) {
          res.status(401).json({ error: 'invalid_internal_signature' });
          return;
        }
        const decoded = JSON.parse((req.body as Buffer).toString('utf8')) as unknown;
        const event = parseCatalogEvent(decoded);
        if (event === null) {
          res.status(400).json({ error: 'invalid_request' });
          return;
        }
        const result = await service.ingestCatalogEvent(event);
        res.status(result.accepted ? 202 : 200).json({
          status: result.accepted ? 'accepted' : 'duplicate',
          campaignId: result.campaignId,
        });
      } catch (error) {
        next(error);
      }
    },
  );
}

function validSignature(
  body: Buffer,
  timestamp: string,
  header: string | undefined,
  secret: string,
): boolean {
  if (header === undefined || !/^[0-9a-f]{64}$/i.test(header)) return false;
  const expected = createHmac('sha256', secret)
    .update(timestamp)
    .update('.')
    .update(body)
    .digest();
  const supplied = Buffer.from(header, 'hex');
  return supplied.length === expected.length && timingSafeEqual(expected, supplied);
}

function parseCatalogEvent(value: unknown): CatalogEventInput | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const eventId = stringValue(record.eventId, 200);
  const eventType = record.eventType;
  const source = stringValue(record.source, 120);
  const productKey = stringValue(record.productKey, 300);
  const occurredAt = typeof record.occurredAt === 'string' ? new Date(record.occurredAt) : null;
  const after = plainObject(record.after);
  const before = record.before === null ? null : plainObject(record.before);
  if (
    eventId === null || source === null || productKey === null || after === null ||
    occurredAt === null || Number.isNaN(occurredAt.getTime()) ||
    (record.before !== null && before === null) ||
    (eventType !== 'catalog.product.created' &&
      eventType !== 'catalog.product.restocked' &&
      eventType !== 'catalog.product.price_dropped')
  ) {
    return null;
  }
  // F28: do not accept retired external-catalog event sources or keys.
  if (source === 'external' || source.startsWith('external') || productKey.startsWith('external:')) {
    return null;
  }
  if (!productKey.startsWith('shopify:')) {
    return null;
  }
  return { eventId, eventType, source, productKey, occurredAt, before, after };
}

function stringValue(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' || trimmed.length > max ? null : trimmed;
}

function plainObject(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

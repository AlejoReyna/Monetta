import { createHmac, timingSafeEqual } from 'node:crypto';
import type { Express, NextFunction, Request, Response } from 'express';
import { SOURCE_IDS, SOURCES, type SourceId } from '../domain/types.js';
import { evaluateSourceHealth, type SourceHealth } from '../monitor/health.js';
import type { CrawlRunRepository, ProductRepository } from '../crawl/ports.js';
import {
  validateSourcePolicy,
  type SourcePolicy,
  type SourcePolicyRepository,
} from '../admin/sourcePolicy.js';
import type { InternalRequestReplayRepository } from './internalReplay.js';

const MAX_CLOCK_SKEW_MS = 5 * 60 * 1_000;

export interface InternalAdminDeps {
  readonly products: ProductRepository;
  readonly crawlRuns: CrawlRunRepository;
  readonly policies: SourcePolicyRepository;
  readonly secret: string;
  readonly replay?: InternalRequestReplayRepository;
  readonly now?: () => Date;
  readonly enabledSourceIds?: readonly SourceId[];
}

export function registerInternalAdminRoutes(app: Express, deps: InternalAdminDeps): void {
  const seenRequestIds = new Map<string, number>();
  app.get('/internal/admin/sources', signedRequest(deps, seenRequestIds), asyncRoute(async (_req, res) => {
    const sources = await sourceViews(deps);
    res.status(200).json({
      schemaVersion: 1,
      generatedAt: (deps.now ?? (() => new Date()))().toISOString(),
      sources,
    });
  }));

  app.get('/internal/admin/sources/:sourceId', signedRequest(deps, seenRequestIds), asyncRoute(async (req, res) => {
    const sourceId = sourceIdValue(req.params.sourceId);
    if (sourceId === null) {
      res.status(404).json({ error: 'source_not_found' });
      return;
    }
    const view = (await sourceViews(deps)).find((source) => source.id === sourceId);
    if (view === undefined) {
      res.status(404).json({ error: 'source_not_found' });
      return;
    }
    res.status(200).json({ source: view });
  }));

  app.put('/internal/admin/sources/:sourceId', signedRequest(deps, seenRequestIds), asyncRoute(async (req, res) => {
    const sourceId = sourceIdValue(req.params.sourceId);
    if (sourceId === null) {
      res.status(404).json({ error: 'source_not_found' });
      return;
    }
    const body = req.body as Record<string, unknown>;
    const error = validateSourcePolicy({
      enabled: body.enabled,
      itemLimit: body.itemLimit,
      baseCommissionBps: body.baseCommissionBps,
      highValueCommissionBps: body.highValueCommissionBps,
      highValueThresholdMxn: body.highValueThresholdMxn,
    });
    if (error !== null) {
      res.status(422).json({ error });
      return;
    }
    const policy = await deps.policies.upsert({
      sourceId,
      enabled: body.enabled as boolean,
      itemLimit: body.itemLimit as number,
      baseCommissionBps: body.baseCommissionBps as number,
      highValueCommissionBps: body.highValueCommissionBps as number,
      highValueThresholdMxn: body.highValueThresholdMxn as number,
    });
    const [health, products] = await Promise.all([
      healthFor(deps, sourceId),
      deps.products.getActiveProducts(sourceId),
    ]);
    res.status(200).json({ source: sourceJson(sourceId, policy, health, products.length) });
  }));
}

function asyncRoute(
  handler: (req: Request, res: Response) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction) => {
    void handler(req, res).catch(next);
  };
}

type SourceView = ReturnType<typeof sourceJson>;

async function sourceViews(deps: InternalAdminDeps): Promise<SourceView[]> {
  const ids = deps.enabledSourceIds ?? SOURCE_IDS;
  const stored = new Map((await deps.policies.list()).map((policy) => [policy.sourceId, policy]));
  return Promise.all(ids.map(async (sourceId) => {
    const policy = stored.get(sourceId) ?? defaultPolicy(sourceId, deps.now);
    const [health, products] = await Promise.all([
      healthFor(deps, sourceId),
      deps.products.getActiveProducts(sourceId),
    ]);
    return sourceJson(sourceId, policy, health, products.length);
  }));
}

async function healthFor(deps: InternalAdminDeps, sourceId: SourceId): Promise<SourceHealth> {
  return evaluateSourceHealth(sourceId, deps.crawlRuns, deps.now?.());
}

function defaultPolicy(sourceId: SourceId, now?: () => Date): SourcePolicy {
  return {
    sourceId,
    enabled: true,
    itemLimit: SOURCES[sourceId].vertical === 'perfumes' ? 12 : 8,
    baseCommissionBps: 2_200,
    highValueCommissionBps: 1_400,
    highValueThresholdMxn: 4_000,
    updatedAt: (now ?? (() => new Date()))(),
  };
}

function sourceJson(
  sourceId: SourceId,
  policy: SourcePolicy,
  health: SourceHealth,
  itemCount: number,
) {
  return {
    id: sourceId,
    merchant: SOURCES[sourceId].merchant,
    enabled: policy.enabled,
    itemLimit: policy.itemLimit,
    baseCommissionRate: policy.baseCommissionBps / 10_000,
    highValueCommissionRate: policy.highValueCommissionBps / 10_000,
    highValueThreshold: policy.highValueThresholdMxn,
    itemCount,
    lastSuccessfulRunAt: health.lastSuccessfulRunAt?.toISOString() ?? null,
    health: {
      status: health.status === 'healthy' ? 'ready' : 'degraded',
      reasons: health.reasons,
      freshnessHours: health.freshnessHours,
      lastRequiredFieldCoverage: health.lastRequiredFieldCoverage,
    },
    updatedAt: policy.updatedAt.toISOString(),
  };
}

function sourceIdValue(value: string | undefined): SourceId | null {
  return value !== undefined && (SOURCE_IDS as readonly string[]).includes(value)
    ? value as SourceId
    : null;
}

function signedRequest(deps: InternalAdminDeps, seenRequestIds: Map<string, number>) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const timestamp = req.header('X-Monetta-Timestamp') ?? '';
    const signature = req.header('X-Monetta-Signature') ?? '';
    const requestId = req.header('X-Monetta-Request-Id') ?? '';
    const parsed = Number(timestamp);
    if (!/^\d{10,13}$/.test(timestamp) || !Number.isFinite(parsed) ||
        !/^req_[0-9a-f-]{16,80}$/i.test(requestId) ||
        Math.abs((deps.now ?? (() => new Date()))().getTime() - parsed) > MAX_CLOCK_SKEW_MS) {
      res.status(401).json({ error: 'invalid_internal_signature' });
      return;
    }
    const currentTime = (deps.now ?? (() => new Date()))().getTime();
    for (const [seenId, seenAt] of seenRequestIds) {
      if (currentTime - seenAt > MAX_CLOCK_SKEW_MS) seenRequestIds.delete(seenId);
    }
    if (seenRequestIds.has(requestId)) {
      res.status(401).json({ error: 'replayed_internal_request' });
      return;
    }
    const body = req.method === 'GET' ? '' : stableJson(req.body ?? {});
    const expected = createHmac('sha256', deps.secret)
      .update(`${timestamp}.${requestId}.${req.method}.${req.originalUrl}.${body}`)
      .digest('hex');
    const given = Buffer.from(signature, 'hex');
    const expectedBytes = Buffer.from(expected, 'hex');
    if (given.length !== expectedBytes.length || !timingSafeEqual(given, expectedBytes)) {
      res.status(401).json({ error: 'invalid_internal_signature' });
      return;
    }
    if (deps.replay !== undefined) {
      let accepted: boolean;
      try {
        accepted = await deps.replay.claim({
          requestId,
          expiresAt: new Date(currentTime + MAX_CLOCK_SKEW_MS),
        });
      } catch (_) {
        res.status(503).json({ error: 'internal_replay_store_unavailable' });
        return;
      }
      if (!accepted) {
        res.status(401).json({ error: 'replayed_internal_request' });
        return;
      }
    }
    seenRequestIds.set(requestId, currentTime);
    next();
  };
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, item]) => `${JSON.stringify(key)}:${stableJson(item)}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

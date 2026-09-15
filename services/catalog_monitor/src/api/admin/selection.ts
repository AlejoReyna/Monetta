import type { Express, NextFunction, Request, RequestHandler, Response } from 'express';
import { computeEtag } from '../etag.js';
import {
  compileSelection,
  hashSelectionDocument,
  isSelectionError,
  parseSelectionDocument,
  canonicalJsonStringify,
  isSourceId,
  isStageARuleKind,
  isStageBRuleKind,
  type CompiledSelection,
  type SelectionDocument,
  type SelectionError,
} from '../../selection/index.js';
import type { SourceId } from '../../domain/types.js';
import { ADMIN_LIST_LIMIT_MAX, clampLimit, type AdminDbClient } from './runs.js';

/**
 * WP-62 selection console endpoints (§ 5, § 6.3):
 *
 * - `GET /admin/selection` — current document + version metadata
 * - `PUT /admin/selection` — validate + apply a new version (identical
 *   document is a no-op, invalid names the failing rule)
 * - `GET /admin/selection/versions` — append-only history, newest first
 * - `POST /admin/selection/rollback` — new version copying an old document
 * - `POST /admin/selection/preview` — per-rule match counts against a
 *   caller-supplied candidate URL set. Zero fetches by construction: it only
 *   runs the pure `matchUrl` evaluator.
 * - `POST /admin/products/:sourceScopedId/pin|hide` — scoped Stage-A rule
 *   writes (never free-form JSON), idempotent via the same apply path.
 *
 * Versioning model: the store's append-only sequence (`version`) is the
 * version of record and is stamped into `document.version` on every apply,
 * so the runner's `selection.version` lifecycle always agrees with history.
 * Semantic equality ignores the stamp: re-applying an identical document is
 * a no-op returning the current version (WP-14).
 */

export interface SelectionVersionMeta {
  readonly version: number;
  readonly hash: string;
  readonly appliedBy: string;
  readonly appliedAt: string;
  readonly note: string | null;
}

export interface SelectionVersionRecord extends SelectionVersionMeta {
  readonly document: SelectionDocument;
}

export interface SelectionVersionStore {
  current(): Promise<SelectionVersionRecord | null>;
  history(limit: number): Promise<SelectionVersionMeta[]>;
  getByVersion(version: number): Promise<SelectionVersionRecord | null>;
  /**
   * Appends a pre-stamped document. Implementations assign
   * `document.version` before calling this; concurrent appends must not
   * reuse a version (pg retries on PK conflict, in-memory is single-owner).
   */
  append(record: SelectionVersionRecord): Promise<SelectionVersionRecord>;
  /** Next version in the append-only sequence (`max + 1`, or 1 when empty). */
  nextVersion(): Promise<number>;
}

/** Test seam: single-owner, no concurrency control needed. */
export class InMemorySelectionVersionStore implements SelectionVersionStore {
  private readonly rows: SelectionVersionRecord[] = [];

  seed(rows: readonly SelectionVersionRecord[]): void {
    this.rows.push(...rows);
    this.rows.sort((a, b) => a.version - b.version);
  }

  async current(): Promise<SelectionVersionRecord | null> {
    return this.rows.length === 0 ? null : this.rows[this.rows.length - 1]!;
  }

  async history(limit: number): Promise<SelectionVersionMeta[]> {
    return [...this.rows]
      .sort((a, b) => b.version - a.version)
      .slice(0, limit)
      .map(toMeta);
  }

  async getByVersion(version: number): Promise<SelectionVersionRecord | null> {
    return this.rows.find((row) => row.version === version) ?? null;
  }

  async append(record: SelectionVersionRecord): Promise<SelectionVersionRecord> {
    if (this.rows.some((row) => row.version === record.version)) {
      throw new Error(`selection version ${record.version} already exists`);
    }
    this.rows.push(record);
    this.rows.sort((a, b) => a.version - b.version);
    return record;
  }

  async nextVersion(): Promise<number> {
    return this.rows.length === 0 ? 1 : this.rows[this.rows.length - 1]!.version + 1;
  }
}

function toMeta(record: SelectionVersionRecord): SelectionVersionMeta {
  return {
    version: record.version,
    hash: record.hash,
    appliedBy: record.appliedBy,
    appliedAt: record.appliedAt,
    note: record.note,
  };
}

function rowToRecord(row: Record<string, unknown>): SelectionVersionRecord | null {
  const version = typeof row.version === 'number'
    ? row.version
    : typeof row.version === 'string' && row.version.trim() !== ''
      ? Number.parseInt(row.version, 10)
      : NaN;
  if (!Number.isInteger(version) || version <= 0) return null;
  const parsed = parseSelectionDocument(row.document);
  if (isSelectionError(parsed)) return null;
  const appliedRaw = row.applied_at;
  return {
    version,
    hash: String(row.hash ?? ''),
    document: parsed,
    appliedBy: String(row.applied_by ?? ''),
    appliedAt: appliedRaw instanceof Date ? appliedRaw.toISOString() : String(appliedRaw ?? ''),
    note: typeof row.note === 'string' ? row.note : null,
  };
}

function isUndefinedTable(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code: unknown }).code === '42P01'
  );
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code: unknown }).code === '23505'
  );
}

/**
 * Production store over `selection_versions` (migration 008). Reads degrade
 * to empty when the table is absent (pre-P4 database); writes then fail
 * through the generic catch-all rather than silently succeeding.
 */
export function createPgSelectionVersionStore(
  db: AdminDbClient,
  now: () => Date = () => new Date(),
): SelectionVersionStore {
  const findByHash = async (hash: string): Promise<SelectionVersionRecord | null> => {
    const { rows } = await db.query(
      `SELECT version, document, hash, applied_by, applied_at, note
         FROM selection_versions WHERE hash = $1`,
      [hash],
    );
    const row = rows[0];
    return row === undefined ? null : rowToRecord(row);
  };
  return {
    async current(): Promise<SelectionVersionRecord | null> {
      try {
        const { rows } = await db.query(
          `SELECT version, document, hash, applied_by, applied_at, note
             FROM selection_versions ORDER BY version DESC LIMIT 1`,
        );
        const row = rows[0];
        return row === undefined ? null : rowToRecord(row);
      } catch (error) {
        if (isUndefinedTable(error)) return null;
        throw error;
      }
    },
    async history(limit: number): Promise<SelectionVersionMeta[]> {
      try {
        const { rows } = await db.query(
          `SELECT version, document, hash, applied_by, applied_at, note
             FROM selection_versions ORDER BY version DESC LIMIT $1`,
          [limit],
        );
        return rows
          .map(rowToRecord)
          .filter((r): r is SelectionVersionRecord => r !== null)
          .map(toMeta);
      } catch (error) {
        if (isUndefinedTable(error)) return [];
        throw error;
      }
    },
    async getByVersion(version: number): Promise<SelectionVersionRecord | null> {
      try {
        const { rows } = await db.query(
          `SELECT version, document, hash, applied_by, applied_at, note
             FROM selection_versions WHERE version = $1`,
          [version],
        );
        const row = rows[0];
        return row === undefined ? null : rowToRecord(row);
      } catch (error) {
        if (isUndefinedTable(error)) return null;
        throw error;
      }
    },
    async append(record: SelectionVersionRecord): Promise<SelectionVersionRecord> {
      try {
        await db.query(
          `INSERT INTO selection_versions (version, document, hash, applied_at, applied_by, note)
           VALUES ($1, $2::jsonb, $3, $4, $5, $6)`,
          [
            record.version,
            JSON.stringify(record.document),
            record.hash,
            record.appliedAt,
            record.appliedBy,
            record.note,
          ],
        );
        return record;
      } catch (error) {
        if (!isUniqueViolation(error)) throw error;
        // Lost a race with an identical concurrent apply — the row with
        // this hash is the winner; report it as the no-op outcome.
        const winner = await findByHash(record.hash).catch(() => null);
        if (winner !== null) return winner;
        throw error;
      }
    },
    async nextVersion(): Promise<number> {
      const { rows } = await db.query(
        `SELECT COALESCE(MAX(version), 0) AS max_version FROM selection_versions`,
      );
      const raw = rows[0]?.max_version;
      const max = typeof raw === 'number'
        ? raw
        : typeof raw === 'string' && raw.trim() !== ''
          ? Number.parseInt(raw, 10)
          : 0;
      void now;
      return (Number.isFinite(max) ? max : 0) + 1;
    },
  };
}

/**
 * Functional document key: canonical form with the version stamp and the
 * free-text note stripped. Notes are operator metadata — two documents with
 * identical rules are the same selection, so re-applying one (even with a
 * different note) is a no-op returning the current version (WP-14).
 */
export function semanticKey(document: SelectionDocument): string {
  const { version: _v, note: _n, ...rest } = document as SelectionDocument & {
    version?: unknown;
    note?: unknown;
  };
  void _v;
  void _n;
  return canonicalJsonStringify({ ...rest, version: 0 });
}

export interface SelectionApplyResult {
  readonly record: SelectionVersionRecord;
  readonly applied: boolean;
}

export interface SelectionApplyDeps {
  readonly appliedBy: string;
  readonly note?: string | null;
  readonly now?: () => Date;
}

/**
 * Shared apply path for PUT, rollback, pin and hide: validate has already
 * happened; an identical document is a no-op, otherwise the document is
 * stamped with the next version and appended.
 */
export async function applySelectionDocument(
  store: SelectionVersionStore,
  candidate: SelectionDocument,
  deps: SelectionApplyDeps,
): Promise<SelectionApplyResult> {
  const current = await store.current();
  if (current !== null && semanticKey(current.document) === semanticKey(candidate)) {
    return { record: current, applied: false };
  }
  const version = await store.nextVersion();
  const stamped: SelectionDocument = { ...candidate, version };
  // Drop the caller-supplied note: history notes record who did what.
  const { note: _ignored, ...docWithoutNote } = stamped as SelectionDocument & { note?: unknown };
  void _ignored;
  const finalDoc: SelectionDocument = {
    ...docWithoutNote,
    ...(deps.note === undefined || deps.note === null || deps.note === ''
      ? (candidate.note !== undefined ? { note: candidate.note } : {})
      : { note: deps.note }),
  };
  const record: SelectionVersionRecord = {
    version,
    hash: hashSelectionDocument(finalDoc),
    document: finalDoc,
    appliedBy: deps.appliedBy,
    appliedAt: (deps.now ?? (() => new Date()))().toISOString(),
    note: finalDoc.note ?? null,
  };
  try {
    return { record: await store.append(record), applied: true };
  } catch (error) {
    if (!isUniqueViolation(error)) throw error;
    // Version-sequence race: re-read; an identical document may have won.
    const fresh = await store.current();
    if (fresh !== null && semanticKey(fresh.document) === semanticKey(candidate)) {
      return { record: fresh, applied: false };
    }
    const retryVersion = await store.nextVersion();
    const retry: SelectionVersionRecord = {
      ...record,
      version: retryVersion,
      document: { ...finalDoc, version: retryVersion },
    };
    const rehashed: SelectionVersionRecord = {
      ...retry,
      hash: hashSelectionDocument(retry.document),
    };
    return { record: await store.append(rehashed), applied: true };
  }
}

function selectionErrorBody(error: SelectionError): Record<string, unknown> {
  return { error: error.error, code: error.code, message: error.message };
}

function appliedByOf(req: Request): string | null {
  const raw = req.header('X-Applied-By');
  if (raw === undefined) return null;
  const trimmed = raw.trim();
  if (trimmed === '' || trimmed.length > 128) return null;
  return trimmed;
}

/**
 * Optional optimistic concurrency: when the client sends
 * `If-Match: "<version>"` (or a bare integer), the write applies only if
 * the current version still matches. A stale tab gets `412
 * version_conflict` instead of silently overwriting a newer selection.
 * Absent header means last-write-wins (pin/hide use this path).
 */
function ifMatchOf(req: Request): { present: false } | { present: true; version: number } | { present: 'invalid' } {
  const raw = req.header('If-Match');
  if (raw === undefined || raw.trim() === '') return { present: false };
  const digits = raw.trim().replace(/^"|"$/g, '');
  if (!/^\d+$/.test(digits)) return { present: 'invalid' };
  return { present: true, version: Number.parseInt(digits, 10) };
}

async function checkIfMatch(
  req: Request,
  res: Response,
  store: SelectionVersionStore,
): Promise<SelectionVersionRecord | 'proceed' | 'rejected'> {
  const guard = ifMatchOf(req);
  if (guard.present === 'invalid') {
    res.status(400).json({ error: 'invalid_if_match' });
    return 'rejected';
  }
  const current = await store.current();
  if (!guard.present) return current ?? 'proceed';
  if (current === null || current.version !== guard.version) {
    res.status(412).json({ error: 'version_conflict', currentVersion: current?.version ?? null });
    return 'rejected';
  }
  return current;
}

function sendEtagged(req: Request, res: Response, body: unknown): void {
  const json = JSON.stringify(body);
  const etag = computeEtag(json);
  res.setHeader('ETag', etag);
  if (req.header('If-None-Match') === etag) {
    res.status(304).end();
    return;
  }
  res.status(200).json(body);
}

function asyncRoute(handler: (req: Request, res: Response) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction): void => {
    void handler(req, res).catch(next);
  };
}

function slugifyExternalId(value: string): string {
  const slug = value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  return slug === '' ? 'product' : slug;
}

function splitSourceScopedId(value: string): { source: string; externalId: string } | null {
  const index = value.indexOf(':');
  if (index <= 0 || index === value.length - 1) return null;
  return { source: value.slice(0, index), externalId: value.slice(index + 1) };
}

export interface SelectionPreviewCandidate {
  readonly source: string;
  readonly url: string;
}

export interface SelectionPreviewResult {
  readonly valid: true;
  readonly hash: string;
  readonly perRule: ReadonlyArray<{
    readonly ruleId: string;
    readonly kind: string;
    readonly stage: 'A' | 'B' | 'C';
    readonly matchedUrls: number;
    /** Stage-B rules cost a fetch per candidate — flagged explicitly (§ 6.3). */
    readonly fetchCosting: boolean;
  }>;
  readonly perSource: ReadonlyArray<{
    readonly source: string;
    readonly candidates: number;
    readonly selected: number;
    readonly requiresProductEvaluation: number;
    readonly maxSelectedUrls: number | null;
    readonly overBudget: boolean;
  }>;
  readonly note: string | null;
}

/**
 * Pure preview: compiles the candidate document and runs `matchUrl` over a
 * caller-supplied candidate set. No I/O, no fetches — the counts answer "how
 * many would Stage A select?" without crawling anything.
 */
export function previewSelection(
  document: SelectionDocument,
  candidates: readonly SelectionPreviewCandidate[],
): SelectionPreviewResult {
  const compiled: CompiledSelection = compileSelection(document);
  const wins = new Map<string, number>();
  const perSource = new Map<string, { candidates: number; selected: number; needsProduct: number }>();
  for (const candidate of candidates) {
    const bucket = perSource.get(candidate.source) ?? { candidates: 0, selected: 0, needsProduct: 0 };
    bucket.candidates += 1;
    const decision = compiled.matchUrl(candidate.source, candidate.url);
    if (decision.selected) {
      bucket.selected += 1;
      if (decision.requiresProductEvaluation === true) bucket.needsProduct += 1;
      if (decision.ruleId !== undefined) {
        wins.set(decision.ruleId, (wins.get(decision.ruleId) ?? 0) + 1);
      }
    }
    perSource.set(candidate.source, bucket);
  }
  const perRule = Object.entries(document.sources).flatMap(([sourceId, source]) =>
    source.include.map((rule) => {
      const stage = isStageARuleKind(rule.kind) ? 'A' : isStageBRuleKind(rule.kind) ? 'B' : 'C';
      return {
        ruleId: rule.id,
        kind: rule.kind,
        stage: stage as 'A' | 'B' | 'C',
        matchedUrls: wins.get(rule.id) ?? 0,
        fetchCosting: stage === 'B',
        source: sourceId,
      };
    }),
  );
  const sources = Object.entries(document.sources).map(([sourceId, source]) => {
    const bucket = perSource.get(sourceId) ?? { candidates: 0, selected: 0, needsProduct: 0 };
    const max = source.maxSelectedUrls ?? null;
    return {
      source: sourceId,
      candidates: bucket.candidates,
      selected: bucket.selected,
      requiresProductEvaluation: bucket.needsProduct,
      maxSelectedUrls: max,
      overBudget: max !== null && bucket.selected > max,
    };
  });
  return {
    valid: true,
    hash: compiled.hash,
    perRule,
    perSource: sources,
    note: candidates.length === 0
      ? 'No candidate URLs supplied — counts are zero. Supply `urls` (or per-source `candidates`) to preview Stage-A matching.'
      : null,
  };
}

export const ADMIN_SELECTION_VERSIONS_LIMIT_DEFAULT = 50;

export interface AdminSelectionRouteDeps {
  readonly gate: RequestHandler;
  readonly store: SelectionVersionStore;
  readonly now?: () => Date;
  readonly buildFeed: () => Promise<{ json: string; etag: string }>;
}

export function registerAdminSelectionRoutes(app: Express, deps: AdminSelectionRouteDeps): void {
  const now = deps.now ?? (() => new Date());

  app.get(
    '/admin/selection',
    deps.gate,
    asyncRoute(async (req, res) => {
      const record = await deps.store.current();
      if (record === null) {
        res.status(404).json({ error: 'no_selection' });
        return;
      }
      sendEtagged(req, res, { ...toMeta(record), document: record.document });
    }),
  );

  app.put(
    '/admin/selection',
    deps.gate,
    asyncRoute(async (req, res) => {
      const appliedBy = appliedByOf(req);
      if (appliedBy === null) {
        res.status(400).json({ error: 'missing_applied_by' });
        return;
      }
      const guarded = await checkIfMatch(req, res, deps.store);
      if (guarded === 'rejected') return;
      const raw = (req.body as { document?: unknown; note?: unknown } | undefined)?.document;
      const parsed = parseSelectionDocument(raw);
      if (isSelectionError(parsed)) {
        res.status(400).json(selectionErrorBody(parsed));
        return;
      }
      const note = typeof (req.body as { note?: unknown }).note === 'string'
        ? (req.body as { note: string }).note
        : null;
      const { record, applied } = await applySelectionDocument(deps.store, parsed, {
        appliedBy,
        note,
        now: deps.now,
      });
      res.status(applied ? 201 : 200).json({ applied, ...toMeta(record) });
    }),
  );

  app.get(
    '/admin/selection/versions',
    deps.gate,
    asyncRoute(async (req, res) => {
      const versions = await deps.store.history(clampLimit(req.query.limit, ADMIN_SELECTION_VERSIONS_LIMIT_DEFAULT));
      sendEtagged(req, res, { versions });
    }),
  );

  app.post(
    '/admin/selection/rollback',
    deps.gate,
    asyncRoute(async (req, res) => {
      const appliedBy = appliedByOf(req);
      if (appliedBy === null) {
        res.status(400).json({ error: 'missing_applied_by' });
        return;
      }
      const guarded = await checkIfMatch(req, res, deps.store);
      if (guarded === 'rejected') return;
      const raw = (req.body as { version?: unknown } | undefined)?.version;
      const target = typeof raw === 'number' && Number.isInteger(raw)
        ? raw
        : typeof raw === 'string' && raw.trim() !== ''
          ? Number.parseInt(raw, 10)
          : NaN;
      if (!Number.isInteger(target) || target <= 0) {
        res.status(400).json({ error: 'invalid_version' });
        return;
      }
      const old = await deps.store.getByVersion(target);
      if (old === null) {
        res.status(404).json({ error: 'version_not_found' });
        return;
      }
      const note = typeof (req.body as { note?: unknown }).note === 'string' && (req.body as { note: string }).note.trim() !== ''
        ? (req.body as { note: string }).note
        : `rollback to v${old.version}`;
      // Append-only: a NEW version whose document equals the old one.
      const { record, applied } = await applySelectionDocument(deps.store, old.document, {
        appliedBy,
        note,
        now: deps.now,
      });
      res.status(applied ? 201 : 200).json({ applied, ...toMeta(record) });
    }),
  );

  app.post(
    '/admin/selection/preview',
    deps.gate,
    asyncRoute(async (req, res) => {
      const body = (req.body as {
        document?: unknown;
        urls?: unknown;
        candidates?: unknown;
        source?: unknown;
      } | undefined) ?? {};
      const parsed = parseSelectionDocument(body.document);
      if (isSelectionError(parsed)) {
        res.status(400).json(selectionErrorBody(parsed));
        return;
      }
      const candidates: SelectionPreviewCandidate[] = [];
      if (Array.isArray(body.candidates)) {
        for (const entry of body.candidates as unknown[]) {
          if (
            typeof entry === 'object' && entry !== null &&
            typeof (entry as { source: unknown }).source === 'string' &&
            typeof (entry as { url: unknown }).url === 'string'
          ) {
            const source = (entry as { source: string }).source;
            const url = (entry as { url: string }).url;
            if (!isSourceId(source)) {
              res.status(400).json({ error: 'invalid_source', source });
              return;
            }
            candidates.push({ source, url });
          }
        }
      } else if (Array.isArray(body.urls)) {
        const source = typeof body.source === 'string' ? body.source : null;
        if (source === null || !isSourceId(source)) {
          res.status(400).json({ error: 'invalid_source' });
          return;
        }
        for (const url of body.urls as unknown[]) {
          if (typeof url === 'string' && url !== '') candidates.push({ source, url });
        }
      }
      sendEtagged(req, res, previewSelection(parsed, candidates.slice(0, 5000)));
    }),
  );

  const mutateProductRule = async (
    req: Request,
    res: Response,
    action: 'pin' | 'hide',
  ): Promise<void> => {
    const appliedBy = appliedByOf(req);
    if (appliedBy === null) {
      res.status(400).json({ error: 'missing_applied_by' });
      return;
    }
    const split = splitSourceScopedId(req.params.id as string);
    if (split === null || split.externalId.trim() === '') {
      res.status(400).json({ error: 'invalid_product_id' });
      return;
    }
    if (!isSourceId(split.source)) {
      res.status(400).json({ error: 'invalid_source', source: split.source });
      return;
    }
    const sourceId: SourceId = split.source;
    const externalId = split.externalId;
    const current = await deps.store.current();
    if (current === null) {
      res.status(404).json({ error: 'no_selection' });
      return;
    }
    const entry = (current.document.sources as Record<string, SelectionDocument['sources'][string] | undefined>)[sourceId];
    if (entry === undefined) {
      res.status(400).json({ error: 'unknown_source_entry', source: sourceId });
      return;
    }
    const slug = slugifyExternalId(externalId);
    const pinId = `pin-${slug}`;
    const hideId = `hide-${slug}`;
    const sameValue = (value: unknown): boolean =>
      typeof value === 'string' && value.toLowerCase() === externalId.toLowerCase();
    let include = [...entry.include];
    let exclude = [...entry.exclude];
    if (action === 'pin') {
      // Pin wins over hide: drop any externalId exclude for this product.
      exclude = exclude.filter((rule) => !(rule.kind === 'externalId' && sameValue(rule.value)));
      include = include.filter((rule) => rule.id !== pinId);
      include.push({
        id: pinId,
        kind: 'externalId',
        value: externalId,
        tier: 'pinned',
        placements: ['home_rail', 'catalog_browse'],
      });
    } else {
      // Hide wins over pin: drop any externalId include for this product.
      include = include.filter((rule) => !(rule.kind === 'externalId' && sameValue(rule.value)));
      exclude = exclude.filter((rule) => rule.id !== hideId);
      exclude.push({ id: hideId, kind: 'externalId', value: externalId });
      void pinId;
    }
    const candidate: SelectionDocument = {
      ...current.document,
      sources: {
        ...current.document.sources,
        [sourceId]: { ...entry, include, exclude },
      },
    };
    const parsed = parseSelectionDocument(candidate);
    if (isSelectionError(parsed)) {
      res.status(400).json(selectionErrorBody(parsed));
      return;
    }
    const note = typeof (req.body as { note?: unknown } | undefined)?.note === 'string' &&
        ((req.body as { note: string }).note.trim() !== '')
      ? (req.body as { note: string }).note
      : `${action} ${sourceId}:${externalId}`;
    const { record, applied } = await applySelectionDocument(deps.store, parsed, {
      appliedBy,
      note,
      now: deps.now,
    });
    res.status(applied ? 201 : 200).json({ applied, ...toMeta(record) });
  };

  app.post(
    '/admin/products/:id/pin',
    deps.gate,
    asyncRoute(async (req, res) => mutateProductRule(req, res, 'pin')),
  );

  app.post(
    '/admin/products/:id/hide',
    deps.gate,
    asyncRoute(async (req, res) => mutateProductRule(req, res, 'hide')),
  );

  app.get(
    '/admin/feed-preview',
    deps.gate,
    asyncRoute(async (req, res) => {
      // Byte-for-byte the public feed body for the same state (same builder,
      // same inputs). Headers stay admin-appropriate: session-gated responses
      // are never publicly cacheable.
      const { json, etag } = await deps.buildFeed();
      void now;
      res.setHeader('ETag', etag);
      res.setHeader('Cache-Control', 'private, no-store');
      if (req.header('If-None-Match') === etag) {
        res.status(304).end();
        return;
      }
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.status(200).send(json);
    }),
  );
}

export { ADMIN_LIST_LIMIT_MAX };

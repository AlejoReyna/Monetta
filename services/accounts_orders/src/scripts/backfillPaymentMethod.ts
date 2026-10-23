/**
 * One-time backfill of orders_mirror.payment_method for pending orders
 * whose webhook did not store a method, and for pending orders still
 * stored as a stale transfer alias such as `other:transferencia_bancaria`
 * or `other:deposito_bancario`.
 *
 * Dry-run is the default and never writes. It prints shopify order id,
 * order name, and the proposed payment_method. Writes happen only with
 * an explicit --apply flag, and only for rows that are still pending and
 * either still have a null payment_method, or still store a stale
 * `other:<alias>` from [TRANSFER_METHOD_ALIASES] (for example
 * `other:transferencia_bancaria` or `other:deposito_bancario`, rewritten
 * only to `bank_deposit`).
 *
 *   npm run backfill:payment-method
 *   npm run backfill:payment-method -- --apply
 *
 * Required environment (never pass the token as an argument):
 *   SHOPIFY_ADMIN_ACCESS_TOKEN
 *   DATABASE_URL
 *   SHOPIFY_STORE_DOMAIN
 * Optional:
 *   SHOPIFY_ADMIN_API_VERSION  (default 2026-07)
 *
 * Runbook: dry-run, review the id/name list, apply on staging, then
 * production only after Alexis approves that dry-run list.
 *
 * Does not backfill checkout_token or cart_token. Those columns are filled
 * by orders/create and orders/updated. This script's candidate set is
 * pending rows still missing a payment method, plus pending rows whose
 * method is a stale transfer alias. Its stdout prints every looked-up
 * field — printing checkout or cart tokens would log them.
 */
import { fileURLToPath } from 'node:url';
import type pg from 'pg';
import { getPool, closePool } from '../db/pool.js';
import {
  isNormalizedPaymentMethod,
  normalizePaymentMethod,
  staleTransferAliasPaymentMethods,
} from '../orders/paymentMethod.js';

const ORDER_PAYMENT_QUERY = `
query OrderPaymentMethods($ids: [ID!]!) {
  nodes(ids: $ids) {
    __typename
    ... on Order {
      id
      name
      paymentGatewayNames
      transactions(first: 20) {
        gateway
        kind
        formattedGateway
      }
    }
  }
}
`.trim();

export { ORDER_PAYMENT_QUERY };

const BATCH_SIZE = 10;

export interface PendingPaymentOrder {
  readonly shopifyOrderId: string;
  readonly storedPaymentMethod: string | null;
}

export interface PaymentMethodBackfillStore {
  /** Pending rows with a null method, or a stale `other:<transfer alias>`. */
  listPendingWithoutPaymentMethod(): Promise<readonly PendingPaymentOrder[]>;
  /**
   * Writes when the row is still pending and the method is null.
   * Also replaces a stale `other:<transfer alias>` with `bank_deposit`.
   */
  setPaymentMethodIfNull(shopifyOrderId: string, paymentMethod: string): Promise<boolean>;
}

/** True when the backfill may store [proposed] over [stored]. */
export function backfillWouldWrite(stored: string | null, proposed: string): boolean {
  if (!isNormalizedPaymentMethod(proposed)) return false;
  if (stored === null) return true;
  return staleTransferAliasPaymentMethods().includes(stored) && proposed === 'bank_deposit';
}

export const PENDING_PAYMENT_METHOD_CANDIDATES_SQL = `
SELECT shopify_order_id, payment_method
FROM orders_mirror
WHERE shopify_order_id IS NOT NULL
  AND lower(btrim(financial_status)) = 'pending'
  AND (
    payment_method IS NULL
    OR payment_method = ANY($1::text[])
  )
ORDER BY id
`.trim();

export const WRITE_PAYMENT_METHOD_SQL = `
UPDATE orders_mirror
SET payment_method = $1, updated_at = now()
WHERE shopify_order_id = $2
  AND lower(btrim(coalesce(financial_status, ''))) = 'pending'
  AND (
    payment_method IS NULL
    OR (
      $1 = 'bank_deposit'
      AND payment_method = ANY($3::text[])
    )
  )
`.trim();

export type OrderPaymentLookup =
  | { readonly ok: true; readonly name: string | null; readonly paymentMethod: string | null }
  | { readonly ok: false; readonly error: string };

export interface OrderPaymentReader {
  read(shopifyOrderIds: readonly string[]): Promise<ReadonlyMap<string, OrderPaymentLookup>>;
}

export type BackfillAction =
  | 'would_write'
  | 'written'
  | 'skip_no_method'
  | 'skipped_filled'
  | 'error';

export interface BackfillEntry {
  readonly shopifyOrderId: string;
  readonly name: string | null;
  readonly paymentMethod: string | null;
  readonly action: BackfillAction;
  readonly error?: string;
}

export interface BackfillReport {
  readonly mode: 'dry-run' | 'apply';
  readonly applied: boolean;
  readonly reason: string | null;
  readonly candidates: number;
  readonly errors: number;
  readonly entries: readonly BackfillEntry[];
}

export interface BackfillArgs {
  readonly apply: boolean;
  readonly help: boolean;
}

export function parseBackfillArgs(argv: readonly string[]): BackfillArgs {
  if (argv.some((arg) => /shpat_|shpca_|shpss_/i.test(arg) || /(^|-)token(=|$)/i.test(arg))) {
    throw new Error('Pass the Admin API token only via SHOPIFY_ADMIN_ACCESS_TOKEN.');
  }
  if (argv.includes('--help') || argv.includes('-h')) {
    return { apply: false, help: true };
  }
  const unknown = argv.filter((arg) => arg !== '--apply');
  if (unknown.length > 0) {
    throw new Error('Unknown argument. The only write flag is --apply.');
  }
  return { apply: argv.includes('--apply'), help: false };
}

export function shopifyOrderGid(shopifyOrderId: string): string {
  const prefix = 'gid://shopify/Order/';
  const numeric = shopifyOrderId.startsWith(prefix)
    ? shopifyOrderId.slice(prefix.length)
    : shopifyOrderId;
  if (!/^\d+$/.test(numeric)) {
    throw new Error('invalid_order_id');
  }
  return `${prefix}${numeric}`;
}

export function orderDisplayName(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const name = raw.trim();
  if (name.length === 0 || name.length > 40) return null;
  if (name.includes('@') || /\d{12,}/.test(name)) return null;
  return name;
}

/** Allowlisted stdout line: order id, name, proposed method, action. */
export function backfillLine(entry: BackfillEntry): string {
  const payload: Record<string, string | null> = {
    shopifyOrderId: entry.shopifyOrderId,
    name: entry.name,
    paymentMethod: entry.paymentMethod,
    action: entry.action,
  };
  if (entry.error !== undefined) payload.error = entry.error;
  return JSON.stringify(payload);
}

export function backfillSummary(report: BackfillReport): string {
  return JSON.stringify({
    mode: report.mode,
    applied: report.applied,
    reason: report.reason,
    candidates: report.candidates,
    errors: report.errors,
  });
}

interface AdminOrderNode {
  readonly __typename?: string;
  readonly id?: string;
  readonly name?: unknown;
  readonly paymentGatewayNames?: readonly unknown[] | null;
  readonly transactions?: readonly {
    readonly gateway?: string | null;
    readonly kind?: string | null;
    readonly formattedGateway?: string | null;
  }[] | null;
}

function lookupFromNode(node: AdminOrderNode | null): OrderPaymentLookup {
  if (node === null || node.__typename !== 'Order' || typeof node.id !== 'string') {
    return { ok: false, error: 'not_found' };
  }
  return {
    ok: true,
    name: orderDisplayName(node.name),
    paymentMethod: normalizePaymentMethod({
      payment_gateway_names: node.paymentGatewayNames ?? null,
      transactions: node.transactions ?? null,
    }),
  };
}

export async function readShopifyOrderPayments(input: {
  readonly shopDomain: string;
  readonly apiVersion: string;
  readonly accessToken: string;
  readonly shopifyOrderIds: readonly string[];
  readonly fetchFn?: typeof fetch;
}): Promise<ReadonlyMap<string, OrderPaymentLookup>> {
  if (!/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/.test(input.shopDomain)) {
    throw new Error('SHOPIFY_STORE_DOMAIN is invalid');
  }
  if (!/^20\d{2}-(01|04|07|10)$/.test(input.apiVersion)) {
    throw new Error('SHOPIFY_ADMIN_API_VERSION is invalid');
  }
  const fetchFn = input.fetchFn ?? fetch;
  const result = new Map<string, OrderPaymentLookup>();
  const pending: string[] = [];
  for (const shopifyOrderId of input.shopifyOrderIds) {
    try {
      shopifyOrderGid(shopifyOrderId);
      pending.push(shopifyOrderId);
    } catch {
      result.set(shopifyOrderId, { ok: false, error: 'invalid_order_id' });
    }
  }

  for (let offset = 0; offset < pending.length; offset += BATCH_SIZE) {
    const batch = pending.slice(offset, offset + BATCH_SIZE);
    let response: Response;
    try {
      response = await fetchFn(
        `https://${input.shopDomain}/admin/api/${input.apiVersion}/graphql.json`,
        {
          method: 'POST',
          headers: {
            Accept: 'application/json',
            'Content-Type': 'application/json',
            'X-Shopify-Access-Token': input.accessToken,
          },
          body: JSON.stringify({
            query: ORDER_PAYMENT_QUERY,
            variables: { ids: batch.map((id) => shopifyOrderGid(id)) },
          }),
          signal: AbortSignal.timeout(15_000),
        },
      );
    } catch {
      for (const id of batch) result.set(id, { ok: false, error: 'shopify_unreachable' });
      continue;
    }
    if (!response.ok) {
      const error = `shopify_http_${response.status}`;
      for (const id of batch) result.set(id, { ok: false, error });
      continue;
    }
    let envelope: {
      readonly data?: { readonly nodes?: readonly (AdminOrderNode | null)[] };
      readonly errors?: readonly unknown[];
    };
    try {
      envelope = await response.json() as typeof envelope;
    } catch {
      for (const id of batch) result.set(id, { ok: false, error: 'shopify_invalid_response' });
      continue;
    }
    if (envelope.errors !== undefined && envelope.errors.length > 0) {
      for (const id of batch) result.set(id, { ok: false, error: 'shopify_graphql' });
      continue;
    }
    const nodes = envelope.data?.nodes ?? [];
    batch.forEach((id, index) => {
      result.set(id, lookupFromNode(nodes[index] ?? null));
    });
  }
  return result;
}

export async function runPaymentMethodBackfill(
  store: PaymentMethodBackfillStore,
  reader: OrderPaymentReader,
  options: { readonly apply: boolean },
): Promise<BackfillReport> {
  const candidates = await store.listPendingWithoutPaymentMethod();
  const lookups = candidates.length === 0
    ? new Map<string, OrderPaymentLookup>()
    : await reader.read(candidates.map((order) => order.shopifyOrderId));

  const drafts: Array<{
    shopifyOrderId: string;
    name: string | null;
    paymentMethod: string | null;
    error?: string;
    writable: boolean;
  }> = [];
  let errors = 0;
  for (const order of candidates) {
    const lookup = lookups.get(order.shopifyOrderId);
    if (lookup === undefined) {
      errors += 1;
      drafts.push({
        shopifyOrderId: order.shopifyOrderId,
        name: null,
        paymentMethod: null,
        error: 'not_found',
        writable: false,
      });
      continue;
    }
    if (!lookup.ok) {
      errors += 1;
      drafts.push({
        shopifyOrderId: order.shopifyOrderId,
        name: null,
        paymentMethod: null,
        error: lookup.error,
        writable: false,
      });
      continue;
    }
    const paymentMethod = lookup.paymentMethod !== null && isNormalizedPaymentMethod(lookup.paymentMethod)
      ? lookup.paymentMethod
      : null;
    drafts.push({
      shopifyOrderId: order.shopifyOrderId,
      name: lookup.name,
      paymentMethod,
      writable: paymentMethod !== null && backfillWouldWrite(order.storedPaymentMethod, paymentMethod),
    });
  }

  const mode = options.apply ? 'apply' : 'dry-run';
  if (!options.apply || errors > 0) {
    return {
      mode,
      applied: false,
      reason: errors > 0 ? 'incomplete_shopify_read' : null,
      candidates: candidates.length,
      errors,
      entries: drafts.map((draft) => ({
        shopifyOrderId: draft.shopifyOrderId,
        name: draft.name,
        paymentMethod: draft.paymentMethod,
        action: draft.error !== undefined
          ? 'error'
          : draft.writable
            ? 'would_write'
            : draft.paymentMethod !== null
              ? 'skipped_filled'
              : 'skip_no_method',
        ...(draft.error !== undefined ? { error: draft.error } : {}),
      })),
    };
  }

  const entries: BackfillEntry[] = [];
  for (const draft of drafts) {
    if (!draft.writable || draft.paymentMethod === null) {
      entries.push({
        shopifyOrderId: draft.shopifyOrderId,
        name: draft.name,
        paymentMethod: draft.paymentMethod,
        action: draft.paymentMethod === null ? 'skip_no_method' : 'skipped_filled',
      });
      continue;
    }
    const wrote = await store.setPaymentMethodIfNull(draft.shopifyOrderId, draft.paymentMethod);
    entries.push({
      shopifyOrderId: draft.shopifyOrderId,
      name: draft.name,
      paymentMethod: draft.paymentMethod,
      action: wrote ? 'written' : 'skipped_filled',
    });
  }
  return {
    mode,
    applied: true,
    reason: null,
    candidates: candidates.length,
    errors: 0,
    entries,
  };
}

export class PgPaymentMethodBackfillStore implements PaymentMethodBackfillStore {
  constructor(private readonly pool: pg.Pool) {}

  async listPendingWithoutPaymentMethod(): Promise<readonly PendingPaymentOrder[]> {
    const stale = [...staleTransferAliasPaymentMethods()];
    const result = await this.pool.query<{
      shopify_order_id: string;
      payment_method: string | null;
    }>(
      PENDING_PAYMENT_METHOD_CANDIDATES_SQL,
      [stale],
    );
    return result.rows.map((row) => ({
      shopifyOrderId: row.shopify_order_id,
      storedPaymentMethod: row.payment_method,
    }));
  }

  async setPaymentMethodIfNull(shopifyOrderId: string, paymentMethod: string): Promise<boolean> {
    if (!isNormalizedPaymentMethod(paymentMethod)) return false;
    const stale = [...staleTransferAliasPaymentMethods()];
    const result = await this.pool.query(
      WRITE_PAYMENT_METHOD_SQL,
      [paymentMethod, shopifyOrderId, stale],
    );
    return (result.rowCount ?? 0) > 0;
  }
}

const HELP = `Backfill orders_mirror.payment_method for pending orders.

Default is dry-run (no writes). Pass --apply to write.
Candidates are pending rows with a null payment_method, plus pending
rows still stored as other:<alias> for a name in TRANSFER_METHOD_ALIASES
(for example other:transferencia_bancaria or other:deposito_bancario,
rewritten to bank_deposit). Paid rows are left as stored.
The Admin token is read from SHOPIFY_ADMIN_ACCESS_TOKEN only.

Runbook: dry-run, review the order id/name list, apply on staging,
then production only after Alexis approves that dry-run list.
`;

function requireEnv(name: string): string {
  const value = process.env[name]?.trim() ?? '';
  if (value === '') {
    throw new Error(`${name} is required`);
  }
  return value;
}

async function main(): Promise<void> {
  const args = parseBackfillArgs(process.argv.slice(2));
  if (args.help) {
    process.stdout.write(HELP);
    return;
  }
  const accessToken = requireEnv('SHOPIFY_ADMIN_ACCESS_TOKEN');
  if (process.argv.some((arg) => arg.includes(accessToken))) {
    throw new Error('Pass the Admin API token only via SHOPIFY_ADMIN_ACCESS_TOKEN.');
  }
  const shopDomain = requireEnv('SHOPIFY_STORE_DOMAIN');
  const apiVersion = (process.env.SHOPIFY_ADMIN_API_VERSION ?? '2026-07').trim();
  requireEnv('DATABASE_URL');

  const pool = getPool();
  try {
    const report = await runPaymentMethodBackfill(
      new PgPaymentMethodBackfillStore(pool),
      {
        read: (shopifyOrderIds) => readShopifyOrderPayments({
          shopDomain,
          apiVersion,
          accessToken,
          shopifyOrderIds,
        }),
      },
      { apply: args.apply },
    );
    process.stdout.write(`${backfillSummary(report)}\n`);
    for (const entry of report.entries) {
      process.stdout.write(`${backfillLine(entry)}\n`);
    }
    if (report.errors > 0) {
      process.exitCode = 1;
    }
  } finally {
    await closePool();
  }
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : 'backfill_failed';
    process.stderr.write(`${message}\n`);
    process.exitCode = 1;
  });
}

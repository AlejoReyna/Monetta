/**
 * An order blocks account deletion while it is still commercially open:
 * unpaid/pending, not yet fulfilled, or a refund that has not finished.
 *
 * A refund in progress blocks even when the order is cancelled. That is a
 * refund status, a refund-in-progress tag, or a cancellation of an order
 * that was charged (`paid`, `partially_paid`, `partially_refunded`) and is
 * not yet `refunded`. `refunded`, `voided`, and a cancellation that was
 * never charged do not block.
 */

export type OpenOrderBlockReason =
  | 'unpaid_or_pending'
  | 'unfulfilled'
  | 'refund_in_progress';

export interface OpenOrderSnapshot {
  readonly financialStatus: string | null;
  readonly fulfillmentStatus: string | null;
  readonly tags: readonly string[];
  /** Shopify `cancelledAt`. A present value closes the order. */
  readonly cancelledAt?: string | null;
  /** Shopify `cancelReason` / `cancel_reason`. A present value closes the order. */
  readonly cancelReason?: string | null;
}

const unpaidStatuses = new Set([
  'pending',
  'authorized',
  'partially_paid',
  'unpaid',
  'partially_authorized',
]);

const closedFinancialStatuses = new Set(['expired']);

const chargedStatuses = new Set(['paid', 'partially_paid', 'partially_refunded']);

const closedFulfillmentStatuses = new Set([
  'fulfilled',
  'delivered',
  'shipped',
  'restocked',
  'in_transit',
  'in transit',
  'out_for_delivery',
]);

const refundInProgressStatuses = new Set([
  'pending_refund',
  'refund_pending',
  'refund_in_progress',
  'refunding',
]);

const refundInProgressTags = new Set([
  'refund-pending',
  'refund_pending',
  'refund-in-progress',
  'refund_in_progress',
  'refunding',
]);

const cancelledTags = new Set(['cancelled', 'canceled', 'cancelado']);

function norm(value: string | null | undefined): string {
  return (value ?? '').trim().toLowerCase();
}

function present(value: string | null | undefined): boolean {
  return norm(value) !== '';
}

function isCancelled(
  order: OpenOrderSnapshot,
  financial: string,
  tags: readonly string[],
): boolean {
  if (financial === 'cancelled' || financial === 'canceled') return true;
  if (present(order.cancelledAt) || present(order.cancelReason)) return true;
  return tags.some((tag) => cancelledTags.has(tag));
}

/** Numeric Shopify order id from a raw id or `gid://shopify/Order/{id}`. */
export function shopifyOrderNumber(id: string | null | undefined): string | null {
  if (id == null) return null;
  const trimmed = id.trim();
  const gid = /^gid:\/\/shopify\/Order\/([0-9]+)$/.exec(trimmed);
  if (gid?.[1] !== undefined) return gid[1];
  return /^[0-9]+$/.test(trimmed) ? trimmed : null;
}

export function openOrderBlockReason(
  order: OpenOrderSnapshot,
): OpenOrderBlockReason | null {
  const financial = norm(order.financialStatus);
  const fulfillment = norm(order.fulfillmentStatus);
  const tags = order.tags.map((tag) => norm(tag));
  const cancelled = isCancelled(order, financial, tags);

  if (financial === 'voided' || financial === 'refunded') return null;

  if (
    refundInProgressStatuses.has(financial) ||
    tags.some((tag) => refundInProgressTags.has(tag))
  ) {
    return 'refund_in_progress';
  }

  if (cancelled) {
    // Charged and not yet refunded: the refund may still be owed.
    if (chargedStatuses.has(financial)) return 'refund_in_progress';
    return null;
  }

  if (closedFinancialStatuses.has(financial)) {
    return null;
  }

  const paymentSettled = financial !== '' && !unpaidStatuses.has(financial);
  if (!paymentSettled) {
    // A missing financial status on an already-closed fulfillment is not
    // treated as an open balance. Anything else unpaid or unknown blocks.
    if (!(financial === '' && closedFulfillmentStatuses.has(fulfillment))) {
      return 'unpaid_or_pending';
    }
  }

  if (!closedFulfillmentStatuses.has(fulfillment)) {
    return 'unfulfilled';
  }

  return null;
}

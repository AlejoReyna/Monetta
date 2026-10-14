/**
 * An order blocks account deletion while it is still commercially open:
 * unpaid/pending, not yet fulfilled, or a refund that has not finished.
 * Voided, cancelled, and fully refunded orders are closed and do not block.
 */

export type OpenOrderBlockReason =
  | 'unpaid_or_pending'
  | 'unfulfilled'
  | 'refund_in_progress';

export interface OpenOrderSnapshot {
  readonly financialStatus: string | null;
  readonly fulfillmentStatus: string | null;
  readonly tags: readonly string[];
}

const unpaidStatuses = new Set([
  'pending',
  'authorized',
  'partially_paid',
  'unpaid',
  'partially_authorized',
]);

const closedFinancialStatuses = new Set(['voided', 'refunded', 'expired']);

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
  'refund_pending',
  'pending_refund',
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

export function openOrderBlockReason(
  order: OpenOrderSnapshot,
): OpenOrderBlockReason | null {
  const financial = norm(order.financialStatus);
  const fulfillment = norm(order.fulfillmentStatus);
  const tags = order.tags.map((tag) => norm(tag));

  if (
    refundInProgressStatuses.has(financial) ||
    tags.some((tag) => refundInProgressTags.has(tag))
  ) {
    return 'refund_in_progress';
  }

  if (
    closedFinancialStatuses.has(financial) ||
    tags.some((tag) => cancelledTags.has(tag))
  ) {
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

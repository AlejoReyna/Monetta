import { detectWholesale } from './rules.js';
import type { RewardsService } from './service.js';

/** Puentes Shopify -> Rewards. Toda firma/identidad/autoridad se verifica en server.ts/handlers antes. */

interface OrderLike {
  id: number;
  tags?: string;
  customer?: { id: number } | null;
  currency?: string | null;
  discount_codes?: { code?: string }[];
  note_attributes?: { name: string; value: string }[];
  line_items?: {
    variant_id?: number | null; product_id?: number | null;
    quantity?: number; price?: string | null; total_discount?: string | null;
  }[];
  total_discounts?: string | null;
}

function cents(value: string | null | undefined): number {
  if (!value) return 0;
  const n = Number.parseFloat(value);
  if (!Number.isFinite(n) || n < 0) return 0;
  return Math.round(n * 100);
}

function parseTags(tags: string | undefined): string[] {
  if (!tags) return [];
  return tags.split(',').map((t) => t.trim()).filter((t) => t.length > 0);
}

/** Lineas + subtotal elegible candidato. La politica fiscal definitiva (IVA, gift cards) queda versionada. */
export function toEarnInput(order: OrderLike): {
  lines: { variantId?: string; productId?: string; quantity: number; unitPriceCents: number; discountCents: number; eligible: boolean }[];
  subtotalEligibleCents: number;
} {
  const lines = (order.line_items ?? []).map((l) => {
    const qty = typeof l.quantity === 'number' && l.quantity > 0 ? Math.floor(l.quantity) : 1;
    const unit = cents(l.price);
    const disc = cents(l.total_discount);
    return {
      variantId: l.variant_id != null ? String(l.variant_id) : undefined,
      productId: l.product_id != null ? String(l.product_id) : undefined,
      quantity: qty,
      unitPriceCents: unit,
      discountCents: Math.min(disc, qty * unit),
      // V1: lineas de mercancia elegibles; envio/propinas/gift cards no llegan
      // como line_items aqui. Si Shopify envia gift_card como linea, excluirla.
      eligible: true,
    };
  });
  return {
    lines,
    subtotalEligibleCents: lines.reduce((s, l) => s + Math.max(0, l.quantity * l.unitPriceCents - l.discountCents), 0),
  };
}

export async function bridgeOrderPaid(args: {
  service: RewardsService; webhookId: string; order: OrderLike; topic: string;
}): Promise<void> {
  const orderId = String(args.order.id);
  const customerId = args.order.customer ? String(args.order.customer.id) : null;
  const tags = parseTags(args.order.tags);
  const codes = (args.order.discount_codes ?? []).map((d) => d.code ?? '').filter(Boolean);
  const notes: Record<string, string> = {};
  for (const a of args.order.note_attributes ?? []) notes[a.name] = a.value;
  const { isWholesale, signals } = detectWholesale({ tags, discountCodes: codes, noteAttributes: notes });
  const { lines, subtotalEligibleCents } = toEarnInput(args.order);
  await args.service.onOrderPaid({
    eventId: `${args.topic}:${args.webhookId}:paid:${orderId}`,
    orderShopifyId: orderId,
    accountId: customerId,
    subtotalEligibleCents,
    lines,
    isWholesale,
    signals,
    currency: args.order.currency ?? 'MXN',
  });
}

/**
 * Solo DELIVERED libera. FULFILLED / IN_TRANSIT / preparado / enviado NO liberan:
 * no equivalen a entrega. fulfillment_status 'fulfilled' sin evento DELIVERED
 * se registra como no-verificado y no libera.
 */
export function isDeliveryEvidence(args: {
  status?: string | null; eventStatus?: string | null;
}): boolean {
  const s = (args.eventStatus ?? args.status ?? '').trim().toUpperCase();
  return s === 'DELIVERED';
}

export async function bridgeDelivery(args: {
  service: RewardsService; webhookId: string;
  orderId: string; eventStatus: string | null; occurredAt?: string | null;
}): Promise<{ released: boolean }> {
  if (!isDeliveryEvidence({ eventStatus: args.eventStatus })) return { released: false };
  await args.service.onOrderDelivered({
    eventId: `fulfillment:${args.webhookId}:${args.orderId}`,
    orderShopifyId: args.orderId,
    occurredAt: args.occurredAt ? new Date(args.occurredAt) : null,
  });
  return { released: true };
}

interface RefundLike {
  order_id?: number;
  refund_line_items?: { line_item?: { price?: string | null; quantity?: number }; quantity?: number; subtotal?: string | null }[];
}

/**
 * Reversion proporcional: 3% del subtotal elegible reembolsado (half-up).
 * El repositorio la acota al remanente no revertido, asi que un reembolso
 * duplicado o un redondeo no revierten dos veces.
 */
export function refundReverseCents(refund: RefundLike, earnBps: number): number | null {
  if (!refund.refund_line_items || refund.refund_line_items.length === 0) return null;
  let refundedEligible = 0;
  for (const item of refund.refund_line_items) {
    const qty = typeof item.quantity === 'number' && item.quantity > 0 ? Math.floor(item.quantity) : 0;
    if (qty <= 0) continue;
    const unit = item.line_item?.price ? cents(item.line_item.price) : 0;
    refundedEligible += qty * unit;
  }
  if (refundedEligible <= 0) return null;
  return Math.floor((refundedEligible * earnBps + 5000) / 10000);
}

/**
 * Reglas puras de Rewards V1 (sin IO): 3% menudeo, tope 20%, vigencia 12 meses,
 * exclusion de mayoreo, redondeo en centavos. Todo lo pendiente de decision
 * comercial se representa como deshabilitado, nunca con importes inventados.
 */
import type { CartLineInput, OrderLineSnapshot, ProgramPolicy } from './types.js';

export interface EligibleBreakdown {
  /** S: subtotal elegible antes de Rewards, en centavos. */
  readonly subtotalEligibleCents: number;
  readonly lines: readonly OrderLineSnapshot[];
  readonly ineligibleCents: number;
}

/** S = suma por linea elegible de (qty*unit - discount), jamas negativo por linea. */
export function eligibleSubtotal(lines: readonly CartLineInput[]): EligibleBreakdown {
  const out: OrderLineSnapshot[] = [];
  let eligible = 0;
  let ineligible = 0;
  for (const line of lines) {
    if (!Number.isInteger(line.quantity) || line.quantity <= 0) throw new Error('invalid_quantity');
    if (!Number.isInteger(line.unitPriceCents) || line.unitPriceCents < 0) throw new Error('invalid_price');
    const discount = line.discountCents ?? 0;
    if (!Number.isInteger(discount) || discount < 0) throw new Error('invalid_discount');
    const gross = line.quantity * line.unitPriceCents;
    const net = Math.max(0, gross - Math.min(discount, gross));
    const isEligible = line.eligible ?? true;
    out.push({
      variantId: line.variantId ?? null,
      productId: line.productId ?? null,
      quantity: line.quantity,
      unitPriceCents: line.unitPriceCents,
      discountCents: Math.min(discount, gross),
      eligible: isEligible,
      lineEligibleCents: isEligible ? net : 0,
    });
    if (isEligible) eligible += net;
    else ineligible += net;
  }
  return { subtotalEligibleCents: eligible, lines: out, ineligibleCents: ineligible };
}

/**
 * Rmax = min(disponible, floor(S * bps / 10000)).
 * S y disponible en centavos enteros.
 */
export function maxRedeemableCents(args: {
  subtotalEligibleCents: number;
  availableCents: number;
  maxRedeemBps: number;
}): number {
  const { subtotalEligibleCents: s, availableCents: a, maxRedeemBps } = args;
  if (!Number.isInteger(s) || s < 0) throw new Error('invalid_subtotal');
  if (!Number.isInteger(a) || a < 0) throw new Error('invalid_balance');
  if (!Number.isInteger(maxRedeemBps) || maxRedeemBps < 0 || maxRedeemBps > 10000) {
    throw new Error('invalid_bps');
  }
  return Math.min(a, Math.floor((s * maxRedeemBps) / 10000));
}

/**
 * G = redondeo half-up de ((S - R) * earnBps / 10000).
 * Propuesta calculable (base neta: despues del canje, antes de bonos).
 * Requiere acuerdo comercial para ser definitiva; esta funcion solo la calcula.
 */
export function estimatedEarnCents(args: {
  subtotalEligibleCents: number;
  redeemCents: number;
  earnBps: number;
}): number {
  const { subtotalEligibleCents: s, redeemCents: r, earnBps } = args;
  if (!Number.isInteger(s) || s < 0) throw new Error('invalid_subtotal');
  if (!Number.isInteger(r) || r < 0 || r > s) throw new Error('invalid_redeem');
  if (!Number.isInteger(earnBps) || earnBps < 0) throw new Error('invalid_bps');
  return Math.floor(((s - r) * earnBps + 5000) / 10000);
}

/** 12 meses calendario desde liberacion; fin de mes se recorta al ultimo dia. */
export function expiryFromRelease(releasedAt: Date, months: number): Date {
  if (!Number.isInteger(months) || months <= 0) throw new Error('invalid_months');
  const y = releasedAt.getUTCFullYear();
  const m = releasedAt.getUTCMonth();
  const d = releasedAt.getUTCDate();
  const targetMonth = m + months;
  const targetYear = y + Math.floor(targetMonth / 12);
  const normMonth = ((targetMonth % 12) + 12) % 12;
  const lastDay = new Date(Date.UTC(targetYear, normMonth + 1, 0)).getUTCDate();
  const day = Math.min(d, lastDay);
  return new Date(Date.UTC(
    targetYear, normMonth, day,
    releasedAt.getUTCHours(), releasedAt.getUTCMinutes(),
    releasedAt.getUTCSeconds(), releasedAt.getUTCMilliseconds(),
  ));
}

const WHOLESALE_TAG = /(mayoreo|wholesale|mayorista|reseller)/i;

/**
 * Deteccion conservadora de mayoreo desde datos comerciales verificables del
 * servidor (tags, codigos, atributos). Nunca desde un booleano del telefono.
 * Ante duda: si hay señal, se trata como mayoreo (no genera).
 */
export function detectWholesale(args: {
  tags?: readonly string[];
  discountCodes?: readonly string[];
  noteAttributes?: Readonly<Record<string, string>>;
}): { isWholesale: boolean; signals: string[] } {
  const signals: string[] = [];
  for (const tag of args.tags ?? []) {
    if (WHOLESALE_TAG.test(tag)) signals.push(`tag:${tag}`);
  }
  for (const code of args.discountCodes ?? []) {
    if (WHOLESALE_TAG.test(code)) signals.push(`discount:${code}`);
  }
  const attrs = args.noteAttributes ?? {};
  for (const [k, v] of Object.entries(attrs)) {
    if (WHOLESALE_TAG.test(k) || WHOLESALE_TAG.test(v)) signals.push(`note:${k}`);
  }
  if ((attrs['wholesale'] ?? '').toLowerCase() === 'true') signals.push('note:wholesale=true');
  return { isWholesale: signals.length > 0, signals };
}

/** Elegibilidad de canje: programa activo + no mayoreo pendiente + R dentro del tope. */
export function redemptionEligibility(args: {
  policy: ProgramPolicy;
  isWholesaleCart: boolean;
  requestedCents: number;
  maxAllowedCents: number;
}): { ok: true } | { ok: false; code: string; message: string } {
  if (!args.policy.redemptionEnabled) {
    return { ok: false, code: 'redemption_disabled', message: 'El canje está deshabilitado.' };
  }
  if (args.isWholesaleCart && args.policy.wholesaleRedeemAllowed !== true) {
    return {
      ok: false,
      code: 'wholesale_redeem_undecided',
      message: 'El uso de Rewards en mayoreo aún no está definido.',
    };
  }
  if (!Number.isInteger(args.requestedCents) || args.requestedCents <= 0) {
    return { ok: false, code: 'invalid_amount', message: 'Importe inválido.' };
  }
  if (args.requestedCents > args.maxAllowedCents) {
    return {
      ok: false,
      code: 'exceeds_limit',
      message: `El máximo canjeable para esta compra es ${(args.maxAllowedCents / 100).toFixed(2)}.`,
    };
  }
  return { ok: true };
}

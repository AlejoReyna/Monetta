/**
 * Gateway and method names, normalized the same way the app stores
 * Customer Account `Order.transactions.type`
 * (`lib/data/customer_auth/customer_orders.dart`).
 *
 * Tokens are lowercase, with spaces and hyphens folded to underscores,
 * de-duplicated, and comma-joined. Processing kinds (`sale`,
 * `authorization`, …), financial statuses, digits-only values, and
 * emails are dropped. Card numbers and other payment details are never read.
 *
 * A known method stays as that token (`paypal`, `mercadopago`, `card`,
 * `bank_deposit`, …). `shopify_payments` and `card`, including case and
 * spacing variants (`Shopify Payments`, `CARD`), are stored as `card`,
 * never as `shopify_payments` or `other:`. Any other gateway is
 * `other:<sanitized name>` so a present method is never stored as null.
 *
 * PayPal and Mercado Pago gateway names, before the `other:` rule:
 * `paypal` / `PayPal` → `paypal`; `PayPal Express Checkout` →
 * `paypal_express_checkout`; `Mercado Pago` / `mercado_pago` →
 * `mercado_pago`; `MercadoPago` → `mercadopago`. Those PayPal and
 * Mercado Pago spellings now collapse to `paypal` and `mercadopago`.
 */

const NON_METHOD_TOKENS = new Set([
  'sale',
  'authorization',
  'capture',
  'void',
  'refund',
  'change',
  'emv_authorization',
  'suggested_refund',
  'pending',
  'paid',
  'authorized',
  'partially_paid',
  'partially_refunded',
  'refunded',
  'voided',
  'cancelled',
  'canceled',
  'expired',
  'unpaid',
  'success',
  'failure',
  'error',
  'unknown',
]);

/** Display labels that already have a Customer Account or gateway token. */
const METHOD_ALIASES: Readonly<Record<string, string>> = {
  cash_on_delivery_cod: 'cash_on_delivery',
  shopify_payments: 'card',
  paypal_express: 'paypal',
  paypal_express_checkout: 'paypal',
  paypal_commerce: 'paypal',
  mercado_pago: 'mercadopago',
  mercado_pago_tarjetas: 'mercadopago',
  mercado_pago_checkout_pro: 'mercadopago',
};

/**
 * Tokens stored as themselves. Anything else that survives sanitizing is
 * prefixed with `other:` instead of being dropped.
 */
const KNOWN_METHOD_TOKENS = new Set([
  'bank_deposit',
  'manual',
  'card',
  'paypal',
  'mercadopago',
  'cash_on_delivery',
  'money_order',
  'gift_card',
  'store_credit',
  'custom',
  'shop_pay',
  'apple_pay',
  'google_pay',
  'bogus',
  'shopify_installments',
]);

export interface ShopifyPaymentTransactionSource {
  readonly gateway?: string | null;
  readonly formattedGateway?: string | null;
  readonly formatted_gateway?: string | null;
  readonly type?: string | null;
  readonly kind?: string | null;
}

export interface ShopifyPaymentMethodSource {
  readonly payment_gateway_names?: readonly unknown[] | string | null;
  readonly gateway?: string | null;
  readonly transactions?: readonly ShopifyPaymentTransactionSource[] | null;
}

export function normalizePaymentMethodToken(raw: string): string | null {
  const folded = raw
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '');
  if (folded.length === 0 || folded.includes('@')) return null;
  const snake = folded
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .replace(/_+/g, '_');
  if (snake.length === 0 || snake.length > 64) return null;
  if (/^\d+$/.test(snake)) return null;
  if (NON_METHOD_TOKENS.has(snake)) return null;
  return METHOD_ALIASES[snake] ?? snake;
}

/** Known token, or `other:<sanitized>` when the gateway name is not a known method. */
export function classifyPaymentMethodToken(raw: string): string | null {
  const snake = normalizePaymentMethodToken(raw);
  if (snake === null) return null;
  if (KNOWN_METHOD_TOKENS.has(snake)) return snake;
  return `other:${snake}`;
}

function pushToken(tokens: string[], raw: unknown): void {
  if (typeof raw !== 'string') return;
  const token = classifyPaymentMethodToken(raw);
  if (token === null || tokens.includes(token)) return;
  tokens.push(token);
}

function formattedGateway(transaction: ShopifyPaymentTransactionSource): string | null {
  if (typeof transaction.formattedGateway === 'string') return transaction.formattedGateway;
  if (typeof transaction.formatted_gateway === 'string') return transaction.formatted_gateway;
  return null;
}

/**
 * Method tokens in source order: transaction type, then gateway, then a
 * non-processing kind, then `payment_gateway_names`, then the order gateway.
 * Empty input is null so a pending order is not guessed to be a transfer.
 */
export function normalizePaymentMethod(source: ShopifyPaymentMethodSource): string | null {
  const tokens: string[] = [];
  const transactions = Array.isArray(source.transactions) ? source.transactions : [];
  for (const transaction of transactions) {
    if (transaction === null || typeof transaction !== 'object') continue;
    pushToken(tokens, transaction.type);
    const gateway = typeof transaction.gateway === 'string' ? transaction.gateway : null;
    pushToken(tokens, gateway);
    if (classifyPaymentMethodToken(gateway ?? '') === null) {
      pushToken(tokens, formattedGateway(transaction));
    }
    pushToken(tokens, transaction.kind);
  }

  const names = source.payment_gateway_names;
  if (Array.isArray(names)) {
    for (const name of names) pushToken(tokens, name);
  } else {
    pushToken(tokens, names);
  }
  pushToken(tokens, source.gateway);

  if (tokens.length === 0) return null;
  return tokens.join(',');
}

/** True when [value] is already a normalized method list safe to persist. */
export function isNormalizedPaymentMethod(value: string): boolean {
  return /^(?:other:)?[a-z0-9_]+(?:,(?:other:)?[a-z0-9_]+)*$/.test(value) &&
    value.length <= 200;
}

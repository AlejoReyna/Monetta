/**
 * Gateway and method names, normalized the same way the app stores
 * Customer Account `Order.transactions.type`
 * (`lib/data/customer_auth/customer_orders.dart`).
 *
 * Tokens are lowercase, with spaces and hyphens folded to underscores,
 * de-duplicated, and comma-joined. Processing kinds (`sale`,
 * `authorization`, …), financial statuses, digits-only values, and
 * anything that is not a method name are dropped. Card numbers and
 * other payment details are never read.
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

/** Reserved Shopify manual-method labels that the Customer Account enum spells differently. */
const METHOD_ALIASES: Readonly<Record<string, string>> = {
  cash_on_delivery_cod: 'cash_on_delivery',
};

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

function pushToken(tokens: string[], raw: unknown): void {
  if (typeof raw !== 'string') return;
  const token = normalizePaymentMethodToken(raw);
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
    if (normalizePaymentMethodToken(gateway ?? '') === null) {
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
  return /^[a-z0-9_]+(,[a-z0-9_]+)*$/.test(value) && value.length <= 200;
}

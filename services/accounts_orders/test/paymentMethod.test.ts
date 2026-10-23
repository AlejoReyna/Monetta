import { describe, expect, it } from 'vitest';
import {
  TRANSFER_METHOD_ALIASES,
  isNormalizedPaymentMethod,
  normalizePaymentMethod,
} from '../src/orders/paymentMethod.js';

/** Not a store name. Proves one alias entry stores `bank_deposit`. */
const FAKE_TRANSFER_ALIAS_FIXTURE = {
  zz_fake_transfer_rail: 'bank_deposit',
} as const;

describe('normalizePaymentMethod', () => {
  it('maps Bank Deposit and manual gateways to the Customer Account tokens', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Bank Deposit'],
    })).toBe('bank_deposit');
    expect(normalizePaymentMethod({
      transactions: [{ kind: 'sale', gateway: 'manual', type: 'MANUAL' }],
    })).toBe('manual');
  });

  it('maps one transfer alias entry to bank_deposit and ignores it until listed', () => {
    expect(TRANSFER_METHOD_ALIASES.transferencia_bancaria).toBe('bank_deposit');
    expect(normalizePaymentMethod(
      { payment_gateway_names: ['ZZ Fake Transfer Rail'] },
      FAKE_TRANSFER_ALIAS_FIXTURE,
    )).toBe('bank_deposit');
    expect(normalizePaymentMethod(
      { gateway: 'zz-fake-transfer-rail' },
      FAKE_TRANSFER_ALIAS_FIXTURE,
    )).toBe('bank_deposit');
    expect(normalizePaymentMethod({
      payment_gateway_names: ['ZZ Fake Transfer Rail'],
    })).toBe('other:zz_fake_transfer_rail');
    expect(normalizePaymentMethod(
      { payment_gateway_names: ['constructor'] },
      FAKE_TRANSFER_ALIAS_FIXTURE,
    )).toBe('other:constructor');
  });

  it('recognizes the confirmed staging transfer name but leaves unlisted names distinct', () => {
    for (const name of [
      'Transferencia bancaria',
      'TRANSFERENCIA BANCARIA',
      '  TRANSFERENCIA   BANCARIA  ',
      'transferencia-bancaria',
      'Transferéncia bancária',
    ]) {
      expect({
        name,
        stored: normalizePaymentMethod({ payment_gateway_names: [name] }),
      }).toEqual({ name, stored: 'bank_deposit' });
      expect({
        name,
        unsanitized: normalizePaymentMethod({ payment_gateway_names: [name] }, {}),
      }).toEqual({ name, unsanitized: 'other:transferencia_bancaria' });
    }
    expect(normalizePaymentMethod({
      gateway: 'Depósito bancario',
    })).toBe('other:deposito_bancario');
  });

  it('collapses PayPal gateway spellings to paypal', () => {
    expect(normalizePaymentMethod({ payment_gateway_names: ['paypal'] })).toBe('paypal');
    expect(normalizePaymentMethod({ payment_gateway_names: ['PayPal'] })).toBe('paypal');
    expect(normalizePaymentMethod({ gateway: 'paypal_express' })).toBe('paypal');
    expect(normalizePaymentMethod({
      payment_gateway_names: ['PayPal Express Checkout'],
    })).toBe('paypal');
    expect(normalizePaymentMethod({ gateway: 'paypal_commerce' })).toBe('paypal');
  });

  it('collapses Mercado Pago gateway spellings to mercadopago', () => {
    expect(normalizePaymentMethod({ payment_gateway_names: ['Mercado Pago'] })).toBe('mercadopago');
    expect(normalizePaymentMethod({ gateway: 'mercado_pago' })).toBe('mercadopago');
    expect(normalizePaymentMethod({ gateway: 'mercado-pago' })).toBe('mercadopago');
    expect(normalizePaymentMethod({ payment_gateway_names: ['MercadoPago'] })).toBe('mercadopago');
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Mercado Pago Checkout Pro'],
    })).toBe('mercadopago');
  });

  it('stores an inherited object key as other:<name>, not the prototype value', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['constructor'],
    })).toBe('other:constructor');
    expect(isNormalizedPaymentMethod('other:constructor')).toBe(true);
  });

  it('accepts every list the normalizer emits, including ones longer than 200 characters', () => {
    const names = ['a', 'b', 'c'].map((suffix) => `${'g'.repeat(63)}${suffix}`);
    const stored = normalizePaymentMethod({ payment_gateway_names: names });
    expect(stored).toBe(names.map((name) => `other:${name}`).join(','));
    expect(stored!.length).toBeGreaterThan(200);
    expect(isNormalizedPaymentMethod(stored!)).toBe(true);
  });

  it('stores an unrecognized gateway as other:<sanitized name>', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Kueski Pay'],
    })).toBe('other:kueski_pay');
    expect(isNormalizedPaymentMethod('other:kueski_pay')).toBe(true);
    expect(isNormalizedPaymentMethod('paypal,other:kueski_pay')).toBe(true);
    expect(isNormalizedPaymentMethod('')).toBe(false);
    expect(isNormalizedPaymentMethod('Kueski Pay')).toBe(false);
  });

  it('maps shopify_payments and card variants to card', () => {
    for (const name of [
      'shopify_payments',
      'Shopify Payments',
      'SHOPIFY_PAYMENTS',
      'shopify-payments',
      'card',
      'Card',
      'CARD',
      ' card ',
    ]) {
      expect(normalizePaymentMethod({ payment_gateway_names: [name] })).toBe('card');
    }
    expect(normalizePaymentMethod({
      payment_gateway_names: ['shopify_payments'],
      transactions: [{
        kind: 'authorization',
        gateway: 'shopify_payments',
        formattedGateway: 'Shopify Payments',
      }],
    })).toBe('card');
    expect(normalizePaymentMethod({
      transactions: [{ type: 'CARD', kind: 'SALE' }],
    })).toBe('card');
    expect(normalizePaymentMethod({
      payment_gateway_names: ['shopify_payments'],
    })).not.toMatch(/^other:/);
  });

  it('returns null when no method name is present', () => {
    expect(normalizePaymentMethod({})).toBeNull();
    expect(normalizePaymentMethod({ payment_gateway_names: [] })).toBeNull();
    expect(normalizePaymentMethod({
      transactions: [{ kind: 'sale' }],
    })).toBeNull();
    expect(normalizePaymentMethod({
      payment_gateway_names: ['4242424242424242'],
    })).toBeNull();
  });

  it('dedupes CAA-shaped transaction types without reading other fields', () => {
    expect(normalizePaymentMethod({
      transactions: [
        { type: 'BANK_DEPOSIT' },
        { type: 'bank_deposit' },
      ],
      payment_gateway_names: ['Bank Deposit'],
    })).toBe('bank_deposit');
  });

  it('maps the reserved cash-on-delivery label onto the Customer Account token', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Cash on Delivery (COD)'],
    })).toBe('cash_on_delivery');
  });
});

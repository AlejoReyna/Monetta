import { describe, expect, it } from 'vitest';
import {
  isNormalizedPaymentMethod,
  normalizePaymentMethod,
} from '../src/orders/paymentMethod.js';

describe('normalizePaymentMethod', () => {
  it('maps Bank Deposit and manual gateways to the Customer Account tokens', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Bank Deposit'],
    })).toBe('bank_deposit');
    expect(normalizePaymentMethod({
      transactions: [{ kind: 'sale', gateway: 'manual', type: 'MANUAL' }],
    })).toBe('manual');
  });

  it('keeps a similar transfer label distinguishable from bank_deposit', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Transferencia bancaria'],
    })).toBe('other:transferencia_bancaria');
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

  it('stores an unrecognized gateway as other:<sanitized name>', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Kueski Pay'],
    })).toBe('other:kueski_pay');
    expect(isNormalizedPaymentMethod('other:kueski_pay')).toBe(true);
    expect(isNormalizedPaymentMethod('paypal,other:kueski_pay')).toBe(true);
    expect(isNormalizedPaymentMethod('')).toBe(false);
    expect(isNormalizedPaymentMethod('Kueski Pay')).toBe(false);
  });

  it('keeps a card gateway and drops processing kinds', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['shopify_payments'],
      transactions: [{ kind: 'authorization', gateway: 'shopify_payments' }],
    })).toBe('shopify_payments');
    expect(normalizePaymentMethod({
      transactions: [{ type: 'CARD', kind: 'SALE' }],
    })).toBe('card');
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

import { describe, expect, it } from 'vitest';
import { normalizePaymentMethod } from '../src/orders/paymentMethod.js';

describe('normalizePaymentMethod', () => {
  it('maps Bank Deposit and manual gateways to the Customer Account tokens', () => {
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Bank Deposit'],
    })).toBe('bank_deposit');
    expect(normalizePaymentMethod({
      transactions: [{ kind: 'sale', gateway: 'manual', type: 'MANUAL' }],
    })).toBe('manual');
    expect(normalizePaymentMethod({
      payment_gateway_names: ['Transferencia bancaria'],
    })).toBe('transferencia_bancaria');
    expect(normalizePaymentMethod({
      gateway: 'Depósito bancario',
    })).toBe('deposito_bancario');
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

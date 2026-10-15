import { describe, expect, it } from 'vitest';
import { orderCorrelationToken } from '../src/webhooks/payloads.js';

describe('orderCorrelationToken', () => {
  it('keeps a single opaque token', () => {
    expect(orderCorrelationToken('chk_a1b2c3d4e5')).toBe('chk_a1b2c3d4e5');
    expect(orderCorrelationToken('  crt-f6e5d4c3b2  ')).toBe('crt-f6e5d4c3b2');
  });

  it('drops a trailing query so the cart key is not stored', () => {
    expect(orderCorrelationToken('crt_f6e5d4c3b2?key=not-a-stored-key')).toBe('crt_f6e5d4c3b2');
    expect(orderCorrelationToken('crt_f6e5d4c3b2?key=not-a-stored-key')).not.toContain('not-a-stored-key');
  });

  it('rejects blanks, non-strings, over-long values, and anything that is not one token', () => {
    expect(orderCorrelationToken(undefined)).toBeNull();
    expect(orderCorrelationToken(null)).toBeNull();
    expect(orderCorrelationToken('')).toBeNull();
    expect(orderCorrelationToken('   ')).toBeNull();
    expect(orderCorrelationToken('?key=not-a-stored-key')).toBeNull();
    expect(orderCorrelationToken(12345)).toBeNull();
    expect(orderCorrelationToken({ token: 'chk_a1b2c3d4e5' })).toBeNull();
    expect(orderCorrelationToken('chk token')).toBeNull();
    expect(orderCorrelationToken('chk_a1b2c3d4e5/extra')).toBeNull();
    expect(orderCorrelationToken(`${'a'.repeat(256)}`)).toBeNull();
    expect(orderCorrelationToken('a'.repeat(255))).toBe('a'.repeat(255));
  });
});

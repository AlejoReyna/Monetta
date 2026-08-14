import { createHmac } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { verifyShopifyWebhookHmac } from '../src/webhooks/verifyHmac.js';

const secret = 'shpss_test_secret';

function sign(body: Buffer, key = secret): string {
  return createHmac('sha256', key).update(body).digest('base64');
}

describe('verifyShopifyWebhookHmac', () => {
  it('accepts a correctly signed body', () => {
    const body = Buffer.from(JSON.stringify({ id: 1 }));
    expect(verifyShopifyWebhookHmac(body, sign(body), secret)).toBe(true);
  });

  it('rejects a body signed with the wrong secret', () => {
    const body = Buffer.from(JSON.stringify({ id: 1 }));
    expect(verifyShopifyWebhookHmac(body, sign(body, 'wrong'), secret)).toBe(false);
  });

  it('rejects a tampered body even with a validly-formed signature', () => {
    const original = Buffer.from(JSON.stringify({ id: 1 }));
    const tampered = Buffer.from(JSON.stringify({ id: 2 }));
    expect(verifyShopifyWebhookHmac(tampered, sign(original), secret)).toBe(false);
  });

  it('rejects a missing signature header', () => {
    const body = Buffer.from('{}');
    expect(verifyShopifyWebhookHmac(body, undefined, secret)).toBe(false);
  });

  it('rejects when the configured secret is empty (fail closed)', () => {
    const body = Buffer.from('{}');
    expect(verifyShopifyWebhookHmac(body, sign(body, ''), '')).toBe(false);
  });

  it('rejects a non-base64 header without throwing', () => {
    const body = Buffer.from('{}');
    expect(verifyShopifyWebhookHmac(body, 'not base64 !!!', secret)).toBe(false);
  });

  it('rejects a signature of a different length without throwing', () => {
    const body = Buffer.from('{}');
    expect(verifyShopifyWebhookHmac(body, Buffer.from('short').toString('base64'), secret)).toBe(
      false,
    );
  });
});

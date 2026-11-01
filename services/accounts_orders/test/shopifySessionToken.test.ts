import { describe, expect, it } from 'vitest';
import { ShopifySessionTokenVerifier } from '../src/admin/shopifySessionToken.js';
import {
  signSessionToken,
  testClientId,
  testClientSecret,
  testShop,
} from './support/shopifySessionTokens.js';

const now = new Date('2026-10-29T18:00:00Z');
const nowSeconds = Math.floor(now.getTime() / 1000);

function verifier(overrides: { shopDomain?: string } = {}) {
  return new ShopifySessionTokenVerifier({
    clientId: testClientId,
    clientSecret: testClientSecret,
    shopDomain: overrides.shopDomain ?? testShop,
    now: () => now,
  });
}

describe('Shopify Admin session tokens', () => {
  it('accepts a token Shopify signed for this app and shop', () => {
    expect(verifier().verify(signSessionToken({}, { now }))).toEqual({ staffUserId: '74218901' });
  });

  it('normalizes a configured shop URL', () => {
    const token = signSessionToken({}, { now });
    expect(verifier({ shopDomain: `https://${testShop.toUpperCase()}/` }).verify(token))
      .toEqual({ staffUserId: '74218901' });
  });

  it('rejects a token signed with another secret', () => {
    expect(verifier().verify(signSessionToken({}, { now, secret: 'someone-else' }))).toBeNull();
  });

  it('rejects a tampered payload', () => {
    const [header, , signature] = signSessionToken({}, { now }).split('.');
    const forged = Buffer.from(JSON.stringify({
      iss: `https://${testShop}/admin`,
      dest: `https://${testShop}`,
      aud: testClientId,
      sub: '1',
      exp: nowSeconds + 60,
      nbf: nowSeconds,
    })).toString('base64url');
    expect(verifier().verify(`${header}.${forged}.${signature}`)).toBeNull();
  });

  it('pins HS256 so an unsigned token is never accepted', () => {
    const token = signSessionToken({}, { now, header: { alg: 'none', typ: 'JWT' } });
    expect(verifier().verify(token)).toBeNull();
    const [header, payload] = token.split('.');
    expect(verifier().verify(`${header}.${payload}.`)).toBeNull();
  });

  it('rejects tokens for another app or another shop', () => {
    expect(verifier().verify(signSessionToken({ aud: 'another-app' }, { now }))).toBeNull();
    expect(verifier().verify(signSessionToken({
      dest: 'https://monetta-2.myshopify.com',
      iss: 'https://monetta-2.myshopify.com/admin',
    }, { now }))).toBeNull();
    expect(verifier().verify(signSessionToken({
      iss: 'https://monetta-2.myshopify.com/admin',
    }, { now }))).toBeNull();
  });

  it('enforces expiry and not-before with a small clock tolerance', () => {
    expect(verifier().verify(signSessionToken({ exp: nowSeconds - 5 }, { now })))
      .toEqual({ staffUserId: '74218901' });
    expect(verifier().verify(signSessionToken({ exp: nowSeconds - 10 }, { now }))).toBeNull();
    expect(verifier().verify(signSessionToken({ nbf: nowSeconds + 5 }, { now })))
      .toEqual({ staffUserId: '74218901' });
    expect(verifier().verify(signSessionToken({ nbf: nowSeconds + 30 }, { now }))).toBeNull();
    expect(verifier().verify(signSessionToken({ exp: undefined }, { now }))).toBeNull();
    expect(verifier().verify(signSessionToken({ nbf: undefined }, { now }))).toBeNull();
  });

  it('requires a numeric staff id', () => {
    expect(verifier().verify(signSessionToken({ sub: undefined }, { now }))).toBeNull();
    expect(verifier().verify(signSessionToken({ sub: 'gid://shopify/User/1' }, { now }))).toBeNull();
    expect(verifier().verify(signSessionToken({ sub: 74218901 }, { now }))).toBeNull();
  });

  it('ignores credentials that are not JWTs', () => {
    expect(verifier().verify('opaque-monetta-session-token')).toBeNull();
    expect(verifier().verify('a.b')).toBeNull();
    expect(verifier().verify('a.b.c.d')).toBeNull();
    expect(verifier().verify('e30.e30.%%%')).toBeNull();
    expect(verifier().verify('bm90LWpzb24.bm90LWpzb24.c2ln')).toBeNull();
  });

  it('refuses to start without its configuration', () => {
    expect(() => new ShopifySessionTokenVerifier({
      clientId: '',
      clientSecret: testClientSecret,
      shopDomain: testShop,
    })).toThrow();
    expect(() => new ShopifySessionTokenVerifier({
      clientId: testClientId,
      clientSecret: '',
      shopDomain: testShop,
    })).toThrow();
    expect(() => new ShopifySessionTokenVerifier({
      clientId: testClientId,
      clientSecret: testClientSecret,
      shopDomain: ' ',
    })).toThrow();
  });
});

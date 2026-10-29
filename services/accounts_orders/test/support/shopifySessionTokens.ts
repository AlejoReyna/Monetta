import { createHmac } from 'node:crypto';

export const testShop = 'monetta-staging.myshopify.com';
export const testClientId = '4a29ba522a35bd476f3d1f467749234f';
export const testClientSecret = 'shopify-test-secret';

/** Signs a token shaped like the ones App Bridge hands an embedded page. */
export function signSessionToken(
  overrides: Record<string, unknown> = {},
  {
    secret = testClientSecret,
    header = { alg: 'HS256', typ: 'JWT' },
    now = new Date(),
  }: {
    readonly secret?: string;
    readonly header?: Record<string, unknown>;
    readonly now?: Date;
  } = {},
): string {
  const issuedAt = Math.floor(now.getTime() / 1000);
  const claims = {
    iss: `https://${testShop}/admin`,
    dest: `https://${testShop}`,
    aud: testClientId,
    sub: '74218901',
    exp: issuedAt + 60,
    nbf: issuedAt,
    iat: issuedAt,
    jti: 'b0c9c7d2-5d1c-4d2a-9f0c-3a1e1e2c7b11',
    sid: 'session-1',
    ...overrides,
  };
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const unsigned = `${encode(header)}.${encode(claims)}`;
  const signature = createHmac('sha256', secret).update(unsigned).digest('base64url');
  return `${unsigned}.${signature}`;
}

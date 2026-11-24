import { describe, expect, it } from 'vitest';
import { FirebaseAppCheckVerifier } from '../src/engagement/infrastructure/firebaseAppCheckVerifier.js';
import { GoogleAccessTokenProvider } from '../src/engagement/infrastructure/googleAccessTokenProvider.js';
class TestTokens extends GoogleAccessTokenProvider {
  constructor() { super('', ''); }
  override async accessToken() { return 'test-access-token'; }
}
function verifier(status: number, body: unknown) {
  return new FirebaseAppCheckVerifier('staging', new TestTokens(),
    (async () => new Response(JSON.stringify(body), { status })) as typeof fetch);
}
const token = 'valid-token-with-sufficient-length';
describe('Firebase REST App Check verification', () => {
  it('accepts the empty successful response from Firebase', async () => {
    expect(await verifier(200, {}).verify(token)).toBe(true);
  });
  it('accepts a verified token for repeat installation requests', async () => {
    expect(await verifier(200, { alreadyConsumed: true }).verify(token)).toBe(true);
  });
  it('rejects invalid tokens and malformed responses', async () => {
    expect(await verifier(403, { error: 'invalid' }).verify(token)).toBe(false);
    expect(await verifier(200, null).verify(token)).toBe(false);
    expect(await verifier(200, { alreadyConsumed: 'true' }).verify(token)).toBe(false);
    expect(await verifier(200, {}).verify(null)).toBe(false);
  });
});

import type { AppCheckVerifier } from '../domain/ports.js';
import { GoogleAccessTokenProvider } from './googleAccessTokenProvider.js';

export class FirebaseAppCheckVerifier implements AppCheckVerifier {
  constructor(
    private readonly projectId: string,
    private readonly tokens: GoogleAccessTokenProvider,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async verify(token: string | null): Promise<boolean> {
    if (token === null || token.length < 20 || token.length > 8192) return false;
    try {
      const accessToken = await this.tokens.accessToken();
      const response = await this.fetchFn(
        `https://firebaseappcheck.googleapis.com/v1beta/projects/${encodeURIComponent(this.projectId)}:verifyAppCheckToken`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ appCheckToken: token }),
          signal: AbortSignal.timeout(10_000),
        },
      );
      if (!response.ok) return false;
      // Firebase returns {} or an optional alreadyConsumed boolean, not appId.
      // Invalid tokens fail with HTTP 403. Repeat installation requests may
      // legitimately reuse a verified token.
      const body: unknown = await response.json();
      return body !== null && typeof body === 'object' && !Array.isArray(body) &&
        (!('alreadyConsumed' in body) || typeof body.alreadyConsumed === 'boolean');
    } catch {
      return false;
    }
  }
}

export class DevelopmentAppCheckVerifier implements AppCheckVerifier {
  async verify(_token: string | null): Promise<boolean> {
    return true;
  }
}

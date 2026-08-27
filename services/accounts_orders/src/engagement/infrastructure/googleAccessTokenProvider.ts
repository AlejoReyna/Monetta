import { createSign } from 'node:crypto';

export class GoogleAccessTokenProvider {
  private cached: { token: string; expiresAt: number } | null = null;

  constructor(
    private readonly clientEmail: string,
    private readonly privateKey: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.cached !== null && this.cached.expiresAt - 60 > now) return this.cached.token;

    const header = base64Url({ alg: 'RS256', typ: 'JWT' });
    const payload = base64Url({
      iss: this.clientEmail,
      scope: 'https://www.googleapis.com/auth/cloud-platform',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    });
    const unsigned = `${header}.${payload}`;
    const signer = createSign('RSA-SHA256');
    signer.update(unsigned);
    signer.end();
    const assertion = `${unsigned}.${signer.sign(this.privateKey, 'base64url')}`;

    const response = await this.fetchFn('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) throw new Error(`google oauth returned HTTP ${response.status}`);
    const json = await response.json() as { access_token?: unknown; expires_in?: unknown };
    if (typeof json.access_token !== 'string') throw new Error('google oauth returned no access token');
    const expiresIn = typeof json.expires_in === 'number' ? json.expires_in : 3600;
    this.cached = { token: json.access_token, expiresAt: now + expiresIn };
    return json.access_token;
  }
}

function base64Url(value: unknown): string {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

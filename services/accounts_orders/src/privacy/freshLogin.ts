import { createPublicKey, createVerify, type JsonWebKey, type KeyObject } from 'node:crypto';
import {
  CustomerTokenVerificationUnavailableError,
  type CustomerTokenVerifier,
} from '../auth/customerTokenVerifier.js';
import type { FreshLoginDecision, FreshLoginVerifier } from './ports.js';

const maxTokenLength = 8192;
const clockSkewSeconds = 60;

export class ShopifyFreshLoginVerifier implements FreshLoginVerifier {
  private jwks: { readonly keys: readonly JsonWebKey[]; readonly issuer: string; readonly fetchedAt: number } | null = null;

  constructor(private readonly options: {
    readonly shopDomain: string;
    readonly customerTokens: CustomerTokenVerifier;
    readonly customerAccountClientId?: string;
    readonly maxAgeMs?: number;
    readonly fetchFn?: typeof fetch;
    readonly now?: () => Date;
    readonly timeoutMs?: number;
  }) {}

  async verify(accessToken: string, idToken: string): Promise<FreshLoginDecision> {
    if (!usableToken(accessToken) || !usableToken(idToken)) return { status: 'invalid' };

    let customerId: string | null;
    try {
      customerId = canonicalCustomerId(await this.options.customerTokens.resolveCustomerId(accessToken));
    } catch (error) {
      if (error instanceof CustomerTokenVerificationUnavailableError) return { status: 'unavailable' };
      return { status: 'unavailable' };
    }
    if (customerId === null) return { status: 'invalid' };

    let claims: JwtClaims;
    try {
      claims = await this.verifyIdToken(idToken);
    } catch (error) {
      if (error instanceof FreshLoginUnavailableError) return { status: 'unavailable' };
      return { status: 'invalid' };
    }

    const subject = canonicalCustomerId(claims.sub);
    if (subject === null || subject !== customerId) return { status: 'invalid' };

    const authenticatedAt = claims.authTime ?? claims.iat;
    if (authenticatedAt === null) return { status: 'invalid' };
    const nowSeconds = Math.floor(this.now().getTime() / 1000);
    if (claims.exp !== null && claims.exp + clockSkewSeconds < nowSeconds) return { status: 'invalid' };
    const ageMs = (nowSeconds - authenticatedAt) * 1000;
    const maxAgeMs = this.options.maxAgeMs ?? 10 * 60 * 1000;
    if (ageMs > maxAgeMs) return { status: 'stale', customerId };
    return {
      status: 'fresh',
      customerId,
      authenticatedAt: new Date(authenticatedAt * 1000).toISOString(),
    };
  }

  private async verifyIdToken(idToken: string): Promise<JwtClaims> {
    const parts = idToken.split('.');
    if (parts.length !== 3 || parts.some((part) => part.length === 0)) {
      throw new FreshLoginInvalidError();
    }
    const [encodedHeader, encodedPayload, encodedSignature] = parts as [string, string, string];
    const header = parseJson(encodedHeader);
    const payload = parseJson(encodedPayload);
    if (header.alg !== 'RS256' || typeof header.kid !== 'string' || header.kid.length === 0) {
      throw new FreshLoginInvalidError();
    }

    const discovered = await this.discover();
    if (typeof payload.iss !== 'string' || payload.iss !== discovered.issuer) {
      throw new FreshLoginInvalidError();
    }
    const expectedAudience = this.options.customerAccountClientId?.trim() ?? '';
    if (expectedAudience !== '' && !audienceMatches(payload.aud, expectedAudience)) {
      throw new FreshLoginInvalidError();
    }

    const jwk = discovered.keys.find((key) => key.kid === header.kid && key.kty === 'RSA');
    if (jwk === undefined) throw new FreshLoginInvalidError();
    const key = createPublicKey({ key: jwk, format: 'jwk' });
    if (!verifyRs256(encodedHeader, encodedPayload, encodedSignature, key)) {
      throw new FreshLoginInvalidError();
    }

    return {
      sub: typeof payload.sub === 'string' ? payload.sub : '',
      iat: numberClaim(payload.iat),
      exp: numberClaim(payload.exp),
      authTime: numberClaim(payload.auth_time),
    };
  }

  private async discover(): Promise<{ readonly keys: readonly JsonWebKey[]; readonly issuer: string }> {
    const cached = this.jwks;
    const now = this.now().getTime();
    if (cached !== null && now - cached.fetchedAt < 60 * 60 * 1000) {
      return cached;
    }
    const shop = this.options.shopDomain.trim().toLowerCase().replace(/^https?:\/\//, '').replace(/\/$/, '');
    if (!/^[a-z0-9.-]+$/.test(shop) || !shop.includes('.')) {
      throw new FreshLoginUnavailableError();
    }
    const fetchFn = this.options.fetchFn ?? fetch;
    const timeoutMs = this.options.timeoutMs ?? 10_000;
    const configResponse = await this.getJson(
      fetchFn,
      `https://${shop}/.well-known/openid-configuration`,
      timeoutMs,
    );
    const issuer = configResponse.issuer;
    const jwksUri = configResponse.jwks_uri;
    if (typeof issuer !== 'string' || typeof jwksUri !== 'string') {
      throw new FreshLoginUnavailableError();
    }
    let jwksUrl: URL;
    try {
      jwksUrl = new URL(jwksUri);
    } catch {
      throw new FreshLoginUnavailableError();
    }
    if (jwksUrl.protocol !== 'https:') throw new FreshLoginUnavailableError();
    const jwksResponse = await this.getJson(fetchFn, jwksUrl.toString(), timeoutMs);
    const keys = Array.isArray(jwksResponse.keys) ? jwksResponse.keys as JsonWebKey[] : [];
    if (keys.length === 0) throw new FreshLoginUnavailableError();
    this.jwks = { keys, issuer, fetchedAt: now };
    return this.jwks;
  }

  private async getJson(
    fetchFn: typeof fetch,
    url: string,
    timeoutMs: number,
  ): Promise<Record<string, unknown>> {
    let response: Response;
    try {
      response = await fetchFn(url, {
        headers: { Accept: 'application/json' },
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch {
      throw new FreshLoginUnavailableError();
    }
    if (!response.ok) throw new FreshLoginUnavailableError();
    const body = await response.json() as unknown;
    if (typeof body !== 'object' || body === null || Array.isArray(body)) {
      throw new FreshLoginUnavailableError();
    }
    return body as Record<string, unknown>;
  }

  private now(): Date {
    return (this.options.now ?? (() => new Date()))();
  }
}

interface JwtClaims {
  readonly sub: string;
  readonly iat: number | null;
  readonly exp: number | null;
  readonly authTime: number | null;
}

class FreshLoginInvalidError extends Error {
  constructor() {
    super('invalid_id_token');
    this.name = 'FreshLoginInvalidError';
  }
}

class FreshLoginUnavailableError extends Error {
  constructor() {
    super('reauthentication_unavailable');
    this.name = 'FreshLoginUnavailableError';
  }
}

function usableToken(value: string): boolean {
  return value.length > 0 && value.length <= maxTokenLength && !/\s/.test(value);
}

function canonicalCustomerId(value: string | null): string | null {
  if (value === null) return null;
  if (/^[0-9]+$/.test(value)) return value;
  const gid = /^gid:\/\/shopify\/Customer\/([0-9]+)$/.exec(value);
  return gid?.[1] ?? null;
}

function parseJson(segment: string): Record<string, unknown> {
  try {
    const json = JSON.parse(Buffer.from(segment, 'base64url').toString('utf8')) as unknown;
    if (typeof json !== 'object' || json === null || Array.isArray(json)) {
      throw new FreshLoginInvalidError();
    }
    return json as Record<string, unknown>;
  } catch (error) {
    if (error instanceof FreshLoginInvalidError) throw error;
    throw new FreshLoginInvalidError();
  }
}

function numberClaim(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function audienceMatches(aud: unknown, expected: string): boolean {
  if (typeof aud === 'string') return aud === expected;
  return Array.isArray(aud) && aud.some((entry) => entry === expected);
}

function verifyRs256(
  encodedHeader: string,
  encodedPayload: string,
  encodedSignature: string,
  key: KeyObject,
): boolean {
  const verifier = createVerify('RSA-SHA256');
  verifier.update(`${encodedHeader}.${encodedPayload}`);
  verifier.end();
  try {
    return verifier.verify(key, Buffer.from(encodedSignature, 'base64url'));
  } catch {
    return false;
  }
}

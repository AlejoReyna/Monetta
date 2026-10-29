import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Verifies the session token App Bridge attaches to requests made from the
 * embedded Shopify Admin page (`src/shopifyAdmin/`). Shopify signs it with
 * HS256 using this app's client secret — the same secret that verifies
 * webhooks — so a valid token proves Shopify issued it for this app, for the
 * configured shop, and for the staff member in `sub`.
 *
 * Only identity is taken from the token. Whether that staff member may do
 * anything is decided by `admin_principals`, exactly like the other subjects.
 *
 * https://shopify.dev/docs/apps/build/authentication-authorization/session-tokens
 */
export interface ShopifyStaffSession {
  /** Shopify staff (user) id, from the `sub` claim. */
  readonly staffUserId: string;
}

const segmentPattern = /^[A-Za-z0-9_-]+$/;
const staffIdPattern = /^[0-9]{1,20}$/;

/** `https://Shop.myshopify.com/` → `shop.myshopify.com`; anything not a hostname → ''. */
export function canonicalShopDomain(value: string): string {
  const shop = value.trim().toLowerCase()
    .replace(/^https?:\/\//, '')
    .replace(/\/+$/, '');
  return /^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$/.test(shop) ? shop : '';
}

export class ShopifySessionTokenVerifier {
  constructor({
    clientId,
    clientSecret,
    shopDomain,
    clockToleranceSeconds = 10,
    now = () => new Date(),
  }: {
    readonly clientId: string;
    readonly clientSecret: string;
    /** `shop.myshopify.com`. Tokens issued for any other shop are rejected. */
    readonly shopDomain: string;
    readonly clockToleranceSeconds?: number;
    readonly now?: () => Date;
  }) {
    const shop = canonicalShopDomain(shopDomain);
    if (clientId.trim() === '' || clientSecret === '' || shop === '') {
      throw new Error('Shopify session tokens need a client id, client secret, and shop domain');
    }
    this.clientId = clientId.trim();
    this.clientSecret = clientSecret;
    this.dest = `https://${shop}`;
    this.clockToleranceSeconds = clockToleranceSeconds;
    this.now = now;
  }

  private readonly clientId: string;
  private readonly clientSecret: string;
  private readonly dest: string;
  private readonly clockToleranceSeconds: number;
  private readonly now: () => Date;

  /** Returns null for anything that is not a currently valid token for this app and shop. */
  verify(token: string): ShopifyStaffSession | null {
    if (token.length > 8192) return null;
    const parts = token.split('.');
    if (parts.length !== 3 || !parts.every((part) => segmentPattern.test(part))) return null;
    const [encodedHeader, encodedPayload, encodedSignature] = parts as [string, string, string];

    // Pin the algorithm before trusting anything else in the token, so a
    // forged `alg: none` or an asymmetric algorithm can never be accepted.
    const header = decodeJson(encodedHeader);
    if (header?.alg !== 'HS256') return null;

    const expected = createHmac('sha256', this.clientSecret)
      .update(`${encodedHeader}.${encodedPayload}`)
      .digest();
    const received = Buffer.from(encodedSignature, 'base64url');
    if (received.length !== expected.length || !timingSafeEqual(received, expected)) return null;

    const claims = decodeJson(encodedPayload);
    if (claims === null) return null;
    if (claims.aud !== this.clientId) return null;
    if (claims.dest !== this.dest || claims.iss !== `${this.dest}/admin`) return null;

    const nowSeconds = this.now().getTime() / 1000;
    if (typeof claims.exp !== 'number' || nowSeconds >= claims.exp + this.clockToleranceSeconds) {
      return null;
    }
    if (typeof claims.nbf !== 'number' || nowSeconds < claims.nbf - this.clockToleranceSeconds) {
      return null;
    }

    if (typeof claims.sub !== 'string' || !staffIdPattern.test(claims.sub)) return null;
    return { staffUserId: claims.sub };
  }
}

function decodeJson(segment: string): Record<string, unknown> | null {
  try {
    const value: unknown = JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
    return value !== null && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

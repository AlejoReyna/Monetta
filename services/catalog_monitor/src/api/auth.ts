import { createHash, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scryptAsync = promisify(scrypt);

/**
 * Dashboard passphrase verifier, reusing the `accounts_orders` pattern.
 *
 * Stored format: `scrypt$<salt base64url>$<hash base64url>` (64-byte derived
 * key). Only the verifier string lives in `DASHBOARD_PASSPHRASE_VERIFIER`;
 * the passphrase itself is never stored.
 */
export async function createPassphraseVerifier(passphrase: string): Promise<string> {
  if (typeof passphrase !== 'string' || passphrase.length < 16) {
    throw new Error('passphrase must be at least 16 characters');
  }
  const salt = randomBytes(16);
  const derived = (await scryptAsync(passphrase, salt, 64)) as Buffer;
  return `scrypt$${salt.toString('base64url')}$${derived.toString('base64url')}`;
}

/**
 * Verifies a passphrase against a stored verifier with no timing signal:
 * a wrong passphrase costs the same scrypt work as a correct one, and the
 * comparison uses `timingSafeEqual` on equal-length buffers. Malformed
 * verifiers burn equivalent work against a dummy salt before returning
 * false, so a missing/misconfigured verifier is indistinguishable by timing.
 */
export async function verifyPassphrase(
  passphrase: string,
  verifier: string | null | undefined,
): Promise<boolean> {
  const candidate = typeof passphrase === 'string' ? passphrase : '';
  const parts = typeof verifier === 'string' ? verifier.split('$') : [];
  const [algorithm, saltText, hashText] = parts;
  if (algorithm !== 'scrypt' || !saltText || !hashText) {
    // Burn comparable work so "no verifier configured" is not timing-visible.
    try {
      await scryptAsync(candidate || 'dummy', Buffer.alloc(16), 64);
    } catch {
      // ignore — the answer is still false
    }
    return false;
  }
  try {
    const expected = Buffer.from(hashText, 'base64url');
    if (expected.length === 0) return false;
    const actual = (await scryptAsync(
      candidate,
      Buffer.from(saltText, 'base64url'),
      expected.length,
    )) as Buffer;
    return expected.length === actual.length && timingSafeEqual(expected, actual);
  } catch {
    return false;
  }
}

/** SHA-256 hex of an opaque token. Only this hash is ever persisted. */
export function hashSessionToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Extracts a bearer token, or null when missing/malformed. */
export function bearerTokenFromHeader(authorization: string | undefined): string | null {
  if (!authorization?.startsWith('Bearer ')) return null;
  const token = authorization.slice('Bearer '.length).trim();
  if (token === '' || token.length > 8192 || /\s/.test(token)) return null;
  return token;
}

/**
 * Dashboard session (WP-63, CATALOG_DASHBOARD § 3).
 *
 * The short-lived bearer token lives in **`sessionStorage`** — it dies with
 * the tab, bounding XSS exfiltration. Never `localStorage`, never a baked-in
 * bundle secret, never a Vercel env var.
 */
const TOKEN_KEY = 'monetta.dashboard.token';
const EXPIRES_KEY = 'monetta.dashboard.expiresAt';

export interface SessionStorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

function storage(): SessionStorageLike | null {
  try {
    if (typeof sessionStorage !== 'undefined') return sessionStorage;
  } catch {
    return null;
  }
  return null;
}

export function getSessionToken(store: SessionStorageLike | null = storage()): string | null {
  if (store === null) return null;
  const token = store.getItem(TOKEN_KEY);
  if (token === null || token === '') return null;
  const expiresRaw = store.getItem(EXPIRES_KEY);
  if (expiresRaw !== null) {
    const expires = Date.parse(expiresRaw);
    if (Number.isFinite(expires) && expires <= Date.now()) {
      clearSession(store);
      return null;
    }
  }
  return token;
}

export function saveSession(
  token: string,
  expiresAt: string | null,
  store: SessionStorageLike | null = storage(),
): void {
  if (store === null) return;
  store.setItem(TOKEN_KEY, token);
  if (expiresAt !== null) store.setItem(EXPIRES_KEY, expiresAt);
}

export function clearSession(store: SessionStorageLike | null = storage()): void {
  if (store === null) return;
  store.removeItem(TOKEN_KEY);
  store.removeItem(EXPIRES_KEY);
}

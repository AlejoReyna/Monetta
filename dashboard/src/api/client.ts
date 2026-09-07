/**
 * Bearer + ETag API client (WP-63, CATALOG_DASHBOARD § 7.1).
 *
 * - `Authorization: Bearer` from session storage, never a baked-in secret.
 * - `If-None-Match` round-trips the last ETag per path; `304` surfaces as
 *   `notModified` so polls keep last-known data without a refetch.
 * - `401` invokes `onUnauthorized` (session drop + route back to login);
 *   the client never interprets auth itself.
 */
export interface ApiClientDeps {
  readonly baseUrl: string;
  readonly getToken: () => string | null;
  readonly onUnauthorized: () => void;
  readonly fetchImpl?: typeof fetch;
}

export interface ApiGetResult<T> {
  readonly status: number;
  readonly data: T | null;
  readonly etag: string | null;
  readonly notModified: boolean;
}

export class ApiClient {
  private readonly etags = new Map<string, string>();
  private readonly cache = new Map<string, unknown>();

  constructor(private readonly deps: ApiClientDeps) {}

  forgetEtag(path: string): void {
    this.etags.delete(path);
    this.cache.delete(path);
  }

  async get<T>(path: string): Promise<ApiGetResult<T>> {
    const token = this.deps.getToken();
    const headers: Record<string, string> = {};
    if (token !== null) headers.Authorization = `Bearer ${token}`;
    const cached = this.etags.get(path);
    if (cached !== undefined) headers['If-None-Match'] = cached;
    const response = await (this.deps.fetchImpl ?? fetch)(`${this.deps.baseUrl}${path}`, {
      headers,
    });
    if (response.status === 401) {
      this.deps.onUnauthorized();
      return { status: 401, data: null, etag: null, notModified: false };
    }
    if (response.status === 304) {
      // A 304 means "your cached copy is still valid" — hand it back so a
      // revisited screen repopulates instead of sitting on "Loading…".
      return { status: 304, data: (this.cache.get(path) as T | undefined) ?? null, etag: cached ?? null, notModified: true };
    }
    const etag = response.headers.get('ETag');
    if (etag !== null) this.etags.set(path, etag);
    if (!response.ok) {
      return { status: response.status, data: null, etag, notModified: false };
    }
    const data = (await response.json()) as T;
    this.cache.set(path, data);
    return { status: response.status, data, etag, notModified: false };
  }

  async send<T>(path: string, method: string, body?: unknown, extraHeaders?: Record<string, string>): Promise<{
    readonly status: number;
    readonly data: T | null;
  }> {
    const token = this.deps.getToken();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...extraHeaders,
    };
    if (token !== null) headers.Authorization = `Bearer ${token}`;
    // Mutations invalidate cached reads derived from the same state.
    // Selection writes invalidate the console reads; product writes
    // invalidate the table and the feed join that reads it.
    if (method !== 'GET') {
      for (const key of [...this.etags.keys()]) {
        if (
          key.startsWith('/admin/selection') ||
          key.startsWith('/admin/products') ||
          key.startsWith('/admin/feed-preview')
        ) {
          this.etags.delete(key);
          this.cache.delete(key);
        }
      }
    }
    const response = await (this.deps.fetchImpl ?? fetch)(`${this.deps.baseUrl}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (response.status === 401) {
      this.deps.onUnauthorized();
      return { status: 401, data: null };
    }
    if (response.status === 204 || response.status === 304) {
      return { status: response.status, data: null };
    }
    let data: T | null = null;
    try {
      data = (await response.json()) as T;
    } catch {
      data = null;
    }
    return { status: response.status, data };
  }
}

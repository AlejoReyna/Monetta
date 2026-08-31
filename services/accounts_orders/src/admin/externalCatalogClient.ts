import { createHmac, randomUUID } from 'node:crypto';

export interface ExternalSourcePolicyInput {
  readonly enabled: boolean;
  readonly itemLimit: number;
  readonly baseCommissionRate: number;
  readonly highValueCommissionRate: number;
  readonly highValueThreshold: number;
}

export interface ExternalSourceProjection {
  readonly id: string;
  readonly merchant: string;
  readonly enabled: boolean;
  readonly itemLimit: number;
  readonly baseCommissionRate: number;
  readonly highValueCommissionRate: number;
  readonly highValueThreshold: number;
  readonly itemCount: number;
  readonly lastSuccessfulRunAt: string | null;
  readonly health?: {
    readonly status: 'ready' | 'degraded' | 'unavailable';
    readonly reasons?: readonly string[];
    readonly freshnessHours?: number | null;
  };
  readonly updatedAt: string;
}

export interface ExternalCatalogAdminClient {
  fetchSources(requestId?: string): Promise<ExternalSourceProjection[]>;
  fetchSource(sourceId: string, requestId?: string): Promise<ExternalSourceProjection>;
  updateSource(input: {
    readonly sourceId: string;
    readonly source: ExternalSourcePolicyInput;
    readonly requestId?: string;
  }): Promise<ExternalSourceProjection>;
}

export class ExternalCatalogClientError extends Error {
  constructor(
    message: string,
    readonly statusCode?: number,
    readonly code?: string,
  ) {
    super(message);
    this.name = 'ExternalCatalogClientError';
  }
}

export interface HttpExternalCatalogAdminClientOptions {
  readonly baseUrl: string;
  readonly serviceSecret: string;
  readonly fetchFn?: typeof fetch;
  readonly now?: () => number;
  readonly timeoutMs?: number;
}

export class HttpExternalCatalogAdminClient implements ExternalCatalogAdminClient {
  constructor(private readonly options: HttpExternalCatalogAdminClientOptions) {
    const parsed = new URL(options.baseUrl);
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      throw new ExternalCatalogClientError('External catalog URL must use HTTP or HTTPS.');
    }
    if (options.serviceSecret.length < 32) {
      throw new ExternalCatalogClientError('External catalog service secret is missing.');
    }
    this.fetchFn = options.fetchFn ?? fetch;
    this.now = options.now ?? (() => Date.now());
    this.timeoutMs = options.timeoutMs ?? 8_000;
  }

  private readonly fetchFn: typeof fetch;
  private readonly now: () => number;
  private readonly timeoutMs: number;

  async fetchSources(requestId?: string): Promise<ExternalSourceProjection[]> {
    const root = await this.send('GET', '/internal/admin/sources', undefined, requestId);
    const sources = root.sources;
    if (!Array.isArray(sources)) throw new ExternalCatalogClientError('Invalid external source response.');
    return sources.filter(isSourceProjection);
  }

  async fetchSource(sourceId: string, requestId?: string): Promise<ExternalSourceProjection> {
    const root = await this.send(
      'GET',
      `/internal/admin/sources/${encodeURIComponent(sourceId)}`,
      undefined,
      requestId,
    );
    if (!isSourceProjection(root.source)) {
      throw new ExternalCatalogClientError('Invalid external source response.');
    }
    return root.source;
  }

  async updateSource(input: {
    readonly sourceId: string;
    readonly source: ExternalSourcePolicyInput;
    readonly requestId?: string;
  }): Promise<ExternalSourceProjection> {
    const root = await this.send(
      'PUT',
      `/internal/admin/sources/${encodeURIComponent(input.sourceId)}`,
      {
        enabled: input.source.enabled,
        itemLimit: input.source.itemLimit,
        baseCommissionBps: Math.round(input.source.baseCommissionRate * 10_000),
        highValueCommissionBps: Math.round(input.source.highValueCommissionRate * 10_000),
        highValueThresholdMxn: input.source.highValueThreshold,
      },
      input.requestId,
    );
    if (!isSourceProjection(root.source)) {
      throw new ExternalCatalogClientError('Invalid external source response.');
    }
    return root.source;
  }

  private async send(
    method: 'GET' | 'PUT',
    path: string,
    body: Record<string, unknown> | undefined,
    requestId?: string,
  ): Promise<Record<string, any>> {
    const timestamp = String(this.now());
    const resolvedRequestId = requestId ?? `req_${randomUUID()}`;
    const encodedBody = body === undefined ? '' : stableJson(body);
    const signature = createHmac('sha256', this.options.serviceSecret)
      .update(`${timestamp}.${resolvedRequestId}.${method}.${path}.${encodedBody}`)
      .digest('hex');
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'X-Monetta-Timestamp': timestamp,
      'X-Monetta-Signature': signature,
      'X-Monetta-Request-Id': resolvedRequestId,
      'X-Request-Id': resolvedRequestId,
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    };
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await this.fetchFn(new URL(path, this.options.baseUrl), {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: controller.signal,
      });
      const text = await response.text();
      let decoded: unknown;
      try {
        decoded = JSON.parse(text);
      } catch {
        throw new ExternalCatalogClientError('External catalog returned malformed JSON.', response.status);
      }
      if (typeof decoded !== 'object' || decoded === null || Array.isArray(decoded)) {
        throw new ExternalCatalogClientError('External catalog returned an invalid response.', response.status);
      }
      if (!response.ok) {
        const error = (decoded as Record<string, unknown>).error;
        const code = typeof error === 'object' && error !== null
          ? (error as Record<string, unknown>).code
          : undefined;
        throw new ExternalCatalogClientError(
          'External catalog request failed.',
          response.status,
          typeof code === 'string' ? code : undefined,
        );
      }
      return decoded as Record<string, any>;
    } catch (error) {
      if (error instanceof ExternalCatalogClientError) throw error;
      throw new ExternalCatalogClientError('External catalog is unavailable.');
    } finally {
      clearTimeout(timer);
    }
  }
}

function isSourceProjection(value: unknown): value is ExternalSourceProjection {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const source = value as Record<string, unknown>;
  return typeof source.id === 'string' && typeof source.merchant === 'string' &&
    typeof source.enabled === 'boolean' && Number.isInteger(source.itemLimit) &&
    typeof source.baseCommissionRate === 'number' &&
    typeof source.highValueCommissionRate === 'number' &&
    typeof source.highValueThreshold === 'number' && Number.isInteger(source.itemCount) &&
    typeof source.updatedAt === 'string';
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, item]) => `${JSON.stringify(key)}:${stableJson(item)}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

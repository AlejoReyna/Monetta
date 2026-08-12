/** Retries a temporary failure at most `maxRetries` times with exponential backoff and jitter. */
export interface RetryOptions {
  readonly maxRetries?: number;
  readonly baseDelayMs?: number;
  readonly isRetryable?: (error: unknown) => boolean;
  readonly sleep?: (ms: number) => Promise<void>;
  readonly random?: () => number;
}

export class NonRetryableError extends Error {}

export async function withRetry<T>(
  task: () => Promise<T>,
  options: RetryOptions = {},
): Promise<T> {
  const maxRetries = options.maxRetries ?? 3;
  const baseDelayMs = options.baseDelayMs ?? 500;
  const isRetryable = options.isRetryable ?? (() => true);
  const sleep = options.sleep ?? ((ms: number) => new Promise((r) => setTimeout(r, ms)));
  const random = options.random ?? Math.random;

  let attempt = 0;
  let lastError: unknown;
  while (attempt <= maxRetries) {
    try {
      return await task();
    } catch (error) {
      lastError = error;
      if (error instanceof NonRetryableError || !isRetryable(error) || attempt === maxRetries) {
        throw error;
      }
      const exponential = baseDelayMs * 2 ** attempt;
      const jitter = exponential * 0.5 * random();
      await sleep(exponential + jitter);
      attempt++;
    }
  }
  throw lastError;
}

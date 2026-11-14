import type { AdminMutationRateLimiter } from './mutationPorts.js';

export class SlidingWindowAdminRateLimiter implements AdminMutationRateLimiter {
  constructor(
    private readonly maxAttempts = 30,
    private readonly windowMs = 60_000,
    private readonly now: () => number = () => Date.now(),
  ) {}

  private readonly attempts = new Map<string, number[]>();

  allow(actorId: string, operation: string): boolean {
    const now = this.now();
    const cutoff = now - this.windowMs;
    for (const [storedKey, timestamps] of this.attempts) {
      const recent = timestamps.filter((timestamp) => timestamp > cutoff);
      if (recent.length === 0) this.attempts.delete(storedKey);
      else if (recent.length !== timestamps.length) this.attempts.set(storedKey, recent);
    }

    const key = `${actorId}:${operation}`;
    const recent = this.attempts.get(key) ?? [];
    if (recent.length >= this.maxAttempts) return false;
    recent.push(now);
    this.attempts.set(key, recent);
    return true;
  }
}

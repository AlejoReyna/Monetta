import type { AdminMutationRateLimiter } from './mutationPorts.js';

export class SlidingWindowAdminRateLimiter implements AdminMutationRateLimiter {
  constructor(
    private readonly maxAttempts = 30,
    private readonly windowMs = 60_000,
    private readonly now: () => number = () => Date.now(),
  ) {}

  private readonly attempts = new Map<string, number[]>();

  allow(actorId: string, operation: string): boolean {
    const key = `${actorId}:${operation}`;
    const cutoff = this.now() - this.windowMs;
    const recent = (this.attempts.get(key) ?? []).filter((timestamp) => timestamp > cutoff);
    if (recent.length >= this.maxAttempts) {
      this.attempts.set(key, recent);
      return false;
    }
    recent.push(this.now());
    this.attempts.set(key, recent);
    return true;
  }
}

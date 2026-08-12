/**
 * Enforces "at most one active request per domain, at least `delayMs`
 * between requests to that domain." One instance is shared across a whole
 * crawl run (or reused across runs); each domain gets its own queue so two
 * different sources never block each other.
 */
export class DomainRateLimiter {
  private readonly queueTailByDomain = new Map<string, Promise<void>>();
  private readonly lastStartByDomain = new Map<string, number>();

  constructor(private readonly delayMs: number) {}

  async schedule<T>(domain: string, task: () => Promise<T>): Promise<T> {
    const previousTail = this.queueTailByDomain.get(domain) ?? Promise.resolve();
    let release!: () => void;
    const thisTail = new Promise<void>((resolve) => (release = resolve));
    this.queueTailByDomain.set(domain, previousTail.then(() => thisTail));

    await previousTail;
    try {
      const lastStart = this.lastStartByDomain.get(domain) ?? 0;
      const wait = Math.max(0, lastStart + this.delayMs - Date.now());
      if (wait > 0) await sleep(wait);
      this.lastStartByDomain.set(domain, Date.now());
      return await task();
    } finally {
      release();
    }
  }
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function domainOf(url: string): string {
  return new URL(url).hostname;
}

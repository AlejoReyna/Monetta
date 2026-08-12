import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';

describe('loadConfig', () => {
  it('defaults LIVE_CRAWL_ENABLED to false and accepts the placeholder contact when disabled', () => {
    const config = loadConfig({});
    expect(config.liveCrawlEnabled).toBe(false);
    expect(config.userAgent).toContain('example.invalid');
  });

  it('rejects a browser-impersonation USER_AGENT', () => {
    expect(() =>
      loadConfig({ USER_AGENT: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' }),
    ).toThrow(/browser-impersonation/);
  });

  it('rejects LIVE_CRAWL_ENABLED=true with the default placeholder contact address', () => {
    expect(() => loadConfig({ LIVE_CRAWL_ENABLED: 'true' })).toThrow(/contact/i);
  });

  it('rejects LIVE_CRAWL_ENABLED=true with an explicit but still-placeholder contact address', () => {
    expect(() =>
      loadConfig({
        LIVE_CRAWL_ENABLED: 'true',
        USER_AGENT: 'MonettaCatalogMonitor/0.1 (+https://monetta.mx; contact: research@example.test)',
      }),
    ).toThrow(/contact/i);
  });

  it('rejects LIVE_CRAWL_ENABLED=true with no contact address at all', () => {
    expect(() =>
      loadConfig({
        LIVE_CRAWL_ENABLED: 'true',
        USER_AGENT: 'MonettaCatalogMonitor/0.1 (+https://monetta.mx)',
      }),
    ).toThrow(/contact/i);
  });

  it('accepts LIVE_CRAWL_ENABLED=true with a real, non-placeholder contact address', () => {
    const config = loadConfig({
      LIVE_CRAWL_ENABLED: 'true',
      USER_AGENT: 'MonettaCatalogMonitor/0.1 (+https://monetta.mx; contact: research@monetta.mx)',
    });
    expect(config.liveCrawlEnabled).toBe(true);
  });
});

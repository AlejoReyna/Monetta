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

  it('parses commission and curation configuration without a stale default FX rate', () => {
    const config = loadConfig({
      USD_TO_MXN_RATE: '19.5',
      COMMISSION_DEFAULT_BPS: '2300',
      COMMISSION_HIGH_VALUE_BPS: '1300',
      COMMISSION_SOURCE_RATES_JSON: '{"kate_spade_us":1800}',
      COMMISSION_PRODUCT_RATES_JSON: '{"coach_us:CU068":900}',
      FASHION_ITEMS_PER_SOURCE: '7',
      PERFUME_ITEMS_PER_SOURCE: '9',
      MAXIMUM_CATALOG_ITEMS: '40',
    });
    expect(config.usdToMxnRate).toBe(19.5);
    expect(config.defaultCommissionBps).toBe(2300);
    expect(config.highValueCommissionBps).toBe(1300);
    expect(config.sourceCommissionBps).toEqual({ kate_spade_us: 1800 });
    expect(config.productCommissionBps).toEqual({ 'coach_us:CU068': 900 });
    expect(config.fashionItemsPerSource).toBe(7);
    expect(config.perfumeItemsPerSource).toBe(9);
    expect(config.maximumCatalogItems).toBe(40);
    expect(loadConfig({}).usdToMxnRate).toBeNull();
    expect(config.enabledSourceIds).toHaveLength(9);
  });

  it('rejects malformed commission overrides', () => {
    expect(() => loadConfig({ COMMISSION_SOURCE_RATES_JSON: '[]' })).toThrow(/JSON object/);
    expect(() =>
      loadConfig({ COMMISSION_PRODUCT_RATES_JSON: '{"coach_us:X":12000}' }),
    ).toThrow(/basis points/);
  });

  it('accepts a configurable source subset and rejects unknown source ids', () => {
    expect(
      loadConfig({ ENABLED_SOURCE_IDS: 'coach_us,gp_mcallen_perfumes,coach_us' })
        .enabledSourceIds,
    ).toEqual(['coach_us', 'gp_mcallen_perfumes']);
    expect(() => loadConfig({ ENABLED_SOURCE_IDS: 'coach_us,not_a_source' })).toThrow(
      /unknown sources/,
    );
  });
});

import { describe, expect, it } from 'vitest';
import { assertSafeToSeedDemoData } from '../src/cli/seedDemoData.js';

const localConfig = { databaseUrl: 'postgres://u:p@localhost:5433/db' };
const remoteConfig = { databaseUrl: 'postgres://u:p@prod-db.example.com:5432/db' };

describe('assertSafeToSeedDemoData', () => {
  it('passes when all three guards hold: ALLOW_DEMO_SEED, non-production, loopback host', () => {
    expect(() =>
      assertSafeToSeedDemoData(localConfig, { ALLOW_DEMO_SEED: 'true', NODE_ENV: 'development' }),
    ).not.toThrow();
  });

  it('refuses when ALLOW_DEMO_SEED is not exactly "true"', () => {
    expect(() => assertSafeToSeedDemoData(localConfig, { NODE_ENV: 'development' })).toThrow(
      /ALLOW_DEMO_SEED/,
    );
    expect(() =>
      assertSafeToSeedDemoData(localConfig, { ALLOW_DEMO_SEED: '1', NODE_ENV: 'development' }),
    ).toThrow(/ALLOW_DEMO_SEED/);
  });

  it('refuses when NODE_ENV is production, even with ALLOW_DEMO_SEED=true', () => {
    expect(() =>
      assertSafeToSeedDemoData(localConfig, { ALLOW_DEMO_SEED: 'true', NODE_ENV: 'production' }),
    ).toThrow(/production/i);
  });

  it('refuses a non-loopback DATABASE_URL host, even with the other two guards satisfied', () => {
    expect(() =>
      assertSafeToSeedDemoData(remoteConfig, { ALLOW_DEMO_SEED: 'true', NODE_ENV: 'development' }),
    ).toThrow(/loopback/i);
  });

  it('refuses a malformed DATABASE_URL', () => {
    expect(() =>
      assertSafeToSeedDemoData(
        { databaseUrl: 'not a url' },
        { ALLOW_DEMO_SEED: 'true', NODE_ENV: 'development' },
      ),
    ).toThrow();
  });

  it('accepts 127.0.0.1 as a loopback host', () => {
    expect(() =>
      assertSafeToSeedDemoData(
        { databaseUrl: 'postgres://u:p@127.0.0.1:5433/db' },
        { ALLOW_DEMO_SEED: 'true', NODE_ENV: 'test' },
      ),
    ).not.toThrow();
  });
});

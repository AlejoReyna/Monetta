import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
    globals: false,
    // Live crawling must never run during tests — this is enforced in code
    // (config.ts throws if LIVE_CRAWL_ENABLED is read as true here), and this
    // env override is a second, independent guard at the test-runner level.
    env: {
      LIVE_CRAWL_ENABLED: 'false',
    },
  },
});

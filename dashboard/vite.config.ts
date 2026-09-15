import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

// `@selection` imports the server's validator directly (CATALOG_DASHBOARD
// § 7.2) — one rule set, not two. If the cross-package import ever becomes
// awkward the fix is to publish the module, never to duplicate it.
export default defineConfig({
  // `as never`: @vitejs/plugin-react types against top-level vite while
  // vitest/config bundles its own — identical at runtime, incompatible
  // nominally. Cast once here instead of weakening tsconfig.
  plugins: [react() as never],
  resolve: {
    alias: {
      '@selection': resolve(here, '../services/catalog_monitor/src/selection'),
    },
  },
  test: {
    environment: 'jsdom',
  },
});

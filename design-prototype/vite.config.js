import { defineConfig } from 'vite';

// Single-page prototype: every storefront path (/collections/…, /products/…,
// /search, /cart, /pages/…) falls back to index.html in dev and preview.
export default defineConfig({
  appType: 'spa',
  server: {
    port: 5173,
    strictPort: false,
  },
  preview: {
    port: 4173,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: false,
    // The demo catalog is bundled JSON; keep the warning meaningful.
    chunkSizeWarningLimit: 700,
  },
});

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Express, Request, Response } from 'express';
import { canonicalShopDomain } from '../admin/shopifySessionToken.js';

// Copied next to the compiled module by the Dockerfile, like db/migrations.
const assetsDir = join(dirname(fileURLToPath(import.meta.url)), 'assets');

/**
 * Serves the embedded Shopify Admin page for push campaigns at `/shopify/app`,
 * the Shopify app's `application_url`. The page holds no secret and no
 * privilege of its own: it calls the existing `/admin/notification*` routes
 * with an App Bridge session token, and the server authorizes every call.
 */
export function registerShopifyAdminPanel(
  app: Express,
  { clientId, shopDomain }: { readonly clientId: string; readonly shopDomain: string },
): void {
  const shop = canonicalShopDomain(shopDomain);
  if (clientId.trim() === '' || shop === '') {
    throw new Error('The Shopify Admin panel needs the app client id and the shop domain');
  }
  const page = readFileSync(join(assetsDir, 'panel.html'), 'utf8')
    .replace('{{SHOPIFY_API_KEY}}', escapeAttribute(clientId.trim()));
  const script = readFileSync(join(assetsDir, 'panel.js'), 'utf8');
  const styles = readFileSync(join(assetsDir, 'panel.css'), 'utf8');
  // Shopify requires an embedded app to allow framing by this shop's admin
  // and by admin.shopify.com, and by nothing else.
  const frameAncestors = `frame-ancestors https://${shop} https://admin.shopify.com`;

  app.get('/shopify/app', (_req: Request, res: Response) => {
    res.setHeader('Content-Security-Policy', frameAncestors);
    res.setHeader('Cache-Control', 'no-store');
    res.type('html').send(page);
  });
  app.get('/shopify/app/panel.js', (_req: Request, res: Response) => {
    res.setHeader('Cache-Control', 'no-cache');
    res.type('application/javascript').send(script);
  });
  app.get('/shopify/app/panel.css', (_req: Request, res: Response) => {
    res.setHeader('Cache-Control', 'no-cache');
    res.type('css').send(styles);
  });
}

function escapeAttribute(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Server } from 'node:http';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createApp, type ServerDeps } from '../src/api/server.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

/**
 * Drift guard between `shopify/shopify.app*.toml` and the routes
 * `src/api/server.ts` actually registers.
 *
 * Shopify POSTs to the absolute `uri` in the deployed app config. A topic
 * pointing at a path this server does not serve gets a silent 404 — and for
 * the three mandatory compliance topics that is a compliance failure, not
 * just a missing feature. The TOMLs and the router are edited in different
 * files by different people, so the only thing keeping them honest is a
 * test that reads both.
 *
 * Behavioural on purpose: rather than introspecting Express' internals, it
 * POSTs to each configured path with a deliberately wrong signature. A
 * registered webhook route rejects that with 401; an unregistered one
 * 404s. So "not 404" is exactly the property under test.
 */

const here = dirname(fileURLToPath(import.meta.url));
const shopifyConfigDir = join(here, '..', '..', '..', 'shopify');

interface ConfiguredUri {
  readonly file: string;
  readonly path: string;
}

/**
 * Minimal TOML reading: this repo has no TOML parser dependency and needs
 * exactly one field. `uri = "https://HOST/path"` lines under
 * `[[webhooks.subscriptions]]` are unambiguous enough to match directly,
 * and an over-broad match would only ever add paths — making the test
 * stricter, never vacuous.
 */
function configuredWebhookPaths(): ConfiguredUri[] {
  const files = readdirSync(shopifyConfigDir).filter((f) => f.endsWith('.toml'));
  const found: ConfiguredUri[] = [];
  for (const file of files) {
    const text = readFileSync(join(shopifyConfigDir, file), 'utf8');
    for (const match of text.matchAll(/^\s*uri\s*=\s*"([^"]+)"/gm)) {
      const uri = match[1];
      // Only absolute HTTPS webhook URIs describe a route on this service;
      // `application_url` and auth redirects live under other keys.
      if (!uri.startsWith('https://')) continue;
      const { pathname } = new URL(uri);
      found.push({ file, path: pathname });
    }
  }
  return found;
}

describe('shopify.app*.toml webhook URIs match registered routes', () => {
  let server: Server;
  let baseUrl: string;

  beforeEach(async () => {
    const deps: ServerDeps = {
      appAccounts: new InMemoryAppAccountsRepository(),
      customers: new InMemoryCustomersRepository(),
      orders: new InMemoryOrdersRepository(),
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: 'shpss_test_secret',
    };
    const app = createApp(deps);
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;
  });

  afterEach(async () => {
    await new Promise<void>((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
  });

  it('finds webhook URIs to check', () => {
    // Guards the guard: a regex or path change that silently matched
    // nothing would otherwise make every assertion below pass trivially.
    expect(configuredWebhookPaths().length).toBeGreaterThan(0);
  });

  it('serves every path any app config subscribes to', async () => {
    const missing: string[] = [];

    for (const { file, path } of configuredWebhookPaths()) {
      const response = await fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Hmac-Sha256': 'not-a-real-signature',
          'X-Shopify-Webhook-Id': 'drift-guard',
        },
        body: '{}',
      });
      if (response.status === 404) missing.push(`${file} → POST ${path}`);
    }

    expect(missing).toEqual([]);
  });
});

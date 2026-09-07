import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import express from 'express';
import { createPassphraseVerifier, verifyPassphrase } from '../src/api/auth.js';
import {
  InMemoryDashboardSessionStore,
  LoginRateLimiter,
  registerDashboardSessionRoutes,
  requireDashboardSession,
} from '../src/api/session.js';

const PASSPHRASE = 'correct-horse-battery-staple-01';

function buildTestApp(verifier: string | null, store: InMemoryDashboardSessionStore, now: () => Date) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '32kb' }));
  registerDashboardSessionRoutes(app, {
    store,
    passphraseVerifier: verifier,
    ttlHours: 12,
    now,
    limiter: new LoginRateLimiter(),
  });
  // Minimal session-gated probe standing in for the WP-61 `/admin/*` reads.
  app.get('/admin/probe', requireDashboardSession({ store, now }), (_req, res) => {
    res.status(200).json({ ok: true });
  });
  return app;
}

describe('dashboard session auth (WP-60)', () => {
  let server: Server;
  let baseUrl: string;
  let store: InMemoryDashboardSessionStore;
  let verifier: string;
  const now = new Date('2026-09-02T12:00:00.000Z');

  beforeEach(async () => {
    verifier = await createPassphraseVerifier(PASSPHRASE);
    store = new InMemoryDashboardSessionStore();
    const app = buildTestApp(verifier, store, () => now);
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

  it('issues a session token for the correct passphrase', async () => {
    const response = await fetch(`${baseUrl}/admin/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ passphrase: PASSPHRASE }),
    });
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(typeof body.token).toBe('string');
    expect(body.token.length).toBeGreaterThan(20);
    expect(typeof body.expiresAt).toBe('string');

    const probe = await fetch(`${baseUrl}/admin/probe`, {
      headers: { Authorization: `Bearer ${body.token}` },
    });
    expect(probe.status).toBe(200);
  });

  it('wrong passphrase returns 401 with no detail (no timing signal)', async () => {
    const bad = await fetch(`${baseUrl}/admin/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ passphrase: 'wrong-passphrase-value-00' }),
    });
    expect(bad.status).toBe(401);
    expect(await bad.json()).toEqual({ error: 'invalid_credentials' });

    const missing = await fetch(`${baseUrl}/admin/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    expect(missing.status).toBe(401);
    expect(await missing.json()).toEqual({ error: 'invalid_credentials' });

    // Unit level: malformed verifier is also a plain false, never throws.
    expect(await verifyPassphrase(PASSPHRASE, null)).toBe(false);
    expect(await verifyPassphrase(PASSPHRASE, 'garbage')).toBe(false);
    expect(await verifyPassphrase('wrong-passphrase-value-00', verifier)).toBe(false);
    expect(await verifyPassphrase(PASSPHRASE, verifier)).toBe(true);
  });

  it('6th failed attempt inside 15 minutes returns 429', async () => {
    for (let attempt = 0; attempt < 5; attempt++) {
      const response = await fetch(`${baseUrl}/admin/session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ passphrase: `wrong-passphrase-${attempt}-xx` }),
      });
      expect(response.status).toBe(401);
    }
    const sixth = await fetch(`${baseUrl}/admin/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ passphrase: 'another-wrong-passphrase' }),
    });
    expect(sixth.status).toBe(429);
    expect(await sixth.json()).toEqual({ error: 'too_many_attempts' });
  });

  it('expired token returns 401', async () => {
    const login = await fetch(`${baseUrl}/admin/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ passphrase: PASSPHRASE }),
    });
    const { token } = await login.json();

    // Force expiry by rebuilding the app with a later clock over the same store.
    await new Promise<void>((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
    const lateApp = buildTestApp(verifier, store, () => new Date(now.getTime() + 13 * 3_600_000));
    await new Promise<void>((resolve) => {
      server = lateApp.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;

    const probe = await fetch(`${baseUrl}/admin/probe`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(probe.status).toBe(401);
  });

  it('revoked token returns 401', async () => {
    const login = await fetch(`${baseUrl}/admin/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ passphrase: PASSPHRASE }),
    });
    const { token } = await login.json();

    const logout = await fetch(`${baseUrl}/admin/session`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(logout.status).toBe(200);

    const probe = await fetch(`${baseUrl}/admin/probe`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(probe.status).toBe(401);

    const missing = await fetch(`${baseUrl}/admin/probe`);
    expect(missing.status).toBe(401);
  });
});

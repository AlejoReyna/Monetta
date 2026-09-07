import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import express from 'express';
import { dashboardCors, parseDashboardOrigins } from '../src/api/cors.js';

const ALLOWED = 'https://dash.staging.monetta.mx';
const OTHER_ALLOWED = 'http://localhost:5173';

function buildCorsApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(dashboardCors(parseDashboardOrigins(`${ALLOWED}, ${OTHER_ALLOWED}`)));
  app.get('/admin/probe', (_req, res) => {
    res.setHeader('ETag', '"probe-etag"');
    res.status(200).json({ ok: true });
  });
  return app;
}

describe('dashboard CORS (WP-60)', () => {
  let server: Server;
  let baseUrl: string;

  beforeEach(async () => {
    const app = buildCorsApp();
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

  it('allowlisted origin gets Allow-Origin and Expose-Headers: ETag', async () => {
    const response = await fetch(`${baseUrl}/admin/probe`, {
      headers: { Origin: ALLOWED },
    });
    expect(response.status).toBe(200);
    expect(response.headers.get('access-control-allow-origin')).toBe(ALLOWED);
    expect(response.headers.get('access-control-expose-headers')).toBe('ETag');
    expect(response.headers.get('vary')).toContain('Origin');
    expect(response.headers.get('access-control-allow-credentials')).toBeNull();
  });

  it('non-allowlisted origin gets no CORS headers', async () => {
    const response = await fetch(`${baseUrl}/admin/probe`, {
      headers: { Origin: 'https://evil.example' },
    });
    expect(response.status).toBe(200);
    expect(response.headers.get('access-control-allow-origin')).toBeNull();
    expect(response.headers.get('access-control-expose-headers')).toBeNull();
  });

  it('OPTIONS preflight on an allowlisted origin answers 204', async () => {
    const response = await fetch(`${baseUrl}/admin/probe`, {
      method: 'OPTIONS',
      headers: {
        Origin: ALLOWED,
        'Access-Control-Request-Method': 'GET',
        'Access-Control-Request-Headers': 'Authorization',
      },
    });
    expect(response.status).toBe(204);
    expect(response.headers.get('access-control-allow-origin')).toBe(ALLOWED);
    expect(response.headers.get('access-control-allow-methods')).toContain('OPTIONS');
  });

  it('rejects wildcard origins at parse time', () => {
    expect(() => parseDashboardOrigins('*')).toThrow();
    expect(() => parseDashboardOrigins('https://*.vercel.app')).toThrow();
    expect(parseDashboardOrigins('')).toEqual([]);
  });
});

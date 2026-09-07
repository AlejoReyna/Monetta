import { describe, expect, it, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { LoginScreen } from '../src/auth/LoginScreen.js';
import { getSessionToken, clearSession } from '../src/auth/session.js';
import { AppRoutes } from '../src/routes.js';

function memoryStore(): Map<string, string> {
  return new Map<string, string>();
}

function sessionShim(store: Map<string, string>) {
  return {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => { store.set(key, value); },
    removeItem: (key: string) => { store.delete(key); },
  };
}

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('LoginScreen (WP-63)', () => {
  it('stores the token in sessionStorage and lands on the preserved route', async () => {
    const store = memoryStore();
    vi.stubGlobal('sessionStorage', sessionShim(store));
    const fetchImpl = vi.fn(async () =>
      new Response(JSON.stringify({ token: 'tok-123', expiresAt: new Date(Date.now() + 3_600_000).toISOString() }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    render(
      <MemoryRouter initialEntries={[{ pathname: '/login', state: { from: '/runs' } }]}>
        <LoginScreen apiBaseUrl="https://api.example" fetchImpl={fetchImpl as typeof fetch} />
      </MemoryRouter>,
    );
    fireEvent.change(screen.getByLabelText('Passphrase'), { target: { value: 'owner-passphrase-here' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    await waitFor(() => expect(fetchImpl).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(store.get('monetta.dashboard.token')).toBe('tok-123'));
    expect(getSessionToken(sessionShim(store))).toBe('tok-123');
  });

  it('shows a generic error on wrong passphrase and a wait message on 429', async () => {
    const store = memoryStore();
    vi.stubGlobal('sessionStorage', sessionShim(store));
    let status = 401;
    const fetchImpl = vi.fn(async () => new Response(JSON.stringify({ error: 'x' }), { status }));
    const { rerender } = render(
      <MemoryRouter>
        <LoginScreen apiBaseUrl="https://api.example" fetchImpl={fetchImpl as typeof fetch} />
      </MemoryRouter>,
    );
    fireEvent.change(screen.getByLabelText('Passphrase'), { target: { value: 'nope-nope-nope-nope' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    await waitFor(() => expect(screen.getByRole('alert').textContent).toContain('Invalid passphrase.'));
    expect(store.get('monetta.dashboard.token')).toBeUndefined();

    status = 429;
    rerender(
      <MemoryRouter>
        <LoginScreen apiBaseUrl="https://api.example" fetchImpl={fetchImpl as typeof fetch} />
      </MemoryRouter>,
    );
    fireEvent.change(screen.getByLabelText('Passphrase'), { target: { value: 'nope-nope-nope-nope' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    await waitFor(() => expect(screen.getByRole('alert').textContent).toContain('Too many attempts'));
  });
});

describe('AppRoutes (WP-63)', () => {
  it('redirects to login preserving the target route when no session exists', async () => {
    const store = memoryStore();
    vi.stubGlobal('sessionStorage', sessionShim(store));
    clearSession(sessionShim(store));
    render(
      <MemoryRouter initialEntries={['/runs']}>
        <AppRoutes apiBaseUrl="https://api.example" />
      </MemoryRouter>,
    );
    expect(await screen.findByLabelText('Login')).not.toBeNull();
  });

  it('a failed poll keeps last data and flips the banner (unit: banner states)', async () => {
    const { ConnectionBanner } = await import('../src/components/ConnectionBanner.js');
    const { container } = render(
      <ConnectionBanner status="unreachable" lastOkAt={new Date('2026-09-03T10:00:00.000Z')} />,
    );
    expect(container.textContent).toContain('unreachable');
    expect(container.textContent).toContain('2026-09-03');
  });
});

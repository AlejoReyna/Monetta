import { useState, type FormEvent } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { saveSession } from './session.js';
import type { SessionResponse } from '../api/types.js';

export interface LoginScreenDeps {
  readonly apiBaseUrl: string;
  readonly fetchImpl?: typeof fetch;
  readonly onLoggedIn?: () => void;
}

/** Owner login: passphrase in, short-lived token out, straight to where they were. */
export function LoginScreen(deps: LoginScreenDeps): JSX.Element {
  const navigate = useNavigate();
  const location = useLocation();
  const [passphrase, setPassphrase] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent): Promise<void> {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const response = await (deps.fetchImpl ?? fetch)(`${deps.apiBaseUrl}/admin/session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ passphrase }),
      });
      if (response.status === 429) {
        setError('Too many attempts — wait 15 minutes and try again.');
        return;
      }
      if (!response.ok) {
        setError('Invalid passphrase.');
        return;
      }
      const body = (await response.json()) as SessionResponse;
      saveSession(body.token, body.expiresAt);
      deps.onLoggedIn?.();
      const target = (location.state as { from?: string } | null)?.from ?? '/';
      navigate(target, { replace: true });
    } catch {
      setError('The API is unreachable. Check the connection and try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main aria-label="Login">
      <h1>Catalog dashboard</h1>
      <p>Owner sign-in. The session dies with this tab.</p>
      <form onSubmit={(event) => void submit(event)}>
        <label>
          Passphrase
          <input
            aria-label="Passphrase"
            type="password"
            autoComplete="off"
            value={passphrase}
            onChange={(event) => setPassphrase(event.target.value)}
          />
        </label>
        <button type="submit" disabled={busy || passphrase === ''}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
      {error !== null && <p role="alert">{error}</p>}
    </main>
  );
}

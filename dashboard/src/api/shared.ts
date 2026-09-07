import { useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { ApiClient } from './client.js';
import { clearSession, getSessionToken } from '../auth/session.js';

/** One shared client per session: bearer from storage, 401 drops to login. */
export function useApiClient(baseUrl: string): ApiClient {
  const navigate = useNavigate();
  return useMemo(
    () =>
      new ApiClient({
        baseUrl,
        getToken: () => getSessionToken(),
        onUnauthorized: () => {
          clearSession();
          navigate('/login', { replace: true });
        },
      }),
    [baseUrl, navigate],
  );
}

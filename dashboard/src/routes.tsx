import type { ReactNode } from 'react';
import { Link, Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { LoginScreen } from './auth/LoginScreen.js';
import { OverviewScreen } from './screens/Overview.js';
import { RunsScreen } from './screens/Runs.js';
import { SelectionScreen } from './screens/Selection.js';
import { ProductsScreen } from './screens/Products.js';
import { EventsScreen } from './screens/Events.js';
import { FeedPreviewScreen } from './screens/FeedPreview.js';
import { useApiClient } from './api/shared.js';
import { getSessionToken } from './auth/session.js';

export interface AppRoutesDeps {
  readonly apiBaseUrl: string;
}

function RequireSession(props: { readonly children: ReactNode }): JSX.Element {
  const location = useLocation();
  if (getSessionToken() === null) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  return <>{props.children}</>;
}

function Shell(props: { readonly children: ReactNode }): JSX.Element {
  return (
    <div className="app-shell">
      <nav className="app-nav" aria-label="Dashboard">
        <Link className="app-brand" to="/"><span>MONETTA</span> / CATALOG</Link>
        <div className="app-links">
          <Link to="/">Overview</Link>
          <Link to="/runs">Runs</Link>
          <Link to="/selection">Selection</Link>
          <Link to="/products">Products</Link>
          <Link to="/events">Events</Link>
          <Link to="/feed">Feed preview</Link>
        </div>
      </nav>
      <main className="app-content">{props.children}</main>
    </div>
  );
}

export function AppRoutes(deps: AppRoutesDeps): JSX.Element {
  const client = useApiClient(deps.apiBaseUrl);
  return (
    <Routes>
      <Route path="/login" element={<LoginScreen apiBaseUrl={deps.apiBaseUrl} />} />
      <Route
        path="/"
        element={
          <RequireSession>
            <Shell>
              <OverviewScreen client={client} />
            </Shell>
          </RequireSession>
        }
      />
      <Route
        path="/runs"
        element={
          <RequireSession>
            <Shell>
              <RunsScreen client={client} />
            </Shell>
          </RequireSession>
        }
      />
      <Route
        path="/selection"
        element={
          <RequireSession>
            <Shell>
              <SelectionScreen client={client} />
            </Shell>
          </RequireSession>
        }
      />
      <Route
        path="/products"
        element={
          <RequireSession>
            <Shell>
              <ProductsScreen client={client} />
            </Shell>
          </RequireSession>
        }
      />
      <Route
        path="/events"
        element={
          <RequireSession>
            <Shell>
              <EventsScreen client={client} />
            </Shell>
          </RequireSession>
        }
      />
      <Route
        path="/feed"
        element={
          <RequireSession>
            <Shell>
              <FeedPreviewScreen client={client} />
            </Shell>
          </RequireSession>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

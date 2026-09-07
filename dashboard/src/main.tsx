import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { AppRoutes } from './routes.js';
import './styles.css';

// Public, non-secret: the API hostname only. Nothing else belongs in Vercel env.
const apiBaseUrl = import.meta.env.VITE_CATALOG_API_BASE_URL as string | undefined ?? '';

const root = document.getElementById('root');
if (root === null) throw new Error('missing #root');
createRoot(root).render(
  <StrictMode>
    <BrowserRouter>
      <AppRoutes apiBaseUrl={apiBaseUrl} />
    </BrowserRouter>
  </StrictMode>,
);

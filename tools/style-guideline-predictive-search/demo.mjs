import http from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { pageHTML, responseHTML, theme, products } from './fixture.mjs';

const assetTypes = {
  'monetta-tokens.css': 'text/css',
  'monetta-predictive-search.css': 'text/css',
  'monetta-predictive-search.js': 'text/javascript',
  'monetta-core.js': 'text/javascript',
  'monetta-listing.js': 'text/javascript',
};

export async function startServer(port = 0) {
  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url, 'http://127.0.0.1');
    const send = (status, type, body) => {
      response.writeHead(status, { 'Content-Type': type + '; charset=utf-8', 'Cache-Control': 'no-store' });
      response.end(body);
    };
    try {
      const asset = url.pathname.startsWith('/assets/') && url.pathname.slice('/assets/'.length);
      if (asset && Object.hasOwn(assetTypes, asset)) {
        send(200, assetTypes[asset], await readFile(path.join(theme, 'assets', asset)));
      } else if (url.pathname === '/fixtures/product.svg') {
        send(200, 'image/svg+xml', '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72"><rect width="72" height="72" fill="#f0f0f0"/><rect x="15" y="24" width="42" height="36" rx="6" fill="#8f6838"/><path d="M26 27V21a10 10 0 0 1 20 0v6" fill="none" stroke="#211b16" stroke-width="3"/></svg>');
      } else if (/^\/[a-z]{2}-[a-z]{2}\/search\/suggest$/.test(url.pathname)) {
        const query = (url.searchParams.get('q') || '').toLowerCase();
        const locale = url.pathname.split('/')[1];
        const finish = () => {
          if (response.destroyed) return;
          if (query === 'error') send(503, 'text/plain', 'Simulated endpoint failure');
          else send(200, 'text/html', responseHTML(query === 'vacío' || query === 'vacio' ? [] : products, locale));
        };
        setTimeout(finish, query === 'lento' ? 1600 : 120);
      } else if (url.pathname === '/' || /^\/[a-z]{2}-[a-z]{2}\/search$/.test(url.pathname)) {
        const locale = url.searchParams.get('locale') === 'en' ? 'en-US' : 'es-MX';
        send(200, 'text/html', await pageHTML({
          query: url.searchParams.get('q') || '', locale,
          core: url.searchParams.get('core') === '1',
          autofocus: url.searchParams.get('autofocus') === '1',
        }));
      } else if (/^\/[a-z]{2}-[a-z]{2}\/products\//.test(url.pathname)) {
        send(200, 'text/html', '<!doctype html><html lang="es"><title>Producto de prueba</title><h1>Destino de producto simulado</h1><p>El enlace conserva la URL y la variante del fixture.</p><a href="/">Volver</a></html>');
      } else {
        send(404, 'text/plain', 'Not found');
      }
    } catch (error) {
      send(500, 'text/plain', String(error));
    }
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(port, '127.0.0.1', resolve); });
  const url = 'http://127.0.0.1:' + server.address().port;
  return {
    url,
    close: () => new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
      server.closeAllConnections();
    }),
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const port = Number(process.env.PREDICTIVE_PORT || 0);
  const server = await startServer(port);
  console.log('Demo predictiva local (fixtures): ' + server.url);
  console.log('Puerto propio; Ctrl+C para detener. No usa Shopify ni los procesos de otros agentes.');
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => { await server.close(); process.exit(0); });
}

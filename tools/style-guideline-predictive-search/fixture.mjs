/*
 * Fixture substitution, NOT a Shopify Liquid runtime. Materializes the actual
 * component snippet so tests exercise its HTML, JS and CSS without a theme upload.
 * Only the explicitly listed bindings/branches are supported; drift fails loudly.
 * Shopify syntax/semantics are checked separately by the installed Theme Check.
 */
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const root = fileURLToPath(new URL('../../', import.meta.url));
export const theme = path.join(root, 'storefront-theme');
export const evidence = path.join(root, 'docs/style-guideline-migration/predictive-search');
export const escapeHTML = (value) => String(value).replace(/[&<>"']/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[char]));

export async function component({ id = 'demo-primary', query = '', locale = 'es-MX', recentLimit = 5, autofocus = false, inputID } = {}) {
  const snippet = await readFile(path.join(theme, 'snippets/monetta-predictive-search.liquid'), 'utf8');
  const copySource = await readFile(path.join(theme, 'snippets/monetta-predictive-copy.liquid'), 'utf8');
  const copyCases = [...copySource.matchAll(/{%- case key -%}([\s\S]*?){%- endcase -%}/g)];
  const english = locale.startsWith('en');
  const copy = Object.fromEntries([...copyCases[english ? 0 : 1][1].matchAll(
    /{%- when '([^']+)' -%}([\s\S]*?)(?={%- when |$)/g,
  )].map((match) => [match[1], match[2].trim()]));
  const values = {
    predictive_id: id, predictive_input_id: inputID || id + '-input',
    predictive_language: english ? 'en' : 'es', predictive_limit: 6,
    predictive_recent_limit: recentLimit, predictive_query: query,
    predictive_encoded_query: encodeURIComponent(query),
    predictive_label: copy.label, predictive_placeholder: copy.placeholder,
    predictive_loading: copy.loading, predictive_empty: copy.empty,
    predictive_error: copy.error, predictive_count: copy.count,
    predictive_recent_count: copy.recent_count, predictive_forgotten: copy.forgotten,
    'routes.predictive_search_url': '/' + locale.toLowerCase() + '/search/suggest',
    'routes.search_url': '/' + locale.toLowerCase() + '/search',
    'request.locale.iso_code': locale, 'localization.country.iso_code': 'MX',
    'cart.currency.iso_code': 'MXN', placeholder: copy.placeholder,
  };
  let html = snippet
    .replace(/{%- doc -%}[\s\S]*?{%- enddoc -%}/g, '')
    .replace(/{%- liquid[\s\S]*?-%}/g, '')
    .replace(/{%- capture [^%]+-%}[\s\S]*?{%- endcapture -%}/g, '')
    .replace(/{%- unless include_assets == false -%}([\s\S]*?){%- endunless -%}/g, '$1')
    .replace(/{% if hide_label %}([\s\S]*?){% endif %}/g, '')
    .replace(/{% if placeholder != blank %}([\s\S]*?){% endif %}/g, '$1')
    .replace(/{% if search_autofocus %}([\s\S]*?){% endif %}/g, autofocus ? '$1' : '')
    .replace(/{% render 'monetta-predictive-copy', key: '([^']+)' %}/g, (_, key) => {
      if (!(key in copy)) throw new Error('Unknown fixture copy: ' + key);
      return escapeHTML(copy[key]);
    })
    .replace(/{{ 'monetta-predictive-search.css' \| asset_url \| stylesheet_tag }}/g, '<link rel="stylesheet" href="/assets/monetta-predictive-search.css">')
    .replace(/{{ 'monetta-predictive-search.js' \| asset_url }}/g, '/assets/monetta-predictive-search.js')
    .replace(/{{ ([^}]+) }}/g, (_, expression) => {
      const binding = expression.split('|')[0].trim();
      if (!(binding in values)) throw new Error('Unknown fixture binding: ' + expression);
      return escapeHTML(values[binding]);
    });
  if (html.includes('{%') || html.includes('{{')) throw new Error('Unresolved Liquid in fixture');
  return html;
}

export const products = [
  { handle: 'bolsa-muestra', title: 'Bolsa de muestra con nombre largo para comprobar lectura y salto de línea', price: '$1,250.00 MXN' },
  { handle: 'cartera-muestra', title: 'Cartera de muestra en piel', price: '$480.00 MXN' },
  { handle: 'reloj-muestra', title: 'Reloj de muestra', price: '$890.00 MXN' },
];

export function responseHTML(items = products, locale = 'es-mx') {
  return '<div id="shopify-section-monetta-predictive-results"><div data-monetta-predictive-response data-count="' + items.length + '"><ul data-monetta-predictive-products>' +
    items.map((product, index) => '<li role="presentation"><a role="option" aria-selected="false" tabindex="-1" class="monetta-predictive-search__option" data-monetta-predictive-option href="/' +
      locale + '/products/' + escapeHTML(product.handle) + '?_pos=' + (index + 1) + '&amp;_psq=sample&amp;variant=' + (100 + index) +
      '"><span class="monetta-predictive-search__media" aria-hidden="true"><img src="/fixtures/product.svg" alt="" width="72" height="72"></span>' +
      '<span class="monetta-predictive-search__details"><span class="monetta-predictive-search__title" lang="' + locale + '">' +
      escapeHTML(product.title) + '</span><span class="monetta-predictive-search__price">' + escapeHTML(product.price) + '</span></span></a></li>').join('') +
    '</ul></div></div>';
}

export async function pageHTML({ query = '', locale = 'es-MX', core = false, autofocus = false } = {}) {
  const primary = await component({ query, locale, autofocus, inputID: 'page-search-input' });
  const secondary = await component({ id: 'demo-secondary', query, locale, inputID: 'header-search-input' });
  return '<!doctype html><html lang="es-MX"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<title>Monetta · Predictivo · Demo local</title><link rel="icon" href="data:,"><link rel="stylesheet" href="/assets/monetta-tokens.css">' +
    '<style>body{margin:0;background:var(--color-canvas);color:var(--color-ink);font-family:var(--font-sans);line-height:1.5}main{padding:24px;max-width:1100px;margin:auto}h1{font-family:var(--font-serif);font-size:2rem;line-height:1.3}' +
    '.demo-notice{padding:12px 24px;background:var(--color-surface-deep)}.demo-primary{max-width:680px}.demo-secondary{max-width:420px;margin:48px 0 0 auto}.demo-note{margin-block:24px}a{color:inherit}button{font:inherit}.demo-bottom{margin-top:900px}dialog{width:min(600px,80vw)}.demo-zoom{font-size:200%}</style>' +
    (core ? '<script src="/assets/monetta-core.js" defer></script><script src="/assets/monetta-listing.js" defer></script>' : '') +
    '</head><body><div class="demo-notice">Demostración local · catálogo simulado · sin conexión a Shopify</div><main><h1>Búsqueda predictiva Monetta</h1>' +
    '<p class="demo-note">Prueba “bolsa”, “vacío”, “error” o “lento”. Las dos instancias son independientes. Enter sin selección abre un GET local de demostración.</p>' +
    (query ? '<p data-demo-submitted>GET recibido: ' + escapeHTML(query) + '</p>' : '') +
    '<section class="demo-primary" aria-label="Instancia principal">' + primary + '</section>' +
    '<section class="demo-secondary" aria-label="Instancia secundaria">' + secondary + '</section>' +
    '<p><button type="button" id="outside">Control exterior</button></p>' +
    '<p class="demo-note">Esta página carga los tokens existentes y únicamente los estilos del componente. Los precios, imágenes y destinos mostrados aquí son fixtures.</p>' +
    '<div class="demo-bottom"><a href="/">Volver al inicio de la demo</a></div></main></body></html>';
}

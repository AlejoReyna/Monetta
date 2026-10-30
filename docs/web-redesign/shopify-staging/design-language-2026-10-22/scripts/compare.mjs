// Builds the before/after review page of the design-language pass from captures/before and captures/after (same names, same
// widths), plus the app's reference renders (test/goldens/ui04, the committed Flutter goldens with the real fonts) beside the
// phone captures they correspond to. Writes captures/comparison.html (relative links, opens from the folder) and one PNG sheet
// per width (captures/compare-<width>.png) for a quick look.
//
//   node compare.mjs
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch } from '../../scripts/e2e/lib.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const captures = path.resolve(here, '../captures');
const root = path.resolve(here, '../../../../..');
const before = JSON.parse(readFileSync(path.join(captures, 'before/index.json'), 'utf8')).captures.filter((c) => c.file);
const after = JSON.parse(readFileSync(path.join(captures, 'after/index.json'), 'utf8')).captures.filter((c) => c.file);
const key = (c) => `${c.width}-${c.name}`;
const afterByKey = new Map(after.map((c) => [key(c), c]));
const widths = [...new Set(after.map((c) => c.width))].sort((a, b) => a - b);
const APP = { home: 'inicio', collection: 'coleccion', 'product-long-name': 'ficha', bag: 'bolsa' };

const rows = [];
for (const w of widths) {
  const names = [...new Set([...before, ...after].filter((c) => c.width === w).map((c) => c.name))];
  for (const name of names) {
    const b = before.find((c) => key(c) === `${w}-${name}`);
    const a = afterByKey.get(`${w}-${name}`);
    const app = w === 390 && APP[name] && existsSync(path.join(root, `test/goldens/ui04/${APP[name]}_375x812.png`)) ? `../../../../../test/goldens/ui04/${APP[name]}_375x812.png` : null;
    rows.push({ w, name, before: b ? `before/${b.file}` : null, after: a ? `after/${a.file}` : null, app, beforeFull: b?.full ? `before/${b.full}` : null, afterFull: a?.full ? `after/${a.full}` : null });
  }
}

const cell = (src, label) => (src ? `<figure><a href="${src}"><img loading="lazy" src="${src}" alt="${label}"></a><figcaption>${label}</figcaption></figure>` : `<figure class="missing"><figcaption>${label}: not captured</figcaption></figure>`);
const html = `<!doctype html>
<html lang="es-MX"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Antes y después · lenguaje de la app en Shopify</title>
<style>
  :root { --canvas:#FBF8F2; --ink:#211B16; --muted:#73665D; --line:#E7DCCE; }
  body { margin:0; padding:24px; background:var(--canvas); color:var(--ink); font:15px/1.5 system-ui, sans-serif; }
  h1 { font:400 28px/1.2 Georgia, serif; margin:0 0 4px; } h2 { font:400 22px/1.2 Georgia, serif; margin:32px 0 12px; }
  p { color:var(--muted); max-width:70ch; }
  .row { display:grid; grid-template-columns: 160px repeat(3, minmax(0, 1fr)); gap:16px; align-items:start; padding:16px 0; border-top:1px solid var(--line); }
  .row h3 { margin:0; font-size:14px; } figure { margin:0; } img { width:100%; height:auto; border:1px solid var(--line); background:#fff; }
  figcaption { font-size:12px; color:var(--muted); margin-top:4px; } .missing { padding:24px 0; }
  a.full { font-size:12px; color:var(--muted); }
</style></head><body>
<h1>Antes y después</h1>
<p>Borrador <code>192125304866</code> de <code>monetta-staging.myshopify.com</code>, servido por <code>shopify theme dev</code>. Antes: estado del 22 de octubre al empezar este paso. Después: estado entregado. A 390 px se muestra junto a cada pantalla el render de referencia de la app (golden <code>test/goldens/ui04/*_375x812.png</code>, fuentes reales, sin fotos de producto).</p>
${widths
  .map(
    (w) => `<h2>${w} px</h2>${rows
      .filter((r) => r.w === w)
      .map(
        (r) => `<div class="row"><h3>${r.name}${r.beforeFull || r.afterFull ? `<br>${r.beforeFull ? `<a class="full" href="${r.beforeFull}">antes, página completa</a>` : ''}${r.afterFull ? ` · <a class="full" href="${r.afterFull}">después, página completa</a>` : ''}` : ''}</h3>${cell(r.before, 'Antes')}${cell(r.after, 'Después')}${r.app ? cell(r.app, 'App (golden 375×812)') : '<figure></figure>'}</div>`,
      )
      .join('')}`,
  )
  .join('')}
</body></html>`;
writeFileSync(path.join(captures, 'comparison.html'), html);

// PNG sheets: before | after pairs, one sheet per width.
const { browser, page } = await launch({ width: 1600, height: 1000 });
for (const w of widths) {
  const pairs = rows.filter((r) => r.w === w && r.before && r.after);
  const data = (rel) => `data:image/png;base64,${readFileSync(path.join(captures, rel)).toString('base64')}`;
  const perRow = w >= 1024 ? 1 : w >= 768 ? 2 : 3;
  const sheet = `<body style="margin:0;background:#d8d8d8;font:13px sans-serif"><div style="display:grid;grid-template-columns:repeat(${perRow},1fr);gap:12px;padding:12px">${pairs
    .map((p) => `<div style="background:#fff;padding:6px"><div style="display:grid;grid-template-columns:1fr 1fr;gap:6px"><img style="width:100%" src="${data(p.before)}"><img style="width:100%" src="${data(p.after)}"></div><div>${w}px · ${p.name} — antes | después</div></div>`)
    .join('')}</div></body>`;
  await page.setContent(sheet);
  await page.evaluate(() => Promise.all([...document.images].map((im) => im.decode())));
  await page.screenshot({ path: path.join(captures, `compare-${w}.png`), fullPage: true });
}
await browser.close();
console.log(`comparison.html with ${rows.length} rows; sheets for ${widths.join(', ')}`);

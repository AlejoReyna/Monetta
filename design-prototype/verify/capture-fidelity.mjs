// Side-by-side evidence for the mobile fidelity review: captures the prototype at the
// review's viewports (375×812 and 440×956 for the app comparison, 768 and 1440 for the
// tablet/desktop adaptations), measures the same values the 2026-10-18 audit measured
// plus the new bar/recommendation facts, and writes a three-way comparator
// (app · prototype before · prototype after). The audit folder is only read.
//
//   npm run capture:fidelity                       # build, serve, write ../docs/web-redesign/fidelity-2026-10-18/
//   npm run capture:fidelity -- --skip-build --out=../docs/web-redesign/some-other-folder
import { existsSync } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch, watch } from './browser.mjs';
import { demoCartLines } from './check-layout.mjs';
import { scrollThrough, seedCart } from './report.mjs';
import { build, startPreview } from './server.mjs';

const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
const root = fileURLToPath(new URL('..', import.meta.url));
const outDir = path.resolve(root, args.out ?? '../docs/web-redesign/fidelity-2026-10-18');
const auditDir = path.resolve(root, '../docs/web-redesign/audit-2026-10-18');
// The comparator links to the audit folder and to its own result: relative to wherever --out puts it.
const auditRel = path.relative(outDir, auditDir).split(path.sep).join('/');
const resultRel = [['RESULTADO.md', 'RESULTADO.md'], [path.join('..', 'RESULTADO.md'), '../RESULTADO.md']].find(([file]) => existsSync(path.join(outDir, file)))?.[1];
const webDir = path.join(outDir, 'web');

const PRODUCT = '/products/bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa';
const OTHER_PRODUCT = '/products/bolso-coach-shoulder-negro-rectangular';
const ROUTES = [
  ['inicio', '/'],
  ['coleccion', '/collections/guess'],
  ['ficha', PRODUCT],
  ['busqueda', '/search?q=bolsa&type=product'],
  ['bolsa', '/cart'],
];
const VIEWPORTS = [
  { width: 375, height: 812 },
  { width: 440, height: 956 },
  { width: 768, height: 1024 },
  { width: 1440, height: 900 },
];
const STRIP = 28;

async function measure(page) {
  return page.evaluate(() => {
    const round = (value) => Math.round(value * 100) / 100;
    const rect = (element) => {
      if (!element) return null;
      const r = element.getBoundingClientRect();
      return Object.fromEntries(['x', 'y', 'width', 'height'].map((key) => [key, round(r[key])]));
    };
    const shown = (element) => Boolean(element) && element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden';
    const role = (selector) => {
      const element = document.querySelector(selector);
      if (!element) return null;
      const style = getComputedStyle(element);
      return { text: element.textContent.trim(), rect: rect(element), family: style.fontFamily, size: style.fontSize, weight: style.fontWeight, color: style.color, display: style.display };
    };
    const controls = (selector) =>
      [...document.querySelectorAll(selector)]
        .filter(shown)
        .map((element) => ({ label: element.getAttribute('aria-label') || element.textContent.trim(), rect: rect(element) }))
        .sort((a, b) => a.rect.x - b.rect.x);
    const card = document.querySelector('#rail-more .card, #rail-novedades .card');
    const media = card?.querySelector('.card__media');
    const name = card?.querySelector('.card__name');
    return {
      scroll: { x: scrollX, y: scrollY },
      width: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
      prototypeStrip: rect(document.querySelector('.proto-strip')),
      header: shown(document.querySelector('.site-header')) ? rect(document.querySelector('.site-header')) : null,
      pageBar: shown(document.querySelector('[data-page-bar]')) ? rect(document.querySelector('[data-page-bar]')) : null,
      firstCard: rect(document.querySelector('.card')),
      pageTitle: role('main h1'),
      homeHeading: role('#home-novedades'),
      recommendationHeading: role('#product-more'),
      recentHeading: role('#product-recent'),
      summaryHeading: role('.summary__title'),
      productName: role('.product-panel__name'),
      cardBrand: role('.card__brand'),
      cardName: role('.card__name'),
      cardPrice: role('.card__price'),
      headerControls: controls('.site-header a, .site-header button'),
      barControls: controls('[data-page-bar] a, [data-page-bar] button'),
      recommendationCard: card && {
        width: round(card.getBoundingClientRect().width),
        photoRatio: round(media.getBoundingClientRect().width / media.getBoundingClientRect().height),
        nameLines: Math.round(name.getBoundingClientRect().height / Number.parseFloat(getComputedStyle(name).lineHeight)),
      },
    };
  });
}

async function frame(page, selector, top) {
  await page.evaluate(
    ([query, offset]) => {
      const element = document.querySelector(query);
      if (element) window.scrollTo(0, element.getBoundingClientRect().top + window.scrollY - offset);
    },
    [selector, top],
  );
  await page.waitForTimeout(350);
}

const read = async (file) => JSON.parse(await readFile(file, 'utf8'));
const esc = (text) => String(text).replace(/[&<>"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[char]);
const fmt = (value) => (value === null || value === undefined ? '—' : `${Math.round(value * 10) / 10} px`);

function describe(key, before, after, app) {
  const stripless = (card) => (card ? card.y - STRIP : null);
  const labels = (controls) => (controls ?? []).map((control) => control.label.replace(/^Carrito.*/, 'Carrito')).join(' · ') || '—';
  switch (key) {
    case 'coleccion':
      return `H01 · primera tarjeta a ${fmt(stripless(after.firstCard))} bajo el aviso (antes ${fmt(stripless(before.firstCard))}; app ${fmt(app.firstCard?.y)}). Una barra fijada con ${labels(after.barControls)} sustituye barra global, migas y fila de filtros; queda la fila de atajos de estilo.`;
    case 'busqueda':
      return `H01 · primera tarjeta a ${fmt(stripless(after.firstCard))} bajo el aviso (antes ${fmt(stripless(before.firstCard))}; app ${fmt(app.firstCard?.y)}). Barra «Buscar» con ${labels(after.barControls)}, campo y encabezado de resultados en Inter ${after.pageTitle?.size}/${after.pageTitle?.weight}.`;
    case 'bolsa':
      return `H01 · una barra (${labels(after.barControls)}) con el título «${after.pageTitle?.text}» de ${after.pageTitle?.size} y el contador al borde derecho, como en la app. Antes: barra global (${labels(before.headerControls)}) y título debajo.`;
    case 'ficha':
      return `H02 · encabezado: ${labels(after.headerControls)}. Antes: ${labels(before.headerControls)}. App: volver · buscar · logo · cuenta · bolsa.`;
    case 'ficha_recomendaciones':
    case 'ficha_vistas':
      return `H03 · «${after.recommendationHeading?.text ?? '—'}» en ${after.recommendationHeading?.family.split(',')[0].replaceAll('"', '')} ${after.recommendationHeading?.size}/${after.recommendationHeading?.weight} (antes ${before.recommendationHeading?.family?.split(',')[0].replaceAll('"', '')} ${before.recommendationHeading?.size}/${before.recommendationHeading?.weight}; app Inter 17/600). Tarjeta de ${fmt(after.recommendationCard?.width)} (antes ${fmt(before.firstCard?.width)}), foto ${after.recommendationCard?.photoRatio} (4:5 = 0.8; antes cuadrada), nombre de ${after.recommendationCard?.nameLines} líneas (antes una).`;
    default:
      return 'Sin cambios: Inicio conserva su composición, el encabezado Playfair de Novedades y las tarjetas compactas.';
  }
}

async function writeComparator(captures) {
  const beforeMetrics = await read(path.join(auditDir, 'web/metrics.json'));
  const byFile = (set, file) => set.captures.find((capture) => capture.file === file)?.metrics ?? {};
  const keys = ['inicio', 'coleccion', 'ficha', 'ficha_recomendaciones', 'ficha_vistas', 'busqueda', 'bolsa'];
  const names = { inicio: 'Inicio', coleccion: 'Colección · Bolsas', ficha: 'Ficha de producto', ficha_recomendaciones: 'Ficha · Más de la marca', ficha_vistas: 'Ficha · Vistas hace un momento', busqueda: 'Búsqueda', bolsa: 'Mi bolsa' };
  const texts = {};
  for (const size of ['375x812', '440x956']) {
    for (const key of keys) {
      const file = `${key}_${size}.jpg`;
      const appFile = path.join(auditDir, 'mobile', `${key === 'ficha_vistas' ? 'ficha_recomendaciones' : key}_${size}.json`);
      const app = await read(appFile).catch(() => ({}));
      // The audit measured the recommendation rails on the product page capture itself.
      const beforeFile = file.replace(/^ficha_(recomendaciones|vistas)/, 'ficha');
      texts[`${key}_${size}`] = describe(key, byFile(beforeMetrics, beforeFile), byFile({ captures }, file), app);
    }
  }
  const page = `<!doctype html>
<html lang="es-MX">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Monetta · Fidelidad móvil, antes y después</title>
  <style>
    :root { font-family: system-ui, sans-serif; color: #111; background: #f5f5f5; }
    * { box-sizing: border-box; }
    body { margin: 0; }
    main { max-width: 1280px; margin: 0 auto; padding: 28px 24px 48px; }
    h1 { font-size: 27px; line-height: 1.2; margin: 0 0 12px; }
    p { line-height: 1.55; margin: 8px 0; }
    a { color: #785724; text-underline-offset: 3px; }
    .intro { max-width: 90ch; color: #555; }
    .controls { display: flex; gap: 20px; flex-wrap: wrap; margin: 24px 0 16px; }
    label { display: grid; gap: 6px; font-size: 14px; font-weight: 600; }
    select { min-height: 44px; padding: 9px 36px 9px 12px; font: inherit; border: 1px solid #bbb; border-radius: 8px; background: white; }
    :focus-visible { outline: 3px solid #8f6838; outline-offset: 3px; }
    .finding { padding: 16px 20px; border: 1px solid #d6c59f; border-radius: 10px; background: #fff; margin-bottom: 22px; }
    .trio { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 20px; align-items: start; }
    figure { margin: 0; min-width: 0; }
    figcaption { font-size: 16px; font-weight: 600; margin: 0 auto 10px; max-width: var(--phone-width, 375px); }
    figcaption span { display: block; font-size: 12px; font-weight: 400; color: #666; margin-top: 4px; }
    .screen { width: 100%; max-width: var(--phone-width, 375px); margin: 0 auto; background: white; border: 1px solid #ddd; box-shadow: 0 6px 20px #0000000b; }
    img { display: block; width: 100%; height: auto; }
    .note { margin-top: 20px; color: #555; font-size: 13px; max-width: 100ch; }
    @media (max-width: 1000px) { .trio { grid-template-columns: 1fr; gap: 28px; } main { padding: 24px 16px; } }
  </style>
</head>
<body>
  <main>
    <h1>Monetta · App móvil, prototipo del 17 de octubre y prototipo corregido</h1>
    <p class="intro">Resultado de la revisión de fidelidad del 18 de octubre de 2026 (H01–H03). Izquierda: widgets Flutter actuales (carpeta de la auditoría, sin tocar). Centro: el prototipo antes de los cambios (auditoría). Derecha: el prototipo corregido. Las tres se muestran a la misma escala lógica.</p>
    <p>${resultRel ? `<a href="${resultRel}">Leer el resultado por hallazgo</a> · ` : ''}<a href="${auditRel}/REVISION_FIDELIDAD_MOBILE.md">Revisión original</a> · <a href="${auditRel}/comparacion.html">Comparador original (app y antes)</a></p>
    <div class="controls">
      <label for="page">Pantalla
        <select id="page">${keys.map((key) => `<option value="${key}">${names[key]}</option>`).join('')}</select>
      </label>
      <label for="viewport">Viewport lógico
        <select id="viewport"><option value="375x812">375 × 812</option><option value="440x956">440 × 956</option></select>
      </label>
    </div>
    <p class="finding" id="finding" role="status"></p>
    <div class="trio">
      <figure><figcaption>App móvil actual<span>Widgets Flutter · DPR 3 · fotos de producto como marcador</span></figcaption><div class="screen"><img id="app" alt=""></div></figure>
      <figure><figcaption>Prototipo del 17 de octubre<span>Brave · DPR 1 · estado previo (auditoría)</span></figcaption><div class="screen"><img id="before" alt=""></div></figure>
      <figure><figcaption>Prototipo corregido<span>Brave · DPR 1 · build actual</span></figcaption><div class="screen"><img id="after" alt=""></div></figure>
    </div>
    <p class="note">Las capturas web incluyen 28 px del aviso de prototipo: se descuentan al comparar posiciones. Las fotos de producto no cargan en el arnés Flutter y quedan como marcadores; los productos y estados de bolsa difieren entre los dos snapshots. «Ficha · Vistas hace un momento» no tiene captura de la app: usa la misma sección que «Más de la marca». Las cifras de cada hallazgo salen de <code>web/metrics.json</code> y de las mediciones Flutter de la auditoría.</p>
  </main>
  <script>
    const texts = ${JSON.stringify(texts)};
    const names = ${JSON.stringify(names)};
    const page = document.getElementById('page');
    const viewport = document.getElementById('viewport');
    function update() {
      const key = page.value;
      const size = viewport.value;
      document.documentElement.style.setProperty('--phone-width', size.split('x')[0] + 'px');
      const appKey = key === 'ficha_vistas' ? 'ficha_recomendaciones' : key;
      const beforeKey = key === 'ficha_vistas' ? 'ficha_recomendaciones' : key;
      document.getElementById('app').src = '${auditRel}/mobile/' + appKey + '_' + size + '.png';
      document.getElementById('before').src = '${auditRel}/web/' + beforeKey + '_' + size + '.jpg';
      document.getElementById('after').src = 'web/' + key + '_' + size + '.jpg';
      for (const [id, label] of [['app', 'app actual'], ['before', 'prototipo antes'], ['after', 'prototipo corregido']]) {
        document.getElementById(id).alt = names[key] + ' en ' + label + ', ' + size;
      }
      document.getElementById('finding').textContent = texts[key + '_' + size];
    }
    page.addEventListener('change', update);
    viewport.addEventListener('change', update);
    update();
  </script>
</body>
</html>
`;
  await writeFile(path.join(outDir, 'comparacion.html'), page);
}

if (!args['skip-build']) await build();
const server = await startPreview(Number(args.port ?? 4175));
const { browser, version } = await launch();
await mkdir(webDir, { recursive: true });
const captures = [];

async function shoot(context, page, file, route, extra) {
  const problems = watch(page);
  await page.goto(`${server.url}${route}`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.locator('main').waitFor();
  if (extra) await extra(page);
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(webDir, file), type: 'jpeg', quality: 85 });
  captures.push({ file, route, viewport: page.viewportSize(), metrics: await measure(page), problems });
  console.log(`Captured ${file}${problems.length ? ` ! ${problems.join(' | ')}` : ''}`);
}

try {
  for (const viewport of VIEWPORTS) {
    const size = `${viewport.width}x${viewport.height}`;
    const phone = viewport.width < 768;
    for (const [name, route] of ROUTES) {
      const context = await browser.newContext({ viewport, deviceScaleFactor: 1, reducedMotion: 'reduce' });
      if (name === 'bolsa') await seedCart(context, demoCartLines());
      const page = await context.newPage();
      await shoot(context, page, `${name}_${size}.jpg`, route);
      if (name === 'ficha' && phone) {
        // Recommendation rails, framed like the app's capture: the section heading about a third down.
        await frame(page, '#product-more', 300);
        await page.screenshot({ path: path.join(webDir, `ficha_recomendaciones_${size}.jpg`), type: 'jpeg', quality: 85 });
        captures.push({ file: `ficha_recomendaciones_${size}.jpg`, route: `${route}#product-more`, viewport, metrics: await measure(page), problems: [] });
        console.log(`Captured ficha_recomendaciones_${size}.jpg`);
      }
      await context.close();
    }
    if (phone) {
      // "Vistas hace un momento" needs a previous view; the other rail is captured the same way.
      const context = await browser.newContext({ viewport, deviceScaleFactor: 1, reducedMotion: 'reduce' });
      const page = await context.newPage();
      await page.goto(`${server.url}${OTHER_PRODUCT}`, { waitUntil: 'networkidle' });
      await shoot(context, page, `ficha_vistas_${size}.jpg`, PRODUCT, (target) => frame(target, '#product-recent', 220));
      await context.close();

      const scrolled = await browser.newContext({ viewport, deviceScaleFactor: 1, reducedMotion: 'reduce' });
      const scrolledPage = await scrolled.newPage();
      await shoot(scrolled, scrolledPage, `coleccion_desplazada_${size}.jpg`, '/collections/guess', async (target) => {
        await scrollThrough(target);
        await frame(target, '[data-grid] li:nth-child(9)', 320);
      });
      await scrolled.close();
    }
  }
} finally {
  await browser.close();
  server.stop();
}

await writeFile(path.join(webDir, 'metrics.json'), `${JSON.stringify({ capturedAt: new Date().toISOString(), browser: version, captures }, null, 2)}\n`);
await writeComparator(captures);
console.log(`Saved ${captures.length} captures, metrics.json and comparacion.html to ${path.relative(process.cwd(), outDir)}`);

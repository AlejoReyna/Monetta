// Acceptance checks of the guide 1:1 pass, measured in the browser on the rendered draft theme. One block per phase
// (F1 base visual, then the screens of F2–F5); every block was first run against the tree before its phase and seen to
// fail (guia-1a1/RESULTADO.md). Fonts are measured with CDP CSS.getPlatformFontsForNode, never assumed.
//
//   node guia-checks.mjs --base-url=http://127.0.0.1:9292 [--phases=f1,f2] [--name=guia-checks] [--inject-css=...]
//
// Results go to $MONETTA_RUNS_DIR (or shopify-staging/runs/) through the shared harness (scripts/e2e/lib.mjs).
import { launch, parseArgs, Run, settle } from '../../scripts/e2e/lib.mjs';
import { predictiveChecks } from './predictive-checks.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const phases = new Set((args.phases || 'f1,f2').split(','));
const injectCss = args['inject-css'] || null;
const run = new Run(args.name || 'guia-checks', { baseUrl, extra: { phases: [...phases], injectCss } });

const WIDTHS = [[320, 640], [390, 844], [768, 1024], [1024, 768], [1440, 900]];

async function open(page, path) {
  for (let i = 0; i < 4; i += 1) {
    const response = await page.goto(`${baseUrl}${path}`, { waitUntil: 'load' });
    const broken = await page.evaluate(() => /Failed to render storefront|Bad Gateway|unauthorized/i.test(document.body?.innerText || ''));
    if (!broken) {
      await settle(page, { timeoutMs: 8000 });
      return response;
    }
    await page.waitForTimeout(3000);
  }
  throw new Error(`proxy kept answering with an error page for ${path}`);
}

/** The faces the platform actually used for the text of the first node matching `selector`. */
async function platformFonts(page, selector) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('DOM.enable');
  await cdp.send('CSS.enable');
  const { root } = await cdp.send('DOM.getDocument', { depth: -1 });
  const { nodeId } = await cdp.send('DOM.querySelector', { nodeId: root.nodeId, selector });
  if (!nodeId) return [];
  const { fonts } = await cdp.send('CSS.getPlatformFontsForNode', { nodeId });
  await cdp.detach();
  return fonts.map((f) => f.familyName);
}

// The rendered font of an input's text. It lives in the input's user-agent shadow root, which DOM.querySelector does not
// reach, so the document is read with pierce: 'placeholder' measures the placeholder's box (field empty), 'typed' the
// inner editor (field filled).
async function inputPlatformFonts(page, selector, which) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('DOM.enable');
  await cdp.send('CSS.enable');
  const { root } = await cdp.send('DOM.getDocument', { depth: -1, pierce: true });
  const { nodeId } = await cdp.send('DOM.querySelector', { nodeId: root.nodeId, selector });
  const walk = (n) => (n.nodeId === nodeId ? n : [...(n.children || []), ...(n.shadowRoots || [])].map(walk).find(Boolean));
  const shadow = walk(root)?.shadowRoots?.[0];
  const divs = (shadow?.children || []).filter((c) => c.nodeName === 'DIV');
  const hasText = (d) => (d.children || []).some((c) => c.nodeType === 3);
  const deepest = (n) => { const kids = (n.children || []).filter((c) => c.nodeType === 1); return kids.length ? deepest(kids[0]) : n; };
  const editor = divs.find((d) => !hasText(d));
  const target = which === 'placeholder' ? divs.find(hasText) : editor && deepest(editor);
  const fonts = target ? (await cdp.send('CSS.getPlatformFontsForNode', { nodeId: target.nodeId })).fonts : [];
  await cdp.detach();
  return fonts.map((f) => f.familyName);
}

const overflow = (page) => page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);

/* ======================================================================== F1: base visual */
async function f1() {
  const { browser, page } = await launch({ width: 390, height: 844, injectCss });
  try {
    await open(page, '/');
    // Guide tokens, Shopify side.
    const tokens = await page.evaluate(() => {
      const s = getComputedStyle(document.documentElement);
      return { serif: s.getPropertyValue('--font-guide-serif').trim(), script: s.getPropertyValue('--font-guide-script').trim(), pill: s.getPropertyValue('--color-guide-pill').trim(), pillInk: s.getPropertyValue('--color-guide-pill-ink').trim() };
    });
    run.check('F1 tokens: --font-guide-serif starts with Cormorant Garamond, --font-guide-script with Mrs Saint Delafield', /^'?Cormorant Garamond/.test(tokens.serif) && /^'?Mrs Saint Delafield/.test(tokens.script), JSON.stringify(tokens));
    run.check('F1 tokens: guide pill #cdb48d with ink #2b2118 (GuidePillButton)', tokens.pill.toLowerCase() === '#cdb48d' && tokens.pillInk.toLowerCase() === '#2b2118', JSON.stringify(tokens));

    // The six OFL faces load (declared in snippets/monetta-fonts.liquid, served from the theme).
    const faces = await page.evaluate(async () => {
      const want = [['normal', 300, 'Cormorant Garamond'], ['italic', 300, 'Cormorant Garamond'], ['normal', 400, 'Cormorant Garamond'], ['italic', 400, 'Cormorant Garamond'], ['normal', 500, 'Cormorant Garamond'], ['normal', 400, 'Mrs Saint Delafield']];
      const out = [];
      for (const [style, weight, family] of want) {
        const loaded = await document.fonts.load(`${style} ${weight} 20px "${family}"`).catch(() => []);
        out.push({ face: `${family} ${weight} ${style}`, ok: loaded.some((f) => f.family.replace(/"/g, '') === family && f.status === 'loaded' && f.style === style && String(f.weight) === String(weight)) });
      }
      return out;
    });
    run.check('F1 fonts: Cormorant Garamond 300, 300 italic, 400, 400 italic, 500 and Mrs Saint Delafield 400 load', faces.every((f) => f.ok), JSON.stringify(faces.filter((f) => !f.ok)));

    // Measured: text set with the guide classes is drawn with those faces, not a fallback.
    await page.evaluate(() => {
      const probe = document.createElement('div');
      probe.id = 'guia-probe';
      probe.innerHTML = '<p class="guide-serif" id="probe-serif">Compra fácil desde México</p><p class="guide-serif guide-serif--italic" id="probe-italic">Totes</p><p class="guide-script" id="probe-script">mayoreo</p>';
      document.body.append(probe);
    });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(300);
    const serif = await platformFonts(page, '#probe-serif');
    const italic = await platformFonts(page, '#probe-italic');
    const script = await platformFonts(page, '#probe-script');
    run.check('F1 fonts measured: .guide-serif is drawn in Cormorant Garamond', serif.length > 0 && serif.every((f) => /Cormorant Garamond/i.test(f)), JSON.stringify(serif));
    run.check('F1 fonts measured: .guide-serif--italic is drawn in Cormorant Garamond Italic', italic.length > 0 && italic.every((f) => /Cormorant Garamond/i.test(f)), JSON.stringify(italic));
    run.check('F1 fonts measured: .guide-script is drawn in Mrs Saint Delafield', script.length > 0 && script.every((f) => /Mrs Saint Delafield/i.test(f)), JSON.stringify(script));

    // Every guide asset is served by the theme: 21 icons, 23 owner photographs at 768/1280/1920, the three app stills.
    const icons = ['categoria-accesorios', 'categoria-carteras', 'categoria-crossbody', 'categoria-handbags', 'categoria-perfumes', 'categoria-shoulder', 'categoria-tote', 'contacto-grupo', 'contacto-whatsapp', 'estilo-crossbody', 'estilo-perfumes', 'estilo-satchel', 'estilo-shoulder', 'estilo-tote', 'red-facebook', 'red-instagram', 'red-tiktok', 'servicio-atencion', 'servicio-envios', 'servicio-originales', 'servicio-pagos'];
    const photos = ['home-banner-compra-facil', 'home-banner-nueva-coleccion', 'home-banner-perfumes', 'home-precios-mayoreo', 'mayoreo-hero', 'mayoreo-bolsos-carteras', 'mayoreo-perfumes', 'contacto-hero', 'comparte-gana-catalogo', 'comparte-gana-rewards', 'coleccion-coach', 'coleccion-michael-kors', 'coleccion-steve-madden', 'coleccion-tory-burch', 'coleccion-kate-spade', 'coleccion-marc-jacobs', 'coleccion-totes', 'coleccion-shoulder', 'coleccion-bolsos-de-mano', 'coleccion-carteras', 'coleccion-perfumes', 'coleccion-accesorios', 'coleccion-crossbody'];
    const names = [
      ...icons.map((n) => `monetta-guia-icon-${n}.webp`),
      ...photos.flatMap((n) => [768, 1280, 1920].map((w) => `monetta-guia-${n}-${w}.webp`)),
      'monetta-guia-bienvenida-fondo-full.webp', 'monetta-guia-comparte-banner-fondo-full.webp', 'monetta-guia-studio-banner-fondo-full.webp',
      'CormorantGaramond-Light.woff2', 'CormorantGaramond-LightItalic.woff2', 'CormorantGaramond-Regular.woff2', 'CormorantGaramond-Italic.woff2', 'CormorantGaramond-Medium.woff2', 'MrsSaintDelafield-Regular.woff2',
    ];
    const assets = await page.evaluate(async (list) => {
      const known = [...document.querySelectorAll('link[rel="stylesheet"]')].map((l) => l.href).find((h) => /\/assets\/monetta-tokens\.css/.test(h));
      const base = known.slice(0, known.indexOf('monetta-tokens.css'));
      const missing = [];
      for (const name of list) {
        const r = await fetch(`${base}${name}`, { method: 'GET', cache: 'no-store' });
        if (!r.ok) missing.push(`${name} ${r.status}`);
      }
      return { base, missing };
    }, names);
    run.check(`F1 assets: the ${names.length} guide files (21 icons, 23 photos × 3 widths, 3 stills, 6 fonts) are served by the theme`, assets.missing.length === 0, assets.missing.slice(0, 8).join(', ') || `${names.length} ok`);
  } finally {
    await browser.close();
  }

  // TileViewProductButton: «VER PRODUCTO» on the collection grid only, inside the card's single link.
  for (const [w, h] of WIDTHS) {
    const { browser: b, page: p } = await launch({ width: w, height: h, injectCss });
    try {
      await open(p, '/collections/vendors?q=Coach');
      const cards = await p.evaluate(() => {
        const list = [...document.querySelectorAll('.listing .card, [data-results] .card, .product-grid .card')];
        const grid = list.length ? list : [...document.querySelectorAll('main .card')];
        return grid.map((card) => {
          const view = card.querySelector('.card__view');
          const link = card.querySelector('.card__link');
          if (!view) return { view: false };
          const cs = getComputedStyle(view);
          const r = view.getBoundingClientRect();
          const lr = link.getBoundingClientRect();
          return { view: true, inLink: link.contains(view), hidden: view.getAttribute('aria-hidden') === 'true', text: view.textContent.trim(), transform: cs.textTransform, family: cs.fontFamily, weight: cs.fontWeight, size: cs.fontSize, bg: cs.backgroundColor, height: Math.round(r.height), linkH: Math.round(lr.height), focusables: card.querySelectorAll('a[href], button:not([hidden])').length };
        });
      });
      const views = cards.filter((c) => c.view);
      run.check(`F1 ${w}: every Coach collection card shows VER PRODUCTO (${views.length}/${cards.length})`, cards.length >= 4 && views.length === cards.length, `${views.length}/${cards.length}`);
      const first = views[0] || {};
      run.check(`F1 ${w}: VER PRODUCTO is visual only, inside the card's link (no extra tab stop or name)`, views.length > 0 && views.every((v) => v.inLink && v.hidden), JSON.stringify({ inLink: first.inLink, hidden: first.hidden }));
      run.check(`F1 ${w}: VER PRODUCTO reads «Ver producto» in Inter 600 uppercase on the brown action #745237`, views.length > 0 && views.every((v) => /^ver producto$/i.test(v.text) && v.transform === 'uppercase' && /Inter/.test(v.family) && v.weight === '600' && v.bg === 'rgb(116, 82, 55)'), JSON.stringify(first));
      run.check(`F1 ${w}: VER PRODUCTO pill ${w >= 1024 ? 44 : 40}px; the card's link target is at least 48px`, views.length > 0 && views.every((v) => v.height === (w >= 1024 ? 44 : 40) && v.linkH >= 48), JSON.stringify({ height: first.height, linkH: first.linkH }));
      run.check(`F1 ${w}: no horizontal overflow on the collection`, (await overflow(p)) <= 0, `${await overflow(p)}px`);
      if (w === 390) {
        await open(p, '/');
        const railViews = await p.evaluate(() => document.querySelectorAll('.card--compact .card__view').length);
        run.check('F1 390: home rails keep their compact cards without VER PRODUCTO (as the app)', railViews === 0, `${railViews}`);
        await open(p, '/search?q=bolso&type=product');
        const searchViews = await p.evaluate(() => document.querySelectorAll('main .card .card__view').length);
        run.check('F1 390: search results keep cards without VER PRODUCTO (guide slide 05)', searchViews === 0, `${searchViews}`);
      }
    } finally {
      await b.close();
    }
  }
}

/* ======================================================================== F2: Inicio, header, menú, barra inferior y pie */
const text = (page, selector) => page.evaluate((sel) => [...document.querySelectorAll(sel)].map((el) => el.textContent.replace(/\s+/g, ' ').trim()), selector);

async function f2() {
  for (const [w, h] of WIDTHS) {
    const { browser, page } = await launch({ width: w, height: h, injectCss });
    try {
      await open(page, '/');
      run.check(`F2 ${w}: no horizontal overflow on the home`, (await overflow(page)) <= 0, `${await overflow(page)}px`);
      const tiles = await page.evaluate(() => [...document.querySelectorAll('.guia-brand')].map((a) => { const r = a.getBoundingClientRect(); return [r.left, r.right, r.top, r.height]; }));
      const overlap = tiles.some((t, i) => i > 0 && Math.abs(t[2] - tiles[i - 1][2]) < 1 && t[0] < tiles[i - 1][1] - 0.5);
      run.check(`F2 ${w}: brand tiles do not overlap and are at least 48px tall`, tiles.length > 0 && !overlap && tiles.every((t) => t[3] >= 47.5), JSON.stringify(tiles.map((t) => [Math.round(t[0]), Math.round(t[1]), Math.round(t[3])])));
      if (w !== 390 && w !== 1440) continue;

      // Module order of the guide and the app (home_screen.dart): carousel, styles, brands, two rails, offers, services, register, footer.
      const order = await page.evaluate(() => {
        const pos = (el) => (el ? el.getBoundingClientRect().top + window.scrollY : -1);
        const heading = (t) => [...document.querySelectorAll('main h2')].find((h) => h.textContent.trim() === t);
        return {
          carousel: pos(document.querySelector('[data-guia-carousel]')),
          styles: pos(heading('Compra por estilo')),
          brands: pos(heading('Tus marcas favoritas')),
          nueva: pos(heading('Nueva colección')),
          buscado: pos(heading('Lo más buscado')),
          offers: pos(document.querySelector('.guia-offer')),
          services: pos(document.querySelector('.guide-services')),
          register: pos(document.querySelector('.guia-register')),
          footer: pos(document.querySelector('footer, .site-footer, [class*="footer-grid"]')),
        };
      });
      const seq = Object.values(order);
      run.check(`F2 ${w}: home modules in the guide's order (carousel, estilo, marcas, Nueva colección, Lo más buscado, mayoreo, servicios, regístrate, pie)`, seq.every((v) => v >= 0) && seq.every((v, i) => i === 0 || v > seq[i - 1]), JSON.stringify(order));

      // Carousel: three owner photographs with the app's copy, one active dot.
      const slides = await page.evaluate(() => [...document.querySelectorAll('[data-guia-carousel] .guia-carousel__slide')].map((s) => ({ text: s.textContent.replace(/\s+/g, ' ').trim(), photo: s.querySelector('img')?.currentSrc || '', ok: !!s.querySelector('img')?.naturalWidth || s.querySelector('img')?.loading === 'lazy', href: s.querySelector('a')?.getAttribute('href') })));
      const want = ['Compra fácil desde México', 'Nueva Colección Un paraíso de marcas por descubrir.', 'Perfumes Descubre nuestra selección de fragancias originales'];
      run.check(`F2 ${w}: carousel has the three slides with the app's copy`, slides.length === 3 && slides.every((s, i) => s.text === want[i]), JSON.stringify(slides.map((s) => s.text)));
      run.check(`F2 ${w}: carousel slides show the owner's photographs`, slides.length === 3 && ['home-banner-compra-facil', 'home-banner-nueva-coleccion', 'home-banner-perfumes'].every((n, i) => slides[i].photo.includes(n) || slides[i].photo === ''), JSON.stringify(slides.map((s) => s.photo.split('/').pop())));
      const dots = await page.evaluate(() => [...document.querySelectorAll('.guia-carousel__dots span')].map((d) => d.classList.contains('is-active')));
      run.check(`F2 ${w}: three indicator dots, the first active`, dots.length === 3 && dots[0] && !dots[1] && !dots[2], JSON.stringify(dots));
      const easy = await platformFonts(page, '.guia-slide__italic');
      const script = await platformFonts(page, '.guia-slide__script');
      run.check(`F2 ${w}: «Compra … desde México» measured in Cormorant Garamond, «fácil» in Mrs Saint Delafield`, easy.every((f) => /Cormorant/.test(f)) && easy.length > 0 && script.length > 0 && script.every((f) => /Saint Delafield/.test(f)), JSON.stringify({ easy, script }));
      if (w === 1440) {
        const arrows = await page.evaluate(() => [...document.querySelectorAll('[data-guia-next], [data-guia-prev]')].map((b) => { const r = b.getBoundingClientRect(); return { w: r.width, h: r.height, shown: getComputedStyle(b).display !== 'none' }; }));
        run.check('F2 1440: carousel previous/next buttons are shown, 48px', arrows.length === 2 && arrows.every((a) => a.shown && a.w >= 48 && a.h >= 48), JSON.stringify(arrows));
        await page.click('[data-guia-next]');
        await page.waitForTimeout(900);
        const active = await page.evaluate(() => [...document.querySelectorAll('.guia-carousel__dots span')].findIndex((d) => d.classList.contains('is-active')));
        run.check('F2 1440: «siguiente» moves to slide 2 and the dots follow', active === 1, `active ${active}`);
      }

      // Compra por estilo: five guide icons with their labels.
      const styles = await page.evaluate(() => [...document.querySelectorAll('.guia-styles__tile')].map((a) => ({ label: a.textContent.trim(), icon: a.querySelector('img')?.getAttribute('src') || '', h: a.getBoundingClientRect().height, href: a.getAttribute('href') })));
      run.check(`F2 ${w}: «Compra por estilo» has Crossbody, Tote, Shoulder, Satchel, Perfumes with the guide icons`, styles.map((x) => x.label).join(',') === 'Crossbody,Tote,Shoulder,Satchel,Perfumes' && styles.every((x) => /monetta-guia-icon-estilo-/.test(x.icon)), JSON.stringify(styles.map((x) => [x.label, x.icon.split('/').pop()?.split('?')[0]])));
      run.check(`F2 ${w}: style tiles are 48px targets and lead to listings`, styles.length === 5 && styles.every((x) => x.h >= 48 && /\/collections\//.test(x.href)), JSON.stringify(styles.map((x) => [Math.round(x.h), x.href])));

      // Tus marcas favoritas: tiles for the brands the store sells, in the guide's order, four across on phones.
      const brands = await page.evaluate(() => [...document.querySelectorAll('.guia-brand')].map((a) => ({ name: a.getAttribute('aria-label'), w: a.getBoundingClientRect().width, href: a.getAttribute('href') })));
      run.check(`F2 ${w}: «Tus marcas favoritas» shows Coach, Guess, Michael Kors, Steve Madden first, as the guide orders them`, brands.slice(0, 4).map((b) => b.name).join(',') === 'Ver Coach,Ver Guess,Ver Michael Kors,Ver Steve Madden', JSON.stringify(brands.map((b) => b.name)));
      if (w === 390) run.check('F2 390: brand tiles four across', brands.length >= 4 && Math.abs(brands[0].w - brands[3].w) < 1 && brands[0].w < 100, JSON.stringify(brands.map((b) => Math.round(b.w))));

      // Precios de mayoreo, services, regístrate.
      const offer = await page.evaluate(() => {
        const o = document.querySelector('.guia-offer');
        const pill = o?.querySelector('.guide-pill');
        const label = pill?.querySelector('.guide-pill__label');
        return o && { title: o.querySelector('h2')?.textContent.replace(/\s+/g, ' ').trim(), body: o.querySelector('.guia-offer__body')?.textContent.trim(), pill: label?.textContent.trim(), transform: label && getComputedStyle(label).textTransform, bg: label && getComputedStyle(label).backgroundColor, h: pill?.getBoundingClientRect().height, href: pill?.getAttribute('href'), photo: o.querySelector('img')?.getAttribute('src') };
      });
      run.check(`F2 ${w}: «PRECIOS DE mayoreo · A partir de 3 piezas · CONOCE MÁS» on the owner's photograph`, offer && offer.title === 'Precios de mayoreo' && offer.body === 'A partir de 3 piezas' && offer.pill === 'Conoce más' && offer.transform === 'uppercase' && /monetta-guia-home-precios-mayoreo/.test(offer.photo || ''), JSON.stringify(offer));
      run.check(`F2 ${w}: the gold pill (#cdb48d) is a 48px target that leads to Mayoreo`, offer && offer.bg === 'rgb(205, 180, 141)' && offer.h >= 48 && /mayoreo/.test(offer.href || ''), JSON.stringify(offer && { bg: offer.bg, h: offer.h, href: offer.href }));
      const accent = await platformFonts(page, '.guia-offer__accent');
      run.check(`F2 ${w}: «mayoreo» measured in Mrs Saint Delafield`, accent.length > 0 && accent.every((f) => /Saint Delafield/.test(f)), JSON.stringify(accent));
      const services = await text(page, '.guide-services__title');
      run.check(`F2 ${w}: the four services of the app`, services.join('|') === 'Envíos seguros|Pagos seguros|Productos 100% originales|Atención personalizada', JSON.stringify(services));
      const register = await text(page, '.guia-register .guia-register__title, .guia-register .guia-register__body, .guia-register .guia-register__action, .guia-register .guia-register__payments');
      run.check(`F2 ${w}: «REGÍSTRATE» invitation with the app's copy`, register.join('|') === 'Regístrate|Consulta tus pedidos y datos de compra|Registrarme ahora|Pagos seguros con Shopify.', JSON.stringify(register));

      // Header.
      const header = await page.evaluate(() => {
        const vis = (el) => !!el && getComputedStyle(el).display !== 'none' && el.getBoundingClientRect().width > 0;
        const menu = document.querySelector('.site-header__menu');
        const logo = document.querySelector('.site-header .wordmark');
        const r = logo?.getBoundingClientRect();
        return { menu: vis(menu), logoCentre: r ? Math.round(r.left + r.width / 2) : null, nav: [...document.querySelectorAll('.site-nav .site-nav__link')].filter(vis).map((a) => a.textContent.trim()), emoji: /[\u{1F300}-\u{1FAFF}]/u.test(document.querySelector('.site-header')?.textContent || '') };
      });
      if (w === 390) run.check('F2 390: phone header is menu · centred wordmark · search', header.menu && Math.abs(header.logoCentre - 195) <= 2, JSON.stringify(header));
      if (w === 1440) {
        run.check('F2 1440: the menu button is visible on desktop (same drawer)', header.menu, JSON.stringify(header));
        run.check('F2 1440: category row reads Bolsas, Carteras, Relojes, Perfumes, Marcas, Mayoreo, without emoji', header.nav.join(',') === 'Bolsas,Carteras,Relojes,Perfumes,Marcas,Mayoreo' && !header.emoji, JSON.stringify(header.nav));
      }

      // Dock (phones only): Inicio · Categorías · Carrito · Cuenta.
      const dock = await page.evaluate(() => {
        const d = document.querySelector('#dock');
        return { shown: !!d && getComputedStyle(d).display !== 'none' && d.getBoundingClientRect().height > 0, items: [...document.querySelectorAll('#dock .dock__item')].map((a) => a.textContent.replace(/\d+|\s+/g, ' ').trim()), cat: document.querySelector('#dock [data-dock="catalog"]')?.getAttribute('href') };
      });
      if (w === 390) run.check('F2 390: bottom bar reads Inicio, Categorías, Carrito, Cuenta and «Categorías» opens /collections', dock.shown && dock.items.join(',') === 'Inicio,Categorías,Carrito,Cuenta' && dock.cat === '/collections', JSON.stringify(dock));
      if (w === 1440) run.check('F2 1440: no bottom bar on desktop', !dock.shown, JSON.stringify(dock));

      // Footer.
      const footer = await page.evaluate(() => ({ heads: [...document.querySelectorAll('.footer-grid--guia h2')].map((h) => h.textContent.trim()), social: document.querySelectorAll('.footer-col--social .guia-social__link').length, rights: /Todos los derechos reservados/.test(document.querySelector('.footer-bottom')?.textContent || ''), boxes: [...document.querySelectorAll('.footer-col--social .guia-social__link')].map((a) => { const r = a.getBoundingClientRect(); return [Math.round(r.top), Math.round(r.width), Math.round(r.height)]; }) }));
      run.check(`F2 ${w}: footer as the guide: Ayuda, Información, Síguenos (3 networks) and the rights line`, footer.heads.join(',') === 'Ayuda,Información,Síguenos' && footer.social === 3 && footer.rights, JSON.stringify(footer));
      run.check(`F2 ${w}: the footer's three networks sit in one row of 48px targets`, footer.boxes.length === 3 && footer.boxes.every((b) => b[0] === footer.boxes[0][0] && b[1] >= 48 && b[2] >= 48), JSON.stringify(footer.boxes));

      // Drawer.
      await page.click('.site-header__menu');
      await page.waitForSelector('#menu-drawer[open]');
      await page.waitForTimeout(450);
      const drawer = await page.evaluate(() => ({
        rows: [...document.querySelectorAll('#menu-drawer .guia-menu__row')].filter((r) => !r.hidden).map((r) => r.textContent.replace(/\(se abre en otra pestaña\)/, '').replace(/\s+/g, ' ').trim()),
        heights: [...document.querySelectorAll('#menu-drawer .guia-menu__row')].filter((r) => !r.hidden).map((r) => Math.round(r.getBoundingClientRect().height)),
        share: !!document.querySelector('#menu-drawer .guia-share'),
        social: document.querySelectorAll('#menu-drawer .guia-social__link').length,
        identity: document.querySelector('#menu-drawer .guia-identity')?.textContent.replace(/\s+/g, ' ').trim(),
      }));
      run.check(`F2 ${w}: menu drawer rows are the guide's (Bolsas, Carteras, Relojes, Perfumes, Todas las marcas, Contacto por WhatsApp)`, drawer.rows.filter((r) => r !== 'Guardados').join(',') === 'Bolsas,Carteras,Relojes,Perfumes,Todas las marcas,Contacto por WhatsApp', JSON.stringify(drawer.rows));
      run.check(`F2 ${w}: drawer has the identity row, «Comparte y gana» banner and the three networks; rows ≥48px`, !!drawer.identity && drawer.share && drawer.social === 3 && drawer.heights.every((x) => x >= 48), JSON.stringify(drawer));
      const rowFont = await platformFonts(page, '#menu-drawer .guia-menu__row span');
      run.check(`F2 ${w}: drawer rows measured in Playfair Display`, rowFont.length > 0 && rowFont.every((f) => /Playfair/.test(f)), JSON.stringify(rowFont));
    } finally {
      await browser.close();
    }
  }
}

/* ======================================================================== F3: colecciones, Categorías y Búsqueda */
const LISTINGS = [
  { path: '/collections/vendors?q=Coach', photo: 'coleccion-coach', title: 'Coach', italic: false, pill: 'Marcas' },
  { path: '/collections/all/tote', photo: 'coleccion-totes', title: 'Totes', italic: true, pill: 'Bolsas' },
  { path: '/collections/types?q=Cartera', photo: 'coleccion-carteras', title: 'Carteras', italic: true, pill: 'Carteras' },
  { path: '/collections/all/reloj', photo: 'coleccion-accesorios', title: 'Relojes', italic: true, pill: 'Relojes' },
];

async function f3() {
  for (const [w, h] of WIDTHS) {
    const { browser, page } = await launch({ width: w, height: h, injectCss });
    try {
      await open(page, LISTINGS[0].path);
      run.check(`F3 ${w}: no horizontal overflow on a brand collection`, (await overflow(page)) <= 0, `${await overflow(page)}px`);
      await open(page, '/collections');
      run.check(`F3 ${w}: no horizontal overflow on Categorías`, (await overflow(page)) <= 0, `${await overflow(page)}px`);
      if (w !== 390 && w !== 1440) continue;

      for (const l of LISTINGS) {
        await open(page, l.path);
        const info = await page.evaluate(() => {
          const hero = document.querySelector('.guia-collection-hero .guide-hero');
          const title = hero?.querySelector('.guide-hero__title');
          const cs = title && getComputedStyle(title);
          const header = document.querySelector('.site-header');
          return {
            photo: hero?.querySelector('img')?.getAttribute('src') || '',
            h1: [...document.querySelectorAll('h1')].map((x) => x.textContent.trim()),
            tag: title?.tagName, transform: cs?.textTransform, style: cs?.fontStyle,
            pills: [...document.querySelectorAll('.guia-pills .guia-pill:not(.guia-pill--icon)')].map((a) => a.textContent.trim()),
            current: document.querySelector('.guia-pills [aria-current="page"]')?.textContent.trim() || null,
            filterBtn: (() => { const b = document.querySelector('.guia-pills .guia-pill--icon'); if (!b) return null; const r = b.getBoundingClientRect(); return [Math.round(r.width), Math.round(r.height)]; })(),
            count: document.querySelector('.guia-listing-bar__count')?.textContent.trim() || '',
            sortLabel: document.querySelector('.guia-sort__label')?.textContent.trim() || '',
            header: !!header && getComputedStyle(header).display !== 'none' && header.getBoundingClientRect().height > 0,
            siteNav: !!document.querySelector('.site-nav'),
            searchFocused: document.activeElement?.id === 'header-search-input',
            predictiveOpen: !!document.querySelector('#site-header [data-monetta-predictive-panel]:not([hidden])'),
          };
        });
        const tag = `F3 ${w} ${l.title}`;
        run.check(`${tag}: the guide's banner photograph and the title as the page's only h1`, info.photo.includes(l.photo) && info.tag === 'H1' && info.h1.length === 1 && info.h1[0] === l.title, JSON.stringify({ photo: info.photo.split('/').pop()?.split('?')[0], h1: info.h1 }));
        run.check(`${tag}: title in capitals, ${l.italic ? 'italic (silhouette or category)' : 'upright (brand)'}`, info.transform === 'uppercase' && (info.style === 'italic') === l.italic, JSON.stringify({ transform: info.transform, style: info.style }));
        run.check(`${tag}: pills Bolsas, Carteras, Accesorios, Relojes, Perfumes, Marcas, Mayoreo; current ${l.pill || 'none'}; 48px filters button`, info.pills.join(',') === 'Bolsas,Carteras,Accesorios,Relojes,Perfumes,Marcas,Mayoreo' && info.current === l.pill && info.filterBtn && info.filterBtn[0] >= 48 && info.filterBtn[1] >= 48, JSON.stringify({ pills: info.pills, current: info.current, filterBtn: info.filterBtn }));
        run.check(`${tag}: no header category row (the pills carry it) and the search field stays closed on arrival`, !info.siteNav && !info.searchFocused && !info.predictiveOpen, JSON.stringify({ siteNav: info.siteNav, searchFocused: info.searchFocused, predictiveOpen: info.predictiveOpen }));
        run.check(`${tag}: «N productos» and «Ordenar por»`, /^\d+ productos?$/.test(info.count) && info.sortLabel === 'Ordenar por', JSON.stringify({ count: info.count, sort: info.sortLabel }));
        if (w === 390) run.check(`${tag}: phones keep the guide's header (no page bar) on the collection`, info.header, JSON.stringify({ header: info.header }));
      }
      const titleFont = await platformFonts(page, '.guia-collection-hero .guide-hero__title');
      run.check(`F3 ${w}: collection banner title measured in Cormorant Garamond`, titleFont.length > 0 && titleFont.every((f) => /Cormorant/.test(f)), JSON.stringify(titleFont));

      // Categorías.
      await open(page, '/collections');
      const cats = await page.evaluate(() => ({
        h1: [...document.querySelectorAll('h1')].map((x) => x.textContent.trim()),
        lede: document.querySelector('.guia-categories__lede')?.textContent.trim(),
        h2: [...document.querySelectorAll('.guia-categories h2')].map((x) => x.textContent.trim()),
        tiles: [...document.querySelectorAll('.guia-category')].map((a) => ({ label: a.textContent.trim(), icon: a.querySelector('img')?.getAttribute('src') || '', w: a.getBoundingClientRect().width })),
        brands: document.querySelectorAll('.guia-categories .guia-brand').length,
      }));
      run.check(`F3 ${w}: Categorías with its line, «Colecciones» and «Marcas»`, cats.h1.join() === 'Categorías' && cats.lede === 'Descubre todas nuestras colecciones de tus marcas favoritas.' && cats.h2.join(',') === 'Colecciones,Marcas', JSON.stringify(cats.h1.concat(cats.h2)));
      run.check(`F3 ${w}: the seven collections with the guide's icons`, cats.tiles.map((t) => t.label).join(',') === 'Crossbody,Tote,Shoulder,Handbags,Carteras,Perfumes,Accesorios' && cats.tiles.every((t) => /monetta-guia-icon-categoria-/.test(t.icon)), JSON.stringify(cats.tiles.map((t) => t.label)));
      if (w === 390) run.check('F3 390: collection tiles three across', cats.tiles.length >= 3 && Math.abs(cats.tiles[0].w - cats.tiles[2].w) < 1 && cats.tiles[0].w < 130, JSON.stringify(cats.tiles.map((t) => Math.round(t.w))));
      run.check(`F3 ${w}: brand tiles for the brands the store sells`, cats.brands >= 4, `${cats.brands}`);

      // Búsqueda: suggestions, then recent searches kept in this browser and removable.
      await open(page, '/search?q=bolso+coach&type=product');
      const search = await page.evaluate(() => ({
        suggest: [...document.querySelectorAll('#guia-suggest-heading ~ ul .guia-search__row')].map((a) => a.textContent.trim()),
        recent: [...document.querySelectorAll('[data-guia-recent-list] .guia-search__row')].map((a) => a.textContent.trim()),
        recentShown: !document.querySelector('[data-guia-recent-block]')?.hidden,
      }));
      run.check(`F3 ${w}: search shows «Sugerencias» Bolsas, Carteras, Relojes, Perfumes`, search.suggest.join(',') === 'Bolsas,Carteras,Relojes,Perfumes', JSON.stringify(search.suggest));
      run.check(`F3 ${w}: «Búsquedas recientes» lists this search`, search.recentShown && search.recent[0] === 'bolso coach', JSON.stringify(search));
      await page.click('[data-guia-recent-list] .guia-search__remove');
      const after = await page.evaluate(() => ({ items: document.querySelectorAll('[data-guia-recent-list] li').length, hidden: document.querySelector('[data-guia-recent-block]')?.hidden, stored: localStorage.getItem('monetta:recent-searches') }));
      run.check(`F3 ${w}: removing it empties the list, hides the block and the browser forgets it`, after.items === 0 && after.hidden === true && after.stored === '[]', JSON.stringify(after));
    } finally {
      await browser.close();
    }
  }
}

/* ======================================================================== F4: vista rápida y producto */
async function f4() {
  for (const [w, h] of [[390, 844], [1440, 900]]) {
    const { browser, page } = await launch({ width: w, height: h, injectCss });
    try {
      await open(page, '/products/bolso-coach-shoulder-negro-rectangular');
      const product = await page.evaluate(() => ({
        add: [...document.querySelectorAll('[data-add] [data-label]')].map((x) => x.textContent.trim()),
        trust: [...document.querySelectorAll('.guia-trust li')].map((li) => li.textContent.replace(/\s+/g, ' ').trim()),
      }));
      run.check(`F4 ${w}: product buttons read «Agregar a bolsa» (the app's label)`, product.add.length > 0 && product.add.every((t) => t === 'Agregar a bolsa'), JSON.stringify(product.add));
      run.check(`F4 ${w}: trust row Entrega estimada · Productos originales · Pago seguro`, product.trust.join('|') === 'Entrega estimada 3 a 5 días|Productos originales Garantía de autenticidad|Pago seguro Compra con confianza', JSON.stringify(product.trust));
      if (w === 390) {
        // The phone purchase dock's button gets the focus back when the bag sheet closes with Escape (defect found in F0).
        await page.evaluate(async () => { await fetch('/cart/clear.js', { method: 'POST' }); });
        await page.locator('[data-add]:visible').last().click();
        await page.waitForSelector('#cart-sheet.is-open', { timeout: 15000 });
        await page.waitForTimeout(400);
        await page.keyboard.press('Escape');
        await page.waitForFunction(() => !document.querySelector('#cart-sheet')?.open);
        await page.waitForTimeout(400);
        const focus = await page.evaluate(() => ({ add: !!document.activeElement?.matches('[data-add]'), visible: document.activeElement?.offsetParent !== null }));
        run.check('F4 390: after adding from the purchase dock, Esc closes the bag and the focus returns to that button', focus.add && focus.visible, JSON.stringify(focus));
      }

      // Quick view from a card's «+» on a piece with several variants.
      await open(page, '/collections/vendors?q=Coach');
      const trigger = page.locator('[data-quick-view]').first();
      run.check(`F4 ${w}: cards of pieces with several variants show the «+» that opens the quick view`, (await trigger.count()) === 1, `${await page.locator('[data-quick-view]').count()} triggers`);
      const cardName = await trigger.evaluate((b) => b.closest('.card')?.querySelector('.card__name')?.textContent.trim());
      await trigger.click();
      await page.waitForSelector('#quick-view[open] [data-quick-view-root]', { timeout: 15000 });
      await page.waitForTimeout(450);
      const view = await page.evaluate(() => {
        const d = document.getElementById('quick-view');
        const panel = d.querySelector('.overlay__panel').getBoundingClientRect();
        return {
          name: d.querySelector('#quick-view-title')?.textContent.trim(),
          addDisabled: d.querySelector('[data-quick-view-add]')?.disabled,
          addLabel: d.querySelector('[data-quick-view-add]')?.textContent.trim(),
          more: d.querySelector('a.btn')?.textContent.trim(),
          photo: !!d.querySelector('[data-quick-view-photo]')?.naturalWidth,
          groups: d.querySelectorAll('[data-quick-view-group]').length,
          bottomGap: Math.round(window.innerHeight - panel.bottom),
          centreGap: Math.round(Math.abs(panel.left + panel.width / 2 - window.innerWidth / 2)),
        };
      });
      run.check(`F4 ${w}: quick view shows the piece (${cardName}) with its photo, «Agregar a bolsa» and «Ver producto»`, view.name === cardName && view.photo && view.addLabel === 'Agregar a bolsa' && view.more === 'Ver producto' && view.groups > 0, JSON.stringify(view));
      run.check(`F4 ${w}: nothing can be added until a variant is chosen (the app's requireChoice)`, view.addDisabled === true, JSON.stringify({ addDisabled: view.addDisabled }));
      run.check(`F4 ${w}: ${w < 768 ? 'a bottom sheet on phones' : 'a centred dialog on desktop'}`, w < 768 ? view.bottomGap <= 1 : view.centreGap <= 2 && view.bottomGap > 16, JSON.stringify({ bottomGap: view.bottomGap, centreGap: view.centreGap }));
      await page.keyboard.press('Escape');
      await page.waitForFunction(() => !document.getElementById('quick-view')?.open);
      await page.waitForTimeout(400);
      run.check(`F4 ${w}: Esc closes the quick view and returns the focus to its «+»`, await page.evaluate(() => !!document.activeElement?.matches('[data-quick-view]')));
      // Choose the first available combination and add it.
      await trigger.click();
      await page.waitForSelector('#quick-view[open] [data-quick-view-root]', { timeout: 15000 });
      const before = await page.evaluate(async () => (await (await fetch('/cart.js')).json()).item_count);
      const picked = await page.evaluate(() => {
        const root = document.querySelector('#quick-view [data-quick-view-root]');
        const variants = JSON.parse(root.querySelector('[data-quick-view-variants]').textContent);
        const v = variants.find((x) => x.available);
        if (!v) return null;
        root.querySelectorAll('[data-quick-view-group]').forEach((g, i) => {
          const input = [...g.querySelectorAll('input')].find((x) => x.value === v.options[i]);
          input.checked = true;
          input.dispatchEvent(new Event('change', { bubbles: true }));
        });
        return { id: v.id, enabled: !root.querySelector('[data-quick-view-add]').disabled };
      });
      run.check(`F4 ${w}: choosing an available variant enables «Agregar a bolsa»`, picked?.enabled === true, JSON.stringify(picked));
      if (picked?.enabled) {
        await page.click('#quick-view [data-quick-view-add]');
        await page.waitForSelector('#cart-sheet.is-open', { timeout: 15000 });
        const after = await page.evaluate(async () => { const c = await (await fetch('/cart.js')).json(); return { count: c.item_count, ids: c.items.map((i) => i.variant_id) }; });
        run.check(`F4 ${w}: the chosen variant reaches Shopify's cart and the bag opens`, after.count === before + 1 && after.ids.includes(picked.id), JSON.stringify({ before, after }));
      }
    } finally {
      await browser.close();
    }
  }
}

/* ======================================================================== F8: header search and labels (28 Oct request) */
// Liquid-glass search field (translucent, blurred, specular top edge, shadow) whose rim keeps ≥ 3:1; Cuenta, Carrito and the
// search text in the category row's serif. The header field shows from 768 px.
async function f8() {
  for (const [w, h] of [[768, 1024], [1024, 768], [1440, 900]]) {
    const { browser, page } = await launch({ width: w, height: h, injectCss });
    try {
      await open(page, '/');
      const v = await page.evaluate(() => {
        const cs = (sel, pseudo) => { const el = document.querySelector(sel); return el ? getComputedStyle(el, pseudo) : null; };
        const font = (s) => s && { family: s.fontFamily, size: s.fontSize, weight: s.fontWeight };
        const rgb = (c) => (c.match(/[\d.]+/g) || []).slice(0, 3).map(Number);
        const lum = (c) => { const [r, g, b] = rgb(c).map((x) => { x /= 255; return x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4; }); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
        const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((m, n) => n - m); return (x + 0.05) / (y + 0.05); };
        const field = cs('.header-search .search-field');
        const header = cs('.site-header');
        return {
          nav: font(cs('.site-nav__link')),
          // Below 1024 px the labels are hidden (icons only); their type is checked all the same.
          labels: [...document.querySelectorAll('.header-utility__label')].map((el) => ({ text: el.textContent.trim(), visible: el.getClientRects().length > 0, ...font(getComputedStyle(el)) })),
          input: font(cs('#header-search-input')), placeholder: font(cs('#header-search-input', '::placeholder')),
          glass: field && { backdrop: field.backdropFilter || field.webkitBackdropFilter, image: field.backgroundImage, shadow: field.boxShadow },
          rim: field && header ? Math.round(ratio(field.borderTopColor, header.backgroundColor) * 100) / 100 : 0,
        };
      });
      const same = (a) => a && v.nav && a.family === v.nav.family && a.weight === v.nav.weight;
      run.check(`F8 ${w}: «Cuenta» and «Carrito» use the category row's font (family, size and weight)`, v.labels.length === 2 && v.labels.map((l) => l.text).join('|') === 'Cuenta|Carrito' && v.labels.every((l) => same(l) && l.size === v.nav.size), JSON.stringify({ nav: v.nav, labels: v.labels }));
      run.check(`F8 ${w}: the search text and its placeholder use the category row's font (16px, no zoom on iOS)`, same(v.input) && v.placeholder?.family === v.nav?.family && v.input.size === '16px', JSON.stringify({ nav: v.nav, input: v.input, placeholder: v.placeholder }));
      const label = w >= 1024 ? await platformFonts(page, '.header-utility--account .header-utility__label') : ['(hidden below 1024 px)'];
      const placeholder = await inputPlatformFonts(page, '#header-search-input', 'placeholder');
      await page.fill('#header-search-input', 'bolso');
      const typed = await inputPlatformFonts(page, '#header-search-input', 'typed');
      await page.fill('#header-search-input', '');
      const playfair = (fonts) => fonts.length > 0 && fonts.every((f) => /Playfair/.test(f));
      run.check(`F8 ${w}: ${w >= 1024 ? '«Cuenta», ' : ''}the placeholder and the typed search measured in Playfair Display`, (w < 1024 || playfair(label)) && playfair(placeholder) && playfair(typed), JSON.stringify({ label, placeholder, typed }));
      run.check(`F8 ${w}: the search field is liquid glass (backdrop blur, translucent gradient fill, specular inset edge and shadow)`, /blur\(/.test(v.glass?.backdrop || '') && /gradient/.test(v.glass?.image || '') && /inset/.test(v.glass?.shadow || ''), JSON.stringify(v.glass));
      run.check(`F8 ${w}: the search field's rim keeps ≥ 3:1 on the header (WCAG 1.4.11)`, v.rim >= 3, String(v.rim));
      await page.focus('#header-search-input');
      await page.waitForTimeout(400);
      const focused = await page.evaluate(() => { const s = getComputedStyle(document.querySelector('.header-search .search-field')); return { border: s.borderTopColor, shadow: s.boxShadow }; });
      run.check(`F8 ${w}: focused, the field shows the ink ring`, focused.border === 'rgb(33, 27, 22)' && /rgb\(33, 27, 22\) 0px 0px 0px 1px/.test(focused.shadow), JSON.stringify(focused));
    } finally {
      await browser.close();
    }
  }
}

/* ======================================================================== F7: Bienvenida (slide 01) on the password page */
// The page every visitor of a closed store sees. Checked through the proxy's /password; the password itself is never typed.
async function f7() {
  for (const [w, h] of WIDTHS) {
    const { browser, page } = await launch({ width: w, height: h, injectCss });
    try {
      await open(page, '/password');
      run.check(`F7 ${w}: no horizontal overflow on the password page`, (await overflow(page)) <= 0, `${await overflow(page)}px`);
      if (w !== 390 && w !== 1440) continue;
      const v = await page.evaluate(() => {
        const t = (sel) => document.querySelector(sel)?.textContent.replace(/\s+/g, ' ').trim();
        const photo = document.querySelector('.guia-welcome__photo');
        const box = (el) => (el ? (({ left, top, width, height }) => ({ left, top, width, height }))(el.getBoundingClientRect()) : null);
        return {
          lang: document.documentElement.lang, brand: document.querySelector('.guia-welcome__brand img')?.alt || null,
          tagline: t('.guia-welcome__tagline'), eyebrow: t('.guia-welcome__eyebrow'), start: t('.guia-welcome__start'),
          startBox: box(document.querySelector('.guia-welcome__start')), photo: photo?.currentSrc?.split('/').pop() || '', loaded: photo?.naturalWidth || 0,
          photoBox: box(photo), copyBox: box(document.querySelector('.guia-welcome__copy')),
          footer: t('.password-footer'), english: /Enter using password|Opening soon|powered by/i.test(document.body.innerText),
        };
      });
      run.check(`F7 ${w}: «Un paraíso de marcas por descubrir · BOUTIQUE ONLINE DE PRODUCTOS ORIGINALES · COMENZAR», as the app`, Boolean(v.brand) && v.tagline === 'Un paraíso de marcas por descubrir' && v.eyebrow === 'Boutique online de productos originales' && v.start === 'Comenzar', JSON.stringify({ brand: v.brand, tagline: v.tagline, eyebrow: v.eyebrow, start: v.start }));
      run.check(`F7 ${w}: the owner's welcome photograph loads`, /monetta-guia-bienvenida-fondo/.test(v.photo) && v.loaded > 0, JSON.stringify({ photo: v.photo, loaded: v.loaded }));
      const layoutOk = w < 1024
        ? v.photoBox && v.photoBox.left <= 0 && Math.round(v.photoBox.width) >= w - 1 && v.copyBox && v.copyBox.top < h / 2
        : v.photoBox && Math.round(v.photoBox.left) >= Math.round(w / 2) - 1 && v.copyBox && v.copyBox.left + v.copyBox.width <= w / 2 + 1;
      run.check(`F7 ${w}: ${w < 1024 ? 'photo behind the whole screen, copy in the upper half' : 'photo on the right half, copy on the left'}`, Boolean(layoutOk), JSON.stringify({ photo: v.photoBox, copy: v.copyBox }));
      run.check(`F7 ${w}: «COMENZAR» is a 48px target inside the first screen`, v.startBox && v.startBox.height >= 48 && v.startBox.top + v.startBox.height <= h, JSON.stringify(v.startBox));
      run.check(`F7 ${w}: the page is Spanish (es-MX, footer «Entrar con contraseña», no English left)`, v.lang === 'es-MX' && /Entrar con contraseña/.test(v.footer || '') && !v.english, JSON.stringify({ lang: v.lang, footer: v.footer, english: v.english }));
      const tagline = await platformFonts(page, '.guia-welcome__tagline');
      run.check(`F7 ${w}: tagline measured in Playfair Display`, tagline.length > 0 && tagline.every((f) => /Playfair/.test(f)), JSON.stringify(tagline));
      // COMENZAR opens Shopify's password dialog, in Spanish; Esc closes it and returns the focus. Nothing is typed or sent.
      if (await page.locator('.guia-welcome__start').count()) await page.locator('.guia-welcome__start').click();
      await page.waitForSelector('#password-form dialog[open]', { timeout: 5000 }).catch(() => {});
      const d = await page.evaluate(() => {
        const dialog = document.querySelector('#password-form dialog[open]');
        return dialog ? { title: dialog.querySelector('h2')?.textContent.trim(), label: dialog.querySelector('label[for="Password"]')?.textContent.trim(), type: dialog.querySelector('#Password')?.type, submit: dialog.querySelector('button[type="submit"]')?.textContent.trim() } : null;
      });
      run.check(`F7 ${w}: «COMENZAR» opens the password dialog in Spanish`, d?.title === 'Entra con la contraseña de la tienda' && d.label === 'Contraseña' && d.type === 'password' && d.submit === 'Entrar', JSON.stringify(d));
      await page.keyboard.press('Escape');
      await page.waitForTimeout(400);
      const after = await page.evaluate(() => ({ open: Boolean(document.querySelector('#password-form dialog[open]')), focus: document.activeElement?.className || '' }));
      run.check(`F7 ${w}: Esc closes the dialog and the focus returns to «COMENZAR»`, !after.open && /guia-welcome__start/.test(after.focus), JSON.stringify(after));
    } finally {
      await browser.close();
    }
  }
}

/* ======================================================================== F5: Mayoreo, Contacto, Comparte y gana y Cuenta */
async function f5() {
  for (const [w, h] of WIDTHS) {
    const { browser, page } = await launch({ width: w, height: h, injectCss });
    try {
      for (const view of ['guia-mayoreo', 'guia-contacto', 'guia-rewards']) {
        await open(page, `/pages/contact?view=${view}`);
        run.check(`F5 ${w}: no horizontal overflow on ${view}`, (await overflow(page)) <= 0, `${await overflow(page)}px`);
      }
      if (w !== 390 && w !== 1440) continue;

      // Mayoreo (slides 21–22), with the app's copy.
      await open(page, '/pages/contact?view=guia-mayoreo');
      const m = await page.evaluate(() => {
        const t = (sel) => [...document.querySelectorAll(sel)].map((x) => x.textContent.replace(/\s+/g, ' ').trim());
        const hero = document.querySelector('.guia-page--mayoreo > .guide-hero');
        return {
          h1: t('h1'), photo: hero?.querySelector('img')?.getAttribute('src') || '', heroBody: hero?.querySelector('.guide-hero__body')?.textContent.replace(/\s+/g, ' ').trim(),
          steps: t('.guia-step__title'), stepBodies: t('.guia-step__body'),
          banners: [...document.querySelectorAll('.guia-page__banners .guide-hero')].map((b) => ({ title: b.querySelector('h2')?.textContent.trim(), pill: b.querySelector('.guide-pill__label')?.textContent.trim(), href: b.querySelector('.guide-pill')?.getAttribute('href') })),
          service: t('.guide-services__item:first-child p'),
          doubts: document.querySelector('.guia-doubts')?.getAttribute('href') || '', doubtsText: t('.guia-doubts__copy').join(),
          doubtsPhoto: document.querySelector('.guia-doubts__photo')?.currentSrc || '', doubtsLoaded: document.querySelector('.guia-doubts__photo')?.naturalWidth || 0,
          note: t('.guia-page__note').join(), rail: t('.guia-page--mayoreo h2').includes('Productos que te pueden interesar'),
          cards: document.querySelectorAll('.guia-page--mayoreo .rail .card').length,
        };
      });
      run.check(`F5 ${w}: Mayoreo hero (owner photo) «MAYOREO · Obtén precios especiales … marcas favoritas»`, m.h1.join() === 'Mayoreo' && m.photo.includes('mayoreo-hero') && m.heroBody === 'Obtén precios especiales en productos originales importados de tus marcas favoritas', JSON.stringify({ h1: m.h1, body: m.heroBody }));
      run.check(`F5 ${w}: «¿Cómo comprar?» in the app's three steps`, m.steps.join('|') === 'Elige tus productos|Agrega mínimo 3 piezas|Liquida o aparta' && m.stepBodies[2] === 'Aparta por 20 días con $800 pesos por pedido.', JSON.stringify({ steps: m.steps, bodies: m.stepBodies }));
      run.check(`F5 ${w}: banners «BOLSOS Y CARTERAS» and «PERFUMES» with «VER CATÁLOGO»`, m.banners.map((b) => b.title).join('|') === 'Bolsos y carteras|Perfumes' && m.banners.every((b) => b.pill === 'Ver catálogo' && /\/collections\//.test(b.href || '')), JSON.stringify(m.banners));
      run.check(`F5 ${w}: wholesale services open with «Envío gratis · En compras mayores a $1,999 MXN»`, m.service.join('|') === 'Envío gratis|En compras mayores a $1,999 MXN', JSON.stringify(m.service));
      run.check(`F5 ${w}: «¿Tienes dudas?» sits on the wholesale bags photograph, as the app, and the photograph loads`, /mayoreo-bolsos-carteras-\d+\.webp/.test(m.doubtsPhoto) && m.doubtsLoaded > 0, JSON.stringify({ photo: m.doubtsPhoto.split('/').pop(), loaded: m.doubtsLoaded }));
      run.check(`F5 ${w}: «¿Tienes dudas? Escríbenos por WhatsApp» opens WhatsApp with the app's message; the app's price note; a product rail`, /^https:\/\/wa\.me\/528261066868\?text=Hola/.test(m.doubts) && /¿Tienes dudas\?.*Escríbenos por WhatsApp/.test(m.doubtsText) && m.note === 'Precios del catálogo de menudeo; cotización de mayoreo pendiente.' && m.rail && m.cards > 0, JSON.stringify({ doubts: m.doubts.slice(0, 60), note: m.note, cards: m.cards }));

      // Contacto (slide 27).
      await open(page, '/pages/contact?view=guia-contacto');
      const c = await page.evaluate(() => ({
        h1: [...document.querySelectorAll('h1')].map((x) => x.textContent.replace(/\s+/g, ' ').trim()),
        rows: [...document.querySelectorAll('.guia-contact__row')].map((a) => ({ title: a.querySelector('.guia-contact__title')?.textContent.trim(), sub: a.querySelector('.guia-contact__sub')?.textContent.trim(), href: a.getAttribute('href') })),
        social: document.querySelectorAll('.guia-contact .guia-social__link').length,
        heights: [...document.querySelectorAll('.guia-contact__row')].map((a) => a.getBoundingClientRect().height),
      }));
      run.check(`F5 ${w}: Contacto hero «Tu boutique y proveedor de confianza.»`, c.h1.join() === 'Tu boutique y proveedor de confianza.', JSON.stringify(c.h1));
      run.check(`F5 ${w}: Contáctanos rows as the app: WhatsApp, Grupo 1, Grupo 2, Grupo de Facebook, Mayoreo por WhatsApp`, c.rows.map((r) => r.title).join('|') === 'WhatsApp|Grupo 1|Grupo 2|Grupo de Facebook|Mayoreo por WhatsApp' && c.rows[0].sub === '+52 826 106 6868' && /chat\.whatsapp\.com/.test(c.rows[1].href) && /facebook\.com\/share\/g\//.test(c.rows[3].href), JSON.stringify(c.rows.map((r) => [r.title, r.sub])));
      run.check(`F5 ${w}: contact rows are 48px targets; «Síguenos en redes» has the three networks`, c.heights.every((x) => x >= 48) && c.social === 3, JSON.stringify({ heights: c.heights.map(Math.round), social: c.social }));
      // The hero title's own text, line by line (the visually hidden «confianza.» is a separate node and stays out).
      const titleLines = await page.evaluate(() => {
        const node = document.querySelector('.guia-page--contacto .guide-hero__title')?.firstChild;
        if (!node || node.nodeType !== Node.TEXT_NODE) return [];
        const lines = new Map();
        const re = /\S+/g;
        let m;
        while ((m = re.exec(node.textContent))) {
          const range = document.createRange();
          range.setStart(node, m.index);
          range.setEnd(node, m.index + m[0].length);
          const top = Math.round(range.getClientRects()[0].top);
          lines.set(top, [...(lines.get(top) || []), m[0]]);
        }
        return [...lines.values()].map((words) => words.join(' '));
      });
      run.check(`F5 ${w}: the Contacto title leaves no word alone on a line`, titleLines.length > 0 && titleLines.every((line) => line.split(' ').length >= 2), JSON.stringify(titleLines));
      // The store's contact form (plan §5, slide 27; web only). Checked, never sent: a submission would email the store.
      const form = await page.evaluate(() => {
        const f = document.querySelector('.guia-page--contacto form[action^="/contact"]');
        if (!f) return null;
        const field = (name) => f.querySelector(`[name="contact[${name}]"]`);
        return {
          heading: document.querySelector('.guia-contact__form h2')?.textContent.trim(),
          labels: [...f.querySelectorAll('.field__label')].map((x) => x.textContent.trim()),
          required: ['name', 'email', 'phone', 'body'].map((n) => Boolean(field(n)?.required)),
          types: [field('email')?.type, field('phone')?.type],
          heights: [...f.querySelectorAll('.input, button[type="submit"]')].map((x) => Math.round(x.getBoundingClientRect().height)),
          button: f.querySelector('button[type="submit"]')?.textContent.trim(),
          formType: f.querySelector('input[name="form_type"]')?.value,
        };
      });
      run.check(`F5 ${w}: «Escríbenos»: the store's contact form in Spanish (email and message required), 48px targets`, form?.heading === 'Escríbenos' && form.labels.join('|') === 'Nombre|Correo electrónico|Teléfono (opcional)|Mensaje' && form.required.join() === 'false,true,false,true' && form.types.join() === 'email,tel' && form.heights.every((x) => x >= 48) && form.button === 'Enviar mensaje' && form.formType === 'contact', JSON.stringify(form));
      const accent = await platformFonts(page, '.guia-page--contacto .guide-hero__accent');
      run.check(`F5 ${w}: «confianza.» measured in Mrs Saint Delafield`, accent.length > 0 && accent.every((f) => /Saint Delafield/.test(f)), JSON.stringify(accent));

      // Monetta Rewards (slide 25) with the app's copy and no invented balance; Comparte y gana (26): the catalog links
      // are the store's real listings and can be copied.
      await page.context().grantPermissions(['clipboard-read', 'clipboard-write'], { origin: baseUrl });
      await open(page, '/pages/contact?view=guia-rewards');
      const r = await page.evaluate(() => {
        const t = (sel) => [...document.querySelectorAll(sel)].map((x) => x.textContent.replace(/\s+/g, ' ').trim());
        return {
          h1: t('h1'), h2: t('.guia-page--rewards h2'), lede: t('.guia-rewards__lede'), notice: t('.guia-rewards__notice').join(),
          rows: t('.guia-rewards__title'), subs: t('.guia-rewards__sub'), pending: t('.guia-rewards__pending').join(),
          cta: document.querySelector('.guia-rewards__cta')?.getAttribute('href'), target: !!document.getElementById('comparte-y-gana'),
          links: [...document.querySelectorAll('.guia-copy input')].map((i) => i.value), titles: t('.guia-copy__title'),
        };
      });
      run.check(`F5 ${w}: «Monetta Rewards · Tus compras, acumulas puntos.» says it is not available yet, as the app without a contract`, r.h1.join() === 'Monetta Rewards' && r.lede[0] === 'Tus compras, acumulas puntos.' && r.notice === 'Monetta Rewards aún no está disponible No hay un saldo que mostrar. No se inventa un puntaje ni un nivel.', JSON.stringify({ h1: r.h1, lede: r.lede[0], notice: r.notice }));
      run.check(`F5 ${w}: «Cómo ganar puntos» and «Canjear puntos» rows as the app`, r.h2.slice(0, 2).join('|') === 'Cómo ganar puntos|Canjear puntos' && r.rows.join('|') === 'Por cada compra|Compartir catálogo en redes|Comprar a mayoreo|Descuentos|Envío gratis|Acceso anticipado' && r.subs.join('|') === 'Usa tus puntos en tus compras|Canjea puntos por envíos|Sé la primera en nuevas colecciones', JSON.stringify({ h2: r.h2, rows: r.rows, subs: r.subs }));
      run.check(`F5 ${w}: «Comparte y gana» button leads to its section`, r.cta === '#comparte-y-gana' && r.target && r.h2.includes('Comparte y gana'), JSON.stringify({ cta: r.cta, target: r.target }));
      run.check(`F5 ${w}: «Comparte y gana» with the bags and perfumes catalog links and «Puntos por compartir: Pendiente de contrato.»`, r.titles.join('|') === 'Copiar enlace de catálogo de bolsos|Copiar enlace de catálogo de perfumes' && r.links.length === 2 && r.links.every((l) => /^https?:\/\/[^/]+\/collections\//.test(l)) && r.pending === 'Puntos por compartir: Pendiente de contrato.', JSON.stringify({ titles: r.titles, links: r.links, pending: r.pending }));
      await page.click('.guia-copy [data-guia-copy-button]');
      await page.waitForTimeout(400);
      const copied = await page.evaluate(async () => { try { return await navigator.clipboard.readText(); } catch { return null; } });
      const said = await page.evaluate(() => document.getElementById('status-live')?.textContent.trim());
      run.check(`F5 ${w}: «Copiar» puts the bags catalog link on the clipboard and says «Enlace copiado», as the app`, copied === r.links[0] && said === 'Enlace copiado', JSON.stringify({ copied, want: r.links[0], said }));
      // «Compartir enlace» (the app's Share.share): hidden where the browser has no share sheet; otherwise it shares the link.
      for (const shareSheet of [false, true]) {
        const other = await page.context().newPage();
        await other.addInitScript((has) => {
          if (has) Navigator.prototype.share = async (data) => { window.__shared = data; };
          else delete Navigator.prototype.share;
        }, shareSheet);
        await open(other, '/pages/contact?view=guia-rewards');
        const buttons = await other.evaluate(() => [...document.querySelectorAll('[data-guia-share-button]')].map((b) => ({ visible: b.getClientRects().length > 0, label: b.getAttribute('aria-label') })));
        if (!shareSheet) {
          run.check(`F5 ${w}: without a share sheet «Compartir enlace» stays hidden`, buttons.length === 2 && buttons.every((b) => !b.visible), JSON.stringify(buttons));
        } else {
          if (buttons[0]?.visible) await other.locator('[data-guia-share-button]').first().click();
          const shared = await other.evaluate(() => window.__shared);
          run.check(`F5 ${w}: with a share sheet «Compartir enlace de catálogo de bolsos» shares the bags link`, buttons.length === 2 && buttons.every((b) => b.visible) && buttons[0]?.label === 'Compartir enlace de catálogo de bolsos' && shared?.url === r.links[0], JSON.stringify({ buttons, shared }));
        }
        await other.close();
      }

      // Navigation reaches these pages and the account.
      await open(page, '/');
      const nav = await page.evaluate(() => ({ share: document.querySelector('#menu-drawer .guia-share')?.getAttribute('href'), mayoreo: [...document.querySelectorAll('.site-nav__link')].find((a) => a.textContent.trim() === 'Mayoreo')?.getAttribute('href'), offer: document.querySelector('.guia-offer .guide-pill')?.getAttribute('href'), account: document.querySelector('.header-utility--account')?.getAttribute('href'), dockAccount: document.querySelector('#dock [data-dock="account"]')?.getAttribute('href') }));
      run.check(`F5 ${w}: the drawer's «Comparte y gana · VER CATÁLOGO» leads to Comparte y gana, as the app's account banner`, /view=guia-rewards#comparte-y-gana|\/pages\/rewards#comparte-y-gana/.test(nav.share || ''), JSON.stringify({ share: nav.share }));
      run.check(`F5 ${w}: «Mayoreo» (header) and «CONOCE MÁS» lead to the Mayoreo page; «Cuenta» to Shopify's account`, /view=guia-mayoreo|\/pages\/mayoreo/.test(nav.offer || '') && (w < 768 || /view=guia-mayoreo|\/pages\/mayoreo/.test(nav.mayoreo || '')) && /\/account/.test(w < 768 ? nav.dockAccount : nav.account), JSON.stringify(nav));
    } finally {
      await browser.close();
    }
  }
}

try {
  if (phases.has('f1')) await f1();
  if (phases.has('f2')) await f2();
  if (phases.has('f3')) await f3();
  if (phases.has('f4')) await f4();
  if (phases.has('f5')) await f5();
  if (phases.has('f7')) await f7();
  if (phases.has('f8')) await f8();
  if (phases.has('f9')) await predictiveChecks({ run, open, overflow, platformFonts, inputPlatformFonts, baseUrl });
  run.finish({ complete: true });
} catch (error) {
  run.finish({ complete: false, error });
  process.exitCode = 1;
}
process.exitCode = process.exitCode || (run.checks.some((c) => !c.pass) ? 1 : 0);

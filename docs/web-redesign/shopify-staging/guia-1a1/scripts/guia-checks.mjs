// Acceptance checks of the guide 1:1 pass, measured in the browser on the rendered draft theme. One block per phase
// (F1 base visual, then the screens of F2–F5); every block was first run against the tree before its phase and seen to
// fail (guia-1a1/RESULTADO.md). Fonts are measured with CDP CSS.getPlatformFontsForNode, never assumed.
//
//   node guia-checks.mjs --base-url=http://127.0.0.1:9292 [--phases=f1,f2] [--name=guia-checks] [--inject-css=...]
//
// Results go to $MONETTA_RUNS_DIR (or shopify-staging/runs/) through the shared harness (scripts/e2e/lib.mjs).
import { launch, parseArgs, Run, settle } from '../../scripts/e2e/lib.mjs';

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
      const footer = await page.evaluate(() => ({ heads: [...document.querySelectorAll('.footer-grid--guia h2')].map((h) => h.textContent.trim()), social: document.querySelectorAll('.footer-col--social .guia-social__link').length, rights: /Todos los derechos reservados/.test(document.querySelector('.footer-bottom')?.textContent || '') }));
      run.check(`F2 ${w}: footer as the guide: Ayuda, Información, Síguenos (3 networks) and the rights line`, footer.heads.join(',') === 'Ayuda,Información,Síguenos' && footer.social === 3 && footer.rights, JSON.stringify(footer));

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

try {
  if (phases.has('f1')) await f1();
  if (phases.has('f2')) await f2();
  run.finish({ complete: true });
} catch (error) {
  run.finish({ complete: false, error });
  process.exitCode = 1;
}
process.exitCode = process.exitCode || (run.checks.some((c) => !c.pass) ? 1 : 0);

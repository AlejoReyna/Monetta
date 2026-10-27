// Layout and fidelity matrix for the first delivery: what must hold at each viewport, measured in the rendered storefront.
//
//   node layout.mjs --base-url=http://127.0.0.1:9292 [--viewports=375x812,440x956,...] [--insets=44]
//
// Checks per viewport and page: no horizontal overflow, pinned chrome measured (reserve equals the real bar), short-viewport
// release at <=480px of height (both sides of 480/481), the phone page bar, the product header's five controls, the
// recommendation rail's measured anatomy, the tablet category row, and the safe region with emulated insets.
import { Run, launch, parseArgs, settle } from './lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const insetPx = args.insets === undefined ? 0 : Number(args.insets);
const viewports = (args.viewports || '375x812,440x956,768x1024,1024x768,1440x900,320x640,812x375,1024x200,1280x200,1024x480,1024x481,360x480,360x481,768x480,768x481')
  .split(',')
  .map((v) => v.split('x').map(Number));
const injectCss = args['inject-css'] || null;
const run = new Run(`${args.label ? `negative-control-${args.label}-` : ''}layout${insetPx ? `-insets${insetPx}` : ''}`, { baseUrl, extra: { viewports, insetPx, injectCss } }); 

const PRODUCT = '/products/reloj-coach-talia-saddle';
const near = (a, b, tol = 0.75) => Math.abs(a - b) <= tol;

async function seedBag(page) {
  // A bag with one line so the cart page shows its real layout (checkout bar, summary).
  await page.goto(`${baseUrl}${PRODUCT}`, { waitUntil: 'load' });
  const id = await page.evaluate(async () => {
    const p = await (await fetch(`${location.pathname}.js`)).json();
    const v = p.variants.find((x) => x.available);
    await fetch('/cart/add.js', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: v.id, quantity: 1 }) });
    return v.id;
  });
  return id;
}

const measure = (page) =>
  page.evaluate(() => {
    const pos = (sel) => {
      const el = document.querySelector(sel);
      if (!el) return null;
      const s = getComputedStyle(el);
      const r = el.getBoundingClientRect();
      return { position: s.position, display: s.display, top: r.top, bottom: r.bottom, height: r.height, width: r.width, maxHeight: s.maxHeight, maxWidth: s.maxWidth };
    };
    const root = getComputedStyle(document.documentElement);
    return {
      scrollWidth: document.documentElement.scrollWidth,
      innerWidth,
      innerHeight,
      pinnedTop: Number.parseFloat(root.getPropertyValue('--pinned-top')),
      pinnedBottom: Number.parseFloat(root.getPropertyValue('--pinned-bottom')),
      scrollPaddingTop: Number.parseFloat(root.scrollPaddingTop),
      scrollPaddingBottom: Number.parseFloat(root.scrollPaddingBottom),
      siteTop: pos('#site-top'),
      pageBar: pos('[data-page-bar]'),
      dock: pos('.dock'),
      purchaseDock: pos('.purchase-dock'),
      checkoutBar: pos('.checkout-bar'),
      sidebar: pos('.filter-sidebar'),
      panel: pos('.product-panel'),
      summary: pos('.summary'),
      viewer: pos('.gallery__main'),
      thumbs: pos('.gallery__thumbs'),
      bodyClasses: document.body.className,
    };
  });

for (const [w, h] of viewports) {
  const tag = `${w}×${h}`;
  const { browser, context, page } = await launch({ width: w, height: h, insets: insetPx || null, injectCss });
  page.setDefaultTimeout(30000);
  try {
    const short = h <= 480;
    const phone = w < 768;

    /* ------------------------------------------------ collection */
    await page.goto(`${baseUrl}/collections/all`, { waitUntil: 'load' });
    await settle(page);
    await page.evaluate(() => scrollTo(0, 800));
    await page.waitForTimeout(250);
    let m = await measure(page);
    run.check(`${tag} collection: no horizontal overflow`, m.scrollWidth <= m.innerWidth, `${m.scrollWidth}/${m.innerWidth}`);
    if (short) {
      run.check(`${tag} collection: short viewport releases the top chrome (header group and page bar static, nothing pinned)`, m.siteTop.position === 'static' && (!m.pageBar || m.pageBar.position === 'static') && m.pinnedTop === 0, `siteTop=${m.siteTop.position} pageBar=${m.pageBar?.position} pinnedTop=${m.pinnedTop}`);
      run.check(`${tag} collection: dock joins the page flow (static) and reserves nothing`, !m.dock || m.dock.display === 'none' || (m.dock.position === 'static' && m.pinnedBottom === 0), `dock=${m.dock?.position}/${m.dock?.display} pinnedBottom=${m.pinnedBottom}`);
      if (m.sidebar && m.sidebar.display !== 'none') run.check(`${tag} collection: filter sidebar is not sticky and not squeezed`, m.sidebar.position === 'static' && m.sidebar.height > 100, JSON.stringify(m.sidebar));
    } else {
      // Since the guide pass (F3) collections keep the global header at every width; the page bar lives on search and the bag.
      const bar = m.siteTop;
      run.check(`${tag} collection: pinned chrome stays pinned above 480px of height (sticky/fixed)`, ['sticky', 'fixed'].includes(bar.position), `${bar.position}`);
      run.check(`${tag} collection: --pinned-top equals the real bottom edge of the pinned bar`, near(m.pinnedTop, bar.bottom, 1), `${m.pinnedTop} vs ${bar.bottom}`);
      run.check(`${tag} collection: scroll-padding-top = reserve + 16`, near(m.scrollPaddingTop, m.pinnedTop + 16, 0.5), `${m.scrollPaddingTop}`);
      if (phone) run.check(`${tag} collection: phones keep the guide's global header, no page bar`, m.siteTop.height > 1 && !m.pageBar, `header ${m.siteTop.height} pageBar ${Boolean(m.pageBar)}`);
      if (phone && m.dock) run.check(`${tag} collection: floating dock is fixed and --pinned-bottom equals its measured height`, m.dock.position === 'fixed' && near(m.pinnedBottom, m.dock.height + 0, 1.5), `dock ${m.dock.height} reserve ${m.pinnedBottom}`);
    }

    // The reserve is measured, not assumed: a title that wraps grows the bar and the reserve follows it. Measured on search,
    // which keeps the phone page bar.
    if (phone && !short) {
      await page.goto(`${baseUrl}/search?q=bolso&type=product`, { waitUntil: 'load' });
      await settle(page);
      await page.evaluate(() => scrollTo(0, 800));
      await page.waitForTimeout(250);
      const ms = await measure(page);
      run.check(`${tag} search: phone page bar is 76px tall with a one-line title`, !!ms.pageBar && near(ms.pageBar.height, 76, 0.75), `${ms.pageBar?.height}`);
      run.check(`${tag} search: phone global header is replaced by the page bar`, ms.siteTop.height < 1 || (await page.locator('#site-header').isHidden()));
      const grown = await page.evaluate(async () => {
        const title = document.querySelector('[data-page-bar] .page-bar__title');
        const before = Number.parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--pinned-top'));
        title.textContent = 'Colección de bolsas, carteras y relojes originales de temporada';
        await new Promise((r) => setTimeout(r, 400));
        const bar = document.querySelector('[data-page-bar]').getBoundingClientRect();
        return { before, after: Number.parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--pinned-top')), bar: bar.bottom, height: bar.height };
      });
      run.check(`${tag} search: a two-line title grows the bar and the measured reserve follows (not a fixed 76)`, grown.height > 76.5 && near(grown.after, grown.bar, 1), JSON.stringify(grown));
    }

    /* ------------------------------------------------ product */
    await page.goto(`${baseUrl}${PRODUCT}`, { waitUntil: 'load' });
    await settle(page);
    await page.evaluate(() => scrollTo(0, 400));
    await page.waitForTimeout(250);
    m = await measure(page);
    run.check(`${tag} product: no horizontal overflow`, m.scrollWidth <= m.innerWidth, `${m.scrollWidth}/${m.innerWidth}`);
    if (short) {
      run.check(`${tag} product: product panel not sticky, gallery not squeezed (viewer ${Math.round(m.viewer.width)}×${Math.round(m.viewer.height)}, panel ${m.panel.position})`, m.panel.position === 'static' && m.viewer.width > 150 && m.viewer.height > 150, JSON.stringify({ viewer: m.viewer, panel: m.panel.position, thumbs: m.thumbs?.maxHeight }));
      run.check(`${tag} product: purchase dock hidden and the inline add button takes over`, (!m.purchaseDock || m.purchaseDock.display === 'none') && (await page.locator('.product-panel .buy-inline [data-add]').first().isVisible()));
      run.check(`${tag} product: gallery drops its viewport-fitted max width and thumbnails their max height`, m.viewer.maxWidth === 'none' && (!m.thumbs || m.thumbs.maxHeight === 'none'), `viewer ${m.viewer.maxWidth} thumbs ${m.thumbs?.maxHeight}`);
    } else if (!phone && w >= 1024) {
      run.check(`${tag} product: desktop columns stay sticky / fitted above 480px of height`, m.panel.position === 'sticky' && m.viewer.maxWidth !== 'none', `panel ${m.panel.position} viewer ${m.viewer.maxWidth}`);
    }
    if (phone && !short) {
      // product_header.dart: back + search · logo · account + bag. Menu and favourites hidden.
      const header = await page.evaluate(() => {
        const vis = (sel) => { const el = document.querySelector(sel); if (!el) return null; const r = el.getBoundingClientRect(); const s = getComputedStyle(el); return s.display === 'none' || s.visibility === 'hidden' || r.width === 0 ? null : { x: r.left, cx: r.left + r.width / 2, w: r.width, h: r.height }; };
        return { back: vis('.site-header__back'), search: vis('.site-header__search-start'), logo: vis('#site-header .wordmark'), account: vis('.header-utility--account'), bag: vis('.header-utility--cart'), menu: vis('.site-header__menu'), searchIcon: vis('.site-header__search-icon') };
      });
      const order = header.back && header.search && header.logo && header.account && header.bag && header.back.x < header.search.x && header.search.x < header.logo.x && header.logo.x < header.account.x && header.account.x < header.bag.x;
      run.check(`${tag} product header (phone): back + search · logo · account + bag in that order`, Boolean(order), JSON.stringify(header));
      run.check(`${tag} product header (phone): menu and the plain search icon are hidden`, header.menu === null && header.searchIcon === null);
      run.check(`${tag} product header (phone): logo centred and targets are 48px`, near(header.logo.cx, w / 2, 1.5) && header.back.w >= 47.5 && header.bag.w >= 47.5, `logo cx ${header.logo.cx}/${w / 2}`);
      run.check(`${tag} product: purchase dock fixed at the bottom and reserved`, m.purchaseDock.position === 'fixed' && near(m.pinnedBottom, m.purchaseDock.height, 1.5), `dock ${m.purchaseDock.height} reserve ${m.pinnedBottom}`);
    }

    // Recommendation rail (phone anatomy): Inter 17/600 heading, tiles min(52vw, 260px), 4:5 photo, 12px gap, <=2-line names.
    await page.evaluate(() => document.querySelector('[data-recommendations]')?.scrollIntoView());
    await page.waitForSelector('.rail--recs .card', { timeout: 20000 }).catch(() => {});
    await settle(page);
    const rail = await page.evaluate(() => {
      const heading = document.querySelector('[data-recommendations] .product-section-title');
      const li = document.querySelectorAll('.rail--recs .rail__track > li');
      if (!heading || li.length < 2) return null;
      const hs = getComputedStyle(heading);
      const media = li[0].querySelector('.card__media').getBoundingClientRect();
      const r0 = li[0].getBoundingClientRect();
      const r1 = li[1].getBoundingClientRect();
      const name = li[0].querySelector('.card__name');
      const ns = getComputedStyle(name);
      return {
        headingSize: hs.fontSize, headingWeight: hs.fontWeight, headingFamily: hs.fontFamily.split(',')[0],
        tileWidth: r0.width, gap: r1.left - r0.right, ratio: media.width / media.height, mediaMargin: getComputedStyle(li[0].querySelector('.card__media')).margin,
        clamp: ns.webkitLineClamp, nameLines: Math.round(name.getBoundingClientRect().height / Number.parseFloat(ns.lineHeight)), tiles: li.length,
        equalHeights: new Set([...li].map((el) => Math.round(el.getBoundingClientRect().height))).size === 1,
      };
    });
    if (!rail) run.check(`${tag} recommendations: rail rendered from Shopify's recommendations`, false, 'no rail');
    else {
      run.check(`${tag} recommendations: rail rendered`, rail.tiles >= 2, `${rail.tiles} tiles`);
      run.check(`${tag} recommendations: tiles have equal heights`, rail.equalHeights);
      if (phone) {
        // Section-title role since 22 Oct (DESIGN_SPEC §3): Playfair 400, 23px on phones. It was Inter 17/600 before.
        run.check(`${tag} recommendations (phone): heading is the section title, Playfair 23px/400`, rail.headingSize === '23px' && rail.headingWeight === '400' && /Playfair/.test(rail.headingFamily), JSON.stringify([rail.headingSize, rail.headingWeight, rail.headingFamily]));
        run.check(`${tag} recommendations (phone): tile width min(52vw, 260px)`, near(rail.tileWidth, Math.min(w * 0.52, 260), 1), `${rail.tileWidth} vs ${Math.min(w * 0.52, 260)}`);
        run.check(`${tag} recommendations (phone): 4:5 photo that fills the frame (no inset) and 12px gap`, near(rail.ratio, 0.8, 0.01) && rail.mediaMargin === '0px' && near(rail.gap, 12, 0.5), JSON.stringify({ ratio: rail.ratio, margin: rail.mediaMargin, gap: rail.gap }));
        run.check(`${tag} recommendations (phone): name clamps at two lines`, rail.clamp === '2' && rail.nameLines <= 2, JSON.stringify([rail.clamp, rail.nameLines]));
      }
    }

    /* ------------------------------------------------ bag */
    await seedBag(page);
    await page.goto(`${baseUrl}/cart`, { waitUntil: 'load' });
    await settle(page);
    await page.evaluate(() => scrollTo(0, 300));
    await page.waitForTimeout(250);
    m = await measure(page);
    run.check(`${tag} bag: no horizontal overflow`, m.scrollWidth <= m.innerWidth, `${m.scrollWidth}/${m.innerWidth}`);
    if (short) {
      run.check(`${tag} bag: checkout bar hidden and the summary's button takes over; summary not sticky`, (!m.checkoutBar || m.checkoutBar.display === 'none') && m.summary.position === 'static' && (await page.locator('.summary [name="checkout"]').isVisible()), `summary ${m.summary?.position}`);
    } else if (phone) {
      run.check(`${tag} bag: checkout bar fixed, reserve equals its height`, m.checkoutBar.position === 'fixed' && near(m.pinnedBottom, m.checkoutBar.height, 1.5), `bar ${m.checkoutBar.height} reserve ${m.pinnedBottom}`);
      run.check(`${tag} bag: the dock gives way to the checkout bar`, m.dock?.display === 'none');
    }

    /* ------------------------------------------------ home + tablet category row */
    await page.goto(`${baseUrl}/`, { waitUntil: 'load' });
    await settle(page);
    m = await measure(page);
    run.check(`${tag} home: no horizontal overflow`, m.scrollWidth <= m.innerWidth, `${m.scrollWidth}/${m.innerWidth}`);
    if (w >= 768 && w < 1024 && !short) {
      // Force overflow in the row so the fade and the end padding are exercised, then reach the last link.
      const row = await page.evaluate(async () => {
        const list = document.querySelector('.site-nav__list');
        for (let i = 0; i < 8; i += 1) list.append(list.children[i % 3].cloneNode(true));
        list.scrollLeft = list.scrollWidth;
        await new Promise((r) => setTimeout(r, 250));
        const last = list.lastElementChild.getBoundingClientRect();
        const lr = list.getBoundingClientRect();
        return { right: last.right, fadeStart: lr.left + lr.width * 0.88, listRight: lr.right, scrollWidth: list.scrollWidth, clientWidth: list.clientWidth, paddingRight: getComputedStyle(list).paddingRight };
      });
      run.check(`${tag} tablet category row: the last link scrolls out of the fade (its right edge is before the 88% fade start)`, row.right <= row.fadeStart + 0.5, JSON.stringify(row));
    }
    await page.screenshot({ path: run.file(`home-${w}x${h}.png`) });
  } catch (error) {
    run.check(`${tag} — unexpected error`, false, String(error.message).split('\n')[0]);
  } finally {
    await browser.close();
  }
}

const result = run.finish({ complete: !args.viewports && !injectCss });
process.exit(result.summary.failed ? 1 : 0);

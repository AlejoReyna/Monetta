// The tablet/desktop category row clips and fades. Judged by what is painted:
//  - every link is reached with Tab (the skip link is passed, never activated) and Shift+Tab,
//  - its focus ring is painted on all four sides (the ring is drawn inside the link: the row's own clip would take an outside ring),
//  - its text is not under the fade: the link's pixels equal those of the same page with the row's mask removed (zero tolerance),
//  - the darkest text pixel is ink (contrast against white), so a faded link cannot pass.
// The staging menu has only three links, so extra links are cloned into the row to force the overflow this layout exists for.
//
//   node nav.mjs --base-url=http://127.0.0.1:9292 [--insets=44] [--viewports=768x1024,812x375,1023x768,1024x768,1440x900]
import { Run, launch, parseArgs, settle } from './lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const insetPx = args.insets === undefined ? 0 : Number(args.insets);
const viewports = (args.viewports || '768x1024,812x375,1023x768,1024x768,1440x900').split(',').map((v) => v.split('x').map(Number));
const run = new Run(`nav${insetPx ? `-insets${insetPx}` : ''}`, { baseUrl, extra: { viewports, insetPx } });

const MASK_OFF = '.site-nav__list{-webkit-mask-image:none!important;mask-image:none!important}';

async function pixels(page, clip) {
  const buffer = await page.screenshot({ clip });
  return buffer.toString('base64');
}

/** Compares two PNGs of the same clip pixel by pixel inside the page; returns the count of differing pixels and the darkest luma. */
async function compare(page, a, b) {
  return page.evaluate(async ([x, y]) => {
    const load = async (b64) => {
      const bmp = await createImageBitmap(await (await fetch(`data:image/png;base64,${b64}`)).blob());
      const cv = new OffscreenCanvas(bmp.width, bmp.height);
      const ctx = cv.getContext('2d');
      ctx.drawImage(bmp, 0, 0);
      return ctx.getImageData(0, 0, bmp.width, bmp.height);
    };
    const [A, B] = [await load(x), await load(y)];
    let diff = 0;
    let darkest = 255;
    for (let i = 0; i < A.data.length; i += 4) {
      if (A.data[i] !== B.data[i] || A.data[i + 1] !== B.data[i + 1] || A.data[i + 2] !== B.data[i + 2]) diff += 1;
      const luma = 0.2126 * A.data[i] + 0.7152 * A.data[i + 1] + 0.0722 * A.data[i + 2];
      if (luma < darkest) darkest = luma;
    }
    return { diff, darkest, width: A.width, height: A.height };
  }, [a, b]);
}

async function ringSides(page, rect, offset, width) {
  const pad = 14;
  const clip = { x: Math.max(0, rect.left - pad), y: Math.max(0, rect.top - pad), width: Math.min(rect.width + 2 * pad, 4000), height: rect.height + 2 * pad };
  const b64 = (await page.screenshot({ clip })).toString('base64');
  return page.evaluate(async ({ b64: data, clip: c, rect: r, d }) => {
    const bmp = await createImageBitmap(await (await fetch(`data:image/png;base64,${data}`)).blob());
    const cv = new OffscreenCanvas(bmp.width, bmp.height);
    const ctx = cv.getContext('2d');
    ctx.drawImage(bmp, 0, 0);
    const dark = (x, y) => {
      for (const k of [-1, 0, 1]) {
        for (const axis of ['x', 'y']) {
          const px = Math.round(x - c.x + (axis === 'x' ? k : 0));
          const py = Math.round(y - c.y + (axis === 'y' ? k : 0));
          if (px < 0 || py < 0 || px >= bmp.width || py >= bmp.height) continue;
          const [R, G, B] = ctx.getImageData(px, py, 1, 1).data;
          if (0.2126 * R + 0.7152 * G + 0.0722 * B < 90) return true;
        }
      }
      return false;
    };
    // The link's corners are square, so each side is a straight line: judge its middle 60%.
    const ts = [0.2, 0.35, 0.5, 0.65, 0.8];
    const side = (pts) => pts.filter(([x, y]) => dark(x, y)).length / pts.length;
    return {
      top: side(ts.map((t) => [r.left + r.width * t, r.top - d])),
      bottom: side(ts.map((t) => [r.left + r.width * t, r.bottom + d])),
      left: side(ts.map((t) => [r.left - d, r.top + r.height * t])),
      right: side(ts.map((t) => [r.right + d, r.top + r.height * t])),
    };
  }, { b64, clip, rect, d: offset + width / 2 });
}

for (const [w, h] of viewports) {
  const tag = `${w}×${h}${insetPx ? ` +${insetPx}px insets` : ''}`;
  const { browser, page } = await launch({ width: w, height: h, insets: insetPx || null, reducedMotion: 'reduce' });
  page.setDefaultTimeout(30000);
  try {
    await page.goto(`${baseUrl}/`, { waitUntil: 'load' });
    await settle(page);
    if (await page.locator('.site-nav').isHidden()) {
      run.note(`${tag}: category row not shown at this width/height (phone layout or short viewport)`);
      continue;
    }
    // Force overflow so the fade and the end padding are in play.
    await page.evaluate(() => {
      const list = document.querySelector('.site-nav__list');
      const originals = [...list.children];
      for (let i = 0; i < 9; i += 1) {
        const clone = originals[i % originals.length].cloneNode(true);
        clone.querySelector('a').textContent = `${clone.querySelector('a').textContent.trim()} ${i + 1}`;
        list.append(clone);
      }
    });
    const overflowing = await page.evaluate(() => { const l = document.querySelector('.site-nav__list'); return l.scrollWidth > l.clientWidth + 1; });
    // From 1024 px the row is as wide as its links (fit-content) and only overflows when they outgrow the window.
    if (w < 1024) run.check(`${tag}: row overflows after adding links (the layout under test is active)`, overflowing);
    else run.note(`${tag}: row ${overflowing ? 'overflows' : 'fits'} with 12 links (desktop: fit-content, no fade)`);

    const count = await page.locator('.site-nav__link').count();
    const results = [];
    // Tab from the document start to the first row link, passing the skip link and the header controls.
    await page.evaluate(() => { document.body.tabIndex = -1; document.body.focus(); document.body.removeAttribute('tabindex'); document.activeElement.blur(); scrollTo(0, 0); });
    const visited = [];
    for (let i = 0; i < 60 && visited.length < count; i += 1) {
      await page.keyboard.press('Tab');
      await page.waitForTimeout(60);
      const info = await page.evaluate(() => {
        const el = document.activeElement;
        if (!el?.classList?.contains('site-nav__link')) return { inRow: false };
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        const list = el.closest('.site-nav__list').getBoundingClientRect();
        return { inRow: true, text: el.textContent.trim(), rect: { left: r.left, top: r.top, right: r.right, bottom: r.bottom, width: r.width, height: r.height }, offset: Number.parseFloat(s.outlineOffset), outlineWidth: Number.parseFloat(s.outlineWidth), outlineStyle: s.outlineStyle, listLeft: list.left, listRight: list.right, fadeStart: list.left + list.width * 0.88 };
      });
      if (!info.inRow) continue;
      visited.push(info.text);
      // Everything about the link must be inside the row and clear of the fade (desktop has no fade).
      const sides = await ringSides(page, info.rect, info.offset, info.outlineWidth);
      const clip = { x: Math.max(0, info.rect.left), y: Math.max(0, info.rect.top), width: Math.max(1, Math.min(info.rect.width, w - Math.max(0, info.rect.left))), height: info.rect.height };
      // Below 1024 px the row has a fade: compare the link with the same page with the mask removed (zero tolerance). From 1024 px
      // there is no mask at all, so there is nothing to remove and the rule is asserted directly.
      let maskDiff = 0;
      let darkest;
      if (w < 1024) {
        const withMask = await pixels(page, clip);
        await page.addStyleTag({ content: MASK_OFF });
        await page.waitForTimeout(80);
        const without = await pixels(page, clip);
        const cmp = await compare(page, withMask, without);
        maskDiff = cmp.diff;
        darkest = cmp.darkest;
        await page.evaluate(() => { for (const s of [...document.querySelectorAll('style')].filter((x) => x.textContent.includes('mask-image:none!important'))) s.remove(); });
      } else {
        const cmp = await compare(page, await pixels(page, clip), await pixels(page, clip));
        darkest = cmp.darkest;
        const mask = await page.evaluate(() => getComputedStyle(document.querySelector('.site-nav__list')).maskImage);
        maskDiff = mask === 'none' ? 0 : 1;
      }
      results.push({ text: info.text, sides, maskDiff, darkest, right: info.rect.right, fadeStart: info.fadeStart });
    }
    run.check(`${tag}: Tab reached all ${count} row links in order`, visited.length === count, `${visited.length}/${count}`);
    const noRing = results.filter((r) => Object.values(r.sides).some((v) => v < 0.8));
    run.check(`${tag}: focus ring painted on all four sides for every link`, noRing.length === 0, noRing.slice(0, 3).map((r) => `${r.text}: ${JSON.stringify(r.sides)}`));
    const masked = results.filter((r) => r.maskDiff > 0);
    run.check(`${tag}: no link is touched by the row's fade or clip (below 1024px: pixels identical with the mask removed, tolerance 0; from 1024px: no mask)`, masked.length === 0, masked.map((r) => `${r.text}: ${r.maskDiff}px differ`));
    const faded = results.filter((r) => r.darkest > 60);
    run.check(`${tag}: every focused link keeps ink-dark text (not faded)`, faded.length === 0, faded.slice(0, 3).map((r) => `${r.text}: darkest luma ${Math.round(r.darkest)}`));
    if (w < 1024) {
      const last = results.at(-1);
      run.check(`${tag}: the last link ends before the 88% fade start`, last && last.right <= last.fadeStart + 0.5, last ? `${Math.round(last.right)} <= ${Math.round(last.fadeStart)}` : 'no stops');
    }
    // Back with Shift+Tab: same links.
    // The traversal ended on the last link: it is the first stop of the way back.
    const back = [visited.at(-1)];
    for (let i = 0; i < 60 && back.length < count; i += 1) {
      await page.keyboard.press('Shift+Tab');
      await page.waitForTimeout(60);
      const text = await page.evaluate(() => (document.activeElement?.classList?.contains('site-nav__link') ? document.activeElement.textContent.trim() : null));
      if (text) back.push(text);
    }
    run.check(`${tag}: Shift+Tab walks the same links in reverse`, back.length === count && back.reverse().join('|') === visited.join('|'), `${back.length}/${count}`);
    await page.screenshot({ path: run.file(`nav-${w}x${h}${insetPx ? `-insets${insetPx}` : ''}.png`) });
  } catch (error) {
    run.check(`${tag} — unexpected error`, false, String(error.message).split('\n')[0]);
  } finally {
    await browser.close();
  }
}

const result = run.finish({ complete: !args.viewports });
process.exit(result.summary.failed ? 1 : 0);

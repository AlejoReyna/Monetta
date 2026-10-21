// D02 — fonts actually used by the renderer, tokens and wordmark.
import { assert } from './report.mjs';

async function platformFonts(page, selector) {
  const client = await page.context().newCDPSession(page);
  await client.send('DOM.enable');
  await client.send('CSS.enable');
  const { root } = await client.send('DOM.getDocument', { depth: -1 });
  const { nodeId } = await client.send('DOM.querySelector', { nodeId: root.nodeId, selector });
  assert(nodeId, `no node for ${selector}`);
  const { fonts } = await client.send('CSS.getPlatformFontsForNode', { nodeId });
  await client.detach();
  return fonts.map((font) => `${font.familyName}${font.isCustomFont ? ' (web font)' : ''}`);
}

export async function checkIdentity({ browser, url, report }) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  report.trackPage(page, 'identity');
  await page.goto(`${url}/`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);

  await report.step('D02', 'Web fonts load in the weights the design uses', async () => {
    const faces = await page.evaluate(() => [...document.fonts].map((face) => `${face.family.replace(/"/g, '')} ${face.weight} ${face.status}`));
    const expected = ['Inter 400 loaded', 'Inter 500 loaded', 'Inter 600 loaded', 'Inter 700 loaded', 'Playfair Display 400 loaded'];
    for (const face of expected) assert(faces.includes(face), `${face} not found in ${faces.join(', ')}`);
    return faces.join(' · ');
  });

  const roles = [
    ['Section heading (Novedades)', '#home-novedades', 'Playfair Display'],
    ['Product card brand', '.card__brand', 'Inter'],
    ['Product card name', '.card__name', 'Inter'],
    ['Product card price', '.card__price .price', 'Inter'],
    ['Category navigation', '.site-nav__link', 'Inter'],
    ['Primary button', '.home-hero__actions .btn--primary', 'Inter'],
  ];
  for (const [label, selector, family] of roles) {
    await report.step('D02', `Renderer uses ${family} for: ${label}`, async () => {
      const used = await platformFonts(page, selector);
      assert(used.length && used.every((name) => name.startsWith(family)), `${selector} rendered with ${used.join(', ')}`);
      return used.join(', ');
    });
  }

  await report.step('D02', 'Computed tokens match the style-guideline palette and geometry', async () => {
    const values = await page.evaluate(() => {
      const style = (selector, property) => getComputedStyle(document.querySelector(selector))[property];
      return {
        canvas: style('body', 'backgroundColor'),
        ink: style('body', 'color'),
        eyebrow: style('.home-hero__panel .eyebrow', 'color'),
        primaryButton: style('.home-hero__actions .btn--primary', 'backgroundColor'),
        buttonRadius: style('.home-hero__actions .btn--primary', 'borderTopLeftRadius'),
        cardRadius: style('.card', 'borderTopLeftRadius'),
        mediaRadius: style('.card__media', 'borderTopLeftRadius'),
        mediaFit: style('.card__media img', 'objectFit'),
        heroFit: style('.home-hero__photo img', 'objectFit'),
        searchRadius: style('.search-field', 'borderTopLeftRadius'),
        sectionFont: style('#home-novedades', 'fontWeight'),
        priceWeight: style('.card__price .price', 'fontWeight'),
      };
    });
    const expect = {
      canvas: 'rgb(251, 248, 242)',
      ink: 'rgb(33, 27, 22)',
      eyebrow: 'rgb(128, 92, 50)',
      primaryButton: 'rgb(116, 82, 55)',
      buttonRadius: '999px',
      cardRadius: '12px',
      mediaRadius: '10px',
      mediaFit: 'contain',
      heroFit: 'cover',
      sectionFont: '400',
      priceWeight: '600',
    };
    for (const [key, value] of Object.entries(expect)) assert(values[key] === value, `${key} is ${values[key]}, expected ${value}`);
    assert(Number.parseFloat(values.searchRadius) >= 24, `search field radius ${values.searchRadius}`);
    return JSON.stringify(values);
  });

  await report.step('D02', 'Wordmark is the app artwork at its own proportions', async () => {
    const logo = await page.evaluate(() => {
      const image = document.querySelector('.site-header .wordmark img');
      const rect = image.getBoundingClientRect();
      return { src: image.currentSrc, natural: [image.naturalWidth, image.naturalHeight], rendered: [rect.width, rect.height] };
    });
    assert(/logo-monetta(@[23]x)?\.png$/.test(logo.src), `logo source ${logo.src}`);
    const naturalRatio = logo.natural[0] / logo.natural[1];
    const renderedRatio = logo.rendered[0] / logo.rendered[1];
    assert(Math.abs(naturalRatio - renderedRatio) < 0.05, `ratio ${renderedRatio.toFixed(3)} vs ${naturalRatio.toFixed(3)}`);
    return `${logo.src.split('/').pop()} ${logo.natural.join('×')} rendered ${logo.rendered.map((value) => Math.round(value)).join('×')}`;
  });

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${url}/`, { waitUntil: 'networkidle' });
  await report.step('D02', 'Bottom navigation is a flat full-width bar; the active item is accent colour, weight 600 and a 2 px rule', async () => {
    const dock = await page.evaluate(() => {
      const bar = document.querySelector('.dock');
      const item = document.querySelector('.dock__item[aria-current="page"]');
      const idle = document.querySelector('.dock__item:not([aria-current])');
      const style = getComputedStyle(item);
      const rule = getComputedStyle(item, '::after');
      const rect = bar.getBoundingClientRect();
      return {
        label: item.textContent.trim(),
        color: style.color,
        weight: style.fontWeight,
        idleColor: getComputedStyle(idle).color,
        idleWeight: getComputedStyle(idle).fontWeight,
        rule: [rule.width, rule.height, rule.backgroundColor],
        barWidth: rect.width,
        viewport: innerWidth,
        barBackground: getComputedStyle(bar).backgroundColor,
        radius: getComputedStyle(bar).borderTopLeftRadius,
        shadow: getComputedStyle(bar).boxShadow,
      };
    });
    assert(dock.color === 'rgb(140, 100, 54)', `active colour ${dock.color}`);
    assert(dock.weight === '600' && dock.idleWeight === '500', `weights ${dock.weight}/${dock.idleWeight}`);
    assert(dock.idleColor === 'rgb(33, 27, 22)', `inactive colour ${dock.idleColor}`);
    assert(dock.rule.join(' ') === '28px 2px rgb(140, 100, 54)', `active rule ${dock.rule.join(' ')}`);
    assert(Math.abs(dock.barWidth - dock.viewport) < 0.5, `bar is ${dock.barWidth}px of ${dock.viewport}`);
    assert(dock.barBackground === 'rgb(247, 243, 236)' && dock.radius === '0px' && dock.shadow === 'none', `bar ${dock.barBackground} radius ${dock.radius} shadow ${dock.shadow}`);
    return `${dock.label}: ${dock.color}/${dock.weight}, bar ${dock.barWidth}px flat`;
  });
  await context.close();
}

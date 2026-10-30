// Pixel regression between two served builds of the prototype: the corrected one must
// look exactly like the build before the corrections wherever the corrections do not apply
// (no cut-out insets, a viewport tall enough to keep the chrome pinned).
//
//   node comparar-pixeles.mjs --out=<folder> --a=http://127.0.0.1:4401 --b=http://127.0.0.1:4402
//
// A is the build rebuilt from baseline-pre-correcciones.tgz, B is design-prototype/dist.
// Every route is captured at several viewports and scroll positions (top, middle, end) with
// reduced motion and a fresh page per capture; the PNGs are decoded and compared in the
// browser, pixel by pixel with no tolerance. Differences are listed with their bounding box
// and written out as a side-by-side image so they can be looked at, not only counted.
//
// Photos are hidden before the shot (--images keeps them): the browser resamples a photograph
// slightly differently on every load (two loads of the very same build differ by a few levels
// on the texture of a bag), which says nothing about layout. Their boxes stay, so anything
// that moves, resizes or restyles around them still shows.
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const prototype = fileURLToPath(new URL('../../../design-prototype/', import.meta.url));
const { launch } = await import(path.join(prototype, 'verify/browser.mjs'));
const { demoCartLines } = await import(path.join(prototype, 'verify/check-layout.mjs'));
const { scrollThrough, seedCart } = await import(path.join(prototype, 'verify/report.mjs'));
const { settle } = await import(path.join(prototype, 'verify/probes.mjs'));

const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
if (!args.out || !args.a || !args.b) throw new Error('--out=<folder> --a=<url of the base build> --b=<url of the corrected build> are required');
const out = path.resolve(args.out);
await mkdir(out, { recursive: true });
const A = args.a.replace(/\/$/, '');
const B = args.b.replace(/\/$/, '');

const VIEWPORTS = (args.viewports ?? '320x568,360x800,375x812,390x844,440x956,768x1024,1024x768,1440x900')
  .split(',')
  .map((value) => value.split('x').map(Number))
  .map(([width, height]) => ({ width, height }));
const ROUTES = [
  ['home', '/'],
  ['collection', '/collections/guess'],
  ['collection-long-title', '/collections/tommy-hilfiger'],
  ['product', '/products/bolso-coach-shoulder-negro-rectangular'],
  ['search-empty', '/search'],
  ['search-results', '/search?q=bolsa&type=product'],
  ['search-none', '/search?q=zzzz-no-match'],
  ['cart', '/cart', { cart: true }],
  ['cart-empty', '/cart'],
  ['favorites', '/pages/favoritos'],
  ['account', '/account'],
  ['mayoreo', '/pages/mayoreo'],
  ['contact', '/pages/contact'],
  ['story', '/pages/nuestra-historia'],
  ['policy', '/policies/shipping-policy'],
  ['not-found', '/zzz-no-existe'],
].filter(([name]) => !args.routes || args.routes.split(',').includes(name));
const POSITIONS = ['top', 'middle', 'end'];

const { browser, version } = await launch();
const scratch = await (await browser.newContext()).newPage();

/** One fresh page per route and viewport; the three scroll positions are shot from the same load. */
async function capture(base, route, viewport, options) {
  const context = await browser.newContext({ viewport, reducedMotion: 'reduce', deviceScaleFactor: 1 });
  try {
    if (options.cart) await seedCart(context, demoCartLines());
    const page = await context.newPage();
    await page.goto(base + route, { waitUntil: 'networkidle' });
    await scrollThrough(page); // below-the-fold images are lazy: bring them in before comparing
    await page.evaluate(async () => {
      await document.fonts.ready;
      const pending = [...document.images].filter((image) => !image.complete);
      await Promise.race([
        Promise.all(pending.map((image) => new Promise((resolve) => { image.addEventListener('load', resolve, { once: true }); image.addEventListener('error', resolve, { once: true }); }))),
        new Promise((resolve) => setTimeout(resolve, 4000)),
      ]);
    });
    if (!args.images) await page.addStyleTag({ content: 'img, video, canvas { visibility: hidden !important; }' });
    const shots = {};
    for (const position of POSITIONS) {
      await page.evaluate((where) => {
        const max = document.documentElement.scrollHeight - innerHeight;
        window.scrollTo(0, where === 'top' ? 0 : where === 'middle' ? Math.round(max / 2) : max);
      }, position);
      await settle(page);
      shots[position] = await page.screenshot({ type: 'png' });
    }
    return shots;
  } finally {
    await context.close();
  }
}

function compare(a, b) {
  return scratch.evaluate(async ([first, second]) => {
    const decode = async (base64) => createImageBitmap(await (await fetch(`data:image/png;base64,${base64}`)).blob());
    const [one, two] = await Promise.all([decode(first), decode(second)]);
    if (one.width !== two.width || one.height !== two.height) return { sizeMismatch: [one.width, one.height, two.width, two.height] };
    const { width, height } = one;
    const read = (bitmap) => {
      const context = new OffscreenCanvas(width, height).getContext('2d', { willReadFrequently: true });
      context.drawImage(bitmap, 0, 0);
      return context.getImageData(0, 0, width, height).data;
    };
    const left = read(one);
    const right = read(two);
    let differing = 0;
    const box = [width, height, 0, 0];
    for (let index = 0; index < left.length; index += 4) {
      if (left[index] !== right[index] || left[index + 1] !== right[index + 1] || left[index + 2] !== right[index + 2] || left[index + 3] !== right[index + 3]) {
        differing += 1;
        const pixel = index / 4;
        const x = pixel % width;
        const y = Math.floor(pixel / width);
        box[0] = Math.min(box[0], x);
        box[1] = Math.min(box[1], y);
        box[2] = Math.max(box[2], x);
        box[3] = Math.max(box[3], y);
      }
    }
    return { width, height, differing, box: differing ? box : null };
  }, [a.toString('base64'), b.toString('base64')]);
}

const rows = [];
let compared = 0;
for (const [name, route, options = {}] of ROUTES) {
  for (const viewport of VIEWPORTS) {
    const [shotsA, shotsB] = await Promise.all([capture(A, route, viewport, options), capture(B, route, viewport, options)]);
    for (const position of POSITIONS) {
      const result = await compare(shotsA[position], shotsB[position]);
      compared += 1;
      const label = `${name} @ ${viewport.width}×${viewport.height} ${position}`;
      const row = { label, ...result };
      rows.push(row);
      if (result.sizeMismatch || result.differing) {
        const file = `diff-${name}-${viewport.width}x${viewport.height}-${position}`;
        await writeFile(path.join(out, `${file}-a.png`), shotsA[position]);
        await writeFile(path.join(out, `${file}-b.png`), shotsB[position]);
        row.files = [`${file}-a.png`, `${file}-b.png`];
        console.log(`DIFF ${label}: ${result.sizeMismatch ? `size ${result.sizeMismatch.join(',')}` : `${result.differing} px, box ${result.box.join(',')}`}`);
      }
    }
    process.stdout.write('.');
  }
}
process.stdout.write('\n');
await browser.close();

const different = rows.filter((row) => row.sizeMismatch || row.differing);
const summary = {
  comparedAt: new Date().toISOString(),
  browser: version,
  a: A,
  b: B,
  captures: compared,
  identical: compared - different.length,
  different: different.length,
  viewports: VIEWPORTS.map((viewport) => `${viewport.width}×${viewport.height}`),
  routes: ROUTES.map(([name]) => name),
  positions: POSITIONS,
  rows,
};
await writeFile(path.join(out, 'comparacion-pixeles.json'), `${JSON.stringify(summary, null, 2)}\n`);
console.log(`${summary.identical}/${compared} captures identical (${different.length} differ)`);

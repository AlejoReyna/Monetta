// Comparison sheets of the guide 1:1 pass: one PNG per slide with four columns, always in this order:
//   guide slide | web 390x844 (top of the full page, cut to the slide's 2:5 proportion) | web 1440x900 (viewport) | app (#33)
// plus sheets.html, which lists them with their labels. Slides come from the PDF render (evidencia/slides/s-NN.png), app
// captures from refs/app/. A missing capture leaves a grey column. Uses ffmpeg only.
//
//   node guia-sheet.mjs --captures=<absolute folder of guia-capture.mjs> --out=<absolute folder> [--only=03,06]
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const guia = path.resolve(here, '..');
const arg = (name) => process.argv.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const captures = arg('captures');
const out = arg('out');
if (!captures || !out || !path.isAbsolute(captures) || !path.isAbsolute(out)) throw new Error('--captures and --out (absolute) are required');
const only = arg('only') ? new Set(arg('only').split(',')) : null;
mkdirSync(out, { recursive: true });

const APP = { '01': 'p-01', '02': 'p-02', '03': 'p-03', '04': 'p-04', '05': 'p-05', '12': 'p-07', '13': 'p-08', '21': 'p-10', '22': 'p-11', '23': 'p-12', '24': 'p-13', '25': 'p-14', '26': 'p-15', '27': 'p-16', '28': 'p-17', '29': 'p-18', '30': 'p-19' };
const appFor = (slide) => {
  const n = Number.parseInt(slide, 10);
  const key = APP[slide] || (n >= 6 && n <= 11 ? 'p-06' : n >= 14 && n <= 20 ? 'p-09' : null);
  if (!key) return null;
  const file = readdirSync(path.join(guia, 'refs/app')).find((f) => f.startsWith(`${key}-`));
  return file ? path.join(guia, 'refs/app', file) : null;
};
const H = 1000;
const files = readdirSync(captures);
const capture = (slide, width, full) => {
  const name = files.find((f) => f.startsWith(`${slide}-`) && f.endsWith(`-${width}${full ? '-full' : ''}.png`));
  return name ? path.join(captures, name) : null;
};

const rows = [];
const slides = [...new Set(files.filter((f) => /^\d\d[a-z]?-.*\.png$/.test(f)).map((f) => f.split('-')[0]))].sort();
for (const slide of slides) {
  if (only && !only.has(slide)) continue;
  const slidePng = path.join(guia, 'evidencia/slides', `s-${slide.slice(0, 2)}.png`);
  const cols = [
    { file: existsSync(slidePng) ? slidePng : null, crop: false },
    { file: capture(slide, 390, true) || capture(slide, 390, false), crop: true },
    { file: capture(slide, 1440, false), crop: false },
    { file: appFor(slide.slice(0, 2)), crop: true },
  ];
  const inputs = [];
  const filters = [];
  cols.forEach((c, i) => {
    if (c.file) {
      inputs.push('-i', c.file);
      const crop = c.crop ? 'crop=iw:min(ih\\,iw*2.5):0:0,' : '';
      filters.push(`[${i}:v]${crop}scale=-2:${H},pad=iw+24:ih:12:0:white[c${i}]`);
    } else {
      inputs.push('-f', 'lavfi', '-i', `color=c=0xDDDDDD:s=400x${H}`);
      filters.push(`[${i}:v]pad=iw+24:ih:12:0:white[c${i}]`);
    }
  });
  const target = path.join(out, `sheet-${slide}.png`);
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', ...inputs, '-filter_complex', `${filters.join(';')};[c0][c1][c2][c3]hstack=inputs=4`, '-frames:v', '1', '-y', target]);
  rows.push({ slide, target: path.basename(target), cols: cols.map((c) => (c.file ? path.basename(c.file) : '—')) });
  console.log(`sheet-${slide}.png  ${cols.map((c) => (c.file ? path.basename(c.file) : '—')).join(' | ')}`);
}
const html = `<!doctype html><meta charset="utf-8"><title>Hojas comparativas</title>
<style>body{font:14px system-ui;margin:16px}h2{margin:24px 0 4px}p{margin:0 0 8px;color:#555}img{max-width:100%;border:1px solid #ddd}</style>
<h1>Lámina | web 390×844 | web 1440×900 | app (#33)</h1>
${rows.map((r) => `<h2>Lámina ${r.slide}</h2><p>${r.cols.join(' · ')}</p><img src="${r.target}" alt="Lámina ${r.slide}">`).join('\n')}`;
writeFileSync(path.join(out, 'sheets.html'), html);

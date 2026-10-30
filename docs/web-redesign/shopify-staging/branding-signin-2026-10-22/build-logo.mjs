import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const outputDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(outputDir, '../../../..');
const logoPath = path.join(projectRoot, 'storefront-theme/assets/monetta-logo-3x.png');
const logo = fs.readFileSync(logoPath).toString('base64');

// Presentation wrapper only: retain the original wordmark pixels and colors.
// The editor caps the SVG preview at 60px tall. Use a small inset for the
// compatible GIF: at the saved 240px width, the visible top moves down 14.5px.
const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="396" height="137" viewBox="0 0 396 137" role="img" aria-labelledby="title">
  <title id="title">Monetta</title>
  <style>
    .wordmark { animation: monetta-reveal 620ms ease-out 100ms both; }
    @keyframes monetta-reveal {
      from { opacity: .76; }
      to { opacity: 1; }
    }
    @media (prefers-reduced-motion: reduce) {
      .wordmark { animation: none; }
    }
  </style>
  <g class="wordmark">
    <image x="0" y="24" width="396" height="113" xlink:href="data:image/png;base64,${logo}" />
  </g>
</svg>
`;
const output = path.join(outputDir, 'monetta-signin-logo-final.svg');
fs.writeFileSync(output, svg);

// The hosted sign-in editor rejects SVG when saving. Render the presentation
// wrapper, then export a brief GIF that plays once and stays fully visible.
const png = path.join(outputDir, 'monetta-signin-logo-final.png');
const matte = path.join(outputDir, 'monetta-signin-logo-matte.png');
const gif = path.join(outputDir, 'monetta-signin-logo-entrada.gif');
execFileSync('rsvg-convert', ['-o', png, output]);
execFileSync('rsvg-convert', ['--background-color', '#fbf8f2', '-o', matte, output]);
execFileSync('ffmpeg', [
  '-hide_banner', '-loglevel', 'error', '-y',
  '-t', '2.84', '-loop', '1', '-framerate', '25', '-i', matte,
  '-filter_complex',
  'fade=t=in:st=0:d=2.58:color=0xfbf8f2,trim=start=1.96,setpts=PTS-STARTPTS,split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=full[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5',
  '-loop', '-1', '-final_delay', '100', gif,
]);
if (fs.readFileSync(gif).includes(Buffer.from('NETSCAPE2.0'))) {
  throw new Error('The logo must play once, with no GIF loop extension.');
}
console.log(gif);

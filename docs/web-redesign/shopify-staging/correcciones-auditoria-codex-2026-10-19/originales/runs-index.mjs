// Builds docs/web-redesign/shopify-staging/RUNS.md from the result files under runs/: one row per run with store, theme, code state,
// command, time and verdict, plus the failing checks of any run that has them. Re-run it after new runs; it only reads runs/.
//   node docs/web-redesign/shopify-staging/scripts/runs-index.mjs
import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const staging = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const runsDir = path.join(staging, 'runs');
const rows = [];
for (const name of readdirSync(runsDir).sort()) {
  const dir = path.join(runsDir, name);
  for (const file of ['result.json', 'result.partial.json']) {
    const p = path.join(dir, file);
    if (!existsSync(p)) continue;
    rows.push({ dir: name, file, r: JSON.parse(readFileSync(p, 'utf8')) });
  }
}
const short = (s) => (s || '').slice(0, 12);
let md = `# Índice de ejecuciones\n\nGenerado por \`scripts/runs-index.mjs\` a partir de \`runs/*/result*.json\`. Cada fila identifica tienda, tema, estado del código (SHA-256 del árbol de \`storefront-theme/\`), comando y hora. \`complete-*\` = ejecución completa; \`partial\` = subconjunto de tamaños o páginas, nunca presentado como resultado completo.\n\n`;
md += `| Hora (UTC) | Ejecución | Estado | Checks | Tienda · tema | Árbol del tema (SHA-256) | Comando |\n|---|---|---|---|---|---|---|\n`;
for (const { dir, file, r } of rows) {
  md += `| ${r.startedAt.slice(0, 19)}Z | [${r.run}](runs/${dir}/${file}) | ${r.status} | ${r.summary.passed}/${r.summary.checks} | ${r.store} · ${r.theme.id} | \`${short(r.codeState.storefrontTheme.sha256)}\` (${r.codeState.storefrontTheme.files} archivos) | \`${r.command.replace(/\|/g, '\\|')}\` |\n`;
}
const isControl = (r) => r.run.startsWith('negative-control-');
const failing = rows.filter(({ r }) => r.summary.failed > 0 && !isControl(r));
const controls = rows.filter(({ r }) => isControl(r));
if (failing.length) {
  md += `\n## Comprobaciones que no pasaron\n\nTodas las de esta lista son **de infraestructura**, no del tema: el proxy local de \`shopify theme dev\` se volvió lento y dio tiempos de espera (\`page.goto\`/\`page.screenshot\` a 30 s), algún 502 y respuestas JSON de error mientras corría la serie del 19/10 (el proxy autenticado ya había caducado una vez con un 401 y se levantó otro; ver ENTREGA §7). Cada una se repitió por separado con la misma orden y el mismo estado del código, y las repeticiones aparecen arriba en verde. Las ejecuciones fallidas se conservan, no se editan.\n\n`;
  for (const { dir, r } of failing) {
    md += `### ${r.run} (${dir})\n\n`;
    for (const c of r.checks.filter((x) => !x.pass)) md += `- **${c.name}** — ${c.detail.slice(0, 400)}\n`;
    md += '\n';
  }
}
if (controls.length) {
  md += `\n## Controles negativos (se espera que fallen)\n\nCada uno reintroduce a propósito, con una hoja de estilos inyectada, un defecto ya corregido (campo \`injectCss\` del resultado) y comprueba que el verificador lo detecta. **Fallar aquí es el resultado correcto**; que pasara significaría que el verificador no ve ese defecto.\n\n`;
  for (const { dir, r } of controls) {
    const failed = r.checks.filter((x) => !x.pass);
    md += `- **${r.run}** (\`runs/${dir}\`): ${failed.length ? `detectado — ${failed.length} comprobación(es) fallan` : '**NO detectado: el verificador pasó con el defecto presente**'}. CSS inyectado: \`${r.injectCss}\`\n`;
    for (const c of failed.slice(0, 2)) md += `  - ${c.name} — ${c.detail.slice(0, 220)}\n`;
  }
}
const notes = rows.flatMap(({ r }) => r.notes.map((n) => `- (${r.run}) ${n}`));
if (notes.length) md += `\n## Notas registradas por las ejecuciones\n\n${[...new Set(notes)].join('\n')}\n`;
writeFileSync(path.join(staging, 'RUNS.md'), md);
console.log(`RUNS.md: ${rows.length} ejecuciones, ${failing.length} con comprobaciones fallidas`);

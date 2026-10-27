// Builds docs/web-redesign/shopify-staging/RUNS.md (and runs-summary.json) from the result files under runs/. It only reads runs/.
//   node docs/web-redesign/shopify-staging/scripts/runs-index.mjs
//
// What it does NOT do (the previous generator did): attribute every failure to infrastructure, count any failing check as a detected
// negative control, or add up checks that a retry repeats. Here:
//  - each failing check gets a symptom (from its own text), a cause that is "determinada" only when the run recorded evidence for it
//    (a proxy incident whose URL appears in the failure), otherwise it says "no determinada", the evidence, and the later run that
//    repeats that very check on the same code (or "sin repetición equivalente");
//  - a negative control counts as detected only when the SPECIFIC assertion(s) it was built to trip failed as assertions, the run
//    finished without a script error, and none of those failures is a timeout, an error page or a crash;
//  - the verified figures take each check (verifier + run + check name) once, from its latest execution on a given code state, so a
//    retry replaces the failure it repeats instead of adding to the total.
import { readdirSync, readFileSync, writeFileSync, existsSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { treeDigest } from './e2e/lib.mjs';

const staging = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const runsDir = path.join(staging, 'runs');
const AUDITED_TREE = 'a962cd92f8a480e199bf880714c3c85addf9e8e5c4eb179aaf7550cf10e5f0bf';
// The code state of the corrections is the tree the workspace has when the index is generated; any other tree that is not the audited
// one is an intermediate state of development.
const CURRENT_TREE = treeDigest().sha256;

/* ---------------------------------------------------------------- load */
const runs = [];
for (const name of readdirSync(runsDir).sort()) {
  const dir = path.join(runsDir, name);
  if (!existsSync(dir) || !statSync(dir).isDirectory() || !readdirSync(dir).length) continue;
  for (const file of ['result.json', 'result.partial.json']) {
    const p = path.join(dir, file);
    if (!existsSync(p)) continue;
    const r = JSON.parse(readFileSync(p, 'utf8'));
    runs.push({ dir: name, file, r, script: /e2e\/([a-z-]+)\.mjs/.exec(r.command)?.[1] ?? 'unknown', tree: r.codeState.storefrontTheme.sha256 });
  }
}
runs.sort((a, b) => a.r.startedAt.localeCompare(b.r.startedAt));
const short = (s) => (s || '').slice(0, 12);
const link = ({ dir, file, r }) => `[${r.run}](runs/${dir}/${file})`;
const isControl = ({ r }) => r.run.startsWith('negative-control-');
const isDev = ({ r }) => /--label=dev/.test(r.command) || /-dev(-|$)/.test(r.run);
const purpose = (x) => (isControl(x) ? (isDev(x) ? 'control (desarrollo)' : 'control negativo') : isDev(x) ? 'desarrollo' : 'verificación');

/* ---------------------------------------------------------------- failure classification */
// Runs recorded before checks carried a kind mark the ones that could not run in their name.
const isError = (check) => check.kind === 'error' || /— unexpected error$|— the check could not run$|^journey aborted$/.test(check.name);
const INFRA_PATTERNS = [
  [/json-formatter-container/i, 'el documento servido no era el tema (visor JSON del navegador)'],
  [/Unexpected end of JSON input|Unexpected token <|is not valid JSON/i, 'respuesta vacía o no JSON'],
  [/Timeout \d+ms exceeded/i, 'tiempo de espera agotado'],
  [/\b502\b|Bad Gateway/i, 'respuesta 502'],
  [/unauthorized/i, 'respuesta «unauthorized» del proxy'],
  [/net::ERR|ECONNRESET|ECONNREFUSED|fetch failed/i, 'error de red'],
];
function symptom(check) {
  for (const [re, label] of INFRA_PATTERNS) if (re.test(check.detail) || re.test(check.name)) return label;
  if (isError(check)) return 'error del guion (la comprobación no pudo ejecutarse)';
  return 'aserción fallida';
}
const looksLikeInfrastructure = (check) => INFRA_PATTERNS.some(([re]) => re.test(check.detail) || re.test(check.name));

function causeOf(run, check) {
  const incidents = run.r.incidents ?? [];
  const hit = incidents.find((i) => i.url && (check.detail.includes(new URL(i.url, 'http://x').pathname) || check.name.includes(new URL(i.url, 'http://x').pathname)));
  if (hit) return { state: 'determinada', text: `incidente de proxy registrado en la propia ejecución: ${hit.kind} — ${hit.detail}`.slice(0, 260) };
  if (looksLikeInfrastructure(check)) return { state: 'no determinada', text: `síntoma compatible con el proxy (${symptom(check)}), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto` };
  if (isError(check)) return { state: 'no determinada', text: 'el guion falló antes de poder evaluar la aserción y no registró una causa' };
  return { state: 'determinada', text: 'la aserción se evaluó y no se cumplió: el detalle es la evidencia' };
}

/**
 * Later runs of the same verifier (same run name) on the same code that repeat this very check and pass it. A check that is "<step> —
 * unexpected error" stands for the whole step, so its repetition is a later run whose checks of that step ("<step>…") all pass.
 */
function retriesOf(run, check) {
  const later = runs.filter((x) => x !== run && x.script === run.script && x.r.run === run.r.run && x.tree === run.tree && x.r.startedAt > run.r.startedAt && !isControl(x) && !isDev(x));
  const step = /^(.*) — unexpected error$/.exec(check.name)?.[1];
  if (step) {
    return later.filter((x) => {
      const mine = x.r.checks.filter((c) => c.name.startsWith(step));
      return mine.length > 0 && mine.every((c) => c.pass);
    });
  }
  // The same check, allowing for what a run counts differently from its repetition: the number of tab stops it found, and the
  // longer name a successful capture gets ("captured" -> "captured with every visible image loaded and decoded").
  const norm = (name) => name.replace(/\b\d+ (tab )?stops?\b/g, '# stops');
  const same = (c) => c.pass && (c.name === check.name || norm(c.name) === norm(check.name) || c.name.startsWith(`${check.name} `));
  return later.filter((x) => x.r.checks.some(same));
}

/* ---------------------------------------------------------------- negative controls */
// Controls recorded before the expectation was stored in the result: what each was built to trip, from its injected defect.
const LEGACY_CONTROLS = {
  'negative-control-dock-ring-keyboard': [{ name: /every centre visible, hit-testable and ring painted/, detail: /Inicio.*focus ring right side not painted/ }],
  'negative-control-thumbs-ring-keyboard': [{ name: /every centre visible, hit-testable and ring painted/, detail: /button\.thumb.*focus ring top side not painted/ }],
  'negative-control-rail-ring-keyboard': [{ name: /every centre visible, hit-testable and ring painted/, detail: /a\.card__link.*focus ring left side not painted/ }],
  'negative-control-sidebar-ring-keyboard': [{ name: /every centre visible, hit-testable and ring painted/, detail: /summary.*focus ring top side not painted/ }],
  'negative-control-short-viewport-release-layout': [
    { name: /short viewport releases the top chrome/, detail: /sticky/ },
    { name: /product panel not sticky, gallery not squeezed/, detail: /./ },
    { name: /gallery drops its viewport-fitted max width/, detail: /./ },
    { name: /checkout bar hidden and the summary's button takes over/, detail: /sticky/ },
  ],
};

function judgeControl(x) {
  const { r } = x;
  const reasons = [];
  if (r.status === 'partial-error' || r.error) reasons.push('la ejecución terminó con un error del guion');
  const failed = r.checks.filter((c) => !c.pass);
  if (failed.some((c) => isError(c))) reasons.push('hubo comprobaciones que fallaron por error del guion, no por aserción');
  const expectations = r.control?.expectedFailures?.length
    ? r.control.expectedFailures.map((text) => ({ label: text, test: (c) => (text.startsWith('/') && text.endsWith('/') ? new RegExp(text.slice(1, -1)).test(c.name) : c.name.includes(text)) }))
    : (LEGACY_CONTROLS[r.run] ?? []).map((e) => ({ label: `${e.name} ∧ ${e.detail}`, test: (c) => e.name.test(c.name) && e.detail.test(c.detail) }));
  if (!expectations.length) reasons.push('no hay una aserción esperada registrada para este control');
  const missing = [];
  for (const e of expectations) {
    const match = failed.find((c) => !isError(c) && !looksLikeInfrastructure(c) && e.test(c));
    if (!match) missing.push(e.label);
  }
  if (missing.length) reasons.push(`no falló la aserción esperada: ${missing.join(' | ')}`);
  return { detected: reasons.length === 0, reasons, expectations: expectations.length };
}

/* ---------------------------------------------------------------- verified figures (no duplicates) */
function figures(tree) {
  const latest = new Map(); // verifier|run|check -> { pass, run }
  for (const x of runs) {
    if (x.tree !== tree || isControl(x) || isDev(x)) continue;
    for (const c of x.r.checks) latest.set(`${x.script}|${x.r.run}|${c.name}`, { pass: c.pass, x, c });
  }
  const byVerifier = new Map();
  for (const [key, v] of latest) {
    const verifier = key.split('|')[0];
    const row = byVerifier.get(verifier) ?? { pass: 0, fail: 0, runs: new Set() };
    if (v.pass) row.pass += 1;
    else row.fail += 1;
    row.runs.add(v.x.r.run);
    byVerifier.set(verifier, row);
  }
  return byVerifier;
}

/* ---------------------------------------------------------------- write */
const trees = [...new Map(runs.map((x) => [x.tree, x.r.codeState.storefrontTheme.files])).entries()];
let md = `# Índice de ejecuciones\n\nGenerado por \`scripts/runs-index.mjs\` a partir de \`runs/*/result*.json\`; no se edita a mano. Cada fila identifica tienda, tema, estado del código (SHA-256 del árbol de \`storefront-theme/\`), comando y hora. \`complete-*\` = ejecución completa; \`partial\` = subconjunto de tamaños o páginas (nunca se presenta como resultado completo); \`partial-error\` = el guion terminó con un error. Las ejecuciones de **desarrollo** (\`--label=dev…\`) se listan pero no cuentan en ninguna cifra.\n\n`;
md += `## Estados del código\n\n| Árbol (SHA-256) | Archivos | Ejecuciones | Qué es |\n|---|---|---|---|\n`;
for (const [tree, files] of trees) {
  const these = runs.filter((x) => x.tree === tree);
  const meaning = tree === AUDITED_TREE ? 'árbol de la primera entrega, el que auditó Codex. **Histórico**: sus ejecuciones no se atribuyen al código corregido' : tree === CURRENT_TREE ? '**árbol actual, con las correcciones de la auditoría**: el estado de código de las ejecuciones de cierre' : 'estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras';
  md += `| \`${short(tree)}\` | ${files} | ${these.length} (${these.filter((x) => !isDev(x) && !isControl(x)).length} de verificación) | ${meaning} |\n`;
}

md += `\n## Ejecuciones\n\n| Hora (UTC) | Ejecución | Propósito | Estado | Checks | Árbol | Comando |\n|---|---|---|---|---|---|---|\n`;
for (const x of runs) {
  const { r } = x;
  md += `| ${r.startedAt.slice(0, 19)}Z | ${link(x)} | ${purpose(x)} | ${r.status} | ${r.summary.passed}/${r.summary.checks} | \`${short(x.tree)}\` | \`${r.command.replace(/\|/g, '\\|')}\` |\n`;
}

md += `\n## Cifras verificadas, sin duplicar por los reintentos\n\nCada comprobación (verificador + ejecución + nombre) cuenta una vez, con el resultado de su última ejecución sobre ese árbol; un reintento que repite una comprobación fallida la sustituye, no se suma. Se excluyen controles negativos y ejecuciones de desarrollo.\n\n`;
const summary = { generatedFrom: 'runs/*/result*.json', trees: {} };
for (const [tree] of trees) {
  if (tree !== AUDITED_TREE && tree !== CURRENT_TREE) continue; // intermediate states do not count
  const f = figures(tree);
  if (!f.size) continue;
  md += `**Árbol \`${short(tree)}\`**${tree === AUDITED_TREE ? ' (histórico, primera entrega)' : ''}\n\n| Verificador | Comprobaciones únicas | Aprobadas | No aprobadas | Ejecuciones que lo componen |\n|---|---|---|---|---|\n`;
  summary.trees[short(tree)] = {};
  let total = 0;
  let failing = 0;
  for (const [verifier, row] of [...f].sort()) {
    md += `| ${verifier} | ${row.pass + row.fail} | ${row.pass} | ${row.fail} | ${[...row.runs].sort().join(', ')} |\n`;
    summary.trees[short(tree)][verifier] = { unique: row.pass + row.fail, passed: row.pass, failed: row.fail, runs: [...row.runs].sort() };
    total += row.pass + row.fail;
    failing += row.fail;
  }
  md += `| **total** | **${total}** | **${total - failing}** | **${failing}** | |\n\n`;
}

const failing = runs.filter((x) => x.r.summary.failed > 0 && !isControl(x) && !isDev(x));
if (failing.length) {
  md += `## Comprobaciones que no pasaron\n\nCada fallo lleva su **síntoma** (lo que dice su propio texto), su **causa** (\`determinada\` solo si la ejecución registró la evidencia; si no, \`no determinada\`), la **evidencia** y la **repetición** que repite esa misma comprobación sobre el mismo árbol de código. Las ejecuciones fallidas se conservan, no se editan.\n\n`;
  for (const x of failing) {
    md += `### ${link(x)} — ${x.r.startedAt.slice(0, 19)}Z, árbol \`${short(x.tree)}\`\n\n`;
    for (const c of x.r.checks.filter((y) => !y.pass)) {
      const cause = causeOf(x, c);
      const retries = retriesOf(x, c);
      md += `- **${c.name}**\n  - síntoma: ${symptom(c)}\n  - causa: ${cause.state} — ${cause.text}\n  - evidencia: \`${c.detail.slice(0, 300).replace(/`/g, "'")}\`\n  - repetición equivalente: ${retries.length ? retries.map((y) => `${link(y)} (${y.r.startedAt.slice(0, 19)}Z, la misma comprobación pasó con el mismo árbol)`).join('; ') : 'sin repetición equivalente'}\n`;
    }
    md += '\n';
  }
}

const controls = runs.filter((x) => isControl(x) && !isDev(x));
if (controls.length) {
  md += `## Controles negativos (se espera que fallen)\n\nCada control reintroduce a propósito un defecto (hoja de estilos inyectada, documento reescrito o guion previo servido) y declara qué aserción concreta debe fallar. **Solo cuenta como detectado** si esa aserción falló como aserción, sin error del guion y sin que el fallo sea un tiempo de espera o una página de error; un fallo cualquiera, una ejecución incompleta o un error no bastan.\n\n`;
  for (const x of controls) {
    const verdict = judgeControl(x);
    const how = x.r.control ? `scripts previos: ${x.r.control.oldAssets.join(', ') || '—'}; reescritura: ${x.r.control.rewrite || '—'}; CSS inyectado: ${x.r.control.injectCss ? `\`${x.r.control.injectCss.slice(0, 120)}\`` : '—'}` : `CSS inyectado: \`${(x.r.injectCss || '').slice(0, 120)}\``;
    md += `- **${x.r.run}** (${link(x)}, árbol \`${short(x.tree)}\`): ${verdict.detected ? `**detectado** — ${verdict.expectations} aserción(es) esperada(s) fallaron como aserciones` : `**NO detectado / no verificable** — ${verdict.reasons.join('; ')}`}. ${how}\n`;
    for (const c of x.r.checks.filter((y) => !y.pass).slice(0, 2)) md += `  - ${c.name} — ${c.detail.slice(0, 200)}\n`;
  }
}

const dev = runs.filter((x) => isDev(x));
if (dev.length) md += `\n## Ejecuciones de desarrollo (no cuentan)\n\n${dev.map((x) => `- ${link(x)} — ${x.r.summary.passed}/${x.r.summary.checks}, ${x.r.status}`).join('\n')}\n`;

const notes = runs.filter((x) => !isDev(x)).flatMap((x) => (x.r.notes ?? []).map((n) => `- (${x.r.run}) ${n}`));
if (notes.length) md += `\n## Notas registradas por las ejecuciones\n\n${[...new Set(notes)].join('\n')}\n`;

writeFileSync(path.join(staging, 'RUNS.md'), md);
writeFileSync(path.join(staging, 'runs-summary.json'), `${JSON.stringify({ ...summary, controls: controls.map((x) => ({ run: x.r.run, dir: x.dir, ...judgeControl(x) })) }, null, 2)}\n`);
console.log(`RUNS.md: ${runs.length} ejecuciones (${runs.filter(isDev).length} de desarrollo, ${controls.length} controles), ${failing.length} con comprobaciones fallidas`);

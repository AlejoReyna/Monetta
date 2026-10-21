// Full verification: build, serve dist/, then run identity, layout,
// journey and accessibility checks in an installed Chromium-based browser.
//
//   npm run verify                       # build + all checks
//   npm run verify -- --skip-build       # reuse dist/
//   npm run verify -- --only=reaudit     # identity | layout | journeys | a11y | fidelity | fixes | reaudit
//   npm run verify -- --out=../docs/web-redesign/evidence
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch } from './browser.mjs';
import { checkA11y } from './check-a11y.mjs';
import { checkAuditFixes } from './check-audit-fixes.mjs';
import { checkReauditFixes } from './check-reaudit-fixes.mjs';
import { checkFidelity } from './check-fidelity.mjs';
import { checkIdentity } from './check-identity.mjs';
import { checkJourneys } from './check-journeys.mjs';
import { checkLayout } from './check-layout.mjs';
import { createReport } from './report.mjs';
import { build, startPreview } from './server.mjs';

const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const [key, value = 'true'] = arg.replace(/^--/, '').split('=');
    return [key, value];
  }),
);
const root = fileURLToPath(new URL('..', import.meta.url));
const outDir = path.resolve(root, args.out ?? 'verify/output');
const only = args.only ? new Set(args.only.split(',')) : null;
const wanted = (name) => !only || only.has(name);

const started = Date.now();
if (!args['skip-build']) {
  process.stdout.write('Building… ');
  await build();
  console.log('done');
}
const server = await startPreview(Number(args.port ?? 4173));
const { browser, executablePath, version } = await launch();
console.log(`Browser: ${executablePath} (${version})\nServing: ${server.url}`);

const report = createReport();
const extras = {};
try {
  if (wanted('identity')) await checkIdentity({ browser, url: server.url, report });
  if (wanted('layout')) extras.layout = await checkLayout({ browser, url: server.url, report });
  if (wanted('journeys')) await checkJourneys({ browser, url: server.url, report });
  if (wanted('a11y')) extras.a11y = await checkA11y({ browser, url: server.url, report });
  if (wanted('fidelity')) await checkFidelity({ browser, url: server.url, report });
  if (wanted('fixes')) await checkAuditFixes({ browser, url: server.url, report });
  if (wanted('reaudit')) await checkReauditFixes({ browser, url: server.url, report });
} finally {
  await browser.close();
  server.stop();
}

report.check('D10', 'No console errors, page errors or failed requests during the checks', report.problems.length === 0, report.problems.slice(0, 10).join(' | ') || 'none');

const failed = report.results.filter((result) => !result.passed);
const byGate = {};
for (const result of report.results) {
  byGate[result.gate] ??= { passed: 0, failed: 0 };
  byGate[result.gate][result.passed ? 'passed' : 'failed'] += 1;
}
const summary = {
  finishedAt: new Date().toISOString(),
  durationSeconds: Math.round((Date.now() - started) / 1000),
  browser: { executablePath, version },
  node: process.version,
  totals: { checks: report.results.length, passed: report.results.length - failed.length, failed: failed.length },
  byGate,
  results: report.results,
  problems: report.problems,
  ...extras,
};
await mkdir(outDir, { recursive: true });
await writeFile(path.join(outDir, 'verify-report.json'), `${JSON.stringify(summary, null, 2)}\n`);

for (const result of report.results) console.log(`${result.passed ? 'PASS' : 'FAIL'} [${result.gate}] ${result.name}${result.passed ? '' : ` — ${result.details}`}`);
console.log(`\n${summary.totals.passed}/${summary.totals.checks} checks passed in ${summary.durationSeconds}s · ${Object.entries(byGate).map(([gate, count]) => `${gate} ${count.passed}/${count.passed + count.failed}`).join(' · ')}`);
console.log(`Report: ${path.relative(process.cwd(), path.join(outDir, 'verify-report.json'))}`);
process.exitCode = failed.length ? 1 : 0;

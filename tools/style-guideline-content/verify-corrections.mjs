#!/usr/bin/env node
// Reproduce the independent review before/after without restoring files via Git.
// Only our Node auditor is executed. Inputs and original source capture stay frozen.
import { readFile, writeFile, mkdir, copyFile, readdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { audit, sha256, AUDIT_VERSION } from './lib/auditor.mjs';
import { loadInputs } from './audit.mjs';
import { defaultDataDir as dataDir, repoRoot, toolDir } from './capture-sources.mjs';

const correctionDir = path.join(dataDir, 'reports/correction-1.0.1');
const archiveDir = path.join(dataDir, 'reports/archive/initial-1.0.0');
const json = async filename => JSON.parse(await readFile(filename, 'utf8'));
const archived = await json(path.join(archiveDir, 'archive-manifest.json'));
const oldAudit = (await import(pathToFileURL(path.join(archiveDir, 'implementation/lib/auditor.mjs')).href)).audit;
const oldContract = await json(path.join(archiveDir, 'inputs/content-contract.v1.schema.json'));

async function preserved() {
  const frozen = [];
  for (const item of [...archived.frozenInputs, archived.unchangedOriginalTest]) {
    const currentSha256 = sha256(await readFile(path.join(repoRoot, item.path)));
    frozen.push({ ...item, currentSha256, unchanged: currentSha256 === item.sha256 });
  }
  const archive = [];
  for (const item of archived.files) {
    const currentSha256 = sha256(await readFile(path.join(archiveDir, item.archived)));
    archive.push({ path: item.archived, sha256: item.sha256, currentSha256, unchanged: currentSha256 === item.sha256 });
  }
  if ([...frozen, ...archive].some(item => !item.unchanged)) throw new Error('Frozen inputs, original 35-test file or archived deliverables changed.');
  return { frozen, archive };
}

const cases = [
  { id: 'catalog-mode-crossing', mutation: 'bags-suggested.destination.routeId = catalog.bags-wholesale', expectedCodes: ['CATALOG_MODE_MISMATCH', 'WHOLESALE_DESTINATION_PUBLIC_SHARE'],
    change: input => { input.baseline.content.catalogs.find(c => c.id === 'bags-suggested').destination.routeId = 'catalog.bags-wholesale'; } },
  { id: 'catalog-category-crossing', mutation: 'bags-wholesale.destination.routeId = catalog.perfume-wholesale', expectedCodes: ['CATALOG_CATEGORY_MISMATCH'],
    change: input => { input.baseline.content.catalogs.find(c => c.id === 'bags-wholesale').destination.routeId = 'catalog.perfume-wholesale'; } },
  { id: 'collection-without-route', mutation: 'todays-picks.source.kind = collection; delete source.routeId', expectedCodes: ['SCHEMA_ANY_OF_MISMATCH', 'SELECTION_ROUTE_REQUIRED'],
    change: input => { const source = input.baseline.content.productSelections['todays-picks'].source; source.kind = 'collection'; delete source.routeId; } },
  { id: 'module-family-crossing', mutation: 'home.moduleOrder = [{id:newest,kind:product_selection,contentRef:rewards}]', expectedCodes: ['SCHEMA_ANY_OF_MISMATCH', 'HOME_MODULE_FAMILY_MISMATCH'],
    change: input => { input.baseline.content.home = { moduleOrder: [{ id: 'newest', kind: 'product_selection', contentRef: 'rewards' }] }; } },
];
function observations(input, run) {
  const base = run(input);
  const known = new Set(base.findings.map(finding => JSON.stringify(finding)));
  return { auditVersion: base.auditVersion, baseline: { inputSha256: base.inputSha256, summary: base.summary }, cases: cases.map(example => {
    const copy = structuredClone(input);
    example.change(copy);
    const result = run(copy);
    return { id: example.id, mutation: example.mutation, expectedCodes: example.expectedCodes, summary: result.summary,
      newFindings: result.findings.filter(finding => !known.has(JSON.stringify(finding))) };
  }) };
}

const initialPreservation = await preserved();
await mkdir(correctionDir, { recursive: true });
const testFiles = (await readdir(path.join(toolDir, 'test'))).filter(filename => filename.endsWith('.test.mjs')).sort().map(filename => path.join(toolDir, 'test', filename));
const testRun = spawnSync(process.execPath, ['--test', '--test-reporter=tap', ...testFiles], { cwd: repoRoot, encoding: 'utf8', timeout: 30000, maxBuffer: 2 * 1024 * 1024 });
await writeFile(path.join(correctionDir, 'tests.tap'), testRun.stdout ?? '');
if (testRun.status !== 0) throw new Error(`Correction tests failed: ${testRun.error?.message ?? testRun.stderr ?? testRun.status}`);
const input = await loadInputs(dataDir);
const before = observations({ ...structuredClone(input), contract: oldContract }, oldAudit);
const after = observations(input, audit);
for (const example of before.cases) if (example.newFindings.length) throw new Error(`Original reproduction no longer matches the recorded gap: ${example.id}.`);
for (const example of after.cases) for (const code of example.expectedCodes) if (!example.newFindings.some(finding => finding.code === code)) throw new Error(`Regression is undetected: ${example.id}/${code}.`);
await mkdir(correctionDir, { recursive: true });
await writeFile(path.join(correctionDir, 'reproductions-after.json'), `${JSON.stringify({ comparedAt: new Date().toISOString(), before, after }, null, 2)}\n`);

const lines = ['# Reproducciones de la revisión independiente', '', `Auditor anterior: ${before.auditVersion}. Auditor corregido: ${after.auditVersion}.`, '',
  'Las mutaciones sólo se aplican en memoria. La baseline y los snapshots permanecen congelados.', '',
  '| Reproducción | Antes: errores/avisos | Hallazgos nuevos antes | Después: errores/avisos | Hallazgos nuevos después |', '| --- | --- | --- | --- | --- |'];
for (const example of after.cases) {
  const old = before.cases.find(item => item.id === example.id);
  lines.push(`| ${example.id} | ${old.summary.error}/${old.summary.warning} | ${old.newFindings.length} | ${example.summary.error}/${example.summary.warning} | ${example.newFindings.map(finding => finding.code).join(', ')} |`);
}
for (const example of after.cases) {
  lines.push('', `## ${example.id}`, '', `Mutación: \`${example.mutation}\`.`, '');
  for (const finding of example.newFindings) lines.push(`- **${finding.code}** en \`${finding.path}\`: ${finding.message}`);
}
await writeFile(path.join(correctionDir, 'reproductions.md'), `${lines.join('\n')}\n`);

function cli(directory, flags = []) {
  const result = spawnSync(process.execPath, [path.join(toolDir, 'audit.mjs'), ...flags, '--out-dir', directory], { cwd: repoRoot, encoding: 'utf8', timeout: 30000 });
  return { command: ['node', 'tools/style-guideline-content/audit.mjs', ...flags, '--out-dir', path.relative(repoRoot, directory)], exitCode: result.status, stdout: result.stdout, stderr: result.stderr, error: result.error?.message };
}
const offlineDir = path.join(correctionDir, 'offline');
const first = cli(offlineDir);
const firstJson = await readFile(path.join(offlineDir, 'audit.json'));
const firstMarkdown = await readFile(path.join(offlineDir, 'audit.md'));
const second = cli(offlineDir);
const secondJson = await readFile(path.join(offlineDir, 'audit.json'));
const secondMarkdown = await readFile(path.join(offlineDir, 'audit.md'));
const strict = cli(path.join(correctionDir, 'strict'), ['--strict']);
const live = cli(path.join(correctionDir, 'live'), ['--live']);
if (first.exitCode !== 0 || second.exitCode !== 0 || strict.exitCode !== 1 || live.exitCode !== 0) throw new Error('Unexpected CLI exit result.');
if (!firstJson.equals(secondJson) || !firstMarkdown.equals(secondMarkdown)) throw new Error('Offline outputs are not byte-identical.');
const report = JSON.parse(secondJson);
const liveReport = await json(path.join(correctionDir, 'live/audit.json'));
const implementation = [];
async function codeFiles(directory) {
  const found = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory() && !entry.name.startsWith('.')) found.push(...await codeFiles(full));
    else if (entry.isFile() && /\.(?:mjs|json|dart|md)$/u.test(entry.name)) found.push(full);
  }
  return found.sort();
}
for (const file of [...await codeFiles(toolDir), path.join(dataDir, 'content-contract.v1.schema.json')]) implementation.push({ path: path.relative(repoRoot, file), sha256: sha256(await readFile(file)) });
const preservation = await preserved();
const tests = await readFile(path.join(correctionDir, 'tests.tap'), 'utf8');
const redTests = await readFile(path.join(correctionDir, 'regressions-before.tap'), 'utf8');
const result = { checkedAt: new Date().toISOString(), auditorVersion: AUDIT_VERSION, contractVersion: report.contractVersion,
  archivedDelivery: 'reports/archive/initial-1.0.0',
  jsonByteIdentical: true, markdownByteIdentical: true, jsonSha256: sha256(secondJson), markdownSha256: sha256(secondMarkdown),
  inputSha256: report.inputSha256, summary: report.summary,
  tests: { total: Number(tests.match(/^# tests (\d+)$/mu)?.[1]), passed: Number(tests.match(/^# pass (\d+)$/mu)?.[1]), failed: Number(tests.match(/^# fail (\d+)$/mu)?.[1]), originalTestsPreserved: 35,
    newTestsAgainstPreviousImplementation: { total: Number(redTests.match(/^# tests (\d+)$/mu)?.[1]), failed: Number(redTests.match(/^# fail (\d+)$/mu)?.[1]) } },
  commands: { tests: { command: ['node', '--test', '--test-reporter=tap', ...testFiles.map(file => path.relative(repoRoot, file))], exitCode: testRun.status }, first, second, strict, live }, normalExitCode: second.exitCode, strictExitCode: strict.exitCode,
  liveComparison: { interpretation: 'Posterior local comparison only; the original capture and offline capability/content facts were not refreshed.', comparedAt: liveReport.liveComparison.comparedAt, sourceCount: liveReport.liveComparison.sources.length, changes: liveReport.liveComparison.sources.filter(source => source.status !== 'unchanged') },
  preservation: { before: initialPreservation, after: preservation }, implementation };
if (result.tests.failed !== 0 || result.tests.total !== result.tests.passed) throw new Error('Correction test run is not passing.');
await writeFile(path.join(correctionDir, 'verification.json'), `${JSON.stringify(result, null, 2)}\n`);
await writeFile(path.join(dataDir, 'reports/reproducibility.json'), `${JSON.stringify(result, null, 2)}\n`);
for (const directory of ['offline', 'live']) {
  await mkdir(path.join(dataDir, 'reports', directory), { recursive: true });
  for (const filename of ['audit.json', 'audit.md']) await copyFile(path.join(correctionDir, directory, filename), path.join(dataDir, 'reports', directory, filename));
}
await copyFile(path.join(correctionDir, 'tests.tap'), path.join(dataDir, 'reports/tests.tap'));
console.log(JSON.stringify({ auditorVersion: result.auditorVersion, errors: report.summary.error, warnings: report.summary.warning,
  tests: result.tests, originalFrozenInputsPreserved: preservation.frozen.length, archivedFilesPreserved: preservation.archive.length,
  reproductions: after.cases.map(example => ({ id: example.id, newCodes: example.newFindings.map(finding => finding.code) })),
  liveComparison: result.liveComparison, jsonByteIdentical: true, markdownByteIdentical: true }, null, 2));

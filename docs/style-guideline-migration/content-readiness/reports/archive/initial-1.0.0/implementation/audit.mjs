#!/usr/bin/env node
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { audit, renderReport, sha256 } from './lib/auditor.mjs';
import { repoRoot, defaultDataDir } from './capture-sources.mjs';

export async function loadInputs(dataDir) {
  const json = async name => JSON.parse(await readFile(path.join(dataDir, name), 'utf8'));
  const [contract, baseline, routeMap, requirements, fieldMap, manifest] = await Promise.all([
    json('content-contract.v1.schema.json'), json('content-baseline.json'), json('route-map.json'),
    json('screen-requirements.json'), json('field-map.json'), json('evidence/source-manifest.json'),
  ]);
  const snapshots = {};
  for (const source of manifest.sources) if (source.snapshot) {
    const snapshotPath = path.resolve(dataDir, 'evidence', source.snapshot);
    if (!snapshotPath.startsWith(`${path.resolve(dataDir, 'evidence', 'snapshots')}${path.sep}`)) throw new Error('Snapshot outside evidence/snapshots.');
    try { snapshots[source.path] = await readFile(snapshotPath, 'utf8'); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  return { contract, baseline, routeMap, requirements, fieldMap, manifest, snapshots };
}

export async function compareLive(manifest, root = repoRoot) {
  const sources = [];
  for (const source of manifest.sources) {
    try {
      const hash = sha256(await readFile(path.resolve(root, source.path)));
      sources.push({ path: source.path, status: hash === source.sha256 ? 'unchanged' : 'changed_since_capture', capturedSha256: source.sha256, currentSha256: hash });
    } catch (error) {
      sources.push({ path: source.path, status: error.code === 'ENOENT' ? 'missing_locally' : 'unreadable', capturedSha256: source.sha256 });
    }
  }
  return { comparedAt: new Date().toISOString(), sources };
}

export async function main(argv = process.argv.slice(2)) {
  let dataDir = defaultDataDir;
  let outputDir;
  let live = false;
  let strict = false;
  for (let i = 0; i < argv.length; i++) {
    const argument = argv[i];
    if (argument === '--help') {
      console.log('Usage: node tools/style-guideline-content/audit.mjs [--data-dir DIR] [--out-dir DIR] [--live] [--strict]\nOffline by default. --live only compares local SHA-256 hashes. No HTTP requests.\nExit: 0 report written, 1 --strict with unresolved findings/drift, 2 usage/input/process error.');
      return 0;
    }
    if (argument === '--live') live = true;
    else if (argument === '--strict') strict = true;
    else if (['--data-dir', '--out-dir'].includes(argument)) {
      const value = argv[++i];
      if (!value || value.startsWith('--')) throw new Error(`Missing value for ${argument}.`);
      if (argument === '--data-dir') dataDir = path.resolve(value);
      else outputDir = path.resolve(value);
    } else throw new Error(`Unknown argument ${argument}.`);
  }
  outputDir ??= path.join(dataDir, live ? 'reports/live' : 'reports/offline');
  // Every write by this task stays inside the authorized tools/docs areas.
  const allowed = [path.resolve(repoRoot, 'tools/style-guideline-content'), defaultDataDir];
  if (!allowed.some(base => outputDir.startsWith(`${base}${path.sep}`))) throw new Error('Output must stay inside tools/style-guideline-content/ or docs/style-guideline-migration/content-readiness/.');
  const input = await loadInputs(dataDir);
  const report = audit(input);
  if (live) report.liveComparison = await compareLive(input.manifest);
  await mkdir(outputDir, { recursive: true });
  await writeFile(path.join(outputDir, 'audit.json'), `${JSON.stringify(report, null, 2)}\n`);
  await writeFile(path.join(outputDir, 'audit.md'), renderReport(report));
  console.log(`${report.summary.error} readiness errors; ${report.summary.warning} warnings; ${report.summary.routes.total} routes; ${report.coverage.length} PDF pages.\nReports: ${path.relative(repoRoot, outputDir)}/audit.{json,md}`);
  const drift = report.liveComparison?.sources.some(source => source.status !== 'unchanged');
  return strict && (!report.ready || drift) ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.exitCode = await main(); }
  catch (error) { console.error(`Content audit failed: ${error.message}`); process.exitCode = 2; }
}

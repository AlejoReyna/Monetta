#!/usr/bin/env node
// Explicit, local, read-only capture of public project sources. No network calls.
import { readFile, writeFile, mkdir, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const toolDir = path.dirname(fileURLToPath(import.meta.url));
export const repoRoot = path.resolve(toolDir, '../..');
export const defaultDataDir = path.join(repoRoot, 'docs/style-guideline-migration/content-readiness');
export const sha256 = value => createHash('sha256').update(value).digest('hex');

export async function captureSources(list, outputDir, { previous = null } = {}) {
  await mkdir(path.join(outputDir, 'snapshots'), { recursive: true });
  const sources = [];
  for (const entry of list) {
    // Existing captures are immutable: a concurrent edit is detected by audit --live.
    const prior = previous?.sources.find(source => source.path === entry.path);
    if (prior) { sources.push(prior); continue; }
    const filename = path.resolve(repoRoot, entry.path);
    const buffer = await readFile(filename);
    const metadata = await stat(filename);
    const digest = sha256(buffer);
    const snapshot = entry.kind === 'text' ? `snapshots/${digest}.txt` : null;
    if (snapshot) await writeFile(path.join(outputDir, snapshot), buffer);
    sources.push({ path: entry.path, kind: entry.kind, capturedAt: new Date().toISOString(),
      mtime: metadata.mtime.toISOString(), size: buffer.length, sha256: digest, snapshot });
  }
  sources.sort((a, b) => a.path.localeCompare(b.path, 'en'));
  const manifest = { schemaVersion: '1.0.0', algorithm: 'sha256',
    captureStartedAt: previous?.captureStartedAt ?? sources[0]?.capturedAt,
    captureCompletedAt: new Date().toISOString(), sources };
  await writeFile(path.join(outputDir, 'source-manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  return manifest;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const list = JSON.parse(await readFile(path.join(toolDir, 'source-list.json'), 'utf8'));
  const outputDir = path.join(defaultDataDir, 'evidence');
  let previous;
  try { previous = JSON.parse(await readFile(path.join(outputDir, 'source-manifest.json'), 'utf8')); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const manifest = await captureSources(list, outputDir, { previous });
  console.log(`Captured ${manifest.sources.length} sources in ${path.relative(repoRoot, outputDir)} (existing captures preserved).`);
}

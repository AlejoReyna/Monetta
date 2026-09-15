import { mkdir, readFile, writeFile, access, rename } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(__dirname, '../../..');
export const AUDIT_RUNS_DIR = path.join(REPO_ROOT, '.audit-runs');

export function runDir(runId) {
  return path.join(AUDIT_RUNS_DIR, runId);
}

export function manifestPath(runId) {
  return path.join(runDir(runId), 'manifest.json');
}

export async function ensureRunDir(runId) {
  const dir = runDir(runId);
  await mkdir(dir, { recursive: true });
  return dir;
}

export function emptyManifest({ runId, prefix, environment, expectedShopId }) {
  return {
    version: 1,
    audit_run_id: runId,
    resource_prefix: prefix,
    environment: environment || 'local',
    expected_shop_id: expectedShopId || null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    cleanup_status: 'pending', // pending | partial | cleaned | dry-run-only
    resources: [],
    notes: [],
  };
}

/**
 * @typedef {object} ManifestResource
 * @property {string} id - Stable fixture key (e.g. persona:G, product:two-variants)
 * @property {string} kind - persona | product | variant | collection | order | metaobject | account | other
 * @property {string} [remote_id] - Shopify GID / DB UUID once created
 * @property {string} [local_id]
 * @property {string} status - planned | seeded | cleaned | skipped | failed
 * @property {string} [environment]
 * @property {object} [meta]
 */

export async function readManifest(runId) {
  const p = manifestPath(runId);
  const raw = await readFile(p, 'utf8');
  return JSON.parse(raw);
}

export async function writeManifest(runId, manifest) {
  await ensureRunDir(runId);
  manifest.updated_at = new Date().toISOString();
  const p = manifestPath(runId);
  const temp = `${p}.${process.pid}.tmp`;
  await writeFile(temp, `${JSON.stringify(manifest, null, 2)}\n`, {encoding: 'utf8', mode: 0o600});
  await rename(temp, p);
  return p;
}

export async function manifestExists(runId) {
  try {
    await access(manifestPath(runId));
    return true;
  } catch {
    return false;
  }
}

export function upsertResource(manifest, resource) {
  const idx = manifest.resources.findIndex((r) => r.id === resource.id);
  if (idx >= 0) {
    manifest.resources[idx] = { ...manifest.resources[idx], ...resource };
  } else {
    manifest.resources.push(resource);
  }
  return manifest;
}

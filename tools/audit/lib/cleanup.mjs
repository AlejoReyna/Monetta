import { withRunLock } from './runLock.mjs';
import { ShopifyAuditAdapter } from './shopifyAdapter.mjs';
import { readManifest, writeManifest, upsertResource, manifestExists } from './manifest.mjs';
import { assertValidRunId } from './runId.mjs';
import { assertRemoteWriteAllowed, loadGuardConfig } from './guards.mjs';

/**
 * Cleanup acts ONLY on resources listed in the run manifest.
 * Never unqualified delete-all against a shared DB or Shopify store.
 */
async function cleanupRunUnlocked({ runId, forceLive = false }) {
  assertValidRunId(runId);

  if (!(await manifestExists(runId))) {
    throw new Error(
      `No manifest for run ${runId} at .audit-runs/${runId}/manifest.json. ` +
        'Cleanup refuses to run without a manifest (no delete-all).',
    );
  }

  const config = loadGuardConfig();
  let writeDecision;
  try {
    writeDecision = assertRemoteWriteAllowed(
      forceLive ? { ...config, dryRun: false } : config,
    );
  } catch (err) {
    writeDecision = { allowed: false, reason: err.message, refused: true };
  }

  const liveWrite = Boolean(writeDecision.allowed) && forceLive && !config.dryRun;
  if (forceLive && !liveWrite) {
    throw new Error(
      `Refusing live cleanup: ${writeDecision.reason || writeDecision.refused || 'guards'}. ` +
        'Cleanup without --live only marks planned cleanup against the manifest.',
    );
  }

  const manifest = await readManifest(runId);
  if (!Array.isArray(manifest.resources) || manifest.resources.length === 0) {
    manifest.cleanup_status = 'cleaned';
    manifest.notes = manifest.notes || [];
    manifest.notes.push({
      at: new Date().toISOString(),
      event: 'cleanup-empty-manifest',
      message: 'No resources listed; nothing to delete.',
    });
    const path = await writeManifest(runId, manifest);
    return { runId, manifestPath: path, cleaned: 0, skipped: 0, mode: 'empty' };
  }

  const adapter = liveWrite ? new ShopifyAuditAdapter() : null;
  if (adapter) {
    const identity = await adapter.verify();
    if (manifest.verified_shop?.id !== identity.id) throw new Error('Cleanup shop does not match verified run');
  }
  let cleaned = 0;
  let skipped = 0;
  // Orders first, then products/collections, then customer records.
  const resources = [...manifest.resources].sort((a,b) => (a.kind === 'order' ? -1 : 0) - (b.kind === 'order' ? -1 : 0));
  for (const resource of resources) {
    if (!adapter || resource.status !== 'created' || !resource.remote_id) { skipped++; continue; }
    if (await adapter.remove(resource)) {
      upsertResource(manifest, {...resource, status: 'cleaned'});
      await writeManifest(runId, manifest);
      cleaned++;
    } else { skipped++; }
  }
  manifest.cleanup_status = liveWrite
    ? manifest.resources.some(r => r.status === 'created') ? 'partial' : 'cleaned'
    : 'dry-run-only';
  manifest.notes = manifest.notes || [];
  manifest.notes.push({
    at: new Date().toISOString(),
    event: liveWrite ? 'cleanup-live' : 'cleanup-dry-run',
    writeDecision,
    policy: 'manifest-only',
  });

  const path = await writeManifest(runId, manifest);
  return {
    runId,
    manifestPath: path,
    cleaned,
    skipped,
    resourceCount: manifest.resources.length,
    mode: liveWrite ? 'live' : 'dry-run',
    writeDecision,
  };
}

export async function cleanupRun(args) {
  return withRunLock(args.runId, () => cleanupRunUnlocked(args));
}

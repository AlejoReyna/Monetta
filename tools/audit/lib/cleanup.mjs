import { readManifest, writeManifest, upsertResource, manifestExists } from './manifest.mjs';
import { assertValidRunId } from './runId.mjs';
import { assertRemoteWriteAllowed, loadGuardConfig } from './guards.mjs';

/**
 * Cleanup acts ONLY on resources listed in the run manifest.
 * Never unqualified delete-all against a shared DB or Shopify store.
 */
export async function cleanupRun({ runId, forceLive = false }) {
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

  let cleaned = 0;
  let skipped = 0;

  for (const resource of manifest.resources) {
    // Manifest-only policy: never invent targets. Only listed IDs.
    if (!resource.remote_id && !resource.local_id) {
      upsertResource(manifest, {
        ...resource,
        status: liveWrite ? 'cleaned' : 'planned',
        meta: {
          ...resource.meta,
          cleanup_mode: liveWrite ? 'live-adapter-pending-no-remote-id' : 'dry-run',
          cleanup_note: 'No remote_id/local_id recorded; nothing remote to delete.',
        },
      });
      skipped += 1;
      continue;
    }

    // Live adapters not yet wired — refuse silent remote deletes even with IDs
    // until adapters exist. Record intent only.
    upsertResource(manifest, {
      ...resource,
      status: liveWrite ? 'skipped' : resource.status,
      meta: {
        ...resource.meta,
        cleanup_mode: liveWrite ? 'live-adapter-pending' : 'dry-run',
        cleanup_note:
          'Adapter pending: would delete ONLY this manifest-listed resource, never delete-all.',
      },
    });
    cleaned += liveWrite ? 0 : 0;
    skipped += 1;
  }

  const anyRemote = manifest.resources.some((r) => r.remote_id || r.local_id);
  manifest.cleanup_status = liveWrite
    ? anyRemote
      ? 'partial'
      : 'cleaned'
    : 'dry-run-only';
  manifest.notes = manifest.notes || [];
  manifest.notes.push({
    at: new Date().toISOString(),
    event: liveWrite ? 'cleanup-live-stub' : 'cleanup-dry-run',
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
    mode: liveWrite ? 'live-adapter-pending' : 'dry-run',
    writeDecision,
  };
}

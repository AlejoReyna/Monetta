import { planPersonaResources } from './personas.mjs';
import { planCatalogOrderResources } from './fixtures.mjs';
import {
  emptyManifest,
  upsertResource,
  writeManifest,
  readManifest,
  manifestExists,
} from './manifest.mjs';
import { resourcePrefix, assertValidRunId } from './runId.mjs';
import { assertRemoteWriteAllowed, loadGuardConfig, describeGuardStatus } from './guards.mjs';

/**
 * Seed scaffolding: always updates the local gitignored manifest.
 * Remote writes are refused unless allowlist + EXPECTED_SHOP_ID match and
 * AUDIT_ALLOW_REMOTE_WRITES=1 with AUDIT_DRY_RUN=0.
 */
export async function seedRun({
  runId,
  environment = process.env.AUDIT_ENVIRONMENT || 'local',
  forceLive = false,
}) {
  assertValidRunId(runId);
  const prefix = resourcePrefix(runId);
  const config = loadGuardConfig();
  const guardProbe = describeGuardStatus(config);

  let writeDecision;
  try {
    writeDecision = assertRemoteWriteAllowed(
      forceLive
        ? { ...config, dryRun: false }
        : config,
    );
  } catch (err) {
    // Dry-run / plan mode still works when live writes would be refused —
    // but we never perform remote writes on failure.
    writeDecision = { allowed: false, reason: err.message, refused: true };
  }

  const liveWrite = Boolean(writeDecision.allowed) && forceLive && !config.dryRun;
  if (forceLive && !liveWrite) {
    const reason =
      writeDecision.reason ||
      writeDecision.refused ||
      'guards refused remote write';
    throw new Error(
      `Refusing live seed write: ${typeof reason === 'string' ? reason : JSON.stringify(writeDecision)}. ` +
        'Default is dry-run. Set EXPECTED_SHOP_ID, AUDIT_SHOP_ALLOWLIST (exact match), ' +
        'AUDIT_ALLOW_REMOTE_WRITES=1, and AUDIT_DRY_RUN=0 only for authorized development shops.',
    );
  }

  let manifest;
  if (await manifestExists(runId)) {
    manifest = await readManifest(runId);
  } else {
    manifest = emptyManifest({
      runId,
      prefix,
      environment,
      expectedShopId: config.expectedShopId || null,
    });
  }

  manifest.environment = environment;
  manifest.expected_shop_id = config.expectedShopId || manifest.expected_shop_id;
  manifest.resource_prefix = prefix;
  manifest.notes = manifest.notes || [];
  manifest.notes.push({
    at: new Date().toISOString(),
    event: liveWrite ? 'seed-live' : 'seed-dry-run',
    guard: guardProbe,
    writeDecision,
  });

  for (const resource of [
    ...planPersonaResources(prefix),
    ...planCatalogOrderResources(prefix),
  ]) {
    const status = liveWrite ? 'seeded' : 'planned';
    // Live adapters are not implemented yet — even "live" marks planned stubs
    // and records that remote adapters must be filled in later. Never invent
    // remote IDs.
    upsertResource(manifest, {
      ...resource,
      status: liveWrite ? 'skipped' : status,
      environment,
      meta: {
        ...resource.meta,
        seed_mode: liveWrite ? 'live-adapter-pending' : 'dry-run',
        remote_write_attempted: false,
      },
    });
  }

  if (!liveWrite) {
    manifest.cleanup_status = 'dry-run-only';
  }

  const path = await writeManifest(runId, manifest);
  return {
    runId,
    prefix,
    manifestPath: path,
    liveWrite,
    resourceCount: manifest.resources.length,
    guard: guardProbe,
    writeDecision,
  };
}

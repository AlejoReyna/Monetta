import { withRunLock } from './runLock.mjs';
import { ShopifyAuditAdapter } from './shopifyAdapter.mjs';
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
async function seedRunUnlocked({
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

  const adapter = liveWrite ? new ShopifyAuditAdapter() : null;
  if (adapter) {
    const identity = await adapter.verify();
    if (manifest.verified_shop && manifest.verified_shop.id !== identity.id) throw new Error('Run belongs to another shop');
    manifest.verified_shop = identity;
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
    const existing = manifest.resources.find(r => r.id === resource.id);
    if (existing?.status === 'created') continue;
    if (!adapter) {
      if (!existing) upsertResource(manifest, {...resource, status: 'planned', environment});
      continue;
    }
    const target = existing ?? resource;
    // Persist write intent first. If the process dies after Shopify commits,
    // recover by exact run tag, never blindly create a second resource.
    upsertResource(manifest, {...target, status: 'creating', environment});
    await writeManifest(runId, manifest);
    const result = await adapter.create(target, manifest);
    upsertResource(manifest, {...target, ...result, environment});
    await writeManifest(runId, manifest);

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

export async function seedRun(args) {
  return withRunLock(args.runId, () => seedRunUnlocked(args));
}

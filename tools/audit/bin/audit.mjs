#!/usr/bin/env node
import { ShopifyAuditAdapter } from '../lib/shopifyAdapter.mjs';
import { operateTestOrder, operateTestProduct } from '../lib/orderOperations.mjs';
import { withRunLock } from '../lib/runLock.mjs';
/**
 * Monetta audit fixture CLI — seed/cleanup scaffolding with shop allowlist guards.
 *
 * Usage:
 *   node tools/audit/bin/audit.mjs <command> [options]
 *
 * Commands:
 *   init                 Create audit_run_id + empty manifest
 *   seed [--run-id ID]   Plan/seed fixtures (dry-run by default)
 *   cleanup --run-id ID  Manifest-only cleanup (dry-run by default)
 *   status --run-id ID   Show manifest + guard status
 *   personas             List required persona stubs
 *   guards               Print whether live remote writes would be allowed
 *
 * Live remote writes require ALL of:
 *   EXPECTED_SHOP_ID          exact shop id / *.myshopify.com domain
 *   AUDIT_SHOP_ALLOWLIST      comma-separated allowlist containing EXPECTED_SHOP_ID
 *   AUDIT_ALLOW_REMOTE_WRITES=1
 *   AUDIT_DRY_RUN=0
 *   --live                    CLI flag
 *
 * Hostname substring "staging" is NOT sufficient.
 */

import { generateAuditRunId, resourcePrefix, assertValidRunId } from '../lib/runId.mjs';
import {
  emptyManifest,
  writeManifest,
  readManifest,
  manifestExists,
  ensureRunDir,
  AUDIT_RUNS_DIR,
} from '../lib/manifest.mjs';
import { loadGuardConfig, describeGuardStatus } from '../lib/guards.mjs';
import { PERSONAS } from '../lib/personas.mjs';
import { seedRun } from '../lib/seed.mjs';
import { cleanupRun } from '../lib/cleanup.mjs';
import { writeFile } from 'node:fs/promises';
import path from 'node:path';

function print(obj) {
  process.stdout.write(`${typeof obj === 'string' ? obj : JSON.stringify(obj, null, 2)}\n`);
}

function fail(message, code = 1) {
  process.stderr.write(`error: ${message}\n`);
  process.exit(code);
}

function parseArgs(argv) {
  const args = { _: [], flags: {} };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--live') {
      args.flags.live = true;
    } else if (a === '--run-id' || a === '--run') {
      args.flags.runId = argv[++i];
    } else if (a === '--env' || a === '--environment') {
      args.flags.environment = argv[++i];
    } else if (['--resource','--action','--fulfillment-order-id','--transaction-id','--amount'].includes(a)) {
      args.flags[a.slice(2)] = argv[++i];
    } else if (a === '--help' || a === '-h') {
      args.flags.help = true;
    } else if (a.startsWith('-')) {
      fail(`Unknown flag: ${a}`);
    } else {
      args._.push(a);
    }
  }
  return args;
}

function usage() {
  return `Monetta audit fixture CLI

Commands:
  init [--env local]
  seed [--run-id <id>] [--env local] [--live]
  cleanup --run-id <id> [--live]
  status --run-id <id>
  personas
  guards

Environment (see tools/audit/env.example):
  EXPECTED_SHOP_ID, AUDIT_SHOP_ALLOWLIST, AUDIT_ALLOW_REMOTE_WRITES, AUDIT_DRY_RUN

Default seed/cleanup is dry-run and writes only under .audit-runs/ (gitignored).
`;
}

async function cmdInit(flags) {
  const runId = generateAuditRunId();
  const prefix = resourcePrefix(runId);
  const config = loadGuardConfig();
  const environment = flags.environment || process.env.AUDIT_ENVIRONMENT || 'local';
  await ensureRunDir(runId);
  const manifest = emptyManifest({
    runId,
    prefix,
    environment,
    expectedShopId: config.expectedShopId || null,
  });
  const mPath = await writeManifest(runId, manifest);
  // Convenience pointer for scripts (still gitignored via .audit-runs/)
  await writeFile(
    path.join(AUDIT_RUNS_DIR, 'LATEST'),
    `${runId}\n`,
    'utf8',
  );
  print({
    audit_run_id: runId,
    resource_prefix: prefix,
    manifest: mPath,
    environment,
    guard: describeGuardStatus(config),
  });
}

async function resolveRunId(flags) {
  if (flags.runId) {
    assertValidRunId(flags.runId);
    return flags.runId;
  }
  try {
    const { readFile } = await import('node:fs/promises');
    const latest = (await readFile(path.join(AUDIT_RUNS_DIR, 'LATEST'), 'utf8')).trim();
    assertValidRunId(latest);
    return latest;
  } catch {
    fail('Missing --run-id and no .audit-runs/LATEST. Run `audit init` first.');
  }
}

async function cmdSeed(flags) {
  const runId = await resolveRunId(flags);
  const result = await seedRun({
    runId,
    environment: flags.environment || process.env.AUDIT_ENVIRONMENT || 'local',
    forceLive: Boolean(flags.live),
  });
  print(result);
}

async function cmdCleanup(flags) {
  if (!flags.runId) fail('cleanup requires --run-id <audit_run_id>');
  const result = await cleanupRun({
    runId: flags.runId,
    forceLive: Boolean(flags.live),
  });
  print(result);
}

async function cmdStatus(flags) {
  if (!flags.runId) fail('status requires --run-id <audit_run_id>');
  assertValidRunId(flags.runId);
  const config = loadGuardConfig();
  if (!(await manifestExists(flags.runId))) {
    fail(`No manifest for ${flags.runId}`);
  }
  const manifest = await readManifest(flags.runId);
  print({
    guard: describeGuardStatus(config),
    manifest_summary: {
      audit_run_id: manifest.audit_run_id,
      resource_prefix: manifest.resource_prefix,
      environment: manifest.environment,
      expected_shop_id: manifest.expected_shop_id,
      cleanup_status: manifest.cleanup_status,
      resource_count: manifest.resources?.length ?? 0,
      resources: (manifest.resources || []).map((r) => ({
        id: r.id,
        kind: r.kind,
        status: r.status,
        remote_id: r.remote_id ?? null,
        local_id: r.local_id ?? null,
      })),
    },
  });
}

function cmdPersonas() {
  print(
    Object.values(PERSONAS).map((p) => ({
      code: p.code,
      name: p.name,
      setup: p.setup,
      purpose: p.purpose,
      storage: p.storage,
      seedKind: p.seedKind,
    })),
  );
}

function cmdGuards() {
  print(describeGuardStatus(loadGuardConfig()));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.flags.help || args._.length === 0) {
    print(usage());
    process.exit(args._.length === 0 ? 1 : 0);
  }
  const cmd = args._[0];
  switch (cmd) {
    case 'operate':
      if (!args.flags.live) throw new Error('Explicit --live required for test order operations');
      await withRunLock(args.flags.runId, async () => {
        const manifest = await readManifest(args.flags.runId);
        const adapter = new ShopifyAuditAdapter();
        const identity = await adapter.verify();
        if (manifest.verified_shop?.id !== identity.id) throw new Error('Run shop mismatch');
        const resource = manifest.resources.find(r => r.id === args.flags.resource);
        if (!resource) throw new Error('Resource must be in this run manifest');
        const result = adapter.kind(resource) === 'product'
          ? await operateTestProduct(adapter,resource,args.flags.action)
          : await operateTestOrder(adapter, resource, args.flags.action, {
          fulfillmentOrderId: args.flags['fulfillment-order-id'], transactionId: args.flags['transaction-id'], amount: args.flags.amount,
        });
        resource.meta.operations = [...(resource.meta.operations ?? []), {action:args.flags.action,result,at:new Date().toISOString()}];
        await writeManifest(args.flags.runId,manifest);
        print({runId:args.flags.runId, resource:resource.id, action:args.flags.action, status:'submitted', note:'Confirm asynchronous job/final Shopify state before journey PASS'});
      });
      break;
    case 'init':
      await cmdInit(args.flags);
      break;
    case 'seed':
      await cmdSeed(args.flags);
      break;
    case 'cleanup':
      await cmdCleanup(args.flags);
      break;
    case 'status':
      await cmdStatus(args.flags);
      break;
    case 'personas':
      cmdPersonas();
      break;
    case 'guards':
      cmdGuards();
      break;
    default:
      fail(`Unknown command: ${cmd}\n\n${usage()}`);
  }
}

main().catch((err) => {
  fail(err?.stack || String(err));
});

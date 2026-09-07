# Audit fixture seed / cleanup scaffolding

Repeatable test-environment tooling for Monetta audit remediation (brief §4).

This directory is intentionally **outside** `services/accounts_orders/` so Phase A
security work can proceed in parallel without merge conflicts.

## Safety model

1. **Dry-run by default.** `seed` and `cleanup` only write a gitignored manifest
   under `.audit-runs/<run-id>/manifest.json` unless every live-write gate is open.
2. **Development-shop allowlist + exact shop ID.** Remote writes require
   `EXPECTED_SHOP_ID` to appear **exactly** in `AUDIT_SHOP_ALLOWLIST`.
   A hostname substring such as `staging` is **not** sufficient.
3. **`audit_run_id` + prefix.** Every run gets `audit_run_id` and tags resources
   with `monetta-qa-<run-id>`.
4. **Manifest-only cleanup.** Cleanup never runs an unqualified delete-all. It
   only considers resources listed in that run’s manifest.
5. **No secrets in Git.** Manifests, `.env`, and persona password files are
   gitignored. Use `tools/audit/env.example` as a template.

Live remote Shopify/Admin adapters are **stubs** in this scaffolding: even with
`--live`, the CLI refuses to invent remote IDs and records adapter-pending notes.
Wire real seeders later against the same guards + manifest.

## Prerequisites

- Node.js 24.x (repo engine)
- Docker (optional, for disposable PostgreSQL)
- Flutter / FVM for isolated-storage notes below

## Exact commands

### 0) Configure guards (local, untracked)

```bash
cp tools/audit/env.example tools/audit/.env
# Edit EXPECTED_SHOP_ID and AUDIT_SHOP_ALLOWLIST to your authorized *development* shop.
# Do not point these at production.

set -a && source tools/audit/.env && set +a
```

Or export inline:

```bash
export EXPECTED_SHOP_ID='1234567890'
export AUDIT_SHOP_ALLOWLIST='1234567890,your-dev-shop.myshopify.com'
export AUDIT_ALLOW_REMOTE_WRITES=0
export AUDIT_DRY_RUN=1
export AUDIT_ENVIRONMENT=local
```

Check gates:

```bash
node tools/audit/bin/audit.mjs guards
```

### 1) Disposable local PostgreSQL (audit-only)

Uses host port **5435** so it does not collide with `services/accounts_orders`
compose on **5434**.

```bash
docker compose -f tools/audit/docker-compose.audit-pg.yml up -d
docker compose -f tools/audit/docker-compose.audit-pg.yml ps

# Connection string (also in env.example):
# postgres://monetta_audit:monetta_audit@127.0.0.1:5435/monetta_audit

# Wipe when finished (destroys the audit volume only):
docker compose -f tools/audit/docker-compose.audit-pg.yml down -v
```

Persona **L** (legacy), **U**, **E**, and local principal rows for **O** / **R**
are intended for this disposable DB — not shared production Neon.

### 2) Init a run (creates `audit_run_id` + empty manifest)

```bash
node tools/audit/bin/audit.mjs init --env local
# → prints audit_run_id, resource_prefix monetta-qa-<run-id>, manifest path
# → writes .audit-runs/LATEST
```

### 3) Seed (dry-run default)

Plans all required personas (G, A, B, C, L, O, U, E, R) and catalog/order
fixture stubs into the manifest. **No remote writes.**

```bash
node tools/audit/bin/audit.mjs seed
# or:
node tools/audit/bin/audit.mjs seed --run-id <audit_run_id>
```

List persona stubs:

```bash
node tools/audit/bin/audit.mjs personas
```

Inspect:

```bash
node tools/audit/bin/audit.mjs status --run-id <audit_run_id>
```

### 4) Live seed (refused unless allowlist + shop ID + flags)

```bash
export AUDIT_ALLOW_REMOTE_WRITES=1
export AUDIT_DRY_RUN=0
node tools/audit/bin/audit.mjs seed --run-id <audit_run_id> --live
```

If `EXPECTED_SHOP_ID` is missing or not in `AUDIT_SHOP_ALLOWLIST`, the CLI
**exits non-zero** and does not write remotely.

### 5) Cleanup (manifest-only)

```bash
# Dry-run: updates cleanup notes on manifest-listed rows only
node tools/audit/bin/audit.mjs cleanup --run-id <audit_run_id>

# Live: still adapter-pending; still manifest-only (never delete-all)
export AUDIT_ALLOW_REMOTE_WRITES=1
export AUDIT_DRY_RUN=0
node tools/audit/bin/audit.mjs cleanup --run-id <audit_run_id> --live
```

Cleanup **requires** `.audit-runs/<run-id>/manifest.json`. Missing manifest →
hard refuse (no unqualified wipe).

## Isolated Flutter storage notes

Guest persona **G** and account-switch tests need a clean client store so OAuth
tokens, carts, and cursors from another shop/identity cannot leak.

Recommended approaches (pick one per run; document which you used):

1. **Fresh simulator / emulator** with app uninstall between runs.
2. **Custom application support subdirectory** via a dart-define such as
   `AUDIT_STORAGE_SUFFIX=monetta-qa-<run-id>` (wire in app code when adding
   integration tests — not part of this scaffolding commit).
3. **Clear app data** on Android (`adb shell pm clear <package>`) / erase
   iOS Simulator settings for the Monetta app.
4. Never reuse Keychain/Keystore items from a previous persona when testing
   **A ↔ B** switching; verify logout + local cleanup invalidate preloaded
   checkout from the previous identity.

Do not commit filled `config/dart_defines.*.json` files (already gitignored).

## Required personas (stubs)

| Code | Name | Storage |
|------|------|---------|
| G | Guest | Flutter isolated |
| A | Shopify customer A | Hosted sign-in (manual / controlled inbox) |
| B | Shopify customer B | Hosted sign-in (separate inbox) |
| C | Existing customer with history | Dev-store + Admin seed for historical orders |
| L | Legacy Monetta account | Disposable PostgreSQL |
| O | Owner principal | Server-provisioned verified identity |
| U | Ordinary non-owner | Local PG / authenticated |
| E | Unverified email matching owner allowlist | Local PG (privilege-escalation regression) |
| R | Revoked owner | Server principal deactivated |

Creating a customer through Admin API does **not** prove hosted login. Seed
historical data as needed; test hosted authentication separately.

## Catalog / order fixtures (planned rows)

See `lib/fixtures.mjs`: two-variant product, unavailable variants, Headless
publish matrix, mutable product, pagination coverage (prefer local fixtures
over bulk remote create), `monetta-todays-picks`, discount matrix, order state
matrix including historical **C** and exclusive **B**, shipping edge cases.

Tag remote fixtures with `monetta-qa-<run-id>` for cleanup. Do not place orders
that trigger real fulfillment, production financial transactions, or messages
to third parties.

## Layout

```
tools/audit/
  README.md
  env.example
  docker-compose.audit-pg.yml
  bin/audit.mjs
  lib/
    runId.mjs
    guards.mjs
    manifest.mjs
    personas.mjs
    fixtures.mjs
    seed.mjs
    cleanup.mjs

.audit-runs/<run-id>/manifest.json   # gitignored
.audit-runs/<run-id>/secrets.json    # gitignored (synthetic passwords)
```

## Makefile helpers (optional)

From repo root you can alias:

```bash
alias monetta-audit='node tools/audit/bin/audit.mjs'
monetta-audit init
monetta-audit seed
```

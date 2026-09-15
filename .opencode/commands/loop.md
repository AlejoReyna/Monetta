---
description: Build→audit loop for all remaining dashboard WPs until clean.
agent: build
---

You are the single loop driver. One agent runs this command; @builder and @auditor are workers you invoke per task.

Target list (in order, skip ones already clean): WP-62, WP-63, WP-64, WP-65, WP-66, WP-67, WP-68. Extra args: $ARGUMENTS (e.g. `/loop WP-64` runs only that WP; `/loop` runs all remaining).

Spec source of truth: docs/CATALOG_DASHBOARD.md §§ 4-10 (plus EXTERNAL_CATALOG_PRODUCTION_PLAN.md where referenced). Rule: doc and code disagree => fix both in the same change.

For EACH WP:
1. @builder — build exactly that WP's scope per its §10 work package (files, acceptance, Verify command). Do not touch `web/vercel.json`. Leave changes uncommitted.
2. @auditor — audit the uncommitted diff evidence-backed (trace routes/stores/migrations end-to-end, failure paths, no secret/fingerprint leaks, run `git diff --check`, typecheck, full tests). Report Blocker / High / Medium / Low with `file:line`.
3. If Blocker or High: @builder fix, @auditor re-audit. Repeat until no Blocker/High.
4. Re-render the dashboard checklist (P1-P4 + WP-60..68 statuses) before advancing.

Stop after all targets are clean and print the final checklist. Never commit.

# MONETTA v4.1 multi-agent implementation guide

Prepared **11 November 2026**. This is a launch-ready plan and prompt pack. **No repair agents have been launched and no application behavior has been changed by creating this guide.**

Recommended operating mode: **one coordinator plus at most three workers at once**, using isolated worktrees and explicit ownership. There are eight implementation packages and two independent review assignments; they run in dependency stages rather than all simultaneously.

The goal is to resolve all confirmed gaps in the [audit](../../audits/2026-11-11-v41/REPORT.md), verify all 50 owner contracts and leave genuine owner/provider dependencies visibly pending. A green test suite alone is insufficient for design approval.

## Current models and reasoning effort

The current official documentation lists **GPT-6.1 Terra** for visual reasoning, computer use and scoped fixes; its supported efforts include `medium`, `high`, `xhigh` and `max`. It lists **GPT-6.1 Sol** for complex work and **GPT-6 Astra** for the most demanding work. These are current model names, not recommendations based on older GPT-5/Codex branding. [Terra model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-terra), [current model guidance](https://developers.openai.com/api/docs/guides/latest-model).

The assignments below are engineering recommendations for this repository, not a benchmark proving one model always wins. Use Sol for cross-file implementation, Terra for the bounded editorial/visual tasks, and Astra for the independent correctness review. This follows the documented role distinctions. [Official model selection](https://developers.openai.com/api/docs/guides/model-selection).

**Effort means the model's reasoning setting**, not hours or a token budget. `high` corresponds to High; `xhigh` corresponds to Extra High. Relative size estimates describe scope, not guaranteed runtime. No `max`/Ultra setting is needed by default. Increase effort only when a reproduced failure warrants it. If an implementation package is straightforward after the interfaces are settled, lower later retries to `high` or `medium` while preserving acceptance.

| ID | Assignment | Recommended model | Reasoning effort | Relative scope |
|---|---|---|---|---|
| A00 | Coordinator, integration and final reflow | **GPT-6.1 Sol** | **xhigh** | L, continuous |
| A01 | Shared assets, type, Glass controls and readable heroes | GPT-6.1 Sol | high | L |
| A02 | Variant identity, common cards, quick view and PDP | GPT-6.1 Sol | xhigh | L |
| A03 | Authoritative service/data capabilities | GPT-6.1 Sol | xhigh | L + external dependencies |
| A04 | Taxonomy, sidebar, all brands, search/filter/sort | GPT-6.1 Sol | high | L |
| A05 | Account, Rewards and notification/navigation states | GPT-6.1 Sol | high | L + external dependencies |
| A06 | Registration/footer/policies, Contact and Wholesale | **GPT-6.1 Terra** | **high** | M–L |
| A07 | Home and Favorites recommendations | GPT-6.1 Sol | high | L |
| A08 | Cart/checkout continuity, orders and variant restock | GPT-6.1 Sol | xhigh | L + external dependencies |
| A09 | Independent visual/accessibility review | **GPT-6.1 Terra** | **high** | M–L review |
| A10 | Independent correctness/integration review | **GPT-6 Astra** | **high** | L review |

Exact model IDs: `gpt-6.1-sol`, `gpt-6.1-terra`, `gpt-6-astra`. Availability depends on the signed-in client/workspace. If Terra is unavailable, use Sol/high for A06/A09. If Astra is unavailable, use Sol/xhigh for A10. Record substitutions. A03 may be escalated to Astra/high if authoritative rules conflict and a second review is needed; do not escalate merely because an owner decision is missing.

## Launch the coordinator

Select **GPT-6.1 Sol / Extra High** in the app and give it this instruction:

```text
Execute the MONETTA v4.1 multi-agent remediation plan in
/Users/alexis/theCode/Monetta/docs/plans/v41-multi-agent/README.md.

Use the full coordinator prompt in prompts/a00-coordinator.md and the
self-contained worker prompts listed in work-packages.json. I authorize
parallel local implementation with one coordinator and at most three workers.
Use each assigned model and reasoning effort explicitly. Preserve the current
dirty working tree and untracked v4.1 assets before creating worker worktrees.

Implement, integrate and verify the confirmed owner requirements, routing fixes
back to their owners until resolved. Keep genuine business/provider decisions
pending with precise evidence, and continue independent work. Deliver the
reviewable implementation and a 50-contract acceptance report. Do not deploy
or change production settings, send messages or perform live money operations.
```

The [full coordinator prompt](prompts/a00-coordinator.md) spells out scheduling, ownership, integration, evidence and closure. Each worker file includes the complete common context and its specific task, so it can be pasted into a fresh agent without inheriting this chat.

CLI alternative, verified against the local CLI's `-m`, `-c` and `-C` options (`codex-cli 0.167.1`):

```sh
codex -C /Users/alexis/theCode/Monetta \
  -m gpt-6.1-sol \
  -c 'model_reasoning_effort="xhigh"' \
  'Read docs/plans/v41-multi-agent/prompts/a00-coordinator.md and execute its coordinated local implementation plan.'
```

This command **starts implementation when you run it**. It has not been run while preparing this plan. It does not install new configuration or change permission settings.

Explicitly configure child models/effort; an instruction inside an already-running worker does not itself change that worker's model. Codex supports per-agent selection and otherwise inherits parent settings. In this session's collaboration tool, cross-model children require fresh context (`fork_turns: "none"`), so A00 must pass the complete prompt and artifact paths. That is a constraint of this session's tool, not general API syntax. [Official subagent configuration](https://learn.chatgpt.com/docs/agent-configuration/subagents).

Optional project configuration, if your Codex client uses these current settings, is:

```toml
[agents]
max_concurrent_threads_per_session = 3
```

That setting caps children, excluding the coordinator. The current session also has a four-total-agent limit. Do not overwrite existing `.codex/config.toml`; merge only a requested setting. This guide does not install a config. Where custom agent files are used, set both `model` and `model_reasoning_effort`; in this session's spawn tool, the equivalent explicit fields are `model` and `reasoning_effort`.

## Stage 0 — capture the real starting point

A00 must first recheck the current code against the audit. The audit is from the dirty working tree, **not bare commit 80735fa**. At guide creation, staged font deletions, modified tokens/code, untracked DM Sans/font assets, `assets/images/v41/`, the v4.1 manifest and the audit files were still present.

A normal worktree created from HEAD would omit that work. A00 must preserve and review the staged/unstaged/task-relevant untracked files, then establish a task-scoped local baseline usable by workers. Exclude credentials, private configuration, build folders and unrelated edits. Do not use repository-wide staging, reset, clean or stash. A local baseline is not a production release or a push. If isolated worktrees cannot safely preserve the baseline, use the shared workspace with explicit file leases and prohibit child Git/index mutations.

A00 creates `docs/remediation/v41/` for current delivery records, keeping the historical audit unchanged:

| File | Purpose | Sole editor |
|---|---|---|
| `tracker.csv` | All 50 contracts broken into observable criteria | A00 |
| `interfaces.md` | Accepted component/data/callback interfaces and owners | A00 |
| `decisions.md` | Missing owner/provider decisions and effect on acceptance | A00 |
| `file-ownership.md` | Current per-file write leases | A00 |
| `integration-log.md` | Baseline, package commits, merge order and checks | A00 |
| `handoffs/Axx.md` | Individual package implementation/evidence report | Assigned agent |
| `evidence/Axx/` | Labeled captures and sanitized test results | Assigned agent |

[contract-ownership.csv](contract-ownership.csv) assigns every audited contract a primary implementation owner and both reviewers. [work-packages.json](work-packages.json) records the model/effort/dependency plan in machine-readable form.

## Stage 1 — shared foundation and service authority

Run **A01 and A03 concurrently**. Keep the remaining worker slot available; there is no benefit in forcing a third writer into shared foundations.

- [A01 prompt](prompts/a01.md): F01 and shared F16; connect delivered assets, build reusable visual primitives, correct type roles and fix text-scaling behavior.
- [A03 prompt](prompts/a03.md): establish real service capabilities for F08–F12/F17, implement supported data contracts and expose unresolved rules honestly.

Before Stage 2, A00 accepts versioned interfaces for semantic assets; real product-option data needed by A02; identity/tier/balance; order details; address/payment capabilities; auth/return; restock variant/channel; unread count; editorial content; and eligibility/rate evidence. Interface agreements describe actual data; they are not inert success stubs. Product mapping implementation belongs to A02.

**Gate:** shared primitives compile and render, supported data changes have tests, missing capabilities are explicit, and workers can branch from the accepted baseline. Pending business decisions do not block independent visual work, but remain open acceptance criteria.

## Stage 2 — three independent implementation packages

From that accepted baseline, run these three packages concurrently:

| Agent | Scope | Audit gaps | Prompt |
|---|---|---|---|
| A02 | Common card, variant continuity, quick view/PDP/zoom | F06/F07 | [Copy-ready prompt](prompts/a02.md) |
| A04 | Categories/brands/sidebar and discovery controls | F04/F05 | [Copy-ready prompt](prompts/a04.md) |
| A06 | Registration/footer/help, Contact/Wholesale | F03/F14/F15 | [Copy-ready prompt](prompts/a06.md) |

A02's new selection contract must remain compatible with existing callers until A00 migrates consumers. A04 exports working route destinations; A06 exports working help/registration interfaces. Each tests its scope against the assigned baseline. A00 integrates **one package at a time**, checks changed seams and creates the shared Stage 3 baseline. Completion messages without integrated code are not a gate pass.

**Gate:** selected variant and recommendation card APIs, semantic destinations and common editorial end sections are accepted and available to downstream workers.

## Stage 3 — three dependent experience packages

Run these from the integrated Stage 2 baseline:

| Agent | Scope | Audit gaps | Prompt |
|---|---|---|---|
| A05 | Account/Rewards/notification UI and bottom navigation | F09/F10/F11 and access part of F17 | [Copy-ready prompt](prompts/a05.md) |
| A07 | Home and Favorites | F02/F13 | [Copy-ready prompt](prompts/a07.md) |
| A08 | Cart/checkout, order details/confirmation and restock | F08/F11/F12/F17 | [Copy-ready prompt](prompts/a08.md) |

A08 can implement orders/restock/cart independently, but its guest/login/navigation journey must consume A05's accepted access/badge handoff before final integration verification. Do not manufacture a temporary provider success to avoid that dependency. A03 can be reactivated for an exclusive service/DTO follow-up after a slot becomes available; only A03 writes those files during that follow-up.

## File ownership and integration rules

These are essential because several findings touch the same files:

| Shared seam | Owner / required order |
|---|---|
| `guide_art.dart`, type/theme/assets and common primitives | A01 first; later feature agents consume them |
| `client_guide_sections.dart` | A01 foundation, then A06 composition; no overlapping writers |
| `product_card.dart`, `product_tile.dart`, variant mapping | A02; A04/A07 consume the accepted API |
| `product_screen.dart` | A02 first; A08 receives a later restock-only lease |
| `monetta_side_menu.dart`, `guide_drawer.dart` | A04 |
| `monetta_bottom_navigation.dart` | A05; A08 supplies authoritative cart signals through A00 |
| `home_screen.dart` callbacks and Home layout | A07, consuming A04 routes |
| Rewards API/models and provider/data DTOs | A03; A05/A08 consume them |
| Global providers, `main.dart`, `CatalogStore`, cross-package callbacks | A00 |
| Dependency locks/codegen/generator invocation | A00 coordinates; one writer/process per checkout |
| Consolidated contract status and owner decisions | A00 |

Worktrees isolate build folders and commits; they do not eliminate logical API conflicts. Preserve backward-compatible interfaces until consumers are integrated. In a shared workspace, workers must never commit other agents' changes. Do not run two Flutter test/codegen processes against the same build directory.

A00 reviews task-scoped diffs, merges/cherry-picks sequentially, records base/new commits and reruns checks for affected seams after integration. API/data changes need compatibility tests; screen changes need real visual evidence. Changes in shared generators may mechanically touch generated theme/prototype files; manual redesign of those products stays out of scope.

## Stage 4 — serialized integration and complete-flow checks

A00 owns the final integrated behavior and remaining F16 fixes across packages. Assign a temporary exclusive file lease to an original worker when a correction belongs there. Also verify G31 layers/return and G33 unavailable/retired content, which are easy to miss in a feature-only split.

At minimum, verify these journeys:

1. Home banner/category/brand -> scoped results -> color choice -> quick view -> PDP -> selected-variant add -> cart, without opening cart automatically.
2. Search + filters + sorting -> zero/error/retry -> product -> back, preserving query, draft rules and position.
3. New collection featured selection with 40 unique products where present; Para ti option selection/add; Favorites two-row paging with 60 unique products where present and fewer-item editorial fallback.
4. Guest cart -> account entry -> success/cancel/expired return -> current identity/rates; sign-out/account switch clears private state and invalidates the previous quote.
5. Cart quantity/stock/error/ambiguous response -> payment rejection/unknown/confirmed -> same authoritative order; no double add, discount subtraction or payment.
6. Order history -> details -> tracking/help -> back; preparing/transit/delivered is independent of financial status and preserves partial/cancelled exceptions.
7. Account header -> Rewards arc/tier benefits/movements -> profile/address capability -> unread notification destination; private data stays account-scoped.
8. Restock request for an actual exhausted variant; email/channel/consent and success are real service results.
9. Registration/error preservation, every footer policy, Contact groups/social and Wholesale single-row steps; external links do not send/join automatically.
10. Keyboard, modal focus/return, system back, withdrawn content, permission decline, 320 px text reflow, reduced motion and opaque fallback throughout.

Run relevant Flutter analysis/tests and available platform builds with the actual configured flavor. Existing checks are inputs; the audit's **239 passes are a historical baseline, not a target count**. Appropriate examples:

```sh
flutter analyze --no-pub
flutter test --no-pub
npm --prefix services/accounts_orders run typecheck
npm --prefix services/accounts_orders test
```

Run service checks for changed services, and use valid local test configuration. Do not apply live migrations or inject fake secrets to make a build succeed. Update old tests only when their expectation is demonstrably superseded by the owner contract. Golden updates require explicit visual inspection; do not auto-accept them.

## Stage 5 — independent review and bounded repair

Freeze the integrated candidate commit and source/build manifest. Run **A09 Terra/high** and **A10 Astra/high** against that same candidate:

- [Visual/accessibility reviewer prompt](prompts/a09.md): actual reference/current pixels, 320/390/440/768/834/1440 layouts, 200% text at narrow/medium/wide, light/dark where supported, keyboard/safe areas/focus/reduced motion/opaque fallback.
- [Correctness/integration reviewer prompt](prompts/a10.md): complete state/data/provider journeys, authorization/privacy, variant identity, money/stock/discount correctness, regression tests and service compatibility.

Reviewers write notes/evidence, not application code. They inspect all 50 contracts, including previously working baselines. A00 routes each failure to the owner, serializes conflicting fixes, freezes a new candidate and repeats affected checks. Do not rerun the entire suite without new changes or unresolved failures just to increase the test count.

## Decisions that agents must not invent

A03/A00 collect exact missing evidence in `decisions.md` before treating an item as an owner question. Existing configured sources may already answer it.

| Dependency | Needed authority/evidence | Progress possible while unresolved |
|---|---|---|
| Rewards tier/points/bonus/cashback | Approved rules plus authoritative fields/service behavior | Arc/components, real balance/movements, unavailable states and fixtures |
| Nuevo commercial date | Approved date source/window | Filter model/UI and tested gated behavior |
| Auth modality/providers/email verification | Supported configured provider and return flow | Branded access/guest/cancel/recovery presentation and adapter tests |
| Account free shipping / wholesale eligibility | Authenticated checkout/service response and approved eligibility | Preserve identity/reconciliation; wire real signals and unavailable states |
| Address/payment management | Actual provider capability and authorized endpoints | Conditional navigation and working supported management |
| Group/social/collection destinations | Valid official bindings from owner/configuration | Page composition, link-failure handling, hide unavailable actions |
| Restock channel | Variant-aware service, authorized channel and consent | Form/selection/cancellation and honest gated state |
| Advertising content | Existing approved editable content source + valid destinations | Slot renderer and empty-state hiding; no invented ad platform |
| Policies/delivery/reservation copy | Approved CMS content/current commercial policy | Reader and return flow; no fabricated terms or guarantees |

An unresolved dependency prevents full closure of its criterion, not progress on unrelated criteria. A mock service response does not resolve it.

## Acceptance and handoff

For every criterion, maintain **VERIFIED**, **IMPLEMENTED_UNVERIFIED**, **PENDING_EXTERNAL**, **FAILED**, or **NOT_APPLICABLE** with a written reason. Track confirmed owner requirements separately from proposed geometry. Do not mark an entire contract verified if some required actions or data are still pending.

A finding is closed only when its confirmed requirements work in the actual route/provider wiring and have appropriate behavioral plus visual evidence. Tests must exercise what the owner asked for, not merely repeat the new widget structure. Live checks must name the test environment, build and sanitized evidence; absent physical/simulator/provider access stays unverified. Do not certify live rates, OTP, payment or notification delivery from widget fixtures.

Final deliverables: task-scoped integrated code/commits; 50-contract acceptance matrix; closure evidence for F01–F17; before/after references; analyzer/tests/build results; exact external decision queue; and remaining risks/limitations. Prepare a concrete reviewable result. Deployment is a separate task.

## Prompt pack

All prompts are complete, with shared instructions included:

[A00 Coordinator](prompts/a00-coordinator.md) · [A01 Foundation](prompts/a01.md) · [A02 Products](prompts/a02.md) · [A03 Services](prompts/a03.md) · [A04 Discovery](prompts/a04.md) · [A05 Account](prompts/a05.md) · [A06 Editorial](prompts/a06.md) · [A07 Home/Favorites](prompts/a07.md) · [A08 Commerce](prompts/a08.md) · [A09 Visual review](prompts/a09.md) · [A10 Engineering review](prompts/a10.md).

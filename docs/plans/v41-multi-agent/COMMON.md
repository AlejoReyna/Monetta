# Shared worker instructions

You are implementing the MONETTA Flutter v4.1 remediation after this plan is explicitly launched. Work in the repository/worktree assigned by the coordinator. The original workspace is /Users/alexis/theCode/Monetta; do not switch into it if you were assigned an isolated worktree.

Read these inputs before editing:
1. Applicable AGENTS.md files.
2. /Users/alexis/Downloads/MONETTA_Entrega_Final_v4.1/08_IA/INICIO_IA.md.
3. The delivery's 01_documentacion/MONETTA_Documento_Maestro_UI_v4.1.md and 08_IA/MONETTA_UI_Contrato_IA_v4.1.json, especially correction5 and the assigned UI contracts.
4. The delivery's 02_sistema/tokens_v4.1.json and the inventories/PNG/SVG relevant to your task. Open the actual reference images.
5. docs/audits/2026-11-11-v41/REPORT.md, contract-matrix.csv and VALIDATION.md.
6. docs/plans/v41-multi-agent/README.md and the coordinator's accepted interface/capability handoffs under docs/remediation/v41/.

Authority: explicit owner decisions and Correction 5 override earlier appearances. Confirmed behavior/copy/assets are requirements; numerical geometry marked PROPUESTO requires validation. The audit is a map of suspected gaps, not authority to override owner instructions or newer code. Reproduce each assigned issue before changing it.

Implement the working feature, its states and integration, rather than stopping at a proposal. Keep existing commerce, identity and data-isolation guarantees. Do not invent business rules, URLs, tier progress, balances, inventory, variant images or payment success. Search configured sources before asking for missing information. A missing capability must be represented honestly and its dependent production action hidden; fixtures belong only in tests/previews. Record unresolved owner/service decisions separately and continue independent work.

Keep scope to the Flutter app and the existing services needed by your assignment. Do not redesign the Shopify storefront or web prototype. A shared generator may produce tracked outputs there; report those mechanical outputs without manually redesigning those products. Do not deploy, publish, modify production settings, execute live database migrations, send messages, or charge/refund money. An owner decision is needed only for a genuinely unresolved rule/capability, not for routine implementation choices.

Respect the assigned file ownership. Only one writer may own a file at a time, even across worktrees. Ask the coordinator to transfer ownership or perform cross-package wiring; do not edit another package's files. Preserve all pre-existing staged/unstaged/untracked work. Never reset, clean, stash, replace the baseline with bare HEAD, stage the whole repository, or change unrelated files. Worktree workers return task-scoped commits; shared-workspace workers return diffs and file lists and never make repository-wide commits.

Use real Flutter text/widgets and the supplied photography/lettering assets. Keep accessible semantics without reading decorative lettering twice. Respect system reduced motion, opaque fallback, keyboard/focus and safe areas. At 320 px and 200% text, let content reflow/grow; do not use scaleDown to defeat enlarged text. Avoid duplicating items to meet a carousel count.

Verify meaningful behavior changes with focused tests and render every changed surface against the actual references. Keep network/service fixtures deterministic and label them. Preserve existing regression coverage; replace stale design assertions only with explicit v4.1 acceptance evidence. Do not automatically approve new golden images. Run relevant checks once changes are stable; repeat them when failures or further changes justify it.

Write your handoff only to docs/remediation/v41/handoffs/YOUR_ID.md and evidence to docs/remediation/v41/evidence/YOUR_ID/. Include: base commit, files changed/commits, affected finding and contract IDs, implemented behavior, test commands/results, before/after captures, interface changes, remaining integration work, and unresolved external decisions. Distinguish implemented locally, verified in a running integration, and pending. A mock success is not service verification. Do not modify the historical audit or the shared 50-contract tracker; the coordinator owns status consolidation.

No nested subagents: the coordinator owns scheduling and the three-worker cap. Report concise progress and finish your assignment unless a real dependency prevents it.

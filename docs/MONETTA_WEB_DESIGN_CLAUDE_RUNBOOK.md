# Run the Monetta design task with Claude Opus 5.5

This runbook starts the **responsive design prototype and Shopify implementation handoff** selected by the user. It does not start a theme upload or production redesign deployment.

The task instructions are in [the master prompt](prompts/MONETTA_WEB_DESIGN_CLAUDE.md). The design source and research are in [the redesign plan](MONETTA_WEB_REDESIGN_PLAN.md).

## 1. Start a dedicated Claude Code session

From Terminal:

```bash
cd /Users/alexis_reyna/MyCode/Monetta
claude --permission-mode auto --effort high
```

Inside Claude Code, run:

```text
/model
```

Select **Opus 5.5** using the model picker and confirm the session shows that model. This avoids assuming that the moving `opus` alias names the exact version you want. The installed CLI inspected for this runbook is **2.1.302** and exposes the `auto` permission mode and `--effort` option. Model availability still comes from the selected account/provider.

Use a dedicated session for the design task; keep the existing native-app refactor separate. Nothing in this setup modifies `.claude/CLAUDE.md`, permission settings, agents, refactor trackers, or the existing OpenCode loop.

## 2. Start the work-until-complete loop

Paste this **single command** into Claude Code:

```text
/goal Read docs/prompts/MONETTA_WEB_DESIGN_CLAUDE.md and execute its complete responsive-prototype-and-handoff task. Completion requires a runnable prototype in design-prototype/; finished home, collection, product, search, cart and supporting views; actual font/visual/interaction/accessibility checks; responsive coverage at the specified widths; current design and Shopify handoff documents; and D01-D14 passing with command results and real screenshot evidence surfaced in this conversation. Continue implementing, rendering, reviewing, fixing and recording progress until those conditions hold. Preserve existing work. No production or Shopify writes, purchases, settings/secret edits, commits or pushes. Do not stop after planning, a homepage, or a self-declared success label. If an external blocker persists after three materially different attempts, complete independent work and report BLOCKED with the incomplete gates and exact unblock action, never successful completion.
```

`/goal` is the recommended mechanism here because it continues at turn boundaries toward a completion condition. Its evaluator uses evidence surfaced in the conversation; it does not independently inspect project files. The prompt therefore requires command results, screenshot inspection, and the acceptance table to appear in the transcript. [Official goal documentation](https://code.claude.com/docs/en/goal)

Auto mode handles tool permissions according to the account's effective policies; it does not guarantee every operation will be allowed. If Claude reports a concrete permission/access problem, resolve that specific dependency rather than disabling permission checks. The task only needs local prototype work and read access to the design sources. [Permission modes](https://code.claude.com/docs/en/permissions)

## 3. What Claude must produce

| Output | Location |
| --- | --- |
| Interactive responsive prototype and launch instructions | `design-prototype/` |
| Durable progress and D01–D14 checklist | `docs/web-redesign/STATUS.md` |
| Design tokens, components, states, and responsive rules | `docs/web-redesign/DESIGN_SPEC.md` |
| Shopify implementation specification | `docs/web-redesign/IMPLEMENTATION_HANDOFF.md` |
| Actual check results and evidence index | `docs/web-redesign/VERIFICATION.md` |
| Rendered browser captures | `docs/web-redesign/screenshots/` |
| Final review handoff | `docs/web-redesign/FINAL_REPORT.md` |

These outputs are to be created by Claude during execution. Their names in this runbook do not mean the design work has already been performed.

The loop follows a repeatable cycle: read the current ledger → implement the next incomplete item → render and inspect → check interactions/accessibility → fix issues → update evidence → continue. It ends successfully only when the prototype and handoff pass the declared gates. Routine page or milestone completion does not require a new approval.

## 4. Check, stop, and resume

Check the active goal:

```text
/goal
```

End automatic continuation:

```text
/goal clear
```

Keep the local Claude Code session and machine running for active work. If the process is interrupted, reopen the design session with:

```bash
claude --resume
```

Select the design session, check the model and `/goal` status, and ask Claude to reread the master prompt and `docs/web-redesign/STATUS.md`. Reapply the goal above if it is no longer active. Do not create a duplicate goal/loop over the same files in another session.

If the session stops because of a usage limit, unavailable model, missing browser, or authentication issue, completion has not been established. Resolve the reported cause and resume from the ledger. A goal can also end when its evaluator judges the condition impossible; inspect the reported result before treating a stopped session as a finished design. [Goal lifecycle](https://code.claude.com/docs/en/goal)

For a deliberately bounded work session, append an explicit checkpoint condition to the goal, such as: “Stop and checkpoint after 30 evaluated turns if unfinished; report the remaining gates instead of success.” This is an optional operating limit, not a design acceptance criterion. Check the accumulated ledger when resuming; a resumed session's turn counter is not a total-project budget.

## 5. If you specifically want `/loop`

Use this as an **alternative** to `/goal`, not alongside it:

```text
/loop Read docs/prompts/MONETTA_WEB_DESIGN_CLAUDE.md and docs/web-redesign/STATUS.md if it exists. Execute the next unfinished prototype-and-handoff work, including rendering, review, fixes and evidence updates. Continue useful work within each turn. When D01-D14 pass, stop this loop and report the evidence and delivery paths. If an external blocker persists after three materially different attempts, finish independent work, stop this loop and report BLOCKED with the incomplete gates. Preserve the task's local-only scope and existing work.
```

This version supplies the task explicitly so it does not change the project's default loop behavior. `/loop` schedules repeated prompts, while `/goal` evaluates progress after turns; the former may introduce waits between iterations. Keep only one driver active. Ask Claude to list and cancel the design schedule if you use this alternative. [Official scheduling documentation](https://code.claude.com/docs/en/scheduled-tasks)

## 6. Review the result

Successful delivery should include the prototype's exact start command, local preview address, D01–D14 evidence, screenshot index, and implementation handoff. `MONETTA_PROTOTYPE_READY_FOR_REVIEW` means the design is ready to inspect. It does not mean Shopify commerce is implemented or that monetta.mx was changed.

Launch the prototype using its README and review the complete phone/desktop shopping journey. Save feedback in the same session; Claude should revise the existing prototype and rerun the affected checks rather than start a separate design.

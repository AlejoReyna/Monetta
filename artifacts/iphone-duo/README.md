# Duo audit evidence

Worktree: `/Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/iphone-duo`, branch `feat/iphone-duo`, base `40567de777ab1d187438edec2ae8e88fc5a7d22d`.

Read `../../docs/IPHONE_DUO_IMPLEMENTATION_REPORT.md` first. `changed-files.txt` lists tracked changes and new implementation/test files; inspect both for this dirty-worktree handoff.

- `resume-format-final.log`, `resume-analyze-final.log`: latest successful static gates. Earlier `gate-*` logs remain historical evidence.
- `resume-full-test.log`, `resume-full-test-summary.txt`: latest full test result (1376 passed, 5 existing skips, 8 baseline golden failures). `gate-test*` preserves the preceding result. Eight golden cases fail; this is not a passing full gate. `baseline-test-summary.txt` records the unchanged-base failures and `resume-golden-failures/` holds the latest comparison output; `final-golden-failures/` preserves the preceding run. Expected goldens were never replaced.
- `android-build.log`: successful staging APK build.
- `native-geometry-spike.log`: actual simulator bridge smoke test.
- `resume-runtime-shopping-task.log`: successful final native shopping walkthrough, including all poses and maximum system text. `resume-runtime-summary.json` records nine capture contexts and checksums. `resume-runtime-shopping-tap-timing.log` preserves the failed tap-timing attempt. `runtime-shopping-task.log` preserves the earlier successful run before the visual fixes. Earlier `runtime-shopping-*-harness.log` and pose-timeout logs preserve failed harness attempts.
- `runtime-captures/*-fixture-photos.png`: actual implemented app captures on the dedicated Duo simulator, with a bundled test photo stand-in. No synthetic geometry override. Unsuffixed preliminary captures show unavailable-network placeholders.
- `resume-targeted-test.log`: 15 passing continuity, accessibility and geometry tests.
- `runtime-captures-before-accessibility-fix/`: preserved screenshots that exposed the visual defects. Current fixture-photo captures include the corrections.
- Widget tests explicitly named “synthetic” inject geometry; their bounds are test fixtures, not hardware measurements.
- `runtime-download/`: authorized iOS runtime export, ignored by Git. Do not commit it or native build products.

No physical-device verification or independent design approval is claimed.

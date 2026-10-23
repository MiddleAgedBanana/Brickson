# Batch pushes to an open PR

*2026-10-23. Branch `codex/open-pr-push-rule`. Codex.*

## What changed and why

AGENTS.md, "Pushing to an open PR", limits pushes after green CI to
failed CI, real bugs or rule violations found in review, and necessary
merges from main. Cosmetic, wording and style fixes join one otherwise
needed push or receive a written answer and thread resolution. The rule
links the existing stop-after-two-rounds record and applies its limit to
fix pushes after the first green run. Owner-enabled auto-merge is left to
finish once merge requirements pass; agents never enable it or merge.

PR #17's repeated pushes restarted long CI runs and delayed completion.
The reversible owner decision is in docs/DECISIONS.md, "Code review".
HANDOFF records the rule and corrects PR #17's stale pending status from
main's merge commit `7bff8f0`. App behaviour and guard code are unchanged.

The two-round limit exists in the previous reconciliation log's
[Main refresh and declined findings, 2026-10-23](2026-10-22-agent-guardrail-reconciliation.md#main-refresh-and-declined-findings-2026-10-23),
not as a standalone AGENTS section; the new rule links that existing
record rather than inventing a section title or repeating its rationale.

## Commits

See this branch's pull request; based on main `7bff8f0`.

## Verified

On a Mac in a clean checkout, all Python suites passed: 34 documentation,
124 hook, 4 site, 54 runner and 21 Xcode-selection tests.
`CI=true scripts/test.sh unit` passed on Xcode 27.1 (27A9275), iPad Pro 13-inch (M5, 16GB) simulator on iOS 27.0: 650 total, 647 passed, zero failed, one existing issue #19 skip
and two documented HomeShape expected failures. The String Catalog is
unchanged. No layout, appearance or keyboard validation is claimed.

The first documentation attempt also scanned an unrelated untracked
skills folder and found broken links there; the clean checkout excludes
that folder without changing it. The first native attempt was blocked
before testing by sandbox access to build outputs; the approved retry
passed. `git diff --check` and an added-text privacy check passed.

## Not verified

Hosted CI for this documentation change is pending when this record is
committed. Local UI tests were not run because this changes only
documentation. No physical-device, sound, gaze, Snap to Item or
visual-layout claims were tested.

## Follow-ups

Wait for this PR's final-head CI, report green, and leave merging to the
owner. No repository hook or skill is added.

# Design reference reconciled with landed work

*2026-10-22. PR #20, prepared on `codex/pr20-reconcile` from
`claude/project-thread-ho952i`.*

## What changed and why

Merged `main` at `5abdd9f` into the design branch with a merge commit
prepared without rebasing. Both sides' documentation is kept: the landed
accessibility coverage precedes the design's solid-fill decision, the
handoff retains the Siri gap and moves icon work to release chores, and
the roadmap records both documentation reviews.

[The screen specification](../work/design-screens.md) answers Codex's
open review by naming states, standard input paths, repeated activations,
invariants, colours, privacy impact, reference screens and remaining
proof. The roadmap reports a reference with unfinished corrections,
not a completed design gate for every flow.

DESIGN.md now follows the landed typing, Home and Settings decisions. It
no longer describes the old one-column Home, the earlier above-Emergency
Stop position, absent decisions, sideways category scrolling or a message
that can never shrink. It separates fixed frames across state from sizing
for Dynamic Type, and marks artwork and actual pointer evidence pending.
The original [design log](2026-10-21-design-screens.md) remains the dated
history of the drawings and their reviews.

Before the first push, PR #27 advanced main from `2895825` to `5abdd9f`.
The uncommitted reconciliation was preserved, then its merge was refreshed
without rebasing. The new Voice Settings decisions and handoff content
remain intact. The specification now includes the Ask, waiting, answered
and reopened states, fixed voice rows and appended arrivals. Production
still asks at launch; device check D1, the real question's return chain
and the longer-card-text gap remain open as the
[voice-screen log](2026-10-22-voice-screen.md) records.

## Decisions and unresolved inconsistency

No landed decision or invariant is weakened. The solid-fill decision
from PR #20 is retained; no new binding choice is made by reconciliation.

"Home's slot plan" still says Back to Talking covers the whole trailing
column. The design's later scoring proposes Phrases alone because Type
can tie under the wider placement. That is an unresolved inconsistency,
not an accepted exception. The next Home/Settings work should update the
decision only with the full entry/exit chain and frame checks. The spec
retains that blocker and main's message-border and fifth-category gaps.

## Verification

- Read-only three-way merge preview identified the documentation conflicts;
  the actual merge preserves both additions and current main decisions.
- Compared the reference against the landed Home, typing and Settings
  entries in DECISIONS.md and their dated logs.
- Conflict-marker, changed-document relative-link and `git diff --check`
  checks passed.
- Imported PR #17's actual `scripts/test-docs.py` temporarily with this
  worktree as its root, without adding the script here. Its eight checker
  self-tests pass, and all eight documents changed by PR #20 pass its
  citation/link functions after two title references were corrected. The
  full-repository document check still reports two unchanged-main
  abbreviations, in `SettingsIdleClock.swift` and the phone-layout log;
  PR #17 owns those corrections.
- `scripts/test.sh unit` passed on an iPad Pro 13-inch (M5), iOS 27.0,
  with Xcode 27.1 (27A9275) and XcodeGen 2.46.0: 460 passed, zero failures,
  skips or expected failures. App line coverage was 62.6% (3,540/5,659);
  the String Catalog was already synchronized. The result bundle is
  `build/TestResults/unit-ipad.xcresult`.
- No separate local UI suite was run for this documentation-only PR;
  its app and test sources are unchanged from main at `5abdd9f`. CI
  on the pushed head remains pending. No physical-device check is claimed.
- Figma was not re-opened or redrawn. The reference's frame measurements
  and historical contrast calculations were not independently repeated.
  No new artwork, completed device checks or accepted exceptions are claimed.

## Follow-ups, in order

1. Commit the locally tested merge, push to the existing PR branch,
   answer the specification review and wait for required CI.
   Preserve the PR body's first two attribution lines.
2. Correct and deep-link the affected Figma frames before a screen's
   implementation follows them; retain the file/page/state references
   until those exact links exist.
3. Resolve Home/Settings landing, message-border, phone-profile floor and
   worst-keyboard conflicts with their owning work; then score Clear,
   Put Back and family editor/import chains.
4. Pin new colour pairs, measure rendered system controls and run the
   required simulator and physical-device checks for each implementation.
5. Release chores produce the icon. The owner remains the merge gate.

# Duo fold design: the scrolling choice

*2026-10-25. Branch `codex/duo-reserved-regions`. Codex. Design draft;
no implementation.*

## What changed and why

Continued Wave 3 item 6 after PR #56 merged. Updated the existing
layout-engine work file with the Mac measurements, verified Apple API
shape, candidate even lanes, and the horizontal-fold scrolling problem.
The owner's spacing-only fold decision remains binding; no exception,
Home code or Settings row change is made.

A static horizontal gap inside a scrolling grid clears a fold only at
one scroll offset. Pinned-prefix and lower scrolling panes avoid that
gap moving, but change which visible row neighbours the prefix after a
scroll. Whole-row paging is another option, currently gated to R1. These
are concrete design choices for the owner, not routine spacing details
an agent can silently accept. The draft Figma diagrams are linked from
the work file and illustrate the failure; they do not certify floor,
chain, camera or real-input safety.

## Commits

- This design record, the current work-file continuation and affected
  HANDOFF/ROADMAP/DESIGN lines.
- Starting app/test source: main `6d040d5`, including merged PR #56.
- Dated measurement source: [PR #55, `cb4c965`](https://github.com/MiddleAgedBanana/Brickson/commit/cb4c965),
  whose measurements used app code `8316743` before #56.

## Verified

- API declaration read in current Apple documentation and the installed
  SDK: `.division` and `.occlusion` are queried separately; both accept
  `.includeInactive`; frames already include margins. This is source/API
  inspection, not a successful runtime reservation query.
- Read-only independent review confirmed the horizontal scroll-gap
  counterexample and the difference between ordinal ownership and
  visible neighbours in a pinned-prefix alternative.
- The existing native gate passed on identical app/test sources:
  Xcode 27.1 (27A9275), 13-inch iPad simulator, iOS 27.0; 740 tests,
  731 passed, 0 failed, the existing issue #19 skip and 8 strict expected
  failures; coverage 67.7%, String Catalog unchanged. Result:
  `build/TestResults/post-alarm-docs-unit/unit-destination.xcresult`;
  log: `/private/tmp/brickson-post-alarm-docs-unit.log`. No source changes
  have followed that gate in this branch.
- Documentation checks: 45 tests passed; `git diff --check` passed.
  The five Python suites also passed on the same scripts for the
  preceding docs branch (251 tests); this branch's independent final
  verification is recorded in the PR.
- Figma review: all four option groups were rendered and visually read.
  The labels distinguish measured canvas sizes from unmeasured bands and
  proposed frames. The saved screenshot is
  `docs/evidence/2026-10-25-duo-design/duo-fold-options.png`.
  The new page is `73:2`, wrapper `73:3`, vertical proposal `74:139`,
  counterexamples `74:190`. Existing Figma nodes were untouched.
- Supporting images live in `docs/evidence/`, keeping only this PR's
  one Markdown record under `docs/log/`. The render's bytes are unchanged.
- GitHub CI: pending after the draft's first push.

## Not verified

- No implementation, new regression test or new runtime Duo run. The
  normal unit gate is not a fold-layout test.
- Exact system division/occlusion rectangles; camera dark-area coverage;
  floors, whole words and complete Home/Settings held-activation chains
  for the proposed lanes or either horizontal alternative.
- Continuous safe scrolling for arbitrary libraries across a horizontal
  division. The proposed simple fixed-gap candidate fails that design
  requirement; pinned panes change its neighbour behaviour.
- Duo windowing, a second-window attempt, live folding/input comfort,
  sound, Phone handoff and controlled on-device input. The owner deferred
  physical testing until a mounted setup is ready.
- The JSON project trial: it still waits for released Xcode 27.2 and its
  first fix release; nothing is converted.

## Follow-ups

- Owner, when ready: choose a horizontal-fold policy from the work-file
  alternatives, or retain the current spacing-only decision while a
  different design is investigated. No request for physical testing now.
- Mac agent after that decision: finish Spec/Figma first, then the
  failing reproductions and implementation/chain/UI gates in the work
  file. Keep this as the one item 6 PR; do not start another Home code job.

# Bounded Home layout queries and enough time for both UI suites

*2026-10-22. Codex, branch `codex/ci-home-test`, from `main` at `2895825`.*

## What changed and why

The UI job now has 75 minutes instead of 50 to complete both simulator
families. Its required check name, permissions, triggers and test matrix
are unchanged. PR #27's first attempt of run
[39829191241](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39829191241)
finished the iPad tests but was cancelled during the iPhone suite after
roughly 50 minutes. Its iPad Home layout test took 165.810 seconds.

`HomeLayoutTests` counts phrase tiles once per layout wait and polls only
the window and first/last tile frames. After selection settles, one
accessibility snapshot supplies every tile's frame for the existing
containment and slot-position assertions. A failed snapshot throws and
fails the test; a layout wait timeout now fails explicitly. No assertion,
category, text size or orientation was removed. The documented narrow
window at AX5 still follows the same scrolling rule.

Apple's Xcode documentation was read for `snapshot()`,
`XCUIElementSnapshot.children` and `element(boundBy:)`. The snapshot owns
the descendant hierarchy, so its traversal does not issue another live
query for each tile. The Swift testing skill guided keeping XCTest for
UI automation and avoiding arbitrary sleeps.

## Commits

One change: the UI job allowance, bounded layout queries and this record.

## Verified

- Apple's releases feed and `scripts/select-xcode.py check` agreed with
  the installed Xcode 27.1 (27A9275) on 2026-10-22; XcodeGen 2.46.0.
- Before the change, the targeted Home test passed on iPad Pro 13-inch
  (M5, 16 GB), iOS 27.0, in 86.767 seconds, and iPhone 17, iOS 27.0,
  in 42.254 seconds. Both used full-screen simulator windows, light
  appearance, default and AX5 text. iPad covered portrait and landscape;
  iPhone remained portrait, as the app requires. No keyboard was shown
  by this Home test; the runner configured the full software keyboard.
- Deliberately moved each category's fourth tile 2,000pt sideways in a
  temporary app mutation. The optimized test reported the interior tile
  outside the window, including Basics and Needs, whose endpoints still
  fit. This proves the endpoint wait did not replace the full containment
  assertion. The mutation was removed; no app code changes remain.
- `scripts/test.sh unit`: all 444 tests passed, with 65.2% app code
  coverage. The String Catalog was already synchronized.
- `scripts/test-runner.py`: all 51 tests passed in 32.416 seconds;
  `scripts/test-site.py`: all four tests passed.
- The optimized Home test passed during the full UI runs in 82.795
  seconds on iPad and 40.892 seconds on iPhone. The local reduction is
  modest; CI timings remain to be measured.
- `scripts/test.sh ui` completed both full suites: 31 passed, no failures
  and four existing opt-in keyboard probe skips on each device. Test
  execution took 477.075 seconds on iPad and 429.110 seconds on iPhone.
  The Home and reachability tests covered default and AX5 text; launch
  audits covered light and dark appearance; Settings used its existing
  default-text checks. All windows were full-screen. The four keyboard
  probes require their existing opt-in launch flag and were not enabled.

## Not verified

CI on the eventual pushed commit is pending. Simulator timings are local
measurements, not a prediction for GitHub's machines. No physical-device,
sound, gaze comfort, Snap to Item or windowed-iPad claim is made here.

## Follow-ups

1. Verify the required CI checks on the pushed commit; the owner merges.
2. The layout engine still owns the already recorded small-window
   scrolling gap and profile floors. This test change accepts no new gap.

## Decisions

No product or accessibility decision changed. The owner requested the
75-minute CI allowance. The extra time does not retry or skip a test.

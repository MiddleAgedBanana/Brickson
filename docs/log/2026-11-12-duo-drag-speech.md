# Why a drag on the phrase grid spoke

*2026-11-12 (measured 2026-11-11, US Eastern). Pull request
(`claude/duo-drag-speech`). The thread "Find why drags on iPhone Duo
speak", on the owner's Mac.*

## What changed and why

Project notes carried an open safety finding from PR #58's work: two UI
tests that dragged on iPhone Duo's tall screen made Home speak, and the
cause was never found; PR #58 stopped it with two scroll modifiers
without saying why they work. In an app that speaks for people who
can't, a drag that speaks by accident matters, so this thread found the
cause. Nothing a person sees or hears changes: Home's code is untouched.

**The cause** (docs/DECISIONS.md, "Phrase-grid drag cancellation",
*Why a drag spoke*): a standard Button speaks when the finger lifts
within it, however far the finger moved while down, unless the phrase
scroll view takes the touch over first, which it does only once the
finger has moved about 10 points in a direction it can scroll. Before
PR #58 a grid whose phrases all fit had scrolling off, so nothing took
the touch over and every slide on it spoke. A touch in the 8-point gap
between two tiles belongs to the tile on its right, which is how the old
prototype's gutter drag said "I'm not finished.". The speech came from
the app's real behaviour, not from the test harness alone.

**What PR #58's repair covers:** an up, down or diagonal slide of about
10 points or more, from a tile or a gap, is silent whether or not the
grid fits. A 5-point wobble still speaks. A sideways slide that stays on
a phrase says that phrase, as a slide on Yes says Yes: the owner decided
on 2026-11-11 to keep that (*Sideways slides*).

Changes:

- `PhraseDragTests` gains two tests that pin the other side of drag
  cancellation: `testASmallWobbleOnAPhraseStillSpeaks` (5 points up) and
  `testASidewaysSlideOnAPhraseSaysThatPhrase` (40 points sideways). Each
  requires the tile's own words and no other sentence.
- `PhraseDragProbeTests`, opt-in like `HeldSlideProbeTests`
  (`TEST_RUNNER_BRICKSON_DRAG_PROBE=1`), runs 19 gestures from fresh
  launches on Yes, a tile and a gap, in each direction and over 5 to 80
  points, and attaches one `DRAG-PROBE {json}` line each. It asserts
  nothing, so it can run on a build with the repair taken out.
- docs/DECISIONS.md, "Phrase-grid drag cancellation": the cause and the
  owner's sideways decision, as two subsections.
- `AGENTS.md`, *Gotchas*, the iPhone Duo entry: which window the drag
  tests' coordinate check passes in, and that a point offset from the
  app's own origin never reaches Home there.
- docs/HANDOFF.md and the website's accessibility page say what is
  now checked.

## Commits

See the pull request.

## Verified

On the owner's Mac: Xcode 27.2 (27B52), XcodeGen 2.46.0, the iPhone Duo
simulator on its own iOS 27.2 runtime (24B91016s), opened flat with
`rocketsim duo pose open` (hinge 180 degrees) and turned with the
Claude desktop app's simulator control. English, light unless named,
no keyboard (Phrases mode).

**Today's app, the tall 669×951 window in which the drag tests'
coordinate check passes** (three right turns from the boot orientation):
`PhraseDragTests` 5 of 5 passed, then 7 of 7 with the two new tests.

**With PR #58's repair taken out** (`scrollDisabled` for a fitting grid
and `.basedOnSize`, put back in the working copy only and restored):
`PhraseDragTests` 3 passed, 2 failed. Both default-size cases spoke
"Wait a moment, please." on the 80-point drag that starts and ends on
that tile, with the coordinate check passing; the gutter drags before
them were silent. Both AX5 cases passed: at AX5 the second row ends at
y 923, below the viewport's 909, so the grid overflowed and could
scroll.

**`PhraseDragProbeTests`, default text, all 19 gestures aimed and sent,
grid fitting (viewport 637×353 at y 556, tiles 153×172):**

| Gesture | Repair out | Today's app |
|---|---|---|
| Yes: tap, 20 and 60 points sideways | "Yes." each | "Yes." each |
| Tile: tap | its phrase | its phrase |
| Tile: 5 points up | its phrase | its phrase |
| Tile: 10, 15, 20, 30, 40, 80 points up | its phrase each | silent each |
| Tile: 40 right and 40 up | its phrase | silent |
| Tile: 10, 20, 40, 80 points sideways | its phrase each | its phrase each |
| Gap between the top row's first two tiles: tap | "I don't know." | "I don't know." |
| Gap: 20 and 80 points up | "I don't know." each | silent each |

"Its phrase" is "Wait a moment, please.", the bottom row's first tile;
every slide stayed on it. "I don't know." is the tile right of that gap.

**The new tests can fail** (each run restored the working copy after):

- A `highPriorityGesture(DragGesture(minimumDistance: 20))` on the phrase
  scroll view fails `testASidewaysSlideOnAPhraseSaysThatPhrase` and
  passes the wobble test.
- With `minimumDistance: 2` it fails both.
- `scrollBounceBehavior(.always, axes: [.horizontal, .vertical])` passed
  both: bouncing sideways too does not take sideways slides over.

The opposite cases, recorded so later work need not rediscover them:
in the wide 951×669 window and the other tall one, the drag tests fail
before input at their coordinate check (line 138: the aimed x 162.7 was
sent as 506.3 in the tall one), PR #58's known reflection. And a probe
that offset its points from the app element's own origin reported every
point aimed correctly, yet none of 19 gestures, plain taps on Yes
included, changed Home; offsets from the touched element reached it.

On the same Mac, `scripts/test.sh` (unit, iPad Pro 13-inch (M5), iOS
27.2): 950 ran, 939 passed, 0 failed, 1 skipped (the existing #19
skip) and 10 strict expected failures; the String Catalog was up to
date. `scripts/test.sh ui` with `PhraseDragTests` and `SlowPressTests`
only: 9 of 9 passed on the iPad Pro 13-inch (M5) and 9 of 9 on the
iPhone 17, both iOS 27.2, portrait, as the tests set text size and
appearance. Codex's local review of the change found nothing to fix.

## Not verified

- **A real finger, dwell, a head pointer, Switch Control or Eye
  Tracking.** These are touches XCTest synthesises on a simulator. Dwell,
  head pointers and switches tap at a point and do not slide, so this
  finding is about touch; whether a real tremor's press crosses the
  10-point threshold is the device check in docs/HANDOFF.md, *Checks that
  need a real device* (the slow-press and slide row).
- **That SwiftUI's `ScrollView` uses UIKit's touch cancellation** as
  Apple documents it for `UIScrollView`. The measurements fit it; no
  debugger read the view's properties.
- **The old prototype itself.** Its layout is lost; that its gutter
  start belongs to "I'm not finished." is worked out from the gap rule
  and the tile order PR #58 recorded, not rerun.
- **Which tile takes a gap touch away from its middle**, and in the gap
  between rows. Only the middle of one column gap was measured.
- **Other text sizes and appearances in the probe**, and iPads and
  iPhones for the probe: it ran at the default text size, light, on the
  Duo only.

## Follow-ups

- None for Home's code. If a person with a tremor finds sideways slides
  or wobbles speak when they did not mean to, Touch Accommodations is
  the first answer; any app change is the owner's decision
  (docs/DECISIONS.md, *Sideways slides*).

# Settings' first row, placed from Home's frames

*2026-10-25. Pull request #<n> (`claude/project-thread-h5wcx3`). The
Settings' first row thread (a cloud session), ROADMAP Wave 3 item 7.*

## What changed and why

CI's first run on PR #53 found that on the 13-inch iPad a look held on
Settings' Family Setup row opened Family Setup, whose Back to Talking
was then the nearest control, and Settings closed with the look over
Home's Get Attention: the alarm sounded with nobody asking. On the phone
the same chain landed on No. PR #53 recorded it as a strict known issue;
this pull request removes it by placement (docs/DECISIONS.md, "Settings'
first row, placed from Home's frames"). The work file is
[`work/settings-row-place.md`](../work/settings-row-place.md), and the
screens are in the Figma file's
[Settings' first row section](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-266).

What a family will notice:

- **Settings' first screen.** The Family Setup row no longer starts
  right under the bar. Its place comes from Home's frames as Home lies
  under the cover (`SettingsRowPlace`): as high as it can sit with its
  top edge nearer Home's quiet controls (Phrases, Type, Emergency, the
  categories, Settings) than its loud ones (Yes, No, Again, Get
  Attention, Stop, the phrase tiles); on the phone, held where going
  back from Family Setup still meets the row, not Back to Talking; and
  as narrow as serves, over Home's own Settings button on the iPad. The
  note goes beside it, above it or under it (`SettingsLeadIn`, formerly
  `SettingsRootColumns`, now shared by both screens). The row is smaller
  than before: 78 points tall instead of 110, and on the iPad 194 wide
  instead of 492.
- **Family Setup.** Set Up Step by Step takes the root row's frame, at
  least as tall, growing downward where its words need more lines
  (`SettingsLeadIn.control(inPlaceOf:width:height:)`), so a look still
  resting where the row was meets a row that only opens the next screen.
  The opening words go beside it where there is room for its words on
  one line (the iPad), and otherwise above it where they fit or under it
  (the phone, and the iPad at the largest size). The check-in card and
  warnings come after it.
- **Every Settings screen measures where it sits** (`SettingsScreenFrames`:
  the stack from the cover, the navigation bar from the screen's own
  safe area), so the row is placed in window coordinates without
  assuming the bar's height.

**A change from the brief, with its reason.** The brief proposed keeping
Family Setup's opening words over the spot and moving its first row up
under them. Modelled on CI's frames, every place the root's row could
take on the phone, at the default size and at AX5, then left Back to
Talking nearer some point of the spot than the row below the words, so
Settings still closed onto No or Get Attention. A row that only
navigates has to be at the spot itself, which is what this does.

**A change during the build, with its reason.** The first version gave
Set Up Step by Step the whole width at the row's top. It cleared CI's
four modelled windows, but an independent review of the branch, before
anything was pushed, swept other windows and found about a third of them
at the default size still closing Settings: on the iPad, a row across
the width has its centre mid-window, so by centre Back to Talking was
nearer a look resting where the narrow root row had been. Set Up Step by
Step now takes the row's own frame, and a unit-test sweep of 630 windows
fails on the first version (90 windows) and on the old Family Setup
(213).

## Commits

- `038c1c3` The work file (intent, spec and plan).
- `f0570e1` The code and tests: `SettingsRowPlace`, `SettingsScreenFrames`,
  `SettingsLeadIn`, the two screens, the chain model and the UI tests.
- `2fefecf` The records, for the first version.
- Set Up Step by Step in the row's frame, the window sweep, the UI test
  scoped to the first step, and the records corrected to match.

## Verified

- **Not built on a Mac.** This is a cloud session with no Xcode; GitHub
  CI is the build, and nothing here is described as working until it
  passes. The SwiftUI views and the UI tests were not compiled here.
- **Pure-Swift tests on Linux** (Swift 6.4.1, a SwiftPM harness that
  compiles the layout types, the chain engine and their tests with
  default main-actor isolation, release mode): 101 tests pass, the known
  issues among them as recorded.
  - `SettingsRowPlaceTests` sweeps 4,200 windows (70 widths from 320 to
    1424 points, six heights from 568 to 1376, five text sizes, Bold
    Text off and on). Fails if the row leaves the first screenful, if
    Home's Settings meets Back to Talking before the row, if Back's spot
    meets Back to Talking where Home under it sounds, if the row's top
    meets a loud control where nothing holds it up, or if CI's windows
    move (pinned tops: phone 312, iPad portrait 354, landscape 355, iPad
    AX5 378; the phone at AX5, 317, is computed, not pinned).
  - `SettingsChainsTests.theRowPlacedFromHomesFramesClosesNothingUnderTheLook`
    models the iPhone 17, the 13-inch iPad in portrait at the default
    size and at AX5, and in landscape, from CI's measurements on PR #53,
    with Set Up Step by Step's width and height modelled (CI has never
    drawn it narrower than the content). No chain closes Settings under
    the look and none is unexpected; the chain from Home's Settings to
    Touch is found on all four. Fails if a change to `SettingsRowPlace`,
    `SettingsLeadIn` or Home's frames brings a closing back: with the row
    across the top of the content, the iPad at AX5 closes Settings onto
    No and Get Attention through the first step.
  - `SettingsChainsTests.noSweptWindowClosesSettingsUnderTheLook`: 630
    windows (widths 320 to 1408 every 32 points, six heights, the
    default size, AX3 and AX5, Bold Text off), with Family Setup's words
    modelled from CI's measurements (`SweptFamilySetup`). No closing, no
    unexpected hazard. Mutated to the first version it fails on 90
    windows, and with the opening words over Set Up Step by Step, on 213.
    A wider scratch sweep (4,200 windows, both Bold Text settings) found
    no closing either; by centre, Back to Talking can be the next control
    at a corner of a large row on some narrow windows at AX3 and AX5, and
    the look then lands on Home's quiet controls.
  - `SettingsLeadInTests.setUpStepByStepTakesTheRowsPlace` and
    `SettingsChainsTests.theFirstStepShowsAnAnswerOnlyAboveNext`.
  - `theHeldGuideLinkWouldSoundTheAlarm` rescored: the held guide link
    still sounds the alarm, and no longer clears every save chain.
- `scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-site.py` pass.
- The Figma frames were drawn from the frames the layout code computes
  for those windows, not from a running app.

## Not verified

- The app has not been built or run. The UI tests that read the real
  frames (`SettingsOnHomeTests`,
  `SettingsTests.testFamilySetupOpensWithSetUpStepByStepOverTheWholeRootRow`)
  run first on CI.
- The phone at AX5 is predicted, not measured: from PR #53's CI frames,
  Set Up Step by Step's first step shows no answer above Next, so a held
  look through it closes Settings, and a look on Next saves the answers.
  `SettingsOnHomeTests` expects both strictly there; CI says whether the
  prediction holds.
- Whether the measured frames arrive in time: the row sits at the top
  of the content until Settings has measured itself, as before. If CI
  shows the row there, the measurement is late, not the rule.
- Resting rather than activating: on the iPad the root's first screen
  has more empty space, where a resting look with Snap to Item meets
  Back to Talking and closes Settings onto Phrases (nothing speaks). Not
  scored.
- A first screen scrolled before its row is chosen: Set Up Step by Step
  takes the row's place in the content, not on the screen (a known gap,
  docs/HANDOFF.md, *Known gaps*).
- Where a pointer rests after an activation, how Snap to Item picks,
  and every sound: real-device checks (docs/HANDOFF.md, "Checks that
  need a real device").
- Text sizes between the default and AX5 on a Mac (CI runs only those
  two; the sweep's AX3 is modelled).

## Follow-ups

1. *The phone at its largest text size* (the next Settings thread):
   place Set Up Step by Step's first step so its first answer, not Back
   to Talking, is nearest the spot; the strict expectation in
   `SettingsOnHomeTests` then fails and comes out.
2. *The chain that saves an answer* (the next Settings thread): still
   open and wider; the held guide link stays held (docs/DECISIONS.md,
   "Typing on Home", *The held guide link stays held*).
3. *Short, very wide windows* (the layout engine's thread): Home's
   Settings lies as near Back to Talking as the row on windows wider
   than about 1300 points and at most 667 tall, as before.
4. *Device checks* (Codex on the owner's Mac, then a real device): open
   Settings by a held look on the iPad and the iPhone and note where the
   pointer rests on Family Setup; check at the largest text sizes, and
   with Settings' first screen scrolled.

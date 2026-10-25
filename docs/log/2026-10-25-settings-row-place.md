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
  `SettingsRootColumns`, now shared by both screens).
- **Family Setup.** Set Up Step by Step takes the root row's place,
  across the whole width and at least as tall, so a look still resting
  where the row was meets a row that only opens the next screen. The
  opening words go above it where they fit (the iPad) and under it where
  they do not (the phone). The check-in card and warnings come after it.
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

## Commits

- `038c1c3` The work file (intent, spec and plan).
- `f0570e1` The code and tests: `SettingsRowPlace`, `SettingsScreenFrames`,
  `SettingsLeadIn`, the two screens, the chain model and the UI tests.
- The records: docs/DECISIONS.md, docs/HANDOFF.md, docs/ROADMAP.md,
  AGENTS.md, docs/work/settings-chains.md and this file.

## Verified

- **Not built on a Mac.** This is a cloud session with no Xcode; GitHub
  CI is the build, and nothing here is described as working until it
  passes.
- **Pure-Swift tests on Linux** (Swift 6.4.1, a SwiftPM harness that
  compiles the layout types and their tests with default main-actor
  isolation, release mode): `SettingsRowPlaceTests`,
  `SettingsScreenFramesTests`, `SettingsLeadInTests`,
  `SettingsChainsTests`, `HomeLayoutEngineTests` and the rest of the
  harness pass.
  - `SettingsRowPlaceTests` sweeps 4,200 windows (70 widths from 320 to
    1432 points, six heights from 568 to 1376, five text sizes, Bold
    Text off and on). Fails if the row leaves the first screenful, if
    Home's Settings meets Back to Talking before the row, if Back's spot
    meets Back to Talking where Home under it sounds, if the row's top
    meets a loud control where nothing holds it up, or if CI's windows
    move (pinned: phone 312, iPad portrait 354, landscape 355, iPad AX5
    378).
  - `SettingsChainsTests.theRowPlacedFromHomesFramesClosesNothingUnderTheLook`
    models the iPhone 17, the 13-inch iPad in portrait at the default
    size and at AX5, and in landscape, from CI's measurements on PR #53.
    No chain closes Settings under the look and none is unexpected; the
    chain through Set Up Step by Step that saves an answer remains, as
    known. Fails if a change to `SettingsRowPlace`, `SettingsLeadIn` or
    Home's frames brings a closing back (with the row back at the top of
    the content, every iPad window closes Settings onto Get Attention
    again).
  - `theHeldGuideLinkWouldSoundTheAlarm` rescored: the held guide link
    still sounds the alarm, and no longer clears every save chain.
- `scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-site.py` pass.
- The Figma frames were drawn from the frames the layout code computes
  for those windows, not from a running app.

## Not verified

- The app has not been built or run. The UI tests that read the real
  frames (`SettingsOnHomeTests`, `SettingsTests.testFamilySetupOpensWithSetUpStepByStepOverTheWholeRootRow`)
  run first on CI.
- Whether the measured frames arrive in time: the row sits at the top
  of the content until Settings has measured itself, as before. If CI
  shows the row there, the measurement is late, not the rule.
- The phone at AX5 is not in the unit tests' chain model; its residual
  (Settings closing through Set Up Step by Step's first step) comes from
  the UI test's real frames and is expected strictly there.
- Resting rather than activating: on the iPad the root's first screen
  has more empty space, where a resting look with Snap to Item meets
  Back to Talking and closes Settings onto Phrases (nothing speaks). Not
  scored.
- Where a pointer rests after an activation, how Snap to Item picks,
  and every sound: real-device checks (docs/HANDOFF.md, "Checks that
  need a real device").
- Larger text sizes on a Mac at every size (only CI's default and AX5).

## Follow-ups

1. *The phone at its largest text size* (the next Settings thread):
   place Set Up Step by Step's first step so its first answer, not Back
   to Talking, is nearest the spot; the strict expectation in
   `SettingsOnHomeTests` then fails and comes out.
2. *The chain that saves an answer* (the next Settings thread): still
   open; the held guide link stays held (docs/DECISIONS.md, "Typing on
   Home", *The held guide link stays held*).
3. *Short, very wide windows* (the layout engine's thread): Home's
   Settings lies as near Back to Talking as the row on windows at least
   1304 points wide and at most 667 tall, as before.
4. *Device checks* (Codex on the owner's Mac, then a real device): open
   Settings by a held look on the iPad and the iPhone and note where the
   pointer rests on Family Setup; check at the largest text sizes.

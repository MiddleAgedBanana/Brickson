# Sizes that follow how the screen is reached

*2026-10-30. Pull request #69 (`claude/project-thread-ffwagr`). The
item 8 thread (ROADMAP Wave 3 item 8), a cloud session: GitHub CI is its
build.*

## What changed and why

Home had one set of sizes, touch's, and nothing read Family Setup's
answer to how the screen is reached. Now Home's sizes and spacing follow
that answer (docs/DECISIONS.md, "Sizes that follow how the screen is
reached"; work file
[`work/sizes-that-follow-reach.md`](../work/sizes-that-follow-reach.md)):

- **Four profiles** (`HomeLayout.Profile`): touch (44 points, 8 apart,
  as before), Switch Control and head tracking (phrase tiles 110, quick
  controls 88, categories 72, 12 apart; new, proposed for the owner) and
  Eye Tracking (136, 109 and 89, 15 apart: the reference app's, held at
  163 points per inch).
- **The answer chooses** (`ProfileChoice`, a new plain type): touch's
  for Touch, Voice Control and Someone Else Helps, each pointing method
  its own, several answers the largest any of them needs, and no answer
  Eye Tracking's.
- **Only where the window holds them.** A profile is taken where every
  control and tile meets its floor, the starter library fits without
  scrolling, and nothing touch's sizes have there (the arrangement,
  typing, whole words) is lost (`HomeLayout.holdsProfile`,
  `ProfileChoice.keepsEverything`); otherwise the largest smaller one,
  and touch's last. No phone holds more than touch's; every iPad in
  portrait holds Eye Tracking's.
- **Nothing changes place.** The arrangement is chosen at touch's gap
  in every profile, so only sizes and gaps differ (invariant 8).
- **Back to Talking keeps touch's frame**, and the profile changes only
  as Settings closes, so nothing moves under a look while Settings is
  open, and a look still resting on Back to Talking meets Phrases.
- **A fold or a camera across Home** keeps touch's sizes.
- **Family Setup's first step** says what the answer does, and, where
  iOS reports Switch Control or VoiceOver on, which answer may fit,
  choosing nothing (SwiftUI's `accessibilitySwitchControlEnabled` and
  `accessibilityVoiceOverEnabled`, iOS 15 and later).
- **UI tests** launch at touch's sizes unless they ask
  (`--home-profile`, debug builds with test storage only), so the
  existing tests keep measuring what they did; `HomeSizesTests` launches
  with the answer.

The same pull request records the owner's decision of 2026-10-30 that
items 8 and 9 come before the first App Review build (docs/DECISIONS.md,
"Items 8 and 9 come before the first App Review build"): the owner
wants the app complete before it is submitted. docs/ROADMAP.md no longer
holds them until that build, stage profiles are no longer left out of
R0, and R0's *Release gate* now says no build with the larger sizes
goes to App Review or an external TestFlight group until the owner has
answered whether Yes and No may border the message.

## Commits

- `7a51022` Write the work file for sizes that follow how the screen is
  reached.
- `d3750b1` Size Home from Family Setup's answer.
- The commit adding this record: the decisions, the roadmap with items
  8 and 9 no longer gated, the handoff, the accessibility map, the
  website's accessibility page, the README and AGENTS.md.

## Verified

- The unit tests that need no Apple framework were built and run on
  Linux (Swift 6.4.1, in a package that links the layout files and their
  tests; not part of the repository): `ProfileChoiceTests` (every test
  passes), `HomeLayoutEngineTests`, `HomeReservedRegionChainTests`,
  `ChainEngineTests`, `SettingsRowPlaceTests`, `SettingsLeadInTests`
  and `KeyboardAllowanceTests`. The whole run: 130 tests in 12
  suites, all passing but one check of
  `HomeReservedRegionChainTests.backToTalkingUsesTheFinalPhrasesFrame`,
  where Linux's Foundation says a rect does not contain another that
  prints identically (a fractional origin); that test runs at touch's
  sizes, for which this change computes the same frames, so CI on
  Apple's frameworks is its check. The 117 known issues recorded are the
  existing strict ones; this change adds none.
- New tests and the change that makes each fail, run on Linux:
  - `noControlChangesPlaceBetweenProfiles` failed when Home's
    arrangement was chosen at the profile's own gap (first at 680×568
    at Switch Control's sizes).
  - `aProfileHoldsOnlyWhereEveryFloorIsMet` failed when the width check
    was dropped from `holdsProfile` (Yes 81 points wide at 392×874 at
    head tracking's sizes).
  - `closingSettingsOntoOtherSizesMeetsOnlyPhrases` failed with each
    profile's own Back to Talking (Type at its foot; Get Attention or
    Again, by centre, on windows 1352 to 1416 points wide).
  - The rest fail if a mapping, a floor, a gap, the windows table, a
    chain finding, the Yes and No share or a fold's sizes change.
- `scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-site.py` pass.
- The String Catalog has the three new sentences; no key the code uses
  is missing from it.
- Apple's documentation, read on 2026-10-30 in its Markdown form:
  `accessibilityVoiceOverEnabled` and `accessibilitySwitchControlEnabled`
  are SwiftUI `EnvironmentValues`, iOS 15.0 and later.
- The Figma frames were drawn from the frames the layout code computes
  for those windows, not from a running app.

## Not verified

- Nothing was built with Xcode or run on a simulator before the first
  push: CI is the first build of the app, its unit tests on Apple's
  frameworks and the UI tests, `HomeSizesTests` among them.
- The first step's question heights that CI measured for the chain
  tests were taken before its new sentence; the sentence's height is
  modelled (`SettingsChainsTests.SweptFamilySetup`), and CI's run is
  the first measurement.
- No person has used the larger sizes. The switch and head floors come
  from studies of head pointing and scanning, none of them with Apple's
  own Head Tracking or Eye Tracking or with people with ALS.
- A fold or a camera at the larger sizes was not measured; those
  windows keep touch's.
- Where a pointer rests after Settings closes onto new sizes, and Snap
  to Item, need a real device.
- Which flags each input method turns on (docs/HANDOFF.md, *Checks
  that need a real device*).

## Follow-ups

- **The owner:** what Home does where a window cannot hold the sizes
  asked for (built: the largest smaller ones; docs/DECISIONS.md,
  *Waiting on the owner*), and, before a build with the larger sizes
  goes to App Review, whether Yes and No may border the message.
- **Device checks** (Codex and the owner's devices): each profile's
  floors with a person using Eye Tracking, Head Tracking and Switch
  Control's point scanning on an iPad; which flags each input method
  turns on.
- **Wave 3 item 9**, the late-stage profile, once this has merged.

## Sources for the proposed floors

Read 2026-10-30. Distances and angles are this record's conversions at
46 cm and 163 points per inch.

- Apple, Eye Tracking on iPad: "about a foot and a half away from your
  face" (https://support.apple.com/guide/ipad/control-ipad-with-the-movement-of-your-eyes-ipad2cd35723/ipados);
  Head Tracking on iPhone: "about 18 inches away from your face"
  (https://support.apple.com/en-sa/guide/iphone/iph9c3dc17cf/ios).
  Apple publishes no target size, dwell time or accuracy for either.
- Roig-Maimó and others, 2016, head pointing on an iPhone where "one
  point equals 1/163 inch": correct selections 0.70 at 44, 0.83 at 88
  and 0.89 at 106 (https://pmc.ncbi.nlm.nih.gov/articles/PMC4801630).
- Hansen and others, 2018, head pointing with dwell: effective target
  width about 2 to 2.5 degrees (https://dl.acm.org/doi/10.1145/3206343.3206344;
  http://www.yorku.ca/mack/etra2018.html).
- Raynal and MacKenzie, 2024, single-switch point scanning: width did
  not change movement time but small targets had many more errors
  (https://www.yorku.ca/mack/icchp2024a.pdf).
- Apple's Human Interface Guidelines, Accessibility: "about 12 points of
  padding around elements that include a bezel"
  (https://developer.apple.com/design/human-interface-guidelines/accessibility).

# Sizes that follow how the screen is reached

*2026-10-30. Pull request #69 (`claude/project-thread-ffwagr`). The
item 8 thread (ROADMAP Wave 3 item 8), a cloud session: GitHub CI is its
build.*

## What changed and why

Home had one set of sizes, touch's, and nothing read Family Setup's
answer to how the screen is reached. Now sizes and spacing that follow
that answer are built, and held until the owner answers what Home does
where a window cannot hold the sizes asked for (docs/DECISIONS.md,
"Sizes that follow how the screen is reached", *Held until the owner
answers*; work file
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
  and touch's last. A profile also holds only where every column keeps
  its words at the profile's own, wider gap
  (`HomeLayout.arrangementHoldsItsWords`, after CodeRabbit's review). No
  phone holds more than touch's; every iPad in portrait holds Eye
  Tracking's, except the iPad mini with Bold Text, which holds head
  tracking's.
- **Nothing changes place.** The arrangement is chosen at touch's gap
  in every profile, so only sizes and gaps differ (invariant 8).
- **Back to Talking keeps touch's frame**, and the profile changes only
  as Settings closes, so nothing moves under a look while Settings is
  open, and a look still resting on Back to Talking meets Phrases.
- **A fold or a camera across Home** keeps touch's sizes.
- **Family Setup's first step** says, where iOS reports Switch Control
  or VoiceOver on, which answer may fit, choosing nothing (SwiftUI's
  `accessibilitySwitchControlEnabled` and
  `accessibilityVoiceOverEnabled`, iOS 15 and later), and, once the
  sizes are switched on, what the answer does to them.
- **Held.** Codex's review of the first push found the fallback (smaller
  sizes where a window cannot hold the ones asked for) active while the
  owner had not accepted it, an exception to invariant 11's floors. So
  `ProfileChoice.followsTheAnswer` is off: Home asks for touch's sizes
  for every answer (`ProfileChoice.requestedForHome`), as before this
  change, and the first step says nothing about sizes. One pull request
  turns it on once the owner answers.
- **UI tests** launch at touch's sizes unless they ask
  (`--home-profile`, debug builds with test storage only), so the
  existing tests keep measuring what they did. `HomeSizesTests` launches
  once following the answer (`--home-profile=from-answer`) and once as a
  person's launch, which must keep touch's sizes and say nothing about
  them. Each compares Home's quick controls, edge by edge, with a launch
  at touch's sizes, and runs with Settings' idle reset at its real
  length, so Settings cannot reset itself while the test walks Family
  Setup.
- **The privacy policy** (`site/privacy/index.html`, the app's copy
  too, Effective October 30, 2026): *How you control the app* said
  Brickson "only learns which button you chose". It now also says that
  Family Setup's first step reads whether VoiceOver or Switch Control is
  on, only to suggest an answer, and that this stays on the device and
  is not saved.

The same pull request records the owner's decision of 2026-10-30 that
items 8 and 9 come before the first App Review build (docs/DECISIONS.md,
"Items 8 and 9 come before the first App Review build"): the owner
wants the app complete before it is submitted. docs/ROADMAP.md no longer
holds them until that build, stage profiles are no longer left out of
R0, and R0's *Release gate* now says no build with the larger sizes
goes to App Review or an external TestFlight group until the owner has
answered the three dwell hazards still open: whether Yes and No may
border the message, the top of Stop's well nearest Again, and dimmed
phrases bordering Clear and Put Back by centre.

## Commits

- `7a51022` Write the work file for sizes that follow how the screen is
  reached.
- `d3750b1` Size Home from Family Setup's answer.
- `f259234` Record sizes that follow reach, and items 8 and 9 before
  App Review: the decisions, the roadmap with items 8 and 9 no longer
  gated, the handoff, the accessibility map, the website's
  accessibility page, the README and AGENTS.md.
- After Codex's and CodeRabbit's reviews and an independent review
  (four reviewers, each finding checked by a second): hold Home's sizes
  at touch's until the owner answers (the switch, the test-only
  override, the hidden sentence and their tests); take a larger profile
  only where its columns keep their words; pin Back to Talking's size
  under the larger profiles; the privacy policy's sentence; and the
  records: the three open hazards in the release gate, the fallback's
  reading of invariant 11 for the owner, the shortfall figures for every
  phone tested, 2.6 degrees for an Eye Tracking tile, and the
  accessibility map's rows and legend. The website's accessibility page
  goes back to its earlier words, which stay true while the sizes are
  held.

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
  - `homeKeepsTouchsSizesUntilTheOwnerAnswers` failed to build before
    the switch existed, and fails if the switch is turned on or a held
    Home asks for other sizes than touch's.
  - `aProfileHoldsOnlyWhereEveryWordFitsAsAtTouchsSizes` failed before
    `arrangementHoldsItsWords` with 1,042 cases, first at 680×744 at
    Switch Control's sizes (categories 120 points wide where their words
    need 122); with it, the windows table changed only for the iPad mini
    in portrait with Bold Text (head tracking's, pinned in
    `eyeTableWithBoldText`).
  - `backToTalkingUnderALargerProfileIsTouchsAsRecorded` pins Back to
    Talking at touch's frame under a larger profile, never under 44
    points, and no smaller than measured (126.4 wide, 64 tall, below the
    larger floors: an exception named in the decision, after the
    independent review); it fails with each profile's own Back to
    Talking.
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
- After the review fixes, the whole Linux run again: 132 tests in 12
  suites, all passing but the same Linux-only check of
  `backToTalkingUsesTheFinalPhrasesFrame` (5 issues at one line, touch's
  frames, which the change leaves as they were); the Back to Talking
  test, written after that run started, passed on its own.
- The shortfalls in the records were measured on Linux with the
  layout engine over `HomeLayoutEngineTests.windows` and every text
  size, Bold Text off and on: at head tracking's sizes every phone is
  84 (iPhone 17 Pro Max) to 635 (a zoomed 375×667 phone) points short,
  at Eye Tracking's 304 to 871; the iPad mini in landscape is 30 to 58
  short at head tracking's (58 at AX5) and 197 at Eye Tracking's.
- CI on the first push (run 41031065358, the current Xcode on GitHub's
  image, iOS 27.0 simulators): the unit tests passed. The UI tests
  passed on the iPad Pro 13-inch (57 passed, 2 skipped) and the iPhone
  17 (53 passed, 6 skipped) except `HomeSizesTests`' one query for the
  first step's sentence on sizes, which XCTest refused because a query
  by identifier is limited to 128 characters and the sentence is
  longer. The rest of that test passed: following the answer, Home on
  the 13-inch iPad in portrait met Eye Tracking's floors before an
  answer, and its quick controls were no taller than touch's 88 points
  once Touch was chosen. The test now finds the sentence by its label,
  and compares frames with a launch at touch's sizes instead of that
  88-point bound.
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

- Nothing was built with Xcode or run on a simulator by this session:
  CI is the build. The changes after the first push (the hold, the word
  check, `HomeSizesTests` as rewritten) were first built by the second
  push's run.
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
  *Waiting on the owner*), and with it Settings' way back at touch's
  size under the larger ones. Until then the sizes are held. If the owner
  chooses the largest that fit, one pull request sets
  `ProfileChoice.followsTheAnswer` to true and its pinned test with it;
  another answer is built first. That pull request also runs Home's
  accessibility audits and the rendered-label check at the larger
  sizes, which no UI test does while they are held (the independent
  review's finding), and records in AGENTS.md's invariant 11 that the
  floor a window must not go below is that of the sizes it takes.
  Before a build with the larger sizes goes to App Review, also the
  three open dwell hazards: Yes and No bordering the message, the top
  of Stop's well nearest Again, and dimmed phrases bordering Clear and
  Put Back by centre.
- **Device checks** (Codex and the owner's devices): each profile's
  floors with a person using Eye Tracking, Head Tracking and Switch
  Control's point scanning on an iPad; which flags each input method
  turns on.
- **Wave 3 item 9**, the late-stage profile, once this has merged.

## Review findings not taken

- CodeRabbit's suggestion to skip the reserved layout's search for a
  larger profile, which a fold or a camera across Home never keeps: it
  saves time only, on the few windows with a fold or a camera, and an
  early return would leave such a layout's frames unresolved for any
  later caller.
- The independent review's finding that Settings over head tracking's
  and Switch Control's Home is never scored: measured, each request
  scored 126 windows at its own profile with no finding, and the Eye
  Tracking request 114 at Eye Tracking's and 12 at head tracking's, so
  the claim in the decision holds; the test was left as it is.
- That every existing UI test runs at touch's sizes: true, and right
  while the sizes are held, since touch's are what every person gets.
  The pull request that switches them on runs Home's audits and the
  rendered-label check at the larger sizes (*Follow-ups*).

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

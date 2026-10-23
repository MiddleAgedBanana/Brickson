# One chain engine for dwell safety

*2026-10-23. Pull request #49 (`claude/project-thread-bt89wd`). The
Wave 3 item 2 thread (a cloud session).*

## What changed and why

Under AssistiveTouch Dwell, head tracking, Eye Tracking and Switch
Control's auto-select, an activation can repeat while the pointer stays
put, so what a person chooses can be followed by whatever is nearest
that spot once the screen changes, and so on. Until now the tests
scored single hops, with the nearest-control rules written twice. This
change adds the one engine docs/LESSONS.md asks for ("Score chains, not
single hops"; "One chain engine, not five scripts"), ROADMAP Wave 3
item 2, and records what it finds (docs/DECISIONS.md, "One chain engine
for dwell safety"). Nothing in the app changes; it is all tests.

- **`ChainEngine`** (`BricksonUITests/ChainEngine.swift`, compiled into
  both test targets) takes a screen's states, each control's frame, what
  it does there (speaks, alarms, changes data, moves things, only
  navigates, nothing) and the state it leads to, and follows every chain
  of held activations from every start, up to six: by nearest centre and
  by nearest edge, ties within half a point followed, with the pointer
  staying on the control or going back to the look. An unasked
  activation that speaks, alarms, changes data or moves things is a
  hazard. It is plain Foundation, so its tests also run on Linux.
- **Surfaces, not scripts.** `HomeChains` describes Home's states
  (spoken or not, which category or Emergency shows, the alarm sounding
  or quiet) and `SettingsChains` Settings' first screen, Family Setup and
  Set Up Step by Step's first step. A control `SettingsChains` does not
  know is reported, not guessed at.
- **Home, every state.** `HomeShapeTests.noChainOnHomeMeetsAHazard`
  scores the layout's frames at widths every 16pt and on both sides of
  each change of arrangement, with Bold Text off and on and the controls
  grown for larger text. It finds only the known hazard at the top of
  Stop's well (docs/DECISIONS.md, "Get Attention and Stop on Home"), as a
  strict known issue. `HomeShapeTests`' own nearest-control helper is
  gone; its checks use the engine's rules.
- **Settings, on the running app.** `SettingsOnHomeTests` now also opens
  Family Setup and, where its row shows without scrolling, Set Up Step by
  Step, reads each screen as it first shows, follows every chain from
  Home's Settings and from each control of those screens, and attaches
  the findings (`settings-chains-…`). Two kinds are expected, strictly;
  anything else fails: a held look saves an answer in the first step
  (the known gap), and, new, Settings closes under the look, when the
  pointer goes back to a look near Back to Talking's leading edge (No on
  Home) or, on a phone at the largest size, its lower edge (Get
  Attention). The UI tests' `nearestControls` uses the engine's rules,
  and `ScreenControl` now carries whether a control shows as selected.
- AGENTS.md's dwell design rules gain "Score chains with the one chain
  engine".

## Commits

- `ee0ded1`: the engine, Home's and Settings' surfaces, and the tests.
- This record, with docs/DECISIONS.md, docs/HANDOFF.md,
  docs/ROADMAP.md, docs/ACCESSIBILITY.md and AGENTS.md.

## Verified

- **No Xcode here.** This is a cloud session: nothing was built for iOS.
  GitHub CI on this pull request is the build and the run.
- **On Linux, Swift 6.4.1** (a package with the unit target's Swift 6
  main-actor default and a second target with the UI target's
  nonisolated default, holding the shared files): everything compiles
  with no warning; `ChainEngineTests`, `HomeChainsTests` and
  `SettingsChainsTests` (26 tests) pass, and
  `noChainOnHomeMeetsAHazard` passes with its known issue, in about 8
  seconds for both Bold Text cases.
- **Each new test fails when it should.** Eleven deliberate breaks, each
  caught by the test named: Get Attention stopping the alarm
  (`noChainOnHomeMeetsAHazard`); no Stop at all (its strict known
  issue); Emergency speaking (`aPhoneAsCIReadsItHasOnlyTheKnownKinds`);
  the Settings kind ignoring the pointer
  (`hazardsAreSortedIntoTheirKinds`); an unknown control scored as
  harmless (`aControlItDoesNotKnowIsReported`); the first step's answers
  not saving (`eachControlDoesWhatSettingsDoes`); the tie narrowed
  (`aTieWithinHalfAPointCountsBoth`, `aLookTiedBetweenTwoControlsChoosesNeither`);
  the person's own choice counted as a hazard (three engine tests); the
  pointer never going back to the look (`bothPointersAreFollowed`); a
  tied look counted as a choice (`aLookTiedBetweenTwoControlsChoosesNeither`);
  tiles dropped from Home's frames (`framesComeFromTheRunningAppsControls`).
- **The Settings findings were predicted first.** Main's UI test results
  of 2026-10-23 (run 40010147376) keep each screen's button frames. Fed
  to the engine for the iPhone 17 and the 13-inch iPad at the default and
  largest sizes and the iPad in landscape, with the first step's rows
  placed as Step 2's are (CI had not captured it), every configuration
  found both kinds and nothing else; moving the first step's rows by
  20 to 200pt changed which answer is met, not the kinds.
- `scripts/test-docs.py` passes.

## Not verified

- Nothing has run on iOS: the unit and UI tests run first on this pull
  request's CI.
- The first step's real frames, and Family Setup's in landscape, have
  not been seen; this pull request's UI run attaches them
  (`first-step-opened-…`, `family-setup-opened-…`).
- Every finding is the model's, on the simulator's frames: not evidence
  of what a gaze, Snap to Item or Dwell does on a device. Whether the
  pointer stays or follows the gaze, how far Snap to Item jumps, and
  whether it ignores controls scrolled off screen are device checks
  (docs/HANDOFF.md, *Checks that need a real device*).
- Home's message and Settings' words are not resting places in the
  engine yet; Settings' other screens and the Personal Voice question's
  chain are not scored.

## Follow-ups

- Fix "Settings closes under the look" and "a held look saves an answer"
  by placement: ROADMAP Wave 3 item 7, with item 4 for Home's side. Each
  is a strict expected failure in `SettingsOnHomeTests`, so the fix
  removes it.
- When Home moves onto the layout engine (item 4), the layout engine's
  own nearest-control helper (`Nearest`, PR #48's tests) moves onto
  `ChainEngine`, and Home's message becomes a resting place.
- Settings' other screens (Voice Settings first, for the Personal Voice
  question) become surfaces when they are scored.

# Settings' chains: a guide link where Set Up Step by Step was

*2026-10-24. Pull request #50 (`claude/project-thread-xn2qoy`). The
Settings' chains thread (a cloud session), ROADMAP Wave 3 item 7.*

## What changed and why

Under Dwell, head tracking, Eye Tracking or Switch Control's auto-select,
a look held after choosing Set Up Step by Step in Family Setup stayed
where the row was, and the first step, "How is the screen reached?", put
an answer there. An answer saves the moment it is chosen, so a held look
could add Touch and restart the check-in clock, some chains starting at
Home's Settings button. The chain engine found it on every window CI
reads (docs/DECISIONS.md, "One chain engine for dwell safety"). The work
file is [`work/settings-chains.md`](../work/settings-chains.md), and the
screens are in the Figma file's
[Settings' chains section](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=48-207).

- **The first step** now opens on its words, filled down to where Family
  Setup's Set Up Step by Step row was, then **Learn About Each Way**, at
  least as tall as that row, which only opens the Reaching the Screen
  guide (all ways shown; Back returns to the step). The six answers,
  Clear My Choices and the failure line follow, one row lower. Next is
  unchanged. Words alone would not have done it: Snap to Item picks the
  nearest control wherever the look rests, and below the words that was
  an answer. The guide is what a family needs to answer the question, so
  the row has a purpose of its own; it is not a decoy.
- **How it finds the place.** `SettingsScreen` names its content's
  coordinate space (`SettingsMetrics.contentSpace`), Family Setup
  measures its Set Up Step by Step row's top and label height into
  `SettingsLanding`, and the first step sizes its opening words from them
  (`SettingsLanding.firstStepOpeningHeight`). A check-in card above the
  row moves the row and so the link; at the largest text sizes, where
  the words are taller than the space, the link sits lower, the safe
  direction.
- **Get Attention is not added to Settings' bar, and the owner
  decides what happens to its place** (docs/DECISIONS.md, "Get Attention
  in Settings' bar: the owner decides"). Scored with the link in place,
  filling the bar's empty place adds 5 to 7 chains on every window that
  sound the alarm unasked, mostly through the standard Back button just
  under it. So this change leaves the place empty, as it has always
  been, and the sound line where it is. The section was first written as
  a reversible default; Codex's review found that it made a gap into an
  exception to an AGENTS.md design rule without the owner, and it was
  rewritten as open, with the owner's three choices, before merging.
- **Tests.** `SettingsChains` knows the link and the guide it opens (its
  Open Dwell Control Settings buttons leave for the Settings app, which
  the chains do not follow). `SettingsOnHomeTests` opens and reads the
  guide where the link shows, and "a held look saves an answer" is now a
  plain assertion instead of a strict expected failure. "Settings closes
  under the look" stays strictly expected. `SettingsTests`' walk through
  the steps chooses Voice Control instead of Eye Tracking, which now sits
  under the Next bar on a phone until the step scrolls, and a new UI test
  opens the guide from the link and comes back with the answer kept.

## Commits

- `c663791`, `31cc050`, `144248b`: the work file's intent, spec and plan.
- `1de50f5`: the link, its measuring, and the tests.
- `603ad93`: this record, with docs/DECISIONS.md, docs/HANDOFF.md,
  docs/ROADMAP.md and docs/ACCESSIBILITY.md.
- The next commit: Get Attention's section rewritten as open for the
  owner, after Codex's review, and the lines that cite it.

## Verified

- **No Xcode here.** This is a cloud session: nothing was built for iOS.
  GitHub CI on this pull request is the build and the run.
- **The findings were modelled first, on CI's real frames.** PR #49's
  last UI run (40036138085, `23fcc0e`) keeps each Settings screen's
  button frames for the iPhone 17 and the 13-inch iPad at the default
  and largest text sizes and the iPad in landscape. Fed to the chain
  engine on Linux, they reproduce that run's findings exactly (saves an
  answer: 7, 0, 6, 4 and 6; Settings closes under the look: 3, 3, 4, 5
  and 4). With the link on Set Up Step by Step's frame and the answers a
  row lower, no chain saves an answer on any of them and nothing new is
  found; the link still clears them 40 or 100pt lower or 60pt taller, and
  does not when shorter than the row. "Settings closes under the look"
  goes to 6, 3, 10, 7 and 9, through the guide's Back to Talking. Get
  Attention in the bar's empty place adds 7, 5, 7, 5 and 7 chains that
  sound the alarm.
- **On Linux, Swift 6.4.1:** the chain files and `ChainEngineTests.swift`
  build with the unit target's main-actor default and the chain files
  with the UI target's nonisolated default, with no warning; the 27 tests
  pass, including the new `aGuideLinkWhereSetUpStepByStepWasSavesNoAnswer`.
- **The new test fails when it should:** with the link scored as saving
  (it and `eachControlDoesWhatSettingsDoes` fail), with the link 64pt
  tall instead of the row's 78, and with it 12pt higher than the row.
- The String Catalog gains "Learn About Each Way" and still matches the
  code's literals (checked by script; CI's catalog check is the proof).

## Not verified

- Nothing has run on iOS: the SwiftUI change (the named coordinate space,
  `onGeometryChange` reading it, the opening block and the link), the
  unit tests that need the app (`SettingsLandingTests`) and every UI test
  run first on this pull request's CI.
- That the link lands on the row's frame in the running app: the model
  used frames placed by arithmetic; `SettingsOnHomeTests` on CI reads the
  real ones and fails if any chain saves an answer.
- Apple's accessibility audit of the first step with the new row.
- Every finding is the model's, on the simulator's frames, not evidence
  of what a gaze, Snap to Item or Dwell does on a device
  (docs/HANDOFF.md, *Checks that need a real device*).
- Still not scored: Voice Settings and Settings' other screens; the
  check-in card's rows (no test can make a check-in due yet); Family
  Setup scrolled before a row is chosen; and opening the Settings app from
  a guide, which the engine counts as navigating, not as a hazard.

## Follow-ups

- **AGENTS.md is ahead of the app.** Its *Design rules for dwell, switch
  and pointer input* say "Settings opens on a large way back and a
  start-only Get Attention". Brickson has never shown Get Attention in
  Settings, and now has a measured reason not to yet. If the owner
  chooses to keep it out, proposed wording: "Settings opens on a large
  way back, with a place kept for a start-only Get Attention until one
  clears its chains (docs/DECISIONS.md, "Get Attention in Settings' bar:
  the owner decides")", with that section retitled for the choice. Not
  changed here, because review rules change only with the owner's yes.
- **Settings closes under the look:** Back to Talking over harmless
  controls only, with Home on the layout engine (ROADMAP Wave 3 item 4).
- **Get Attention in Settings:** the owner's choice of the three in
  docs/DECISIONS.md, "Get Attention in Settings' bar: the owner decides":
  keep it out for now, add it anyway at the measured cost, or find a
  place that clears its chains first.
- **Voice Settings as a chain surface**, with the Personal Voice question,
  before ROADMAP Wave 3 item 8 lets setup answers change sizes.

# The layout engine, with no screen change yet

*2026-10-23. Pull request #48 (`claude/project-thread-607aog`). The
Layout engine thread, a cloud session with no Xcode.*

## What changed and why

Wave 3 item 3 (docs/ROADMAP.md): one plain, tested type, `HomeLayout`,
that turns the space a window gives Home (its size, safe areas and
reserved regions), the input profile, one line of each label style at
the person's text size (with Bold Text) and the library's largest
category into a frame for every slot on Home. Nothing on screen uses
it yet; Home moves onto it in item 4. The work file
(docs/work/layout-engine.md) has the intent, the spec and the plan,
each committed as written; the decisions are in docs/DECISIONS.md,
"The layout engine", with dated notes in "Home's slot plan", "Get
Attention and Stop on Home", "Typing is a state of Home" and *Where the
grid still scrolls*.

What the engine does, in short: the slot plan's regions A, C, B, D from
the top; a compact arrangement below 664 points (714 with Bold Text)
that keeps Get Attention under Emergency, and the slot plan's own
one-row safety row from there; controls at least 44 points and one line
of their words at the person's size; growth toward today's sizes only
where the starter library's largest category fits first; the safety row
kept out of the keyboard's room; a category never taller than the safety
row. It names no device.

What its tests found, each recorded for item 4 or the owner:

- The starter library fits every iPad window at every text size but the
  iPad mini in landscape at AX5, the 375×667 phone at the default size
  (it scrolls today), and larger phones through AX1 (the Pro Max through
  AX3). It cannot fit phones at AX3 and AX5, or 320-point windows, with
  every control holding one line of its words. The roadmap expected the
  engine to fit every window that scrolls today; that was not possible
  at the touch floors, so docs/ROADMAP.md now says so.
- Yes and No border more of the message once Phrases and Type sit beside
  it, as the slot plan has them: up to 97% by centre on compact widths,
  against 56% today. The owner's to accept or reject before R1.
- With Bold Text, "understand." needs 118-point compact tiles; today's
  Home gives 375 and 390-point phones 109 and 114, so the word can break
  there now. The engine gives those windows two columns.
- Below 345 points with Bold Text, the message beside Phrases and Type is
  too narrow for "understand.".
- With the keyboard's room cutting the safety row back, a category could
  grow taller than the safety row, and Emergency then came nearer Stop's
  well than the category under it: the engine now caps categories at the
  safety row's height (`aCategoryIsNeverTallerThanTheSafetyRow`).

`HomeLayoutTests` is already the UI test of the running Home, so the
engine's tests are `HomeLayoutEngineTests` (pure, no fonts) and
`HomeLayoutEngineFontTests` (the real fonts, on CI).
`StarterLabelFitTests` now shares its two fit helpers with the font
tests; nothing else in it changed.

## Commits

- `d912030` the work file's intent.
- `38cae88` the spec.
- `2a16b3b` the plan.
- `9856975` the tests.
- `9388ede` the engine.
- `924ea46` the documents and this record.
- A merge commit bringing in main with #47 and #49 (2026-10-24), its
  four conflicts in documents only, each kept from both sides.
- The engine's tests on the chain engine's rules, and this section's
  updates: the last commit.

## Main merged in, and the one chain engine (2026-10-24)

#49 merged first, with one chain engine for dwell safety
(docs/DECISIONS.md, "One chain engine for dwell safety"), so that
"nearest" has one definition. This pull request had written its own
nearest-control helper, a third copy. Its `Nearest` helper now takes its
rules from `ChainEngine` (the distances, the half-point tie, the points
across a frame), and a new test,
`noChainOnTheEnginesFramesMeetsAHazardButStopsWell`, follows every chain
of held activations on the engine's frames with `HomeChains`' map, with
Phrases and Type added: in every Home state, both rules and both
pointers, at widths every 16 points and both sides of each change of
arrangement, at 874 and 1376 points tall, three text sizes, Bold Text
off and on. It finds the top of Stop's well nearest Again on compact
widths (and Yes at its corner on the narrowest bold windows) and nothing
else; it fails on that hazard on a regular width, and, strict, once
compact widths lose it. Swapping Again and Get Attention on compact
widths made it fail (Get Attention, then Stop). On Linux all 28 tests
pass, the chain test in about 33 seconds.

## Verified

- On Linux with Swift 6.4.1 (Swift 6 language mode, default main-actor
  isolation, warnings as errors), in a package outside the repository
  holding `HomeLayout.swift`, `KeyboardAllowance.swift`,
  `HomeShape.swift` and `HomeLayoutEngineTests.swift`: all 27 tests
  pass, with their strict known issues recorded (Yes and No border the
  message, the top of Stop's well nearest Again, the message on the
  narrowest bold windows, the keyboard on short windows at large text
  sizes, and the windows that cannot fit), in about 19 seconds in a
  debug build.
- Each rule's test was broken on purpose once and failed: categories
  allowed past the safety row; no keyboard cut; an 8-point region gap;
  Get Attention and Emergency swapped; a grid that never scrolls;
  `startersFit` always true; floors that ignore the text size.
- The text sizes in the pure tests, the new minimum widths and the tile
  floors come from Apple's SF Pro measured with HarfBuzz on Linux (the
  method matched CI to half a point before); the font tests check them
  on CI.
- `scripts/test-docs.py` and `scripts/test-hooks.py` pass.

## Not verified

- Nothing was built with Xcode: this session cannot. CI is the build.
  *Since settled:* CI's first run (run 39997145852, on `924ea46`) built
  `HomeLayoutText.swift` and `HomeLayoutEngineFontTests` with warnings as
  errors and passed them on the iPad simulator: `LabelFont` measures the
  pure tests' line heights at all five text sizes with Bold Text off and
  on, and the new widths and tile floors hold their words at the default
  size (by UIKit's and SwiftUI's measurement, not rendered pixels). The
  font tests have not run on an iPhone simulator.
- The iPad safe areas (32 above, 20 below) are inferred from CI's
  frames, and the phones' from Apple's published sizes, not measured
  here. iPhone Duo's displays and iPad windows smaller than the screen
  are not in the table.
- That today's Home breaks "understand." on 375 and 390-point phones with
  Bold Text is a prediction; no screenshot shows it.
- How long the chain test takes on CI's Mac. The rest of the sweep took
  about 52 seconds there (84 summed) on its first run.

## Follow-ups

- Wave 3 item 4 (Home on the engine), in a fresh thread: the
  arrangement for 320-point windows and phones at the largest text
  sizes, the tile floor that follows the tile's width, the Bold Text
  tiles, Back to Talking over Phrases' frame, the UI tests that pin the
  frames, and the Figma check (docs/work/layout-engine.md, *Plan*).
- The owner: *Yes and No border the message*, with the measured cost,
  before a dwell, switch, head or gaze profile ships (docs/DECISIONS.md,
  "Home's slot plan").
- Item 6, iPhone Duo: moving slots off reserved regions once R0 item 13
  has looked at the open device.

# Settings' chains, and Get Attention in Settings

*Roadmap: Wave 3 item 7 (R0 items 4 and 7). Owner: the Settings' chains
thread (a cloud session; GitHub CI is its build). Status: held on
2026-10-24; the link waits for ROADMAP Wave 3 item 4 (*Held*, below).*

## Intent

- **Problem:** under AssistiveTouch Dwell, head tracking, Eye Tracking or
  Switch Control's auto-select, the pointer is still where the last
  control was when the next screen appears, and a held look can choose
  whatever is now nearest it. Choosing Set Up Step by Step in Family
  Setup opens its first step, "How is the screen reached?", with an
  answer nearest that spot, and an answer saves the moment it is chosen.
  The chain engine found it on CI's run of PR #49 on every window where
  the step opens without scrolling: 7 chains on the iPhone 17 at the
  default text size, 6 on the 13-inch iPad in portrait and in landscape,
  4 on the iPad at the largest size, some starting at Home's Settings
  button, three activations away (docs/DECISIONS.md, "One chain engine
  for dwell safety"). Nothing reads the answers yet, but ROADMAP Wave 3 item 8
  will let them change Home's sizes, so this comes first. The second half
  of the item: Settings' safety bar keeps an empty place for a start-only
  Get Attention, waiting for this score.
- **Proposed outcome:** a look held after choosing Set Up Step by Step
  meets a control that only opens a page to read, by either rule of
  "nearest" and with either pointer; no chain through Settings saves an
  answer. Get Attention joins Settings' bar only if its place adds no
  chain that sounds the alarm unasked.
- **Who and what it affects:** families answering the first step (touch,
  mostly), who see one more row; people using dwell, head, gaze or
  switches who wander into Settings. The first step's view
  (`GuidedSetupView`), Family Setup (`FamilySetupView`), the shared
  Settings screen (`SettingsScreen`, `SettingsLanding`), and the tests
  that score Settings (`SettingsChains`, `SettingsOnHomeTests`).
- **Constraints:** invariant 1 (a standard `NavigationLink` with a label,
  at Settings' 64pt rows), 8 (no position depends on use or time: the
  row is always there), 10 (chains scored by nearest centre and nearest
  edge, with both pointers; fixed by placement, never by a timer, a
  decoy button or pointer code), "Words never break", *Layout on every
  device and window* (from measured frames, never a device), and
  docs/DECISIONS.md, "Settings is a cover with a fixed safety bar" and
  "Setup answers are kept as offered, never as completed".
- **Open questions, each answered here:**
  - *Why not words instead of a control?* Family Setup opens on words for
    the root's row, but that works because the nearest control below the
    words is a row that only navigates. On the first step the nearest
    control below any words would be an answer, and Snap to Item picks
    the nearest control wherever the look rests. So the spot needs a
    control that only navigates.
  - *Is that control a decoy?* No. It opens Reaching the Screen, the
    guide to each way of reaching the screen, which is what a family
    member needs to answer "How is the screen reached?" well (what Switch
    Control or Head Tracking is, what each needs). Family Setup already
    has the same guide as a row; step 3 shows only the sections for the
    ways chosen. Its place is chosen for safety; its purpose stands on
    its own.
  - *Get Attention in Settings' empty place?* Scored first, then decided
    (*Spec*, *Concerns*).

## Spec

- **States:** only the first step of Set Up Step by Step changes. Top to
  bottom: the heading and the sentence under it, in one block; **Learn
  About Each Way** (a `NavigationLink` to Reaching the Screen, a book
  icon, `learnAboutEachWay`); the six answers; Clear My Choices; the
  reserved failure line. Next stays in its fixed bar at the bottom.
- **Where the link sits:** its top is where Family Setup's Set Up Step by
  Step row's top was, both measured in the scrolling content of their
  screens (`SettingsLanding`), so a check-in card above the row, when one
  shows, is counted. The block above it is at least tall enough to reach
  that line. Its label is at least as tall as the row's label, so the
  link is at least as tall as the row: modelled on CI's frames, a link
  40 or 100pt lower or 60pt taller still clears every chain, but one
  shorter than the row does not (a look at the row's lower edge then
  meets Touch). Where the words above are taller than the space, at the
  largest text sizes, the link sits lower, which is the safe direction.
  Where Family Setup was scrolled before the row was chosen, the look
  rests higher than the link, on the words or the link, never nearer an
  answer.
- **Where it leads:** the same Reaching the Screen guide as Family
  Setup's row, every way shown. It opens on words: on CI's windows its
  first screenful holds only Back and Back to Talking. Its Open Dwell
  Control Settings buttons, far down, leave for the Settings app, as
  they do from Family Setup. Back returns to the first step, answers
  untouched.
- **Input methods:** touch passes one more row; Voice Control can say
  "Tap Learn About Each Way"; Switch Control scans one more item before
  the answers; a dwell, head or gaze pointer resting where Set Up Step by
  Step was meets the link, which only navigates. On the phone the answers
  sit one row lower, so Eye Tracking and below are reached by scrolling,
  as Head Tracking and below already were.
- **Colours:** none new: the row is white on `Palette.controlFill`
  (5.98:1, pinned in `PaletteTests`).
- **Privacy policy:** no sentence changes.
- **Screens:** in the Figma file, page *Settings and Library*, section
  [Settings' chains: step 1 with Learn About Each Way](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=48-207),
  wireframes at CI's measured frames:
  [A. Family Setup today](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=48-210),
  [B. step 1 today](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=48-238),
  [C. step 1 proposed, iPhone 17](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=48-269),
  [D. step 1 proposed, 13-inch iPad portrait](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=48-301).
  Not yet accepted by the owner; the owner accepts them by merging.
- **Concerns:**
  - *Settings closes under the look, more often.* The guide's Back to
    Talking is a new way into that open hazard, only where the pointer
    goes back to the look: modelled on CI's frames, its chains go from 3
    to 6 on the phone, 4 to 10 on the iPad in portrait, 5 to 7 at the
    largest size and 4 to 9 in landscape. Family Setup's own guide rows
    reach it the same way today, unscored, because the engine stops at
    their screens. It stays a strict expected failure; its fix is Back to
    Talking over harmless controls only (ROADMAP Wave 3 item 4).
  - *Get Attention in the bar's empty place adds alarm chains.* Modelled
    on CI's frames with the link: 5 to 7 chains on every window sound the
    alarm unasked; without it, as merged (*Held*, below), 2 to 5. The
    standard Back button sits just under that place,
    and on a screen with no Back, Settings' first screen, the spot where
    Back was is nearest Get Attention by both rules. On the iPad, the
    middle of a full-width row is as near Get Attention as Back to
    Talking. So this change does not add Get Attention to Settings'
    bar, nor move the sound line, whose move was to come with it; whether
    it stays out is the owner's decision (docs/DECISIONS.md, "Get
    Attention in Settings' bar: the owner decides").

## Plan

- **Files that change** (this thread, one pull request):
  - `Brickson/Settings/SettingsComponents.swift`: `SettingsScreen` names
    its scrolling content's coordinate space, so a frame measured on one
    Settings screen means the same place on the next.
  - `Brickson/Settings/SettingsView.swift`: `SettingsLanding` also keeps
    the top of Family Setup's Set Up Step by Step row and its label's
    height, and gives the first step the least height of its opening
    block.
  - `Brickson/Settings/FamilySetupView.swift`: measures that row.
  - `Brickson/FirstRun/GuidedSetupView.swift`: the opening block and
    Learn About Each Way.
  - `Brickson/Resources/Localizable.xcstrings`: the new row's words.
  - `BricksonUITests/SettingsChains.swift`: the link and the guide it
    opens, as a state of their own.
  - `BricksonUITests/SettingsOnHomeTests.swift`: opens and reads the
    guide where the link shows; "a held look saves an answer" is no
    longer expected.
  - `BricksonUITests/SettingsTests.swift`: the walk through the steps
    chooses Voice Control, which stays clear of the Next bar on a phone
    now that Eye Tracking sits under it until scrolled.
  - `BricksonTests/ChainEngineTests.swift` and a new
    `BricksonTests/SettingsLandingTests.swift`.
  - Records: a `docs/log/` file, docs/DECISIONS.md, docs/HANDOFF.md,
    docs/ROADMAP.md and docs/ACCESSIBILITY.md where they say otherwise.
- **Order of work:** this work file, then the code and its tests in one
  commit, then the records.
- **Risks, and how each is checked:**
  - The link lands off the row's frame (a measuring mistake, or a screen
    whose content starts lower): `SettingsOnHomeTests` reads CI's real
    frames on the iPhone and the iPad and fails if any chain saves an
    answer.
  - A control on the guide that the chains do not know: reported and
    failed, not guessed (`SettingsChains`).
  - The coordinate-space and geometry APIs under Swift 6's strict
    concurrency: the CI build, with warnings as errors.
  - Apple's accessibility audit on the first step: the existing audit
    test of every step.
- **Proof:**
  - `SettingsOnHomeTests` (UI, CI's iPhone and iPad, default and largest
    text, iPad landscape): no chain saves an answer, plainly asserted
    where it was a strict expected failure. Fails if the link is removed,
    sits shorter than the row or more than about 8pt higher.
  - `SettingsChainsTests.aGuideLinkWhereSetUpStepByStepWasSavesNoAnswer`
    (unit, also runs on Linux): CI's phone frames with the link find no
    chain that saves an answer and nothing new. Fails if the link is
    dropped from the first step's frames or scored as saving.
  - `SettingsChainsTests.eachControlDoesWhatSettingsDoes`: the link only
    navigates, to the guide; the guide's Back returns to the first step.
    Fails if either leads anywhere else.
  - `SettingsLandingTests`: the opening block's height is the row's top
    less the gutter and one row's spacing, and never negative. Fails if
    either is dropped.
  - Device checks: none new. Whether Snap to Item lands on the link is
    the open check of how Snap to Item picks a target (docs/HANDOFF.md,
    *Checks that need a real device*).

## Held

*2026-10-24, after Codex's review of PR #50.* The link was built
(commit `1de50f5`), passed CI's unit and UI tests, and was reverted in
the same pull request before it merged. On PR #49's CI frames it clears
every chain that saves an answer, but the Reaching the Screen guide it
opens has only Back and Back to Talking near the look, so a held look
goes on to Back to Talking, and Settings closes over a phrase, No or Get
Attention: "Settings closes under the look" goes from 3, 3, 4, 5 and 4
chains to 6, 3, 10, 7 and 9. That is worse than saving a setup answer,
which nothing reads yet. No placement of the link avoids it while Back
to Talking closes onto Home under the look, so the link comes back
after ROADMAP Wave 3 item 4 puts Back to Talking over harmless controls,
rescored on that pull request's frames (docs/DECISIONS.md, "One chain
engine for dwell safety"). The Figma screens show the held design.

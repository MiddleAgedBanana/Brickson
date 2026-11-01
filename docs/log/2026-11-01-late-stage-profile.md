# The late-stage profile and the rest board

*2026-11-01. Pull request #74 (`claude/project-thread-iu6919`). The Wave 3
item 9 thread, a cloud session: GitHub CI is its first build.*

## What changed and why

Wave 3 item 9 (docs/ROADMAP.md): the map's Yes/No mode and rest board,
as one profile of the layout engine (docs/DECISIONS.md, "The late-stage
profile"; work file [`work/late-stage-profile.md`](../work/late-stage-profile.md)).

- **What a family sees.** Set Up Step by Step has six steps. The new
  second step, "Which phrases does Home show?", offers Every Category
  and each everyday category by its own name. Each choice only selects
  and is saved at once; the summary says which phrases Home shows.
- **What the person sees.** With a category chosen, when Settings
  closes, Home shows that category's phrases, and Emergency's when
  Emergency is chosen, in fewer, larger tiles. The other categories stay
  in their places, dimmed. Yes, No, Emergency, Again and Get Attention
  grow toward 4 degrees of the person's view (206 points at 46 cm), as
  far as the window has room while the tiles stay as tall. Home asks for
  the late stage's sizes and takes the largest the window holds. Every
  Category gives back Home as it was. Nothing moves between the board's
  phrases and Emergency's.
- **The late stage's floors, proposed.** Phrase tiles 136 points, the
  safety row 136, Phrases and Type 109, categories 89, gap 15: Eye
  Tracking's everywhere but the safety row, which is never smaller than
  a tile. The growth toward 4 degrees comes from "Stretch Gaze Targets
  Out" (CHI 2025, https://doi.org/10.1145/3706598.3713092). The owner
  can overrule both, as the roadmap asked.
- **In the code.** `HomeLayout` has the new profile (`lateStage`), a
  floor and height of their own for Phrases and Type, what the phrase
  area holds (`PhraseArea`), and the board's growth after every
  category's growth and the keyboard's give-back. `RestBoard` resolves
  the family's choice against the library. `ProfileChoice.Request` is
  what Home and Settings lay Home out for, read as Settings closes
  (`BricksonApp`). `SetupRecord.restBoardCategory` keeps the choice,
  read as none from older records. `CategorySelection` shows the
  board's category or Emergency's. Home dims the other categories;
  `GuidedSetupStep.restBoard` is the new step. `HomeChains` scores
  dimmed categories on the board.

- **After Codex's review** (two findings, both real; GitHub Copilot
  made the first too):
  - *The second step was not scored by the chain engine*, which
    AGENTS.md asks of every new screen (*Score chains with the one chain
    engine*). `SettingsChains` now maps it: Back returns to the first
    step, Next leads on to the third (not followed), and every other
    control saves. Scoring it found what the spec had claimed could not
    happen: a held look that chose the first step's Next and stayed on
    Next's top edge met a choice just above the bar or under it, and
    saved it, on 203 of the 630 swept windows (53 at the default size,
    99 at AX3, 51 at AX5). Every choice now lies where every point of
    Next is nearer Next than the choice, by centre and by edge, with 8
    points to spare (`SetupChoicesPlace`, from Next's frame,
    `SettingsScreenFrames.foot`, placed by `SetupChoicesLayout`): each
    under the words, or the choice before it, where it holds there, and
    from the first that does not, the rest just below the bar, where the
    family scrolls to them (docs/DECISIONS.md, "The late-stage profile",
    *Where the second step's choices start*). `SettingsOnHomeTests`
    reads the step in the app on CI's windows; the 630-window sweep
    models it, and so do the Settings sweeps over the larger profiles
    and the board, which use the same model.
  - *The first fix showed no choice on any phone.* It moved the whole
    column below the bar wherever the column could not all stay under
    the words. One independent review of the fix (a subagent reading
    the code) worked out, and the sweep's model confirmed, that this
    happens on every phone-height window, at every text size: a
    full-width Next's top corners are nearer the centre of a choice
    just above the bar than Next's own, so five choices never fit
    between the words and the bar. The step opened on its words and a
    blank space, with Every Category, which keeps Home as it is, a
    scroll away. Now the choices that hold stay under the words: the
    first screenful shows at least one on 97 of the 140 phone-height
    windows at the default size (none before the change), Every
    Category and the first category on the iPhone 17; on windows from
    1,000 points tall, at least one on all 70 at the default size (60
    before), 53 of 70 at AX3 (23 before) and 26 of 70 at AX5 (none
    before). At AX3 and AX5 on a phone the words fill the first
    screenful whatever the choices do. The same review showed `HomeRestBoardTests` tapping a
    choice that now starts below the bar on the iPhone, trusting
    XCUITest to scroll it out from under Next: the test now scrolls
    until the choice is whole above Next, and fails if Every Category
    is not on the first screenful.
  - *Saving the choice had no test that makes it fail* (invariant 5).
    `SetupStoreTests` now makes choosing another category, Every
    Category, and a first choice fail: the board on screen and after a
    relaunch stays as it was, and the store reports the failure the
    step shows.
  - CodeRabbit asked that the gaze study be cited without its authors'
    names (AGENTS.md, *Code Review Rules*, personal names): it is now
    cited by title, venue and DOI.

- **After CI's first UI run** (`12d95a4`): of 63 tests on each
  simulator, one failed on both,
  `HomeRestBoardTests.testTheRestBoardPassesTheAuditAndDrawsItsWordsWhole`,
  and every failure in it but one came from the word reader, not the
  app:
  - *A whole "No" read as nothing.* On the iPad at the default text
    size, in light and dark, Vision's fast recognizer read no word in
    the board's "No": 27 pixels of text on a 412-pixel button. The
    captures show it drawn whole, and the same "No" on a 218-pixel
    button, at AX5, was read. A tall capture is now also read in a band
    around its drawn words, eight times their height (`RenderedWords`).
  - *"Attention," for a whole "Attention".* On the iPhone at AX5 in
    dark, the reader returned `Get` and `Attention,`; the capture shows
    both words whole. Punctuation read around a word is now dropped
    before matching. Neither change can add a letter: a crop only leaves
    pixels out, and a clipped word stays clipped in its band. Both
    captures are kept in `BricksonTests/RenderedLabels` and pinned by
    `RenderedWordsTests`.
  - *One audit finding, not explained.* On the iPad at AX5 in dark,
    Apple's audit reported "Potentially inaccessible text" on no
    element (type 2); default light and dark and AX5 light passed. The
    accessibility tree captured at the finding holds every word visible
    on the screen, and the run's recording shows only the audit's own
    text-size changes. `LaunchTests` met the same finding at AX5 on
    2026-10-22, and it was traced to Home's "Speaking" line leaving the
    screen while the audit read it, so audits now wait for speech to
    finish (issue #30, docs/log/2026-10-22-audit-still-screen.md); this
    test speaks nothing before its audits, and nothing else was seen to
    change by itself. Nothing was
    suppressed, retried or changed for it. Its cause is not known, so it
    stays open: a later clean run does not explain it, and a recurrence
    is a real finding to explain before the pull request merges.

## Commits

- `2732302`, `5c96c8c`, `7545902`: the work file's intent, spec and
  plan.
- `245e2a5`: the profile and the rest board in the layout engine, with
  their tests.
- `024da31`: the choice saved, and which category Home shows.
- `cd41bb8`: Home, Settings and the second step, and the UI tests.
- `000e958`: the board's chain and message-share sweeps at head
  tracking's sizes too.
- `b5ed5ad`: the records: this file, docs/DECISIONS.md,
  docs/ROADMAP.md, docs/HANDOFF.md, docs/ACCESSIBILITY.md, `README.md`,
  `AGENTS.md`'s plain types and the work file's measured table.
- `12d95a4`: the rest board UI test's wait helper renamed apart from
  XCTest's own `wait(for:timeout:)`.
- After Codex's review: `95bc446`, the second step in the chain engine
  and its choices started clear of Next; `2e88f93`, the failing saves
  of the choice; `64d4c91`, the study cited by title in the layout
  engine; `f38fe2b`, the choices that hold kept under the words, and
  the rest board UI test scrolling to a choice below the bar.
- After CI's first UI run: `0132a59`, short words on tall buttons read
  in a band, and punctuation around a word dropped; `1394062`, the
  review's changes to these records and the first UI run's findings.
- After CodeRabbit's second review: the setup decision's step count
  and this file's audit finding kept open.

## Verified

Nothing here was built with Xcode or run in a simulator by this thread:
it ran in a cloud session with no Xcode, so CI is the first build of
the app, its SwiftUI views and its UI tests.

- **The layout files on Linux.** A Swift package built from the
  repository's own layout files and pure tests (Swift 6.4.1 on Ubuntu
  24.04, the project's language mode and default main-actor isolation),
  with no SwiftUI, SwiftData or simulator:
  - `LateStageProfileTests` (12 tests, with head tracking in the chain
    and Yes and No sweeps), `RestBoardTests` (4) and
    `SetupRecordTests` passed.
  - The whole pure suite, 211 tests in 18 suites, matched `main`'s code
    run the same way: the only failures, in
    `HomeReservedRegionTests` (`everyMeasuredTextSizeAndBoldTextKeepsTargetsClear`,
    `keyboardAndBackUseTheFinalOccupiedFrames`) and
    `HomeReservedRegionChainTests.backToTalkingUsesTheFinalPhrasesFrame`,
    fail identically on `main` there (843 and 5 issues), and pass on
    CI's Mac; the Linux package is not the app's build. Every other
    engine, profile, chain, Settings and keyboard test passed unchanged,
    so Home with every category is as it was.
  - After the review, the whole suite again, now 216 tests in 19
    suites with the second step in the sweeps, `SetupChoicesPlaceTests`
    and the foot: the same three failures, with the same 843 and 5
    issues, and nothing else. With the choices that hold kept under the
    words, the 78 tests of the chain, Settings, profile, late-stage and
    placement suites passed again. The 630-window sweep took 108.9 s on
    `main`'s code, 132.0 s with the second step in it, run alone.
  - `SetupStoreTests`, in a second package with `SetupStore` and a
    stand-in for `os.Logger`, passed with the two new failing-save
    tests.
- **CI on the first push** (`12d95a4`): the unit job passed in about
  20 minutes, the first build of the app, its views and its tests, with
  warnings as errors and the String Catalog matching the code. The UI
  job ran 63 tests on each simulator: on the iPad 60 passed and 2 were
  skipped, on the iPhone 56 passed and 6 were skipped (the opt-in slide
  probe, and the phone's landscape tests), and the one failure on each
  was the rest board's words-and-audit test above.
  `testTheRestBoardShowsOneCategoryAndEveryCategoryPutsHomeBack` passed
  on both: the second step and the board worked in the app as first
  built, before the review's changes.
- **The sizes the UI tests expect** were read from the engine for CI's
  windows: on the iPhone 17 at the default size, Yes 64 points tall
  with every category and 118 on the board (tiles 111 and 117); on the
  13-inch iPad in portrait, Eye Tracking's 109 and the late stage's 206
  (tiles 350 and 302).
- **New tests, each with the change that makes it fail:**
  - `theLateStagesFloorsAreTheProposedOnes`: a floor, the gap or the
    206-point growth changing, or a late-stage floor smaller than Eye
    Tracking's.
  - `noControlChangesPlaceOnTheRestBoard`: the board changing an
    arrangement, the category layout or the grid's columns.
  - `theRestBoardChangesOnlyTheSafetyRowAndTheGrid`: the board changing
    the message, Phrases, Type, a category's size, a gap, or a safety
    control's width or edge; the safety row past 206 or into the
    keyboard's room; typing lost; the board's growth before Phrases and
    Type's.
  - `theSafetyRowGrowsTowardFourDegreesWhileTheTilesStayAsTall`: the
    safety row stopping short with room left, or growing past the
    board's tiles.
  - `theRestBoardHoldsOnlyWhereEveryFloorIsMet`,
    `theLargestProfileThatHoldsIsTakenOnTheRestBoard`: a profile taken
    where a floor is missed or the board scrolls, or a smaller one taken
    where a larger holds.
  - `theRestBoardTakesTheSizesTheTableSays`: any window taking other
    sizes than `boardTable` says.
  - `noChainOnTheRestBoardMeetsANewHazard`: a held-look chain on the
    board meeting a hazard touch's frames with every category do not.
  - `yesAndNoBorderNoMoreOfTheMessageOnTheRestBoard`: the board
    bordering more of the message with Yes, No or Again than every
    category in the same window, or than the pinned shares.
  - `closingSettingsOntoTheRestBoardMeetsOnlyPhrases`,
    `noSettingsChainOverTheRestBoardClosesSettingsOrSavesAnAnswer`:
    Back to Talking meeting anything but Phrases on the board, or
    Settings over the board closing or saving under a held look.
  - `aFoldOrACameraShowsTheBoardInEveryCategorysFrames`: the board's
    growth under a fold or a camera.
  - `RestBoardTests`: a board for Emergency or a category gone; the
    count not the larger of the board and Emergency; a board not asking
    for the late stage; a request laying Home out differently from
    `ProfileChoice.layout`.
  - `SetupRecordTests`: a choice not kept or not cleared; a record
    saved before the board not reading with none.
  - `SetupStoreTests` (after the review): choosing another category,
    Every Category or a first choice reporting success when the save
    fails, changing the board on screen or after a relaunch, or
    leaving no warning.
  - `SetupChoicesPlaceTests` (after the review): a choice left where a
    look on Next meets it, judged at every point across Next; a choice
    that holds under the words moved from them; the rest starting
    above the bar's foot, apart, or more than a point lower than they
    need. With every choice pushed below the bar, as the first fix did,
    four of its five tests fail.
  - `SettingsScreenFramesTests.theFootIsTheBarAcrossTheStack`: the foot
    not the bar's frame across the stack, or the content not ending a
    gutter above it.
  - `SettingsChainsTests` (after the review): a control on the second
    step doing other than Settings does, the step missing from the
    starts, or a hazard there not sorted as saving an answer; and the
    630-window sweep, with the second step in it: any chain through it
    saving a choice.
  - `CategorySelectionTests`: the board showing another category than
    its own or Emergency's; a board gone changing what Home shows; the
    board's library losing a category, its order or a count.
  - `SettingsIdleClockTests`: a step lost, moved or numbered wrongly.
  - `HomeRestBoardTests` (UI, iPad and iPhone): Every Category not on
    the second step's first screenful, above Next, or a choice that
    scrolling does not bring whole above Next; the board not shown
    after the second step (categories enabled, the wrong phrases, Yes
    not taller, on the iPad a control under the late stage's floors);
    a control moving between the board's phrases and Emergency's; Every
    Category not giving back Home; and at the default and largest text
    sizes, light and dark, a word not drawn whole or an audit finding.
  - `RenderedWordsTests` (after CI's first UI run), on the two kept CI
    captures: the band not read, or not cut around the word, on the
    tall "No"; "Attention," not counting as Attention; a word missing a
    letter or with one added matching once punctuation is dropped; and
    a band cut from any other kept capture, whole or clipped, or none
    from the tall one.
- **The String Catalog** gained the step's five strings by hand, in
  Xcode's own format; CI's unit run checks it against the code.

## Not verified

- **Anything in the app after the review:** `SetupChoicesLayout`, the
  foot it reads, and the scrolling in `HomeRestBoardTests` are untested
  until CI runs them. The sweep's word heights are estimates; the
  second step's real frames are read only on CI's two simulators, by
  `SettingsOnHomeTests`.
- **The word reader's band and trimming** run only on a Mac: Vision has
  no Linux build. That the band reads the kept tall "No" is untested
  until CI's unit job; the band's rows were checked on every kept
  capture by the same arithmetic in Python (only the tall "No" has one,
  rows 90 to 321 of 412).
- **Whether the AX5 dark audit finding comes back** is shown only by
  the next UI run; its cause is not known.
- **Comfort.** The floors and the 4-degree growth have not been tried
  by a person, or with Apple's Eye Tracking; simulator evidence never
  shows gaze comfort or where Snap to Item lands (docs/HANDOFF.md,
  "Checks that need a real device").
- **The website's accessibility page** says nothing about the rest
  board yet; none of its sentences became untrue.
- **How long the new sweeps add to CI's unit job on its Mac.** On the
  Linux package, a debug build like CI's, the two new suites took about
  115 seconds run one test at a time, as the unit job runs them: the
  Settings chains over the board 37 s, the Yes and No shares 27 s, Back
  to Talking onto the board 23 s, the board's chains 16 s, the place
  check 10 s, the rest under 2 s together. CI's result bundle has the
  Mac's figure (`TestCaseRuns.duration`; AGENTS.md, *Gotchas*, the unit
  job's time).

## Follow-ups

- **Device checks** of the late stage's floors and growth on the rest
  board, with a person using Eye Tracking on an iPad (docs/ROADMAP.md,
  *The quality bar*, Q11 and Q13): the owner and Codex.
- **The owner may overrule** the late stage's floors, the 4-degree
  growth, the growth out of the tiles on four columns, and head
  tracking's sizes on the iPhone 17 Pro Max (docs/DECISIONS.md, "The
  late-stage profile", *Where the board's sizes hold*).
- **Settings' floors under the late stage**, with the other larger
  profiles': the next Settings thread (docs/ROADMAP.md, *The quality
  bar*, Q3).
- **Editing (R2)** keeps the board's phrase count while edit mode is
  open, as Settings does now, so a phrase added on Home moves nothing
  until it closes.
- **The website's accessibility page** may describe the rest board once
  CI's UI tests have passed, saying how it was checked: the release
  documentation work (R0 item 10).

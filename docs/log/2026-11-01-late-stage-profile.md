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
  Out" (Namnakani, Abdrabou, Grizou and Khamis, CHI 2025). The owner can
  overrule both, as the roadmap asked.
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

## Commits

- `2732302`, `5c96c8c`, `7545902`: the work file's intent, spec and
  plan.
- `245e2a5`: the profile and the rest board in the layout engine, with
  their tests.
- `024da31`: the choice saved, and which category Home shows.
- `cd41bb8`: Home, Settings and the second step, and the UI tests.
- `000e958`: the board's chain and message-share sweeps at head
  tracking's sizes too.
- The records: this file, docs/DECISIONS.md, docs/ROADMAP.md,
  docs/HANDOFF.md, docs/ACCESSIBILITY.md, `README.md`, `AGENTS.md`'s
  plain types and the work file's measured table.

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
  - `CategorySelectionTests`: the board showing another category than
    its own or Emergency's; a board gone changing what Home shows; the
    board's library losing a category, its order or a count.
  - `SettingsIdleClockTests`: a step lost, moved or numbered wrongly.
  - `HomeRestBoardTests` (UI, iPad and iPhone): the board not shown
    after the second step (categories enabled, the wrong phrases, Yes
    not taller, on the iPad a control under the late stage's floors);
    a control moving between the board's phrases and Emergency's; Every
    Category not giving back Home; and at the default and largest text
    sizes, light and dark, a word not drawn whole or an audit finding.
- **The String Catalog** gained the step's five strings by hand, in
  Xcode's own format; CI's unit run checks it against the code.

## Not verified

- **Anything in the app:** the SwiftUI views, the step, the dimmed
  categories and every UI test are untested until CI runs them.
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

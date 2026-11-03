# The late-stage profile: Yes and No, and the rest board

*Roadmap: Wave 3 item 9 (R1, the profile layout engine), built before
the first App Review build by the owner's decision of 2026-10-30
(docs/DECISIONS.md, "Items 8 and 9 come before the first App Review
build"). Owner: the item 9 thread (a cloud session; GitHub CI is its
build). Status: built, in review; untested in the app until CI runs
it.*

## Intent

- **Problem:** Home asks the same of everyone at every stage: five
  quick controls, four categories, Settings, and a grid with room for
  the starter library's largest category, eight phrases. Late in the
  disease a person may have only their eyes, tire quickly, and point
  less accurately as the day goes on, so the targets they need most
  (Yes, No, Emergency, Get Attention) are the ones that most need to be
  large, and every extra target is one more thing to miss. Today Yes
  and No are at most Eye Tracking's sizes (a 109-point floor, about 2.1
  degrees at 46 cm), the same as Phrases and Type, and nothing lets a
  family make Home ask less of the person. The accessibility map's
  "Yes/No mode" and "Rest board" rows say *add* (docs/ACCESSIBILITY.md).
- **Proposed outcome:** a family can choose one category for a rest
  board. Home then shows that category's phrases, and Emergency's when
  Emergency is chosen, and nothing else in the phrase area; the other
  categories stay in their places, dimmed; Yes, No, Emergency, Again
  and Get Attention grow toward 4 degrees (206 points at 46 cm), the
  size a 2025 study of gaze targets on phones found best everywhere on
  the screen; and Home asks for the late stage's sizes. Every control
  keeps its place relative to every other, so a person who moves to the
  rest board, or back, relearns nothing. Choosing every category again
  gives back Home as it was.
- **Who and what it affects:** people at the late stage using Eye
  Tracking, Head Tracking, Switch Control or a partner pointing for
  them, and their families, who choose. The layout engine
  (`HomeLayout`: a new profile and what the phrase area holds),
  `ProfileChoice` (what Home asks for), a new plain type for the
  family's choice resolved against the library (`RestBoard`),
  `SetupRecord` (the choice, saved), `CategorySelection` (which
  category shows), Home (the dimmed categories, the grid's rows),
  Settings over Home, Set Up Step by Step (a new second step and the
  Ready summary), the app's root (the request, kept while Settings is
  open) and the UI tests' launch options.
- **Constraints:**
  - Invariant 1: standard buttons only, each at least the profile's
    floors. Dimmed categories stay standard buttons, disabled.
  - Invariant 2: every phrase speaks on the first activation, and
    Emergency stays visible and switches straight to its phrases.
  - Invariant 7: the step's words are practical and say nothing about
    the person's condition, and nothing deletes or rewrites a phrase.
  - Invariant 8: positions never depend on the profile or the board.
    Sizes and spacing may change, places may not, and that includes the
    phrase tiles, so the grid keeps its columns.
  - Invariant 10: chains of held activations are scored on the board's
    frames, and the choice in the step only selects.
  - Invariant 11: the starter library never scrolls in a dwell, switch,
    head or gaze profile, and no target goes below its floor to avoid
    it.
  - *Layout on every device and window*: sizes come from the space
    available, never from the device.
  - "Words never break" (AGENTS.md).
  - docs/DECISIONS.md, "Sizes that follow how the screen is reached":
    the largest sizes that fit, touch's last; Back to Talking keeps
    touch's frame; Settings' places come from Home's frames, so Home's
    request is kept while Settings is open.
  - docs/DECISIONS.md, "Accessibility API coverage": late-stage boards
    are a profile, not new screens, and what iOS reports only suggests.
  - docs/DECISIONS.md, "Layouts from the space available": floors held
    at 163 points per inch, and only the owner changes a floor.
  - The privacy policy: the choice is a setting kept on the device.
- **Open questions, each answered here:**
  - *A profile or a screen?* A profile of the same Home, as the
    coverage decision says. The board changes sizes and what the phrase
    area holds; it adds no screen and moves nothing.
  - *What happens to the other categories?* They stay in their places,
    dimmed. Hiding them would leave empty places a look can rest on,
    and Stop's well and Settings would lose the neighbours their dwell
    safety was measured with.
  - *How are there fewer, larger tiles if the columns cannot change?*
    The grid keeps the window's columns, so a tile keeps its place, and
    takes its rows from the larger of the board and Emergency instead
    of the starter library's largest category. On three columns a
    six-phrase board has two rows instead of three, so its tiles are
    taller. On four columns every starter category already fits in two
    rows, so the tiles keep at least the profile's floor and give some
    of their height to Yes and No (measured in the spec). *Added after
    the build:* an eight-phrase board (Basics, Needs) keeps three rows
    on three columns, as every category does, so on a phone its tiles
    give height to Yes and No too; only a six-phrase board on a phone
    has fewer rows.
  - *What grows?* The safety row: Yes, No, Emergency and Get Attention,
    the four the roadmap names, and Again, which shares their row.
    Phrases and Type, which only change Home's mode, stay at Eye
    Tracking's floor, and the categories at their floor.
  - *How far?* Each row of the safety row grows toward 206 points, out
    of what is left once the board fits at the tile floor, only while
    the board's tiles stay at least as tall as it, and never into the
    keyboard's room, so typing stays wherever it would be without the
    board.
  - *What are the late stage's floors?* Proposed in the spec, as
    defaults the owner can overrule.
  - *Who chooses, and where?* The family, in a new second step of Set
    Up Step by Step, after "How is the screen reached?". A step rather
    than a Family Setup row: Family Setup's rows are where a held look
    arrives from Settings' first screen, and every new row there is a
    new place for it to land. What iOS reports never chooses a board.
  - *How does it combine with the first step's answers?* A board asks
    for the late stage's sizes whatever the answers. With no board, the
    answers decide as before, and no answer still asks for Eye
    Tracking's, the largest an answer asks for.
  - *When does it show?* When Settings closes, as an answer's sizes do,
    so nothing moves under Settings while it is open.
  - *Typing?* Unchanged: Type, Phrases, the keyboard, Speak, Clear and
    Put Back keep their places and work as they do now.
  - *Phones?* The late stage's sizes cannot fit a phone. The board
    still shows there, at the largest sizes the window holds (touch's
    on every phone measured), with the safety row grown as far as the
    keyboard's room allows.
  - *What if the chosen category is gone?* Home shows every category,
    and the step shows Every category chosen. A library reset, the only
    way a category can go today, makes new categories.

## Spec

### The rest board on Home

Set Up Step by Step's second step saves the family's choice
(`SetupRecord.restBoardCategory`): one everyday category, or none.
Home shows the rest board while the choice is a category in the library
(`RestBoard`), read when Settings last closed, as the sizes are.

| Home's state | What the board changes | Where everything sits |
|---|---|---|
| Browsing, the board's category showing | Its cell shows selected; the other categories are dimmed, standard buttons that are disabled; the grid shows its phrases | Every control in its place |
| Browsing, Emergency's phrases showing | The board's cell is not selected, and choosing it shows the board's phrases again; the others stay dimmed | Every control in its place |
| Typing | Nothing new: Speak, Clear and Put Back take their places, and every other category and every tile is dimmed, as without the board, whichever cell is the board's | Every control in its place |
| The alarm sounding | Nothing new: Stop shows in its well | Every control in its place |
| Settings over Home | Settings' places come from the board's frames | Settings' rows as they are placed now |

Nothing on Home chooses or leaves the board: only the second step does,
and its change shows when Settings closes. Emergency stays visible and
one activation from every state, and switches straight to its phrases
(invariant 2). Get Attention, Yes and No are one activation away in
every state, as now (invariant 10).

### The engine

- **What the phrase area holds** is a new input to `HomeLayout`
  (`PhraseArea`): every category, with room for the starter library's
  largest (eight phrases, as now), or the rest board, with room for the
  board's phrases or Emergency's, whichever has more. The grid's columns
  come from the width as always, so a tile keeps its place; its rows
  come from that count.
- **Every place stays.** The board changes no arrangement: the same
  compact or regular Home, the same category arrangement, the same
  grid columns, every control in the same region, row and column
  (`noControlChangesPlaceOnTheRestBoard`, every window the profile tests
  sweep, both text extremes, at every profile).
- **What grows, and in what order.** The gaps between regions, Phrases
  and Type, and the categories grow as they would with every category
  showing at the same profile, so the message, Phrases, Type and the
  categories keep the same sizes with or without the board. Then each
  row of the safety row grows on, toward 206 points (4 degrees at
  46 cm), out of what is left once the board's rows fit at the tile
  floor. The safety row and the board's tiles share that room: the
  safety row grows only while the tiles stay at least as tall as it,
  then both grow equally, so the phrases never become the smallest
  targets on the board for the safety row's sake. It never passes the
  keyboard's room (`KeyboardAllowance`), so Type is offered wherever it
  is without the board. The grid takes the rest. Phrases and Type keeping their sizes is what keeps Settings'
  Back to Talking, which is touch's frame with every category, nearest
  Phrases on the board's Home.
- **A fold or a camera across Home** (iPhone Duo): the board shows in
  touch's frames with every category, since no fold check has measured
  the board's frames there.

### The floors

Floors are physical sizes held at the densest supported screens, about
163 points per inch (docs/DECISIONS.md, "Layouts from the space
available"); angles are at 46 cm, the distance Apple's Eye Tracking and
Head Tracking guides give. **Proposed, the owner can overrule.**

| Profile | Phrase tiles | Yes, No, Emergency, Again, Get Attention | Phrases and Type | Categories, Stop, Settings | Gap | Safety row grows toward |
|---|---|---|---|---|---|---|
| Eye Tracking (today) | 136 pt (2.6°) | 109 pt (2.1°) | 109 pt (2.1°) | 89 pt (1.7°) | 15 pt | 109 pt |
| The late stage | 136 pt (2.6°) | **136 pt (2.6°)** | 109 pt (2.1°) | 89 pt (1.7°) | 15 pt | **206 pt (4.0°)**, with the rest board |

Why these:

- The tiles, categories and gap are Eye Tracking's: the reference app's
  gaze sizes held at the densest screen. The late stage asks for no
  smaller target anywhere.
- Yes, No, Emergency, Again and Get Attention are never smaller than a
  phrase tile at the late stage: 136 points is the reference app's gaze
  tile, the largest size it used every day.
- They grow toward 4 degrees: in a study of gaze pointing on a phone
  ("Stretch Gaze Targets Out", CHI 2025,
  https://doi.org/10.1145/3706598.3713092; 24 people, an iPhone X's
  front camera, 25 to 49 cm away),
  "targets with a visual angle of 4° serve as an optimal 'sweet spot'
  across all screen regions and face-to-screen distances", and gaze was
  less accurate up and down than across. The safety row grows in
  height, the direction the study found harder; its widths come from
  the window's arrangement.
- Phrases and Type keep Eye Tracking's 109 points: they only change
  what Home shows, so the room goes to the four controls the roadmap
  names.
- None of this was tested with people with ALS or with Apple's own Eye
  Tracking, so the floors are proposals until the device checks
  (*Concerns*).

### The profile asked for

| Family Setup's choices | Sizes asked for |
|---|---|
| A rest board, whatever the first step's answers | The late stage's |
| No rest board | As before: the first step's answers decide, Eye Tracking's with no answer |

`ProfileChoice.request` makes this choice from `SetupRecord` and the
library. A window that cannot hold the late stage's sizes takes the
largest smaller ones it holds, Eye Tracking's, then head tracking's,
touch's last (`Profile.withSmallerOnes`), each with the board's
content and growth. The late stage's floors are a profile like the
others, so the engine and its tests treat them as one; only the rest
board asks for them.

### Where each profile holds

Measured during the build over `HomeLayoutEngineTests.windows`, with a
six-phrase board (Conversation) and the starter library's Emergency (six
phrases), against the same windows with every category and Eye
Tracking's sizes asked for (no answer). The profile each window takes at
every text size and with Bold Text is pinned in
`LateStageProfileTests.boardTable` (`theRestBoardTakesTheSizesTheTableSays`);
the sizes below are the engine's at the default and the largest text
size (the quick controls' height, a tile's width × height, and the
grid's rows).

| Window | Text | Every category | Yes and No | Tiles | Rest board | Yes and No | Tiles | Rows |
|---|---|---|---|---|---|---|---|---|
| iPhone 17 | default | touch | 64 | 118×111 | touch | 118 | 118×117 | 2, from 3 |
| iPhone 17 | AX5 | touch | 79 | 118×78, scrolls | touch | 87 | 118×87 | 2, from 3 |
| iPhone 17 Pro Max | default | touch | 64 | 131×138 | head tracking | 107 | 128×110 | 2, from 3 |
| iPhone 17 Pro Max | AX5 | touch | 79 | 131×86 | head tracking | 93 | 128×110 | 2, from 3 |
| iPhone 16e | default | touch | 64 | 114×106 | touch | 114 | 114×113 | 2, from 3 |
| iPhone 16e | AX5 | touch | 79 | 114×78, scrolls | touch | 83 | 114×83 | 2, from 3 |
| 375×667 phone | default | touch | 44 | 109×99, scrolls | touch | 97 | 109×99 | 2, from 3 |
| 375×667 phone | AX5 | touch | 79 | 109×99, scrolls | touch | 79 | 109×99, scrolls | 2, from 3 |
| 375×667 phone, zoomed | both | touch | 64, 79 | 140×78, scrolls | touch | 64, 79 | 140×78, scrolls | 3, from 4 |
| 13-inch iPad | both | Eye Tracking | 109 | 239×350 | late stage | 206 | 239×302 | 2 |
| 13-inch iPad, landscape | both | Eye Tracking | 109 | 325×178 | late stage | 155 | 325×155 | 2 |
| 13-inch iPad, landscape, zoomed | default | touch | 88 | 244×143 | touch | 88 | 244×143 | 2 |
| 13-inch iPad, landscape, zoomed | AX5 | touch | 79 | 244×110 | touch | 79 | 244×110 | 2 |
| 11-inch iPad | both | Eye Tracking | 109 | 189×267 | late stage | 206 | 189×219 | 2 |
| 11-inch iPad, landscape | default | head tracking | 88 | 286×137 | head tracking | 92 | 286×135 | 2 |
| 11-inch iPad, landscape | AX5 | touch | 79 | 288×139 | touch | 79 | 288×139 | 2 |
| iPad mini | both | Eye Tracking | 109 | 167×229 | Eye Tracking | 189 | 167×189 | 2 |
| iPad mini, landscape | both | touch | 88, 79 | 269×143, 269×95 | touch | 88, 79 | 269×143, 269×95 | 2 |

What it shows:

- **iPads in portrait and the 13-inch iPad in landscape take the late
  stage's sizes** at every text size. The iPad mini in portrait takes
  Eye Tracking's: its five columns, 130.4 points wide, hold 109-point
  controls but not 136-point ones; with Bold Text it takes head
  tracking's, as it does with every category.
- **Phones take touch's**, except the iPhone 17 Pro Max, where the
  board's two rows leave room for head tracking's. There the tiles are
  110 points tall, head tracking's floor, where touch's were 138 with
  every category: every other target is larger, and the tiles are
  shorter. On the other phones the board's two rows give both the
  safety row and the tiles more height, and on the iPhone 17 and 16e
  at AX5 the phrases stop scrolling.
- **On four columns the tiles give height to Yes and No.** Every
  starter category already fits four columns in two rows, so the board
  has as many rows as every category there, and the safety row's
  growth comes out of the tiles: on the 13-inch iPad in portrait Yes
  and No reach 206 points and the tiles go from 350 to 302 points
  tall; in landscape both meet at 155.
- **Where typing's room or the window leaves nothing over**, the board
  changes only what the phrase area holds (the 13-inch iPad zoomed, the
  11-inch iPad in landscape at AX5, the iPad mini in landscape, the
  zoomed phone).

*Added after the build: boards of eight phrases.* The table above
measured only a six-phrase board, and the starter library also makes
boards of eight (Basics, Needs). Measured the same way on 2026-11-02,
every iPad window in the table takes the same sizes and frames with
eight phrases as with six: four columns hold either in two rows. A
resized iPad window narrow enough for three columns (600 to 672 points
wide, to 720 with Bold Text) can differ, as a phone does; the sweeps
over every window run both boards. On the phones a board of
eight keeps every category's three rows, so the safety row's growth
comes out of the tiles, and the iPhone 17 Pro Max takes touch's sizes
instead of head tracking's (`LateStageProfileTests.boardTableForEight`).
Every layout test of the board (`LateStageProfileTests`) runs with
both boards, and in the app `HomeRestBoardTests` runs Apple's audit
and reads the drawn words on Needs, a board of eight, as it does on
Conversation.

| Window | Text | Board of eight | Yes and No | Tiles | Rows |
|---|---|---|---|---|---|
| iPhone 17 | default | touch | 92 | 118×92 | 3 |
| iPhone 17 | AX5 | touch | 79 | 118×78, scrolls | 3 |
| iPhone 17 Pro Max | default | touch | 109 | 131×108 | 3 |
| iPhone 17 Pro Max | AX5 | touch | 83 | 131×83 | 3 |
| iPhone 16e | default | touch | 89 | 114×89 | 3 |
| iPhone 16e | AX5 | touch | 79 | 114×78, scrolls | 3 |
| 375×667 phone | both | touch | 44, 79 | 109×99, scrolls | 3 |
| 375×667 phone, zoomed | both | touch | 64, 79 | 140×78, scrolls | 4 |

Where every category's phrases scroll, a board of eight scrolls the
same and nothing grows. A board of six, a row shorter, stops the
scrolling on the 375×667 phone to AX1, on the iPhone 17 and 16e at AX5
with Bold Text off and on the iPhone 17 at AX3 with Bold Text, but not
on the 375×667 phone at AX3 and AX5, the zoomed phone, or at AX5 with
Bold Text. Tiles are whole points tall, so they can end
up to a point shorter than Yes and No (108 against 108.8 on the Pro
Max).

### Set Up Step by Step's second step

- The steps become six: how the screen is reached, then **which
  phrases Home shows**, the voice, turning on what was chosen, keeping
  Brickson open, and the summary (`GuidedSetupStep.restBoard`).
- The step's words: the heading "Which phrases does Home show?", and
  "Home can show one category's phrases or Emergency's, with Yes, No,
  Emergency, Again and Get Attention as large as this screen has room
  for. The other categories stay where they are, dimmed, so nothing
  moves. The change shows when Settings closes." *Changed after the
  build:* the words first said the phrases show "in fewer, larger
  buttons", which the measurements (*Where each profile holds*) show
  untrue on four columns and with a board of eight on a phone, where
  the tiles give height to Yes and No.
- The choices: Every Category, then each everyday category in Home's
  order, by its own name, shown as written (`Text(verbatim:)`). Each
  only selects: choosing the chosen one again keeps it, and choosing
  another moves the choice (invariant 10). Each is saved the moment it
  is chosen (`SetupStore.update`); a failed save changes nothing and
  says "That answer could not be saved. Try again."
- Where a held look arrives: on Next, in the fixed bar at the bottom of
  every step, from the first step, or on the standard Back button from
  the third; Next and Back only navigate. Every choice lies where every
  point of Next is nearer Next than the choice, by centre and by edge,
  with 8 points to spare (`SetupChoicesPlace`): each under the words, or
  the choice before it, where it holds there, and from the first that
  does not, the rest just below the bar, where the family scrolls to
  them. The step is a surface of the chain engine (`SettingsChains`):
  `SettingsOnHomeTests` reads it on CI's windows and the 630-window
  sweep models it. *Changed after Codex's review of pull request #74:*
  the spec first put the choices under the words and left the step
  unscored, and scoring it found a held look on Next saving a choice on
  203 of the 630 windows. The first fix moved the whole column below
  the bar wherever it could not all stay under the words, which left
  every phone's first screenful without a choice; now the choices that
  hold stay (docs/DECISIONS.md, "The late-stage profile", *Where the
  second step's choices start*).
- The summary adds one line: "Home shows every category.", or "Home
  shows one category's phrases:" and the category's name (first "...
  phrases, with larger buttons:", changed with the step's words).

### Input methods

- **Touch, Voice Control, Full Keyboard Access, VoiceOver:** the same
  standard buttons in the same order. A dimmed category is a disabled
  standard button, which VoiceOver reads as dimmed and which does
  nothing, as the categories do while typing.
- **Dwell, head, gaze and switch auto-select:** chains of held
  activations are scored on the board's frames, browsing and typing, by
  nearest centre and nearest edge, at every profile that holds and on
  phones at touch's sizes, and meet nothing beyond the findings touch's
  frames already have and the engine tests pin
  (`noChainOnTheRestBoardMeetsANewHazard`). The open hazard of Yes and
  No bordering the message stays within touch's pinned worst shares on
  the board too (`yesAndNoBorderNoMoreOfTheMessageOnTheRestBoard`).
  Settings' Back to Talking meets only Phrases on every Home it can
  close onto, with or without the board
  (`closingSettingsOntoTheRestBoardMeetsOnlyPhrases`), and Settings
  over the board's Home closes nothing and saves nothing under a held
  look (`noSettingsChainOverTheRestBoardClosesSettingsOrSavesAnAnswer`).

### Colours, privacy policy and screens

- **Colours:** none new. A dimmed category has the dimmed look every
  disabled control on Home has (`HomeButtonLook`).
- **Privacy policy:** no sentence changes. The choice is one of "Your
  settings", kept on the device, and holds no phrase words, only which
  category.
- **Screens:** captured from the running app by the board's UI test on
  CI, on an iPad and an iPhone, and listed in the log.

### Concerns

- **The floors and the 4-degree growth are proposals.** The study
  behind 4 degrees used a phone's camera, not Apple's Eye Tracking, and
  people without ALS. The late stage gets its own device session in the
  quality bar's Q11 and Q13 before any build with it goes to App
  Review.
- **The three open dwell hazards apply here too.** Yes and No bordering
  the message, the top of Stop's well nearest Again on compact widths,
  and, by centre, dimmed phrases bordering Clear and Put Back while
  typing stay as R0's *Release gate* records them: no build with the
  larger sizes, the board's included, goes to an external TestFlight
  group or App Review until each is gone or the owner accepts it. The
  board adds none (tested).
- **On four columns the tiles give height to Yes and No.** Every
  starter category already fits four columns in two rows, so there the
  board's grid has as many rows as Home's without it, and the safety
  row's growth comes from the tiles, never past where they would be
  shorter than it (on the 13-inch iPad in portrait, tiles 302 points
  tall where they were 350). The owner can choose to cap the growth
  instead.
- **On the iPhone 17 Pro Max the tiles are shorter than without the
  board.** The board's two rows let the window hold head tracking's
  sizes, so every target but the tiles grows, and the tiles go from
  touch's 138 points to head tracking's 110 (*Where each profile
  holds*). Taking touch's there instead would keep the tiles taller and
  every other target smaller; the rule that a window takes the largest
  sizes it holds decides, as it does everywhere else.
- **The controls' frames now follow the library, on the board only.**
  Without the board they never do: the grid leaves room for the starter
  library's largest category. With it, the room is for the board or
  Emergency, read when Settings closes and kept until it closes again,
  so a library change cannot move anything under Settings. The editing
  pull request (R2) keeps the count while edit mode is open.
- **Simulator evidence only.** Comfort, Snap to Item and where a resting
  look lands need a real device.

## Plan

- **Files that change** (all this thread's):
  - `HomeLayout.swift`: the late stage's profile and its floors, a
    floor and a height of their own for Phrases and Type, what the
    phrase area holds, the board's growth, Back to Talking from touch's
    frames with every category, and the board left out under a fold.
  - `RestBoard.swift` (new): the family's choice resolved against the
    library, with the count the grid leaves room for.
  - `ProfileChoice.swift`: what Home asks for (`Request`), made from
    the setup record and the library, and the layout for it.
  - `SetupRecord.swift`: the choice, saved with the record, read as
    none from records saved before it.
  - `CategorySelection.swift`: the board's category, or Emergency's.
  - `HomeView.swift`: the request, the dimmed categories, the grid's
    count.
  - `SettingsView.swift`, `SetupGuides.swift`: the same request, so
    Settings' places come from the Home it covers.
  - `BricksonApp.swift`: the request, read from the record and the
    library when Settings closes and kept while it is open.
  - `SettingsRoute.swift`, `GuidedSetupView.swift`: the second step and
    the summary's line.
  - The String Catalog; the tests below; the records
    (docs/DECISIONS.md, docs/ROADMAP.md, docs/HANDOFF.md,
    docs/ACCESSIBILITY.md, `README.md`, `AGENTS.md`'s plain types, a
    `docs/log/` file, and the website's accessibility page only where a
    sentence becomes untrue).
- **Order of work:** one pull request: this file, then tests first and
  the code for the engine and the choice, then Home, Settings and the
  step, then the measured tables and the records.
- **Risks, and how each is checked:**
  - Home without the board changing by accident: every existing engine
    and profile test runs unchanged on it, apart from the ones that list
    the profiles, which gain the late stage.
  - The board scrolling, losing typing or a word: a profile holds on
    the board only where every floor is met, the board's rows fit and
    everything touch's sizes keep is kept (the same checks as item 8's,
    run on the board's layouts).
  - Settings placed from another Home than the one it covers: Home and
    Settings read the same request, kept while Settings is open.
  - A held look meeting something new: the chain sweeps above.
  - UI tests that count the steps: each names six now.
- **Proof:**
  - `LateStageProfileTests` (new) and `ProfileChoiceTests`, each with
    the change that makes it fail:
    - a rest board asks for the late stage's sizes, and no board the
      answers' (fails if a board leaves the profile to the answers, or
      no answer asks for the late stage's);
    - the late stage's floors and the 206-point growth (fails if a floor
      changes, or a tile, category or gap is smaller than Eye
      Tracking's);
    - `noControlChangesPlaceOnTheRestBoard` (fails if the board changes
      the grid's columns or any arrangement);
    - the board keeps the message, Phrases, Type and the categories at
      their sizes without it, and grows only the safety row (fails if
      the board's growth comes before Phrases and Type's, which would
      let the keyboard's give-back shrink Phrases);
    - the safety row never passes the keyboard's room on the board
      where typing is offered without it;
    - the board holds only where its floors are met and its rows fit;
    - the windows table; the dwell chains; Back to Talking onto the
      board; the Yes and No share; Settings over the board; a fold.
  - `RestBoardTests` (new): no choice, a choice gone, Emergency chosen
    (impossible from the step, refused all the same), the count from
    the larger of the board and Emergency.
  - `SetupRecordTests`: a record saved before the board decodes with
    none; a choice survives a round trip.
  - `CategorySelectionTests`: with a board, the board's category shows
    unless Emergency's was chosen, and no other category can be; a
    board gone from the library shows as every category does; the
    board's view of the library keeps every category, in order, with
    its phrase count.
  - `SettingsIdleClockTests`: six steps, the board's second.
  - `HomeRestBoardTests` (UI, both families): choosing a category in
    the second step, then closing Settings, shows the board: the other
    categories dimmed, the board's phrases showing, Yes taller than
    before, and Emergency's phrases reachable and back; at the default
    and the largest text size, light and dark, Apple's accessibility
    audit finds nothing and every control's words are drawn whole.
    Every Category gives back Home as it was.
  - Device checks (Codex and the owner's devices): the late stage's
    floors and the 4-degree growth with a person using Eye Tracking on
    an iPad (the quality bar's Q11 and Q13).

## Changed during the build

- **The safety row shares the room with the tiles.** The first rule
  grew the safety row first, all the way toward 206 points, and gave the
  tiles what was left. The engine tests found that it starved the tiles
  on phones: on the iPhone 17 the board's tiles were 78 points tall
  where every category's were 111, and on the 13-inch iPad in landscape
  they sat at their 136-point floor. The safety row now grows only while
  the tiles stay at least as tall as it, then both grow equally
  (`theSafetyRowGrowsTowardFourDegreesWhileTheTilesStayAsTall`): on the
  iPhone 17, Yes and No 118 points and tiles 117.
- **The windows table was measured, not guessed.** The plan expected
  touch's sizes on every phone; the iPhone 17 Pro Max takes head
  tracking's with the board, the 11-inch iPad in landscape head
  tracking's to AX3, and the iPad mini in portrait Eye Tracking's, or
  head tracking's with Bold Text.
- **The Yes and No share is compared window by window.** The plan
  bounded it by touch's pinned worst shares everywhere, but at 672×667
  Home with every category already passes the compact bound (97.1% by
  centre), since the engine's pin is measured at one height. The test
  now checks that the board never borders more of the message than the
  same window and profile with every category, and the pinned bounds
  where the window is at least 744 points tall.
- **No `--home-profile=late-stage`.** The UI tests choose the board in
  the second step and let Home ask for what a person's launch asks for,
  so a launch option that fixes the late stage's sizes would only test
  a combination no one gets: the late stage's sizes with every
  category.
- **Boards of eight phrases were measured after the build.** The board
  tests used only a six-phrase board, while Basics and Needs, half the
  starter categories, make boards of eight. Measured on 2026-11-02 (*Where
  each profile holds*), every layout test of the board now runs with
  both, and
  `StarterPhrasesTests` fails if the starter library makes a board of
  another size. The measurements also showed the step's "fewer, larger
  buttons" untrue on every iPad and with a board of eight on a phone,
  so the step and its summary line no longer say it.

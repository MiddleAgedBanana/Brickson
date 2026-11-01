# The late-stage profile: Yes and No, and the rest board

*Roadmap: Wave 3 item 9 (R1, the profile layout engine), built before
the first App Review build by the owner's decision of 2026-10-30
(docs/DECISIONS.md, "Items 8 and 9 come before the first App Review
build"). Owner: the item 9 thread (a cloud session; GitHub CI is its
build). Status: spec.*

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
    of their height to Yes and No (measured in the spec).
  - *What grows?* The safety row: Yes, No, Emergency and Get Attention,
    the four the roadmap names, and Again, which shares their row.
    Phrases and Type, which only change Home's mode, stay at Eye
    Tracking's floor, and the categories at their floor.
  - *How far?* Each row of the safety row grows toward 206 points where
    there is room once the board fits, and never into the keyboard's
    room, so typing stays wherever it would be without the board.
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
  46 cm), from what is left once the board's rows fit at the tile
  floor, and never past the keyboard's room (`KeyboardAllowance`), so
  Type is offered wherever it is without the board. The grid takes the
  rest. Phrases and Type keeping their sizes is what keeps Settings'
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
  (Namnakani, Abdrabou, Grizou and Khamis, "Stretch Gaze Targets Out",
  CHI 2025; 24 people, an iPhone X's front camera, 25 to 49 cm away),
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

Measured by `ProfileChoiceTests.theRestBoardTakesTheSizesTheTableSays`
over `HomeLayoutEngineTests.windows`, with a six-phrase board and the
starter library's Emergency (six phrases), and filled in from it during
the build.

### Set Up Step by Step's second step

- The steps become six: how the screen is reached, then **which
  phrases Home shows**, the voice, turning on what was chosen, keeping
  Brickson open, and the summary (`GuidedSetupStep.restBoard`).
- The step's words: the heading "Which phrases does Home show?", and
  "Home can show one category's phrases, and Emergency's, with Yes, No,
  Emergency and Get Attention as large as this screen has room for. The
  other categories stay where they are, dimmed, so nothing moves. The
  change shows when Settings closes."
- The choices: Every Category, then each everyday category in Home's
  order, by its own name, shown as written (`Text(verbatim:)`). Each
  only selects: choosing the chosen one again keeps it, and choosing
  another moves the choice (invariant 10). Each is saved the moment it
  is chosen (`SetupStore.update`); a failed save changes nothing and
  says "That answer could not be saved. Try again."
- Where a held look arrives: on Next, in the fixed bar at the bottom of
  every step, from the first step, or on the standard Back button from
  the third. The choices sit under the heading and the words, so
  neither place has a choice nearest it; Next and Back only navigate.
  `SettingsChains` keeps not following the second step, as before.
- The summary adds one line: "Home shows every category.", or "Home
  shows one category's phrases, with larger buttons:" and the
  category's name.

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
  row's growth comes from the tiles. Measured in the table; the owner
  can choose to cap the growth instead.
- **The controls' frames now follow the library, on the board only.**
  Without the board they never do: the grid leaves room for the starter
  library's largest category. With it, the room is for the board or
  Emergency, read when Settings closes and kept until it closes again,
  so a library change cannot move anything under Settings. The editing
  pull request (R2) keeps the count while edit mode is open.
- **Simulator evidence only.** Comfort, Snap to Item and where a resting
  look lands need a real device.

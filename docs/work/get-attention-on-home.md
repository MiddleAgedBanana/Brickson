# Get Attention and Stop on Home

*Roadmap: R0 item 4 (Get Attention), the part PR #16 left for later:
the controls on Home. Owner: the Get Attention and Stop on Home thread.
Status: building (PR #38; untested until CI passes).*

## Intent

- **Problem:** the Get Attention alarm is built and tested (PR #16), but
  nobody can sound it: Home has no Get Attention control and no Stop, so
  a person who cannot speak has no way to call someone into the room
  from Brickson. Invariant 10 says Get Attention is one activation away
  from every Home state; today it is zero activations away from nowhere.
  Home's status line also runs with the alarm always idle, so a tone
  that failed to start or stopped by itself would show nothing
  (invariant 4).
- **Proposed outcome:** Get Attention is on Home in every state, always
  in the same place, in the safety row with Yes, No and Emergency. One
  activation, by any input method, starts the alarm, and a second one
  (a held look, a repeated switch press) leaves it sounding. While it
  sounds, Stop appears in a well of its own, in another region and on
  another row, and the status line says "Sounding". Stop ends it; its
  well empties and nothing else moves. A tone that fails or stops by
  itself shows "Alert failed" or "Alert stopped" and is announced to
  VoiceOver, every time.
- **Who and what it affects:** the person, at every stage and on every
  input method (touch, Voice Control, Switch Control, Full Keyboard
  Access, AssistiveTouch with Dwell, head and Eye Tracking); the family,
  who hear the alarm and stop it. Home's layout (`HomeShape`, `HomeView`),
  its names (`HomeControlNames`), its status line, its colours
  (`Palette`), and a debug launch option for UI tests.
- **Constraints:** invariant 1 (standard `Button`s with labels, at least
  44pt), 2 (Get Attention, Emergency, Yes and No one activation from
  every Home state), 4 (failures shown and announced, layout reserved),
  6 (new fills measured and pinned in `PaletteTests`), 8 (positions never
  depend on state: Stop has a well that keeps its frame), 10 (start and
  stop apart; score what a held activation meets after each), 11 (no new
  scrolling for the starter library on the windows CI runs; every new
  case recorded), *Words never break*, *Layout on every device and
  window*, and the decisions "Get Attention", "Home's slot plan",
  "Settings on Home" (Back to Talking closes onto Emergency) and "Solid
  fills on Home" (Get Attention `#B45309`, Stop `#0F766E`).
- **Open questions, each answered here:**
  - *Where does Get Attention go, while A's trailing column (Phrases and
    Type) is not built?* Not in the safety row's first row: the message
    spans the full width, so anything there borders it, and a look
    resting on the message must never meet an alarm. It goes in a
    second safety row on every window, under Emergency: the first row is
    Yes, No and Emergency (Emergency still under Back to Talking), the
    second Again and Get Attention. Again moves off the message's edge,
    which also reduces the open hazard "Yes and No border the message".
  - *Where does Stop go?* Where the slot plan puts it: the top of the
    categories' leading column, a category directly under it, in region
    B. Under it on the screen is a category, so after Stop its well
    empties and the nearest control only changes which phrases show.
  - *What do they answer to?* Get Attention also answers to "Help" for
    Voice Control (the question *Home's scan order and names* left to
    this work); Stop shows "Stop" (the word that fits beside two
    categories on a 375pt phone with Bold Text) and also answers to
    "Stop Alert".
  - *Settings' Get Attention place* stays empty in this pull request:
    on wide windows Settings' root puts its note under that place, so
    adding it needs its own scoring. Recorded in docs/HANDOFF.md.

## Spec

Frames come from `HomeShape`, from the width Home is given and the
person's Bold Text setting, never from the device. Region order is
unchanged: A (the message), C (the safety row), B (the categories with
Stop's well and Settings), D (the phrase grid). Widths below are content
widths (the window less Home's 16pt margins).

- **States:** Home's states (just opened, a category or the emergency
  phrases showing, a phrase just spoken, an audio warning, the alarm
  sounding, the alarm stopped or failed) change no frame. While the alarm
  sounds, Stop's well shows Stop; otherwise it is empty, hidden from
  accessibility, and nothing moves into it. Get Attention stays where it
  is and stays enabled while sounding: choosing it again changes nothing.
  - **C, the safety row,** two rows on every window, in two equal
    columns: Yes and No sharing the leading column, then Emergency;
    under them Again, then Get Attention. Emergency stays at the
    trailing end of the first row, under Settings' Back to Talking; Get
    Attention is directly under Emergency. Nothing in C shares a row
    with the message's edge but Yes, No and Emergency, as before.
  - **B, the categories:** Stop's well at the top of the leading column
    with a category directly under it, and Settings at the trailing end:
    - *Band* (wide windows, from 584pt, where four categories and
      Settings with its word fit in a row; from 630pt with Bold Text):
      Stop above the first category in the leading column, the other
      three and Settings at the full height of both rows (the slot plan's
      regular band). Narrower wide windows take three columns, so
      Settings' word never shows, hides and shows again as a window
      widens.
    - *Three columns* (narrower, from 304pt, 328pt with Bold Text): Stop,
      Basics, Needs; then Conversation (under Stop), Feelings, Settings.
      The categories keep at least their minimum and share any room
      left as equal thirds; Stop and Settings take the rest, Settings
      showing its gear alone below 80pt (86pt with Bold Text).
    - *Two columns* (the narrowest windows): Stop, Basics; Needs (under
      Stop), Conversation; Feelings, Settings.
    The region is two rows tall in the first two arrangements and three
    in the third, whatever the library holds. A library with more than
    four everyday categories (none can be made yet: editing and import
    have no screen) shows its fourth and later categories in a list that
    scrolls inside the fourth category's cell
    (`CategorySelection.inCell`); Stop and Settings never scroll. The layout engine's thread still decides this for good
    (docs/DECISIONS.md, "Home's slot plan", *Open*).
  - **Minimum widths** (default text size, measured with SF Pro on Linux
    and checked with the real fonts by `StarterLabelFitTests`): Get
    Attention 100 (110 with Bold Text; "Attention" is its widest word,
    85pt, 96pt bold), Stop 52 (56; "Stop" is 37pt, 41pt bold). Get
    Attention always gets half the width (at least 140pt), so it shows
    on one line at the default size wherever the line fits (123pt,
    136pt bold), and on two otherwise.
  - **The status line** shows, in order of what the person most needs:
    an audio problem ("Alert failed", "Alert stopped", then the others),
    else "Sounding" while the alarm sounds, else "Speaking". "Sounding"
    gets a reserved invisible copy like the others, so nothing moves.
    Every new `failureSequence` is announced to VoiceOver, so a retry
    that fails again is heard again (`AudioAnnouncementPolicy`).
- **Input methods:** both are standard `Button`s. Get Attention: label
  "Get Attention" with a decorative bell, Voice Control names "Get
  Attention" and "Help", identifier `getAttention`, fill `AttentionFill`.
  Stop: label "Stop" with a decorative crossed-out bell, names "Stop" and
  "Stop Alert", identifier `stopAlert`, fill `StopFill`. VoiceOver,
  Switch Control and Full Keyboard Access reach C first: Yes, No,
  Emergency, Get Attention, then Again (reached last in its region);
  then A; then B: Stop when it shows, the categories, then Settings;
  then D. In the band the first category sits under Stop, below the
  others' tops, so Stop and the first category carry their own sort
  priorities (`HomeRegion.firstInRegion`, `secondInRegion`). Get
  Attention carries the `playsSound` trait.
  **What a held activation meets** (the model of the frames, from CI's
  captures of the merged Settings on Home; nearest centre and nearest
  edge, ties counted):

  | Window | Nearest Get Attention's spot, after it (other than itself) | After Stop (its well empties) | After Back to Talking | After Home's Settings |
  |---|---|---|---|---|
  | 402×874 phone, default, AX5 and Bold Text | Emergency, both | Conversation (under Stop), both | Emergency, both | Family Setup, both |
  | 375×667 phone | Emergency by edge; Emergency and Needs tie by centre | Conversation, both | Emergency, both | Family Setup, both |
  | 13-inch iPad, both orientations, default and AX5 | Emergency, both | Basics (under Stop), both | Emergency, both | Family Setup, both |
  | 320pt window | Emergency by edge, Basics by centre | Needs (under Stop), both | Emergency, both | Family Setup, both |

  None of these speaks, alarms, deletes or changes a size: Emergency and
  a category only change which phrases show. Stop is never nearest Get
  Attention's spot, so a held look on Get Attention can never stop the
  alarm, and Get Attention is never nearest Stop's, so a held look on
  Stop can never restart it. Margins after Stop: 4pt by edge (the gap
  under Stop is 8pt, the gap above it 12pt) and 12pt or more by centre.
  **Switch Control** counts the same way: every activation takes a
  switch press, and with Auto Tap a repeat on the item just chosen is
  the held activation in the table (Get Attention again changes nothing;
  Stop's element leaves with the alarm). Where the scan cursor goes once
  Stop's element is gone has not been seen; the device check covers it
  (docs/HANDOFF.md, *Checks that need a real device*).
- **Colours** (docs/DECISIONS.md, "Solid fills on Home"; pinned in
  `PaletteTests` with the other fills): `AttentionFill` `#B45309`, white
  text 5.02:1, against a black screen 4.18:1, against white 5.02:1;
  `StopFill` `#0F766E`, white text 5.47:1, against black 3.84:1, against
  white 5.47:1. Primary ink (the pressed ring) on each: 4.18 and 3.84 in
  light, 5.02 and 5.47 in dark.
- **Privacy policy:** no sentence changes. The alarm plays on the
  device and nothing is sent anywhere.
- **Screens:** none drawn for this change; the UI tests attach captures
  of every Home state, the alarm sounding included, on both devices.
- **Concerns:**
  - *The phrase grid loses height on every window.* Phones give up a
    quick-control row (72pt at the default size); wide windows also give
    the categories a second row (176pt in all). On the windows CI runs
    the starter library still fits (tiles about 126pt on a 402×874 phone
    against a 99pt minimum; on the 13-inch iPad 276, 236, 161 and 121pt
    in portrait and landscape, default and AX5, against 110pt), which
    `HomeLayoutTests` checks. It newly scrolls at the default size on a
    375×667 phone (tiles about 83pt; the slot plan expected this), and,
    by the model, on an 11-inch iPad in landscape (about 95pt) and an
    iPad mini in landscape (about 65pt). Listed in docs/DECISIONS.md,
    *Where the grid still scrolls*, for the layout engine. The trade:
    a call for help one activation from every Home state, which
    invariant 10 requires and nothing else gives.
  - *The slot plan's own C* (one row on wide windows, Get Attention at
    the trailing end, under Phrases and Type) waits for A's trailing
    column. Until then Get Attention must not border the message.
  - *Settings' Get Attention place* stays empty (Intent, above).

## Plan

- **Files that change** (all in this one pull request, by this thread):
  - `Brickson/Layout/HomeShape.swift`: the safety row's two equal
    columns, the categories' three arrangements with Stop's well, and
    the minimum widths of Get Attention and Stop.
  - `Brickson/Home/HomeView.swift`: Get Attention in C, Stop's well in B,
    the categories' arrangements, the status line fed by the alarm's real
    state, and the announcement of each new `failureSequence`.
  - `Brickson/Home/ControlNames.swift`: Get Attention and Stop, and Stop
    among the controls the collision check covers.
  - `Brickson/Home/HomeRegion.swift`: Stop's and the first category's
    sort priorities.
  - `Brickson/Home/CategorySelection.swift`: which categories each cell
    holds (`inCell`).
  - `Brickson/Library/LibraryRules.swift`: the new names reserved.
  - `Brickson/Settings/SettingsView.swift`: the bar's comment about Get
    Attention's empty place.
  - `Brickson/Home/Palette.swift` and two colour sets in the asset
    catalog: `AttentionFill`, `StopFill`.
  - `Brickson/Speech/AudioSafetyPolicy.swift`: `HomeStatusLine`, which
    chooses between a problem, "Sounding" and "Speaking".
  - `Brickson/Attention/AttentionTonePlayback.swift`,
    `Brickson/App/LaunchOptions.swift`, `Brickson/App/AppAudio.swift`,
    `Brickson/App/BricksonApp.swift`: a debug-only launch option,
    `--attention-tone=silent`, that plays a silent stand-in tone, so UI
    tests sound the alarm without sound and without depending on the
    simulator's audio. A release build ignores it, like every launch
    option.
  - `Brickson/Resources/Localizable.xcstrings`: the new words.
  - Tests: `HomeShapeTests`, `StarterLabelFitTests`, `ControlNamesTests`,
    `HomeNameCollisionTests`, `PaletteTests`, `AudioSafetyPolicyTests`,
    `LaunchOptionsTests`, `AttentionAlertPlayerTests`,
    `CategorySelectionTests`, `HomeRegionTests`, `LibraryEditTests`; UI:
    the new `GetAttentionOnHomeTests` and `ScreenControls.swift` (the
    frame-reading and nearest-control helpers it shares with
    `SettingsOnHomeTests`), and `HomeReachabilityTests`,
    `HomeAccessibilityOrderTests`, `HomeLayoutTests`, `LaunchTests`,
    `SettingsOnHomeTests`.
  - Docs: DECISIONS ("Get Attention and Stop on Home", and notes in
    "Get Attention", "Home's slot plan", "Home's scan order and names",
    "Settings on Home" and *Where the grid still scrolls*), HANDOFF,
    ROADMAP item 4, ACCESSIBILITY, DESIGN.md, README.md, AGENTS.md (the
    plain types), this file and the log record.
- **Order of work:** the unit tests first (they fail against today's
  `HomeShape`, names and palette), then the code, then the UI tests and
  the docs.
- **Risks, and how each is checked:**
  - *A held look on Get Attention stopping the alarm, or one on Stop
    restarting it:* `GetAttentionOnHomeTests` sounds the alarm and reads
    every frame from the accessibility tree: Stop is not nearest Get
    Attention's spot, Get Attention is not nearest Stop's, and after Stop
    the nearest control is a category (both rules).
  - *Anything moving when the alarm sounds or stops:*
    `GetAttentionOnHomeTests` and `HomeReachabilityTests` compare every
    edge with its launch frame.
  - *New scrolling for the starter library on CI's windows:*
    `HomeLayoutTests`, both devices, default and largest text. The 13-inch
    iPad in landscape at AX5 has the least room (tiles about 121pt
    against 110pt).
  - *Back to Talking or Home's Settings landing somewhere new:*
    `SettingsOnHomeTests`, unchanged in what it requires.
  - *A word cut off:* `StarterLabelFitTests` checks Get Attention and
    Stop at their minimums with the real fonts, Bold Text off and on.
  - *The simulator's audio:* the UI tests use the silent stand-in tone;
    the real tone is covered by `AttentionAlertPlayerTests` and a device
    check (docs/HANDOFF.md, *Checks that need a real device*).
  - *Cloud session:* nothing here was built for iOS before CI; the pure
    `HomeShape`, names and status tests ran on a Linux Swift toolchain
    first.
- **Proof** (each test, and the change that makes it fail):
  - `HomeShapeTests.getAttentionIsDirectlyUnderEmergency`: Get Attention
    and Emergency in different columns, or Get Attention in the first
    row.
  - `HomeShapeTests.stopHasACategoryDirectlyUnderIt`: Stop above
    Settings, or beside its category in one row.
  - `HomeShapeTests.everyControlKeepsItsMinimumWidth` and
    `theRegionsFillTheWidthExactly`: a minimum lowered, or a row that
    overflows.
  - `HomeShapeTests.boldTextTakesNoHeightFromAPhonesPhrases`: Bold Text
    taking a row from a phone's phrases.
  - `HomeShapeTests.aHeldLookMeetsNothingHarmfulAfterGetAttentionOrStop`:
    Stop nearest Get Attention's spot, or anything but a category nearest
    Stop's, at any width, by either rule.
  - `HomeShapeTests.aLibraryOfFewerThanThreeEverydayCategoriesLeavesAgainNearStop`:
    a library of three or more categories leaving anything but a
    category nearest Stop's empty well; and, strict, the known gap for
    fewer than three closing (docs/DECISIONS.md, "Get Attention and Stop
    on Home", *Open*).
  - `AudioSafetyPolicyTests.overSettingsAnAlarmProblemNamesBackThenGetAttention`:
    an alarm problem under Settings naming Get Attention, which Settings
    does not have, instead of Back first.
  - `CategorySelectionTests.theLastCellHoldsEveryCategoryFromThereOn`: a
    category past the fourth dropped, or a cell showing another's.
  - `HomeRegionTests.stopThenTheFirstCategoryComeBeforeTheDefault`: Stop
    or the first category without a priority above the others'.
  - `StarterLabelFitTests.theFixedControlsFitTheirNarrowestWidths`: Get
    Attention's or Stop's minimum below its word.
  - `ControlNamesTests.theFixedControlsAndTheirNamesAreTheDecidedOnes`
    and `homeListsEveryControlOnTheScreen`: a name dropped or Stop left
    out of the check.
  - `PaletteTests`: either fill missing from `Palette.assetNames`, or a
    value other than the measured one.
  - `AudioSafetyPolicyTests.theStatusLinePutsProblemsThenTheAlarmThenSpeech`:
    "Speaking" over "Sounding", or "Sounding" over a problem.
  - `LaunchOptionsTests`: `--attention-tone=silent` not understood.
  - `AttentionAlertPlayerTests.theSilentToneSoundsUntilStopped`: a
    stand-in that reports not playing, which the health check would
    stop.
  - `GetAttentionOnHomeTests`: Stop missing after Get Attention, still
    there after Stop, or any frame moving; the chain checks above; an
    accessibility audit finding while the alarm sounds.
  - `LaunchTests.testLargestTextKeepsQuickControlWordsVisible`: Get
    Attention's words clipped at the largest text size.
  - `HomeReachabilityTests`, `HomeLayoutTests`,
    `HomeAccessibilityOrderTests`: Get Attention unreachable, off
    screen or out of order, or Stop not first among the categories while
    the alarm sounds.
  - Device checks (docs/HANDOFF.md, *Checks that need a real device*): a
    new row for Get Attention from Home's own control with each input
    method, the silent switch on, and what a held look meets.

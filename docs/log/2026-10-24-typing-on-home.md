# Typing on Home

*2026-10-24. Pull request #53 (`claude/project-thread-6yki0x`). The Add
typing to Home thread, a cloud session with no Xcode: the layout engine,
the chain engine and their tests ran on a Linux Swift toolchain, nothing
was built for iOS, and CI is the first build of everything else.*

## What changed and why

Wave 3 item 5 (docs/ROADMAP.md; R0 items 5 and 9): Home can type. The
intent, spec and plan are [`work/typing-on-home.md`](../work/typing-on-home.md),
with the Figma screens it links, and the decisions are in
docs/DECISIONS.md, "Typing on Home", with dated notes in "Settings on
Home", "Home's slot plan", "The layout engine", "Get Attention and Stop
on Home", "One chain engine for dwell safety" and "Settings is a cover
with a fixed safety bar".

What a person sees:

- **Phrases and Type beside the message.** They work like the two
  segments of a mode switch: the one whose mode is on shows selected, and
  choosing it again does nothing. On iPads and other regular-width
  windows the safety row becomes one row, Emergency, Yes, No, Again and
  Get Attention, with Stop's well under Emergency; phones keep two rows.
- **Typing.** Type opens Apple's keyboard with the message being typed in
  the message's place. Speak, in Again's place, or Return says the whole
  message and keeps it. Clear empties it and Put Back brings it back once,
  each in a category's cell; the other categories and the phrase tiles
  are dimmed in place while typing. Phrases leaves typing and keeps the
  message; Emergency leaves it for the emergency phrases; Settings leaves
  it before it opens. Nothing moves when the keyboard shows.
- **No typing where the keyboard would cover the call for help.** Type is
  offered only where the message, Phrases, Type and the whole safety row
  end above the room kept for the keyboard (`HomeLayout.offersTyping`).
  On 320-point windows, a 375×667 phone from AX3, and the iPad mini and
  a zoomed 13-inch iPad in landscape from AX3, Type is dimmed, with a
  VoiceOver hint saying why; if the room goes while typing, the keyboard
  is put away and the field is dimmed, and typing stays on, so the
  phrases stay dimmed.
- **The message is kept.** The app keeps one `DraftStore`, so the message
  survives a relaunch until it is cleared, and a failed save or restore
  shows "Message not saved" or "Message not restored" on the status line,
  after the audio problems, the alarm and speaking. A change refused at
  the 2,000-character limit shows "Message full" there until the next
  change is saved.
- **Settings closes onto Phrases.** Settings lays out Home's engine for
  its own window and puts Back to Talking over Home's Phrases
  (`HomeLayout.backToTalking`): exactly Phrases' frame on phones, centred
  and at most a column wide on regular widths, where Phrases' lower
  corners are nearer Again and Get Attention. A look still resting on it
  when Settings closes meets Phrases, which does nothing.
- **Get Attention on one line on phones** at the default size, beside the
  message.
- **The privacy policy** gains a paragraph on typed and dictated words,
  with its Effective date moved to October 24, 2026; the app shows the
  same page.

What was settled along the way, each recorded in "Typing on Home":

- **Type is dimmed where the keyboard would cover the safety row.** The
  pull request's first push offered Type there too, with the covered
  controls two activations away through Phrases, and recorded it for the
  owner. Codex's review held that against AGENTS.md ("Typing never hides
  the call for help"), and the second push keeps the rule instead: no
  typing on those windows at those sizes until the real keyboards there
  are measured or the owner accepts an exception.
- **A change refused at the length limit says so.** The first push let
  the field put the words back without a reason, though
  `MessageComposer` reports the refusal; Greptile's review found it, and
  `DraftStore` now sets `DraftIssue.reachedLimit`.
- **The phrases are dimmed while typing, not taken away.** The first push
  left the phrase grid empty while typing and recorded for the owner that
  a look resting on its top edge could meet Clear or Put Back, which
  border it on every arrangement. Codex's review held that against
  invariant 10. The tiles now stay in place, disabled like the other
  categories, so the look rests on a tile that does nothing. Scored again
  with looks resting all along the top row's tiles: by nearest edge no
  typing chain meets Clear, Put Back or anything else harmful; by nearest
  centre, a look near the top of a tile is still nearer the centre of the
  shorter cell above, so the finding is narrower, not gone, and stays
  open for the owner, pinned strict.

- **Where Clear and Put Back go**, by scoring every pair of category cells
  in every typing state: never under or beside Stop's well.
- **The held guide link stays held.** Learn About Each Way (commit
  `1de50f5`, held on PR #50) was modelled on the moved frames: its guide's
  Back to Talking, nearest the look, closes Settings over Home's Get
  Attention in three chains on the phone model, so bringing it back would
  trade a milder hazard for a worse one. `ChainEngineTests` pins why.
- **Fewer tiles to a screen** is drawn in Figma as R1's direction (pages
  of whole rows, with "More, 1 of 2" in the grid's last slot) and not
  built, because touch, 1.0's only profile, may scroll.
- **Not decided:** whether Yes and No may border the message, the owner's
  question before R1. With Phrases and Type on Home, its measured share is
  now Home's (up to 97% by centre on phones; docs/HANDOFF.md, *Known
  gaps*).

## Commits

On top of the work file's two commits (`c55d250` the intent, `7091bde`
the spec and plan), one task each: the layout engine and chain maps with
their tests; Home's typing state, the app's message and the names,
regions and status line with their tests; Settings' bar over Phrases with
its tests; the UI tests; and this record with the String Catalog and the
documents. Then, after the reviews: Type offered only where the safety
row clears the keyboard, with its test, hint and records (Codex);
"Message full" for a change refused at the length limit, with its tests
(Greptile); and the phrase tiles dimmed in place while typing, with the
chain maps and tests that score them (Codex).

## Verified

- **Linux, Swift 6.4.1 (Ubuntu 24.04), with Apple's SF Pro fonts through
  HarfBuzz**, which matched CI's widths within half a point before: the
  layout engine, `KeyboardAllowance`, the chain engine, `HomeChains` and
  `SettingsChains` with `HomeLayoutEngineTests`, `KeyboardAllowanceTests`,
  `ChainEngineTests`, `HomeChainsTests`, `HomeChainsTypingTests` and
  `SettingsChainsTests`: 86 tests passed after the reviews, with only the
  strict known issues the decisions name. `ControlNamesTests`, `HomeRegionTests` and
  `SettingsRootColumnsTests` also passed there (17 tests), with a
  harness-only stand-in for `String(localized:)`, which Linux Foundation
  lacks, and so did `DraftStoreTests` and `MessageComposerTests` (70
  tests), with stand-ins for OSLog and the Application Support folder.
- **CI on `e682dc2`** (the second push): the unit tests passed on the
  iPad Pro 13-inch (M5) simulator, iOS 27.0, Xcode 27.1: 725 ran, 717
  passed, 0 failed, 1 skipped (issue #19's disabled reproduction), 7
  expected failures, with the String Catalog up to date. The last push's
  run is the check for the dimmed tiles.
- **What each new test fails on** (each was run against the change that
  should fail it, or the old code):
  - `backToTalkingClosesOntoPhrasesAlone`: Back to Talking as wide as
    Phrases, or a full column on short regular windows (a look at its
    lower corners meets Get Attention or Again).
  - `getAttentionTakesOneLineWhereTheMessageLeavesRoom`: the old
    trailing column, a third of the width.
  - `phrasesHasRoomForBackToTalking`: Phrases at the quick controls'
    floor where Back to Talking takes two lines.
  - `phrasesAndTypeGrowAfterTheSafetyRowAndGiveItBackFirst`: growth
    before the safety row, or kept growth under the keyboard's room.
  - `clearAndPutBackStayOffStopsNeighbours`: Clear or Put Back under or
    beside Stop's well.
  - `typingChainsMeetOnlyClearAndPutBackByCentreFromTheDimmedPhrases`:
    the phrase grid empty while typing, as the first push had it (Clear
    or Put Back met by edge), and the tiles speaking while typing; and,
    strictly, the centre's finding gone.
  - `typeIsOfferedOnlyWhereTheSafetyRowClearsTheKeyboard`: Type offered
    on every window, as the first push did (it fails on the zoomed
    13-inch iPad in landscape at AX5, Codex's case).
  - `DraftStoreTests.aRefusedEditSaysTheMessageIsFull` and
    `aFailedSaveOutranksTheLimit`: no notice for a refused edit, and the
    limit's notice replacing a failed save's.
  - `ChainEngineTests.backToTalkingOverPhrasesClosesOnlyUnderALookItReachesUnasked`
    and `theHeldGuideLinkWouldSoundTheAlarm`: Settings' frames back at
    the old bar, or the guide link's chains clearing.
- **Measured on the engine's frames** (Linux, no simulator): the iPhone
  17 (402×874), a 375×667 phone and the 13-inch iPad in both orientations,
  at the default size and AX5, and the fit and keyboard tables in
  `HomeLayoutEngineTests` for every window they list. The numbers in
  "Typing on Home" come from there.
- **The String Catalog** was edited by hand (this session cannot run
  `xcstringstool`): "Phrases", "Type", "Clear", "Put Back", "Message" and
  Type's dimmed hint added with their comments; the project files' catalog tool found every
  key the code uses and none it does not. CI's catalog check is the
  proof.
- `scripts/test-docs.py`, `scripts/test-site.py` and
  `scripts/test-hooks.py` pass.

## Not verified

- **Nothing was built for iOS or run in a simulator.** Home's typing
  state, Settings' bar, the app's `DraftStore`, the status line and every
  UI test (`TypingOnHomeTests`, the changed `SettingsOnHomeTests`,
  `HomeReachabilityTests`, `HomeLayoutTests` and
  `HomeAccessibilityOrderTests`) are untested until CI runs them.
- **Focus.** Type puts the cursor in the field through `@FocusState` in
  a `task` just after the field appears, the pattern Apple's developer
  forums give for a field new to the screen (set in `onAppear`, a new
  field may not take it yet); whether the keyboard comes at once on CI's
  simulators is the first UI run's to show.
- **The iPads' indirect closings.** The model finds that Settings closed
  through Family Setup lands on Type there, so `SettingsOnHomeTests`
  expects none; CI's frames decide.
- **Typing at the largest text sizes** in the running app, the iPad's
  floating and split keyboards, other languages and iPhone Duo.
- **The keyboards on 320-point windows and on a 375×667 phone at AX3 and
  AX5**, where by the engine Speak and Get Attention end inside the room
  kept for the keyboard and Type is dimmed: not measured anywhere. No CI
  window dims Type, so the dimmed Type, its hint and putting the keyboard
  away when the room goes are checked only on the engine's frames and by
  reading the code.
- **Every device check**: gaze, Dwell, Snap to Item, Switch Control and
  Voice Control typing, Return among the letter keys, sound
  (docs/HANDOFF.md, *Checks that need a real device*, the typing row).
- The Figma screens set labels in Inter, since the connector has no SF
  Pro; how a word fits is the engine's measurement, not the drawing's.

## Follow-ups

1. **CI.** Watch the first run: focus in a `task`, the catalog check,
   the strict known issue on the phone's indirect closings, the iPads'
   expected none. *(this thread)*
2. **For Codex on the owner's Mac:** run `KeyboardProbeTests` on a
   375×667 simulator with and without Display Zoom, which says whether
   the real keyboard would cover Speak or Get Attention there, and so
   whether Type, dimmed there today, could be offered; type on Home at
   AX5 on the iPhone 17 and 13-inch iPad simulators and note anything that
   moves or ends under the keyboard (docs/HANDOFF.md, *Known gaps*).
   *(Codex, through the owner)*
3. **Settings' indirect closing** on phones (Family Setup's Back to
   Talking, nearest a look on the top of the root's row): placing Family
   Setup's first rows for it, and then the held guide link again.
   *(the next Settings thread)*
4. **The owner's questions before R1**, each measured in "Typing on
   Home": by nearest centre, the top of a dimmed phrase nearest Clear or
   Put Back; whether to offer typing, with the covered controls two activations away, where
   Type is dimmed today; Yes and No beside the message. *(the owner)*
5. **Fewer tiles to a screen**, from the Figma direction, with R1's
   profiles. *(R1, Wave 3 item 8)*
6. **320-point windows** need their own arrangement: the message there
   is too narrow for "understand." with Bold Text, the starter library
   never fits, and the keyboard's room reaches Speak and Get Attention,
   so Type is dimmed there.
   *(the layout engine, a new thread)*
7. **Back to Talking's rendered words** join the rendered-label UI test.
   *(the next accessibility pass)*

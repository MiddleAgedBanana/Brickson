# Get Attention and Stop on Home

*Roadmap: R0 item 4 (Get Attention), the part PR #16 left for later:
the controls on Home. Owner: the Get Attention and Stop on Home thread.
Status: intent.*

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

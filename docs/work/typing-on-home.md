# Typing on Home

*Roadmap: Wave 3 item 5 (R0 items 5 and 9). Owner: the Typing on Home
thread (a cloud session; GitHub CI is its build). Status: intent.*

## Intent

- **Problem:** Home can only speak what the library holds. Someone who
  wants to say anything else (a name, a question, a correction) has no
  way to do it in Brickson: the typing foundation is built and tested
  (`MessageComposer`, `DraftStore`, the keyboard's measured room), but
  nothing on Home opens it. Three things wait on it too. Settings' Back
  to Talking closes the cover onto whatever lies under its spot, and a
  look resting near its edge closes it over No or Get Attention
  (docs/DECISIONS.md, "One chain engine for dwell safety", *Open:
  Settings closes under the look*); the slot plan puts it over Phrases,
  which only arrives with typing. The guide link held on PR #50 (commit
  `1de50f5`) waits for that. And Home still scrolls at the largest text
  sizes and with Display Zoom on phones, a design question (fewer tiles
  to a screen) left for this item.
- **Proposed outcome:** Type, beside the message, opens Apple's keyboard
  with the field in the message's place; the person types and chooses
  Speak, in Again's place, or Return; Phrases goes back to the phrases,
  keeping the message. Clear empties the message and Put Back brings it
  back, each in a fixed place. Nothing on Home moves when the keyboard
  shows, and Emergency, Get Attention, Yes, No, Speak and the way back
  stay above it. Settings' Back to Talking sits over Phrases, so closing
  Settings lands on a control that only chooses what Home shows.
- **Who and what it affects:** everyone who can still use a keyboard,
  by touch, Switch Control, Full Keyboard Access, Voice Control or a
  pointer, and their listeners. Home (`HomeView`), the layout engine
  (`HomeLayout`), Settings' bar (`SettingsSafetyBar`), the app's start
  (`BricksonApp`, which keeps the draft), the chain maps (`HomeChains`,
  `SettingsChains`) and the UI tests that read Home.
- **Constraints:** invariant 1 (standard `Button`s and Apple's own
  `TextField` and keyboard), 2 (every phrase still speaks at once;
  Emergency is one activation away while typing and leaves typing), 3
  (speaking never changes the library; the draft is not the library), 4
  and 5 (a draft that cannot be saved or restored says so in the status
  line, and the words stay on screen), 6 (no new colours without a pinned
  pair), 7 (the draft is the person's own words: never rewritten, never
  dropped by a repair), 8 (a state changes what a slot shows, never where
  it is), 10 (chains scored on every state, typing included), 11
  (nothing reflows when the keyboard shows), 12 (unchanged). The privacy
  policy already promises the draft ("The message you are typing, so it
  is still there if the app closes. It stays until you clear it."), and
  the app must keep that sentence true. docs/DECISIONS.md: *Home's slot
  plan*, *Typing is a state of Home*, *Typing uses Apple's keyboard*,
  *Writing Tools off while typing*, *Return speaks*, *The typed message*,
  *Settings on Home*.
- **Open questions:**
  - Where Clear and Put Back sit, and what the phrase grid shows while
    typing: decided by scoring, below (*Spec*).
  - How Back to Talking fits Phrases' frame on a small phone: decided
    below.
  - Fewer tiles to a screen: a direction for R1, drawn here, not built
    (*Spec*, *Fewer tiles*).
  - Not this item's: whether Yes and No may border the message, which
    the owner decides before R1 (docs/DECISIONS.md, "The layout
    engine"). Typing keeps the frames the owner is deciding on.

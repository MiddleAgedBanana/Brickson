# Settings' first row, placed from Home's frames

*Roadmap: Wave 3 item 7 (R0 items 4 and 7), the half left by PR #53.
Owner: the Settings' first row thread (a cloud session; GitHub CI is its
build). Status: building (untested until CI passes).*

## Intent

- **Problem:** under AssistiveTouch Dwell, head tracking, Eye Tracking or
  Switch Control's auto-select, the pointer stays where the last control
  was when the next screen appears, and a held look chooses whatever is
  nearest it then. CI's first run on PR #53 found that on the 13-inch
  iPad a look held on Settings' Family Setup row (524, 216, 492 by 110
  points in portrait) opens Family Setup, whose Back to Talking is then
  the nearest control, because Family Setup's first row starts lower;
  Settings closes onto Home with the look over Get Attention, and the
  alarm sounds. Three held activations from a family's screen, recorded
  as a strict known issue in `SettingsOnHomeTests` (docs/DECISIONS.md,
  "Typing on Home", *Settings closing, rescored*). The phone has the
  same chain, landing on No.
- **Proposed outcome:** no look held on Settings' first row can close
  Settings, on any window, by either rule of "nearest" (centre or edge)
  and with either pointer. Home's Settings button, the way in, still
  meets only that row when Settings opens over it.
- **Who and what it affects:** people using dwell, head, gaze or
  switches who wander into Settings; families, who see the root's row
  and Family Setup's first row in new places. Settings' root
  (`SettingsRootView`), Family Setup (`FamilySetupView`), every Settings
  screen's measurement (`SettingsScreen`), and the tests that score
  Settings (`SettingsChains`, `SettingsOnHomeTests`, `ChainEngineTests`).
- **Constraints:** invariant 1 (standard `NavigationLink`s at Settings'
  row floor), 8 (positions come from the window, never from use or
  time), 10 (chains scored by nearest centre and nearest edge, fixed by
  placement, never by a timer, a decoy or pointer code), 11 (sizes from
  the tested layout engine), *Layout on every device and window* (from
  Home's frames and the measured screen, never a device), "Words never
  break", and docs/DECISIONS.md, "Settings is a cover with a fixed
  safety bar" and "Settings on Home".
- **Open questions, each answered here:**
  - *Why not move only Family Setup's first row up under the root's row,
    as the brief proposed?* The coordinator's brief kept Family Setup's
    opening words under the row's spot. Modelled on CI's frames, that
    leaves the phone, at the default size and at the largest, with a
    chain closing Settings onto No or Get Attention wherever the row
    sits: with the opening words there, Back to Talking is nearer the
    spot than the first row below them. So Set Up Step by Step takes the
    row's place instead (*Spec*), and the words go above it where they
    fit, under it where they do not. Measured in `ChainEngineTests`,
    with no closings on any of CI's windows.
  - *Is Set Up Step by Step a decoy?* No. It is the row a family member
    most needs on arriving in Family Setup, and it was already first;
    only its height and the words' side change.

## Spec

- **Settings' root:** the Family Setup row is placed from Home's frames
  as Home lies under the cover (`SettingsRowPlace`):
  - its top is the highest point in the content where every point of
    its top edge lies nearer, by centre and by edge, a Home control that
    only switches what Home shows (Phrases, Type, Emergency, the
    categories, Settings) than one that speaks or sounds (Yes, No,
    Again, Get Attention, Stop, the phrase tiles), with an 8-point
    margin;
  - where Home under the spot of Settings' Back button speaks or sounds
    (the phone), it is held at the lowest top that keeps that spot
    nearer the row than Back to Talking, so going back from Family
    Setup never meets Back to Talking;
  - its width is the narrowest that serves: over Home's Settings button,
    else the trailing half, else the whole width; and it never leaves
    the first screenful. The note goes beside it where two columns fit
    (`SettingsLeadIn`), above it where it fits, else under it.
- **Family Setup:** Set Up Step by Step takes the root's row as drawn
  (`SettingsLanding`), across the whole width and at least as tall. The
  opening words go above it where they fit in the room between the top
  of the content and the row, and under it where they do not. The
  check-in card, when due, and the setup warnings come after it, so a
  card never moves it. The other rows follow unchanged.
- **Every Settings screen** measures where it sits in the window
  (`SettingsScreenFrames`): the stack's frame from the cover, the
  navigation bar from the screen's own safe area, so the root's row is
  placed in window coordinates without assuming the bar's height.
- **Where things land (CI's windows, from the layout code):**

  | Window | Root row | Note | Set Up Step by Step | Opening words |
  |---|---|---|---|---|
  | iPhone 17, default | 16, 312, 370 by 78 (held by Back's spot) | above | 16, 312, 370 by 78 | under |
  | iPhone 17, AX5 | 16, 317, 370 by 145 | under | 16, 317, 370 by 145 | under |
  | iPad 13-inch portrait, default | 822, 354, 194 by 78 (over Home's Settings) | beside | 16, 354, 1000 by 78 | above |
  | iPad 13-inch portrait, AX5 | top 378 | under | at the row's top | above |
  | iPad 13-inch landscape, default | top 355 | beside | at the row's top | above |

- **Input methods:** touch, VoiceOver and Full Keyboard Access meet the
  same controls in the same reading order (note, then row, or row, then
  words, as drawn). For dwell and switches, the chain model on CI's
  frames finds no chain that closes Settings under the look, on any of
  the four windows it models (`SettingsChainsTests`).
- **Known issues kept strict, so they fail when they clear:**
  - *iPhone at AX5:* the first step behind Set Up Step by Step shows only
    Back, Back to Talking and Next above the fold, and three held looks
    reach Back to Talking (familySetup, guidedSetup, Back to Talking,
    then No or Get Attention; Again while something is spoken). Scoped in
    `SettingsOnHomeTests` to a first step that shows no answer
    (`SettingsChains.showsAnAnswer`).
  - *A short, very wide window* (at least 1304 points wide and at most
    667 tall, default text): Home's Settings' top leading corner lies as
    near Back to Talking's centre as the row's, within half a point, as
    before (`SettingsRowPlaceTests.homesSettingsMeetsTheRow`).
  - *The held guide link* (Learn About Each Way) still sounds the alarm
    and stays held (docs/DECISIONS.md, "Typing on Home", *The held guide
    link stays held*).
- **Colours:** none new.
- **Privacy policy:** nothing it says changes.
- **Screens:** [Settings' first row, placed from Home's frames](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-266):
  [iPhone 17 root](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-267),
  [iPhone 17 Family Setup](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-295),
  [iPhone 17, Home under the root](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-331),
  [iPhone 17 root at AX5](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-386),
  [iPhone 17 Family Setup at AX5](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-414),
  [iPad portrait root](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-444),
  [iPad portrait Family Setup](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-472),
  [iPad portrait, Home under the root](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=61-516).
  Drawn from the layout code's frames; not yet accepted by the owner.
- **Concerns:**
  - *Resting on empty space.* On the iPad the root's row now sits lower
    (354 instead of 216), so more of the first screen is empty space,
    and a look resting there with Snap to Item chooses the nearest
    control, Back to Talking near the top. That closes Settings onto
    Phrases, which only switches; nothing is said or sounded. Not scored
    by the chain engine, which follows activations, not rests.
  - *Simulator evidence only.* Where a pointer rests after an
    activation, and how Snap to Item picks, need a real device (a Codex
    handoff).

## Plan

- **Files that change:** `SettingsRowPlace` and `SettingsScreenFrames`
  (new plain types, with unit tests); `SettingsRootColumns` becomes
  `SettingsLeadIn` (one rule for a control and its words, used by both
  screens); `SettingsComponents.swift` (measurement, `SettingsLeadInLayout`);
  `SettingsView.swift`; `FamilySetupView.swift`; the UI tests
  `SettingsChains`, `SettingsOnHomeTests` and `SettingsTests`; the
  chain model in `ChainEngineTests`.
- **Order of work:** one pull request: this file, then the code and
  tests, then the records (docs/DECISIONS.md, docs/HANDOFF.md,
  docs/ROADMAP.md, AGENTS.md, a `docs/log/` file).
- **Risks:** the row placed from frames measured a moment late, or not
  at all (it then sits at the top of the content until both are known,
  as before); a resized window moving the row while Settings is open
  (it follows the window, as Home does; nothing moves within one
  window); the iPad's emptier root. Each is checked by CI's UI tests
  on both families, which read the real frames.
- **Proof:**
  - `SettingsRowPlaceTests` (4,200 windows: 70 widths from 320 to 1432
    points, six heights from 568 to 1376, five text sizes from the
    default to AX5, Bold Text off and on): the row stays on the first
    screenful; Home's Settings meets only the row; where Home under
    Back sounds, Back's spot meets the row; elsewhere the row's top
    meets only quiet controls; CI's windows pinned. Fails if the rule
    moves the row, lets it leave the screen, or puts it nearer a loud
    control.
  - `SettingsScreenFramesTests`: fails if the content stops starting
    under the bar and a gutter.
  - `SettingsChainsTests`: on four modelled CI windows, no chain closes
    Settings under the look; fails if Set Up Step by Step stops taking
    the row's place.
  - `SettingsOnHomeTests` (UI, both families): unasked closings asserted
    empty except where the first step shows no answer; fails on any new
    closing.
  - `SettingsTests.testFamilySetupOpensWithSetUpStepByStepOverTheWholeRootRow`
    (UI, default and AX5): fails if Set Up Step by Step stops covering
    the root row's frame, or another control meets that spot.
  - Device checks (Codex): where a pointer rests after choosing the root's
    row, with Snap to Item, on an iPad and an iPhone.

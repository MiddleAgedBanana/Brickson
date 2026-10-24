# Settings' chains, and Get Attention in Settings

*Roadmap: Wave 3 item 7 (R0 items 4 and 7). Owner: the Settings' chains
thread (a cloud session; GitHub CI is its build). Status: intent.*

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
  for dwell safety", *Open: a held look saves an answer in Set Up Step
  by Step*). Nothing reads the answers yet, but ROADMAP Wave 3 item 8
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

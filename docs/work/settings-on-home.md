# Settings on Home

*Roadmap: R0 item 7 (Settings and first run), the part it left for later:
Home's Settings button. Owner: the Settings on Home thread. Status: intent.*

## Intent

- **Problem:** Settings is built (PR #23 and #27) but nobody can open it:
  Home has no Settings button, so only UI tests reach it
  (`--screen=settings`). A family cannot choose a voice, read the setup
  guides or open the privacy policy, and the first-run line that tells
  them where setup is was never shown. Separately, the way out of
  Settings is unsafe once Home has a way in: Back to Talking sits over
  the trailing end of Home's message, where Again is today, so a look
  still resting there after Settings closes would land nearest Again,
  which speaks (invariant 10). The open hazard "Yes and No border the
  message" (docs/DECISIONS.md, "Home's slot plan") is the same kind of
  problem: a look resting on the message meets controls that speak.
- **Proposed outcome:** a family member finds Settings on Home in one
  touch, in the same place every time, and a person whose pointer rests
  where a control was never speaks by accident on the way in or out.
  The first launch shows "Family: help with setting up is in Settings."
  in the message area until Family Setup has been opened once.
- **Who and what it affects:** families and caregivers (touch, mostly);
  the person, by every input method, because Settings and the moved
  Again sit on Home. Home's layout (`HomeShape`, `HomeView`), Home's
  names and scan order (`HomeControlNames`, `HomeRegion`), and the
  Settings button (`SettingsButton`).
- **Constraints:** invariant 1 (a standard `Button` with a label, at
  least 44pt), 2 (every phrase still speaks at once; Emergency, Yes and
  No stay one activation away), 8 (positions never depend on state,
  use or the library), 10 (score what a held activation meets on the way
  in and out, by nearest centre and nearest edge), 11 (no new scrolling
  for the starter library), *Words never break*, *Layout on every device
  and window* (sizes from the space, never the device), "Home's slot
  plan", "Settings is a cover with a fixed safety bar", "Home's scan
  order and names", and Apple's current frameworks only (SwiftUI, no
  UIKit in the app's views).
- **Open questions, each answered here:**
  - *Where does Settings go?* Where the slot plan puts it: the trailing
    end of region B, after the categories.
  - *What does Back to Talking close onto, while A's trailing column
    (Phrases and Type) is not built?* Emergency: Again moves into the
    safety row as the slot plan says, and the row is ordered Yes, No,
    Again, Emergency so Emergency is at the trailing end, under Back to
    Talking. The slot plan's regular order (Emergency first) waits for
    Phrases and Type, which are what Back to Talking is meant to close
    onto. Recorded in docs/DECISIONS.md, "Settings on Home".
  - *Is "Yes and No border the message" closed?* No, it is reduced (Again
    no longer sits beside the message, so less of the message is nearest
    a control that speaks) and stays open with a device check, recorded
    in docs/DECISIONS.md, "Settings on Home".

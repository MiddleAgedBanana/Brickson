# The layout engine

*Roadmap: docs/ROADMAP.md, Wave 3 item 3, "The layout engine, with no
screen change yet" (R0 item 3, and R1's profile layout engine); this
file also covers items 4 (Home on the engine) and 6 (Home on iPhone Duo,
in every pose). Owner: the Layout engine thread. Status: intent.*

## Intent

- **Problem:** Home's sizes come from a stand-in (`HomeShape`) with
  fixed numbers chosen one window at a time, and it does not hold the
  slot plan the design settled (docs/DECISIONS.md, "Home's slot plan"):
  Phrases and Type beside the message, the safety row in one row on wide
  windows, wells that keep their frames. On several windows the starter
  phrases scroll at the default text size (a 375×667 phone, iPhone Duo's
  outer display, an 11-inch iPad and an iPad mini in landscape), which
  invariant 11 forbids, because scrolling costs a dwell, switch, head or
  gaze user several activations each time. Nothing yet says, for a given
  window and text size, whether the starter library can fit at all, or
  which windows cannot, so every Home change rediscovers it on CI.
- **Proposed outcome:** one plain, tested function turns the space a
  window gives Home (its size, its safe areas, and regions the system
  reserves, such as a fold), the input profile, the text size and the
  library's shape into a frame for every slot on Home. It says whether
  the starter library fits without scrolling, whether the safety row
  stays above Apple's keyboard, and which slots a reserved region
  crosses. Its tests show, before any screen uses it, where the starter
  library fits and where it cannot, with the numbers. Home moves onto it
  in the next pull request (item 4); typing (item 5) and iPhone Duo
  (item 6) build on it. Nothing a person sees changes in this one.
- **Who and what it affects:** every person, on every input method and
  window, once item 4 puts Home on it; today, nobody: it is code and
  tests that nothing on screen calls. `Brickson/Layout` gains the engine;
  `BricksonTests/Layout` its tests. `HomeShape` stays until item 4
  replaces it.
- **Constraints:** invariant 1 (every target at least 44×44pt, larger
  where the profile's floor is higher), 2 and 10 (Yes, No, Emergency and
  Get Attention one activation from every Home state, above the
  keyboard; a held look scored after each control), 8 (positions never
  follow usage, time or Home's state; a well keeps its frame), 11 (no
  scrolling for the starter library; never a target below its floor to
  avoid it), AGENTS.md *Layout on every device and window* (nothing that
  names a device), *Words never break*, and the decisions "Layouts from
  the space available", "Home's slot plan", "Home's stand-in layout",
  "Get Attention and Stop on Home", "Settings on Home", "Typing is a
  state of Home" and "iPhone Duo".
- **Open questions, each answered in the spec:**
  - *What is the touch profile's floor, and what are today's sizes?*
  - *Where does each slot go when the slot plan meets the decisions made
    after it?* Get Attention and Stop on Home put Get Attention directly
    under Emergency, which the slot plan's two-row safety row does not.
  - *Which windows can hold the starter library without scrolling, and
    at which text sizes?* And what happens where none can.
  - *How does the engine take a fold?* The plan says this waits for R0
    item 13's look at the open iPhone Duo, which has not happened.

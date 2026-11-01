# The late-stage profile: Yes and No, and the rest board

*Roadmap: Wave 3 item 9 (R1, the profile layout engine), built before
the first App Review build by the owner's decision of 2026-10-30
(docs/DECISIONS.md, "Items 8 and 9 come before the first App Review
build"). Owner: the item 9 thread (a cloud session; GitHub CI is its
build). Status: intent.*

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

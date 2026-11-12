# Four phrases in every category

*Roadmap: R0, the quality bar's Q2 (the Library's first follow-up).
Owner: the thread "Fix Home's short-category dwell hazard". Status:
done; merged in pull request #81 on 2026-11-05, after CI's unit and UI
tests passed on its final head (run 42042331740).*

## Intent

- **Problem:** since the Library (2026-11-05) a family can make a
  category with fewer phrases than Home's grid has columns, and a new
  one starts with none. Its grid leaves empty cells in the top row,
  right under the categories. A person using Dwell, head tracking or
  Eye Tracking who rests their look there can, while typing, clear or
  put back the message they are writing, and, while browsing, change
  the category so that the next resting moment speaks a phrase they
  did not choose (invariant 10).
- **Proposed outcome:** Home never shows a grid with an empty top-row
  cell. A category is offered on Home once it has four phrases, and
  keeps four once it has them. The family is told why a category is
  dimmed and how many phrases it still needs.
- **Who and what it affects:** every dwell, switch, head and gaze user,
  and the family editing the library; Home's category row, the
  Library's category screen and phrase editor, Set Up's rest-board
  question, and `LibraryEdit`.
- **Constraints:** invariants 2 (Emergency always reachable, never
  dimmed), 7 (no edit or import removes a person's words: a backup that
  would cross is refused whole, never trimmed), 8 (a dimmed category
  keeps its place) and 10; *Fix hazards with placement, never with
  decoy buttons* (AGENTS.md).
- **Open questions:** whether placement can remove it. Two independent
  reviews found it cannot: a new category has no phrases, so whatever
  the order of the cells, the top row borders the categories with
  nothing in it. Asked on 2026-11-05 whether four is the floor or the
  hazard is accepted, the owner chose the floor (docs/DECISIONS.md,
  "Four phrases in every category").

## Spec

- **States:** no new state. An everyday category with fewer than four
  phrases is dimmed in its cell, in every Home state, as the rest
  board's other categories are; it never shows. Home starts on the
  first everyday category it offers, then Emergency's. Nothing moves
  when a category reaches four: the grid's rows come from the largest
  category (invariant 8).
- **Input methods:** a dimmed button does nothing for touch, Voice
  Control, Switch Control and Full Keyboard Access; VoiceOver reads it
  dimmed, with a hint that it shows once it has four phrases. For Dwell
  with Snap to Item, whether the pointer stops on a dimmed button is a
  device check (docs/DEVICE-CHECKS.md, B2), as it already is for
  typing's dimmed controls (I8).
- **The Library:** a category's screen with fewer than four phrases
  says, under them, "Home shows “Trips” once it has four phrases. Until
  then it is dimmed there. Add 4 more." Emergency's says it should have
  at least four. Delete Phrase is dimmed, with the reason beside it,
  where it would take a category from four to three; a move or a
  restore that would is refused the same way.
- **Set Up:** the rest-board question dims a category with fewer than
  four, unless it is already the board, with a line under the question
  that says why. The line shows wherever any category is short, whatever
  is chosen, so changing the answer never moves the choices.
- **Colours:** none new.
- **Privacy policy:** nothing it says changes.
- **Screens:** no Figma frames: every control keeps its frame, and the
  new words are passive lines in places the screens already keep for
  words.
- **Concerns:** an Emergency already short of four (no edit can make
  one) cannot be dimmed; it stays a strict known issue, and its screen
  tells the family to add phrases.

## Plan

- **Files that change:** `HomeLayout` (`mostColumns`), `LibraryRules`,
  `LibrarySnapshot`, `LibraryEdit`, `CategorySelection`, `HomeView`,
  `GuidedSetupView`, `LibraryCategoryView`, the String Catalog, and
  the tests: `LibraryEditTests`, `CategorySelectionTests`,
  `HomeChainsTests`, `HomeLayoutEngineTests`, `LibraryTests`.
- **Order of work:** one pull request.
- **Risks:** an existing library or test fixture already under four
  stops being editable (checked: only a crossing is refused); a
  remembered choice of a short category shows its empty cells (checked:
  `CategorySelection.resolve` skips it).
- **Proof:** each new test names the change that makes it fail, in the
  pull request's record (`docs/log/2026-11-05-four-phrases.md`).

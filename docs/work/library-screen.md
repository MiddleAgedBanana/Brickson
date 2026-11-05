# The Library screen: editing, export and import

*Roadmap: R0 item 6, the rest of it after the library core (PR #14).
Owner: the thread "Let families edit and back up phrases" (2026-11-05).
Status: intent.*

## Intent

- **Problem:** a family cannot make Brickson say what their person needs.
  The starter phrases are fixed: nobody can add "Please call my
  daughter.", fix a word, put the phrases they use most first, remove one
  that never fits, or name a category for their own life. Nor can they
  keep a copy of what they wrote, move it to a new iPad, or make the
  iPhone and the iPad match. The library core can do every one of these
  changes safely (`LibraryEdit`, `LibraryEditor`, `LibraryImport`,
  `BackupCodec`, all tested), but nothing in the app calls it
  (docs/HANDOFF.md, *Known gaps*, "No editing, export or import
  screens"). The privacy policy already describes backups a person
  exports, and the quality bar's Q24 asks that phrases and categories can
  be added, edited, reordered and removed and the library backed up and
  restored before App Review.
- **Proposed outcome:** in Settings, Family Setup gets a row, Phrases and
  Categories. Behind it a family member, usually by touch, can:
  - add, change, move and delete phrases in each category;
  - add, rename, re-picture, move and delete everyday categories, and
    change Emergency's phrases (never delete Emergency);
  - export a backup file through the share sheet (Files, iCloud Drive,
    AirDrop, Mail, another app), as the privacy policy says;
  - choose a backup file and either add what it has to the library or,
    where that removes none of the person's own words, replace the
    library with it.
  Every change is saved at once, in one save, or not at all, and a
  failure says so where the change was made. Home shows the change when
  Settings closes.
- **Who and what it affects:**
  - *Families and carers*, mostly on touch, sometimes Voice Control:
    they do the editing.
  - *The person*, at every stage: their words change on Home. On a
    dwell, switch, head or gaze profile they can reach these screens by
    a stray dwell, so every screen is scored by the chain engine like
    the rest of Settings, and nothing that deletes or moves is reachable
    by a repeat.
  - *The app:* Settings (a new route and screens), the library core (two
    new rules on how many everyday categories a library keeps), a file
    type for export, the chain engine's Settings surface and the UI
    tests. Home's code does not change: it already reads the library
    through `@Query` and keeps only the selected category's identity.
- **Constraints:**
  - Invariant 1: standard `Button`s and `NavigationLink`s, at least
    Settings' 64-point rows; the text fields are standard `TextField`s.
  - Invariant 2: Home is untouched; every phrase still speaks on the
    first activation. No edit mode on Home (docs/DECISIONS.md, "Editing
    the library": a Library screen inside Settings for 1.0).
  - Invariant 3: changes happen only on these screens. Delete, Add from
    a backup and Replace ask first; Keep takes the asking control's place
    and the confirmation appears where a repeat cannot reach it.
  - Invariant 5: every save goes through `LibraryEditor.apply`, which
    already has a failing-save test for every kind; every failure shows
    passive words in a line kept for it.
  - Invariant 6: no new colour pair unless pinned. The plan is to add
    none.
  - Invariant 7: nothing deletes or rewrites the person's words except a
    delete the family confirmed. Import keeps words byte for byte. Replace
    that would remove the person's words stays refused: the safety-copy
    exception is the owner's and not adopted (docs/DECISIONS.md,
    "Replacing the library").
  - Invariant 8: a category's place on Home changes only when the family
    moves it; every control keeps its frame across each screen's states.
  - Invariant 9: no network code. The share sheet and the file picker
    are the system's; the backup is a plain file the family places.
  - Invariant 10 and *Design rules for dwell, switch and pointer input*:
    each new screen is a surface of the one chain engine; moves are
    absolute, so a repeat changes nothing; a confirmation is never
    nearest the spot just activated.
  - Invariant 11: Home's starter library is unchanged.
  - Home's slot plan has no answer for a fifth everyday category, and
    fewer than three can leave Again nearest Stop's empty well
    (docs/DECISIONS.md, "Home's slot plan", *Open*; "Get Attention and
    Stop on Home", *Open: fewer than three everyday categories*). So no
    edit or import may add a fifth everyday category or leave fewer than
    three.
  - *The privacy policy is a promise*: no sentence becomes untrue. No
    words of a person's phrases in any log or crash message.
  - *Apple's current frameworks first*: SwiftUI's `ShareLink`,
    `fileImporter`, `Transferable` and `UTType`; no UIKit.
- **Open questions:**
  1. *Three everyday categories at least: a rule for the owner.*
     docs/DECISIONS.md asks the library thread to bring the owner a rule
     that keeps three, or to have the layout keep a category nearest
     Stop's well for every library. Put to the owner on 2026-11-05 with
     the recommendation "three is the floor"; this work keeps three
     meanwhile, which either answer needs until Home changes.
  2. *Safety copies.* Not built: their only adopted purpose would be
     Replace over the person's words, which the owner has not adopted.
     Building files nobody can reach would be busywork, and would make
     the policy's "gone from the app" untrue.
  3. *The S4 rollback probe (issue #19) and stores from every schema
     version* come first in the emergency repair record's list, but the
     probe can crash the whole unit run and the store fixture needs a
     store file made on a Mac, so each stays a pull request of its own.

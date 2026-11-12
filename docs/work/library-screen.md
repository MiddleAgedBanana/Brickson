# The Library screen: editing, export and import

*Roadmap: R0 item 6, the rest of it after the library core (PR #14).
Owner: the thread "Let families edit and back up phrases" (2026-11-05).
Status: done; merged in pull request #80 on 2026-11-05, after CI's unit
and UI tests passed on its final head (run 42014189828). Where building
it changed this spec, *What building it changed*, at the end, says how,
and docs/DECISIONS.md holds what was decided.*

## Intent

- **Problem:** a family cannot make Brickson say what their person needs.
  The starter phrases are fixed: nobody can add "Please call my
  daughter.", fix a word, put the phrases they use most first, remove one
  that never fits, or name a category for their own life. Nor can they
  keep a copy of what they wrote, move it to a new iPad, or make the
  iPhone and the iPad match. The library core can do every one of these
  changes safely (`LibraryEdit`, `LibraryEditor`, `LibraryImport`,
  `BackupCodec`, all tested), but nothing in the app called it (a gap
  in docs/HANDOFF.md, *Known gaps*, until this work). The privacy policy already describes backups a person
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
    tests. Home reads the library through `@Query` and keeps only the
    selected category's identity; its grid reads the phrases through a
    query of phrases, since CI showed a phrase edited here keeping its
    old words on Home when read through its category
    (docs/log/2026-11-05-library-screen.md).
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
     Stores from every schema version were built on 2026-11-12, with
     the store made on CI instead
     ([`../log/2026-11-12-stores-from-every-version.md`](../log/2026-11-12-stores-from-every-version.md)).

## Spec

### The drawings

Drawn in the project's Figma file, from copies of the existing Settings
frames, in the section [Library screen flow (R0 item 6,
2026-11-05)](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=206-285).
They are pictures of what the app should produce, not the layout's
source: sizes and places come from the code and its tests. Labels are
Inter, not SF Pro (SF Pro written through the connector draws nothing),
so how words fit is estimated there and measured on CI.

- iPhone 17, light, default size:
  [Family Setup with the new row](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=206-290),
  [the Library](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=207-300),
  [a restore refused](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=207-364),
  [Needs](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=208-330),
  [Emergency](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=208-396),
  [the phrase editor](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=209-360),
  [with words changed and the keyboard up](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=209-406),
  [New Phrase after a save](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=209-1195),
  [Delete](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=210-531),
  [Move](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=210-572),
  [Change Picture](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=210-631),
  [Rename](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=210-741),
  [the Restore question](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=211-591)
  and [its result](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=211-639).
- iPad Pro 13-inch, portrait:
  [the Library](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=212-622),
  [the phrase editor](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=212-679)
  and [Delete](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=212-720).
- [The Library in dark mode](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=213-624),
  [the phrase editor at the largest text size](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=213-704),
  and [the way back in the place of the row that asked](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=214-653):
  Edit Phrase, Delete and Move side by side.

Drawing it settled three points, taken into the spec below: each
category screen keeps a result line at its top, as the Library does; a
restore's result and refusals show in a line kept under Restore from a
Backup, where the family is, not at the top of a Library that may be
scrolled; and Emergency's example count is the starter library's six.

### Where it lives

- **The way in.** Family Setup gets one row, **Phrases and Categories**
  (`library`, `SettingsRoute.library`), the first of its rows: after Set
  Up Step by Step's lead-in, the check-in card and the setup warning,
  before Voice Settings. It only opens the Library. Every row after it
  moves down one row, and the chain sweeps that list Family Setup's rows
  are updated with it.
- **The routes** are `SettingsRoute` cases, so the idle reset
  (`path = []`) and the UI tests treat them like every other screen:
  `library`, `libraryCategory(UUID)`, `newPhrase(category: UUID)`,
  `phrase(UUID)`, `newCategory`, `categoryName(UUID)`,
  `categoryPicture(UUID)`, `movePhrase(UUID)`, `moveCategory(UUID)`,
  `deletePhrase(UUID)`, `deleteCategory(UUID)` and `importBackup`.
  Screens hold identities and a `LibrarySnapshot`, never a model object
  (docs/DECISIONS.md, "Every save is explicit"), read with
  `LibraryEditor.read` when they appear and replaced by what
  `LibraryEditor.apply` returns.
- **Every screen** is a `SettingsScreen` under the safety bar, so Back to
  Talking and the sound line stay where they are. Rows are Settings'
  64-point rows, white on `Palette.controlFill`; Save, the one action
  that commits typing, is white on `Palette.phraseFill`, as
  docs/DESIGN.md's colour table already has it. A person's words
  (category names, phrases) are shown with `Text(verbatim:)`, with a new
  verbatim title for `SettingsScreen`.

### The screens and their states

Every control keeps its frame in every state of its screen: a result or
failure appears as passive words in a line kept for it, with every
version of the words laid out hidden (`SettingsReservedParagraph`), and
a control that cannot act is dimmed in place, never removed.

1. **Phrases and Categories** (the Library). Top to bottom: a line kept
   for results ("Deleted Feelings and its 6 phrases."); where the store is
   only in memory or unreadable, Home's own warning words
   (`PhraseLibraryIssue`, "Phrases can't be saved right now…"); the
   Emergency row first ("Emergency, 6 phrases"), then each everyday
   category in Home's order, each opening its category; **Add a
   Category**, dimmed when there are four everyday categories, with the
   reason beside it ("Home has room for four categories. Rename one, or
   delete one first."); then the backups: a heading, the policy's words
   ("A backup is a file with your categories and phrases. It isn't
   encrypted, so anyone who has it can read your phrases. Keep it
   somewhere private."), **Export a Backup** (the system share sheet,
   `ShareLink`) and **Restore from a Backup** (the system file picker,
   `fileImporter`), with a line kept under it for what a restore did or
   why it could not. Every control here only opens something.
2. **A category** (titled with its name). A line kept for results at
   the top, as on the Library; **Add a Phrase**; then a row
   per phrase, in Home's order, opening its editor; then **Rename**,
   **Change Picture**, **Move Category** and **Delete Category**. For
   Emergency the four category rows are replaced by passive words in
   their place ("Emergency is always one step away on Home, so it can't
   be renamed, moved or deleted. You can change its phrases."). Every
   control here only opens something.
3. **A phrase's editor** (Edit Phrase, or New Phrase from Add a Phrase).
   The text field at the top (`typingFieldTraits()`, Writing Tools off),
   then **Save**, the line kept for results and refusals, then **Move
   Phrase** and **Delete Phrase** (not on New Phrase, whose rows are
   kept empty so nothing moves when the phrase exists). Save is dimmed
   until the words differ from what is saved, so a look resting on it
   meets nothing to do. Return saves, as it speaks on Home (a typed line
   break never reaches the phrase). New Phrase empties its field after a
   save and says "Added "…" to Needs.", ready for the next; Edit Phrase
   stays, with Save dimmed again.
4. **A category's name** (Rename, or New Category from Add a Category):
   the field and Save as on the phrase editor. New Category opens the new
   category's screen in place of itself once saved, so its next step,
   Add a Phrase, is one activation away.
5. **The question screens.** Delete Phrase, Delete Category, Move Phrase,
   Move Category, Change Picture and a chosen backup each open a screen
   built the same way (`LibraryQuestionPlace`):
   - **The way back** (**Keep Phrase**, **Keep Category**, **Leave It
     Here**, **Keep This Picture**, **Cancel**) takes the frame, in the
     window, of the row that opened the screen, so a repeated activation
     meets it and goes back: Keep takes the asking control's place
     (invariant 3), and a held look goes back and forth between two
     controls that only open screens.
   - **The words** sit just under it, so a look that rests on them
     while reading is nearest the way back. (Built first above it where
     there was room; the chain test on CI found their top nearer Back to
     Talking.)
   - **The choices** that change something (**Delete for Good**, the
     places in a move, the pictures, **Add to My Phrases** and **Replace
     My Phrases**) start at least one row's height below both, so none is
     nearest the spot just activated, nor the words. Where they do not
     fit on screen they are scrolled to, which costs a dwell user several
     activations: on these screens that cost protects the person.
   The way back is the standard Back button too, never hidden.
6. **Delete.** The question names what goes and how much ("Delete
   "Hello."? It will be gone from Brickson."; "Delete Needs and its 6
   phrases?"), and that backups keep their copy. Delete for Good deletes
   in one save and returns to the screen above the deleted item (the
   category, or the Library), whose controls only open screens; the
   result shows in its line ("Deleted "Hello."").
7. **Move.** The words name what moves; then each other item as **Before
   "Thank you."**, the item itself as **Leave "Hello." Here**, and **At
   the End** (`LibraryEdit.movePhrase`/`moveCategory`, absolute places).
   Choosing one moves it in one save and the screen stays, the list
   redrawn in the new order in the same frames, every place as tall as
   the tallest (`LibraryEqualRowsLayout`): the moved item's own row
   is where it now is, so a repeat on the spot meets either its Leave
   row or the place it already has, and changes nothing
   (docs/DECISIONS.md, "Editing the library": moves are absolute). Moving
   a phrase to another category is left for later: today it means
   deleting and adding it again.
8. **Change Picture.** The 32 pictures of `LibraryRules.symbolChoices`
   in a grid of 64-point buttons, each named for VoiceOver and Voice
   Control in words; the chosen one marked with a check and its name.
   Choosing saves at once and stays; choosing the chosen one again
   changes nothing.
9. **Restore from a Backup.** The system file picker. The file is read
   through its security-scoped address, decoded by `BackupCodec` and
   checked, without touching the library. Any refusal shows in the line
   kept under Restore from a Backup, ending "Nothing was changed.". A readable
   backup opens the question screen (5): what the backup holds, what
   Add would bring in, and whether Replace can run. **Add to My Phrases**
   (`LibraryImport.merge`) only adds; **Replace My Phrases**
   (`LibraryImport.replace`) is dimmed, with the reason, where it would
   remove the person's own words ("Replacing would remove phrases that
   aren't in the backup…"). After either, the words say what happened
   ("Added 12 phrases and 1 category. Nothing was removed or moved.");
   the choices dim in place and Cancel reads Done.
10. **Export a Backup.** The system share sheet with one file,
    "Brickson Phrases 2026-11-05.json" (the date of the export in the
    name, never in the file: docs/DECISIONS.md, "Backup file format").
    Where the library cannot be encoded (over 8 MB), Export is dimmed
    with the reason.

### Rules the library core gains

- **Three or four everyday categories.** `LibraryEdit.plan` refuses an
  add, merge or replace that would take a library from four or fewer
  everyday categories to more than four
  (`LibraryEditRejection.homeHasRoomForFour`), and a delete or replace
  that would take it from three or more to fewer than three
  (`.homeNeedsThree`). Only an edit that crosses a bound is refused, so
  a library already outside them (a damaged or hand-made store) can
  still be edited and brought back. (Since 2026-11-12 an edit that takes
  such a library farther out is refused too:
  `docs/log/2026-11-12-no-farther-out.md`.) Import keeps every word, so
  it is refused whole, never trimmed.
- **Every word fits the narrowest tile.** A phrase or name with a word
  too wide for Home's narrowest phrase tile or category button, at the
  default text size with Bold Text on, is refused by the editors
  (`HomeWordRoom`, measured with `LabelFont` on the 320-point window the
  engine plans for), and a backup holding one is refused whole, naming
  the word (docs/HANDOFF.md, *Known gaps*: "those must keep every word
  within the narrowest tile").
- **A phrase or category named like a Home control** stays as the
  editor makes it today: category names are refused (`LibraryRules`),
  phrases are allowed, because a phrase tile is named by what it says
  and Home's controls keep their own names (docs/DECISIONS.md, "Home's
  scan order and names"). *Since 2026-11-05 the phrase is saved with a
  note saying so, and since 2026-11-06 the names of the four controls
  one activation away are refused ([`work/phrases-named-like-controls.md`](phrases-named-like-controls.md)).*

### Input methods

- **Touch and Voice Control** (the family): every control is a standard
  button with its words as its name; Voice Control's "Show names" reads
  them. Pictures are named in words.
- **Switch Control, dwell, head and gaze** (the person, by a stray
  activation): every screen reached from Family Setup's row only opens
  screens until a question screen, where the way back is under the
  repeat. Scored by the chain engine on the frames the UI tests measure
  (`LibraryChains`), from every start on every Library screen, under both
  nearest rules and both pointer models; a chain that ends on a choice
  that deletes, moves or saves fails the test.
- **The keyboard.** Settings keeps the whole window whatever the keyboard
  covers, so nothing moves when it appears; the field and Save are the
  first two controls under the navigation bar, above the tallest keyboard
  `KeyboardAllowance` keeps room for on Home, and Return saves.
  Settings' sound line, at the foot, can be under the keyboard while a
  family member types; nothing in Settings speaks then except a voice
  sample, which typing cannot start (an accepted cost, recorded).

### Colours

None new. Delete for Good is a 64-point row on `Palette.controlFill`,
told apart by its words, its trash icon and its place: docs/DESIGN.md
gave it the emergency fill, but one meaning per colour (*The quality
bar*, Q16) keeps red for Emergency, and Settings' rows are white on
`controlFill` or `phraseFill` (docs/DECISIONS.md, "Settings is a cover
with a fixed safety bar"). docs/DESIGN.md's table is corrected.

### Privacy policy

No sentence becomes untrue, and several become true: "the phrases and
categories you use, add or change", "delete a phrase or category in
Brickson, and it is gone from the app", and the backups you export,
through the share sheet to "the Files app, iCloud Drive, AirDrop, email
or another app". The export writes no copy that stays in Brickson's
storage (a `DataRepresentation`, not a file left behind). Import keeps
no copy of the chosen file. The Effective date stays.

### Concerns

1. *Fewer than three everyday categories:* the owner's rule, asked; kept
   meanwhile (Intent, question 1).
2. *A fifth everyday category:* the layout engine's thread decides
   Home's place for it; refused until then.
3. *A chain through the system file picker or share sheet* leaves the
   app and is not scored: what lies past it is the system's. Restore and
   Export are two screens below Family Setup, and the file picker and
   share sheet each need deliberate choices before anything happens.
4. *The idle reset* returns Settings to its root after 90 seconds
   without activity. Typing in a field counts as activity, and a field
   with unsaved words, the file picker, the share sheet and a chosen
   backup waiting for its answer hold the reset
   (`holdsSettingsIdleReset`, as docs/DECISIONS.md, "Settings resets when
   idle and never closes", planned for the Library).
5. *System components* (the share sheet, the file picker, the text
   field's own look) are not measured yet (*The quality bar*, Q17);
   their captures go in the UI tests' attachments for that check.

## Plan

One pull request, in this order of commits (one task each):

1. **The core's new rules, tests first** (`LibraryEditTests`): the
   everyday-category bounds as a backstop for every kind of edit in
   `LibraryEdit.plan`, applied only to a library inside them (three or
   four), so a damaged or hand-made library can still be edited; the
   new `LibraryEditRejection` cases and their words. Then `HomeWordRoom`
   (Layout), with `StarterLabelFitTests`-style checks that every starter
   word fits and a long word does not, and a measured list of common long
   words in the test's attachments, for the owner.
2. **The question screens' placement**, a plain type
   (`LibraryQuestionPlace`) with unit tests: the way back in the opening
   row's frame, the words beside it, the choices at least a row below
   both, at every width and text size the tests sweep.
3. **Export and import as plain types:** `BackupFile` (`Transferable`,
   a `DataRepresentation` of `BackupCodec`'s bytes with the dated file
   name; its closure is `nonisolated` and tested in
   `OffMainThreadCallbackTests`), and `BackupReading` (the picked file's
   bytes through its security-scoped address and `NSFileCoordinator`,
   then the decode, the word check and both plans), each refusal tested.
4. **The screens** in `Brickson/Settings/Library/`: the route cases, the
   Family Setup row, the Library, a category, the editors, the question
   screens, export and import. A verbatim title for `SettingsScreen`.
   Every action records Settings activity; editors with unsaved words,
   the file picker, the share sheet and a pending import hold the idle
   reset.
5. **The chain engine's Library surface** (`BricksonUITests/
   LibraryChains.swift`, compiled into both test targets): each screen's
   controls with what they do, the question screens' states, and the
   moves redrawn in the same frames; unit tests on modelled frames, then
   a UI test that measures every screen on CI's iPhone and iPad and
   scores every start under both rules and both pointer models.
   `SettingsChains` learns the new row, and the sweeps that list Family
   Setup's rows gain it.
6. **UI tests** (`LibraryTests`): add, change, move and delete a phrase
   and see it on Home; Keep in Delete's frame; a category added,
   renamed, re-pictured and deleted; the bounds refused with their
   reasons; a backup restored through a debug-only launch option
   (`--restore-sample-backup`) that stands in for the file picker, which
   UI tests cannot drive; the share sheet opened and closed; Apple's
   audit on every screen in light and dark; captures for Q17.
7. **Documents:** docs/DECISIONS.md (the Library's placement, colours,
   bounds, words, Export and Restore), docs/DESIGN.md's colour table,
   docs/HANDOFF.md in place, docs/ROADMAP.md (R0 item 6, Q2, Q15, Q22,
   Q24 *Today* lines), docs/ACCESSIBILITY.md's R0-6 rows, docs/APP-STORE.md's
   policy rows, README.md, and the log.

**Risks and how each is checked:**
- *SwiftData seeing a delete made in another context while Home's
  `@Query` holds the deleted objects* (docs/LESSONS.md, "Never roll back a
  cascade delete"): the UI test deletes a phrase and a category with
  Home under the cover, then closes Settings and reads Home.
- *The String Catalog* must match the code exactly; CI's check prints
  any difference.
- *Placement under scrolling:* the way back is placed from the opening
  row's frame in the window, measured after any scrolling, not in the
  content; the UI test opens a question from a scrolled row.
- *Unit-test time:* the new chain sweeps are timed on their own and
  reported in the pull request (AGENTS.md, *Gotchas*).

**Proof:** each new test names the change that would make it fail, in
the log. Device checks added to docs/HANDOFF.md: the file picker reaching
iCloud Drive without an iCloud capability; AirDrop and Mail from the
share sheet; Voice Control's names for the pictures; editing with Switch
Control and Full Keyboard Access.

## What building it changed

Each is recorded, with its reason, in docs/DECISIONS.md.

- **The owner's two answers** (2026-11-05): three is the floor ("Three or
  four everyday categories"), and a phrase with a word wider than Home's
  narrowest tile is saved with a note, while a category name with one is
  refused ("Words wider than Home's narrowest buttons"). The spec had
  refused both.
- **The question screens** ("The Library's question screens"): every
  word, results and reasons too, sits just under the way back; Delete for
  Good stays and dims after deleting, and Keep reads Done, instead of
  returning at once; a screen's last row puts its question's choices
  above the way back; Change Picture's pictures are named rows, not a
  grid; Rename is a category's last row. The chain engine found each.
- **Words without plurals:** the Library's rows show names only, and
  counts read "New phrases: 1" ("The Library in Settings").
- **The idle reset:** the Restore question does not hold it, and the share
  sheet cannot ("The Library in Settings").
- **The route** is `restoreBackup`, not `importBackup`.
- **The share sheet** is not opened by a UI test: whether it opens, and
  AirDrop and Mail from it, are device checks.
- **A category shorter than Home's grid.** Editing lets a family make a
  category with fewer phrases than the grid has columns, which the
  starter library never had. Scoring Home with one found that a look
  resting on its empty cells meets Clear or Put Back while typing, and,
  while browsing, a category whose phrase then speaks under the look
  (docs/DECISIONS.md, "Typing on Home", *a category with fewer
  phrases than the grid has columns*). Placing those cells is Home's,
  so this pull request records the finding, open, and pins it strict.
  (No placement could; Home now dims such a category: docs/DECISIONS.md,
  "Four phrases in every category".)
- **The drawings are behind the build** for a category's rows (Rename
  last), Delete (the choice above Keep, Delete for Good staying, Done),
  Change Picture (named rows, not a grid) and the Restore question (every
  word beside Cancel). A thread comparing captures with the frames
  (docs/ROADMAP.md, *The quality bar*, Q15) redraws them.

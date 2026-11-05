# The Library: editing, export and restore in Settings

*2026-11-05. Pull request (`claude/project-thread-muium0`). The thread
"Let families edit and back up phrases", from a cloud session that
cannot build; CI is the build.*

## What changed and why

A family can now make Brickson say what their person needs. Family
Setup's new **Phrases and Categories** row opens the Library: every
category, Add a Category, Export a Backup and Restore from a Backup. A
category's screen adds, opens, moves and deletes its phrases, and
renames, re-pictures, moves and deletes the category. Every change goes
through the library core built in PR #14 (`LibraryEdit.plan`,
`LibraryEditor.apply`) in one save, and what it did shows in a line kept
for it, so nothing moves when words appear. R0 item 6 needed it, and so
does the privacy policy, whose sentences about adding, deleting and
exporting are now true of the build (docs/APP-STORE.md, section 3).

The decisions are in docs/DECISIONS.md:

- "The Library in Settings": the screens, the idle reset, words without
  plurals, no new colours.
- "The Library's question screens": every delete, move, picture and
  restore asks on a screen of its own, with the way back where the row
  that asked was, the words beside it and the choices well clear of
  both, placed by `LibraryQuestionPlace` and scored by the chain engine
  (`LibraryChains`).
- "Three or four everyday categories": the owner's answer, "Yes, three is
  the floor". It closes Q2's hazard of Again nearest Stop's empty well
  with fewer than three.
- "Words wider than Home's narrowest buttons": the owner's answer, "Allow,
  with a note", for phrases; category names with such a word are
  refused (`HomeWordRoom`).
- "Exporting and restoring a backup": a `ShareLink` file made only when
  the family sends it, the system file picker, Add or Replace planned
  first (`RestoreChoices`), and a debug-only sample backup for UI tests.

Scoring the Library's screens with the chain engine, on modelled frames
before any were drawn by the app, found five hazards in the spec's
placement, each fixed by placement (the work file's *What building it
changed*): a question asked from a screen's last row puts its choices
above the way back; Delete for Good stays and dims, with Done; Change
Picture's pictures are named rows, not a grid; result and reason lines
sit with the words; Rename is a category's last row.

Editing also makes possible a category with fewer phrases than Home's
grid has columns (a new one starts with none), which the starter library
never had. Home was scored with one
(`HomeLayoutEngineTests.aShortCategorysEmptyCellsMeetOnlyClearPutBackAndPhrases`):
a look resting on its empty cells meets Clear or Put Back while typing,
and while browsing the category above, whose phrase then speaks under
the look. It is recorded open (docs/DECISIONS.md, "Typing on Home",
*Open: a category with fewer phrases than the grid has columns*; Q2),
pinned as two strict known issues, for the layout engine to place or the
owner to accept before a dwell, switch, head or gaze build ships.

## Commits

- `eb1790f`, `a5cdae7`, `52b82fb`, `ef6df02`: the work file's intent,
  spec, plan and the Figma drawings' links.
- `80a7578`: three or four everyday categories in every edit and import.
- `d754d60`: `HomeWordRoom`, whether a word fits Home's narrowest
  buttons.
- `2c91163`: `LibraryQuestionPlace`.
- `8b25e69`: `BackupFile`, `BackupReading`, `RestoreChoices`, the sample
  backup.
- `6f327e3`: the Library's screens.
- `079360d`: `LibraryChains`, its tests, and the placement fixes they
  found.
- `e2a26ee`: the decisions.
- `2ea98b9`, `1abe4f5`: the build fixes CI found (a missing `import
  Foundation`; a `where` clause the compiler warned about).
- `0fb11b4`: Home scored with a short category.
- The last commits: this record and the documents it makes untrue.

## Verified

- **On Linux, Swift 6.2 (swift.org's toolchain), not Apple's:** the pure
  types and their Swift Testing suites, built as a package with Swift 6,
  default main-actor isolation and the project's upcoming features, and
  `String(localized:)` replaced by a stand-in: `LibraryChainsTests`,
  `LibraryQuestionPlaceTests`, `SetupAnswersPlaceTests`,
  `LibraryEditTests`, `LibraryImportTests` and `BackupCodecTests`, 90
  tests, all passed; `HomeLayoutEngineTests`' new short-category sweep
  passed with its two known issues (1,824 findings while typing and
  3,080 while browsing, none unexpected) in about 121 seconds there,
  unoptimised.
  It found a compiler warning in `LibraryChains` before CI did. This is
  not the app's build: SwiftUI, SwiftData, UIKit and the String Catalog
  are not on Linux.
- **The Python checks**, here: `scripts/test-docs.py`,
  `scripts/test-hooks.py`, `scripts/test-site.py`; the String Catalog
  holds every new string (`xcstringstool` itself runs on CI).
- **GitHub CI**, on the newest released Xcode, CI's iPad Pro 13-inch and
  iPhone simulators: the results are in the pull request.
- **Each new test, and what would make it fail:**
  - `LibraryChainsTests.noHeldLookChangesTheLibrary`: a way back moved
    off the asking row, words among the choices, choices nearer the row
    than the way back, or Delete for Good not dimming after it deletes.
    The three `…IsFound` tests fail if the engine stops seeing the
    hazards the placements prevent (choices under a last row, Delete for
    Good under Delete Phrase, a grid of pictures).
  - `LibraryQuestionPlaceTests`: the way back off the row's frame, words
    overlapping it, choices nearer the row, a last row's choices under
    the way back.
  - `LibraryEditTests`' new four: a fifth everyday category, or fewer
    than three, let through by an edit or a backup.
  - `HomeWordRoomTests`: a starter word wider than its button, or a wide
    word missed.
  - `BackupExportImportTests`: a file name without the day, a file not
    read back as written, a non-backup accepted, Replace removing the
    person's words, a refusal without its own words.
  - `LaunchOptionsTests`' two: the sample backup reachable outside debug
    or test storage, or not the starter library plus one phrase.
  - `LibraryRulesTests.everySymbolChoiceHasAName`: a picture with no
    spoken name.
  - `HomeLayoutEngineTests.aShortCategorysEmptyCellsMeetOnlyClearPutBackAndPhrases`:
    any new hazard from a short category's empty cells; strict, so it
    also fails once placement removes a known one.
  - `LibraryTests` (UI): adding, changing, moving and deleting a phrase
    and its effect on Home; three to four categories, a refused wide
    name, a picture and a rename; the sample backup added; Apple's audit
    on the Library's screens; and the chain engine on the frames the app
    draws at the default and the largest text size, from Home through
    Settings into the Library.

## Not verified

- Anything on a device: the share sheet opening, AirDrop and Mail from
  it, the file picker reading from iCloud Drive and the Files app, every
  input method editing, Snap to Item over a short category's empty cells
  (docs/DEVICE-CHECKS.md, B1 and B2; docs/HANDOFF.md, *Checks that need a
  real device*).
- The share sheet and the file picker in UI tests: XCTest cannot drive
  them, so the sample backup stands in for the picker and nothing for the
  share sheet.
- The chain engine past the share sheet or the file picker, where a look
  rests after the picker closes, and New Phrase, New Category and Rename
  Category, whose Save is dimmed until words are typed.
- Accessibility audits of New Phrase, New Category, Rename, Move and the
  questions in dark, and of every Library screen at the largest text size.
- Whether a phrase a family writes shares a name with a Home control (a
  phrase "Yes"): not checked by the editor.
- The Release build (CI builds Debug).
- Device checks of the larger sizes, unchanged by this work.

## Follow-ups

- **A short category's empty cells on Home:** a placement, or the
  owner's acceptance, before any dwell, switch, head or gaze build goes to
  the external pilot or App Review (Q2). *(the layout engine, a new
  thread; then the owner)*
- **Phrases named like Home's controls:** whether the editor warns about,
  or refuses, a phrase that would answer to "Yes", "No" or another
  control's Voice Control name (`HomeControlNames.collisions`).
  Import keeps the words as they are (invariant 7). *(a library thread)*
- **The Figma drawings** of a category's rows, Delete, Change Picture and
  the Restore question, redrawn to match the build (Q15). *(the thread
  comparing captures with frames)*
- **The rest of the emergency repair record's list:** the rollback probe
  on the current Xcode, stores from every schema version, safety copies,
  each a pull request of its own. *(R0, library threads)*
- **Device checks B1 and B2.** *(the owner)*

# The Library: editing, export and restore in Settings

*2026-11-05. Pull request #80 (`claude/project-thread-muium0`). The thread
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
  that asked was, the words under it and the choices well clear of
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

### What CI and the reviews found

The first CI runs drew the screens, and the chain engine and Apple's
audit read them on CI's iPad and iPhone. Each finding was fixed in the
app or in how the test reads the screen, never by excusing a hazard:

- **A question's words above its way back** reached toward Back to
  Talking: on the phone at the default text size and on the iPad at the
  largest, a look resting on the top of Change Picture's words was
  nearer Back to Talking than the way back, and Back to Talking closes
  Settings onto Home's No, a phrase or Get Attention. The words now go
  just under the way back on every question (`LibraryQuestionPlace`;
  `LibraryQuestionPlaceTests.theWordsGoJustUnderTheWayBack`).
- **Edit Phrase's field** is not a button, so the test did not read it,
  and a look over it met Back to Talking. It is now read on its own and
  scored as a control that changes nothing (`LibraryChains`,
  `LibraryChainsTests.thePhraseFieldChangesNothing`). The modelled
  category grew to seven phrases where a test needs a phrase row level
  with a choice under the words.
- **A row scrolled wholly under the navigation bar** was scored as if a
  look could choose it. On CI a tap on such a row (Change Picture at the
  largest text on the phone) met the bar and nothing asked, so the test
  now leaves such rows out, keeps partly covered ones whole, and scrolls
  a category back by held drags until its four rows that ask show
  together. Whether Snap to Item can reach a covered row joins device
  check F1.
- **A dimmed row** (Add a Category with four categories) failed Apple's
  contrast audit in light and dark: the system's dimmed look is a light
  gray with paler words. A dimmed Settings row is now drawn as Home draws
  a control that is off, unfilled with primary-ink words and edge
  (`SettingsRowButtonStyle`), pairs `PaletteTests` already pins. Save
  uses the same style in the phrase fill.
- **The audit's "not human-readable" guess** on the Library's phrase
  rows ("Maybe.", "Hello."), the same guess the audit helper already
  expects on Home's phrase tiles. The helper now expects it on rows named
  `libraryPhrase` and a number, and AGENTS.md, *Not findings*, says so:
  a widened note for the owner to see.
- **Change Picture's audit timed out** twice in a row on the phone (its
  32 rows), where the iPad finished in about 7 seconds. It is audited one
  kind of issue at a time, every kind iOS has.
- **A phrase row and Home's tile with the same words** under the cover
  matched one query twice; the test now finds a row by its identifier
  and words.

CodeRabbit's review found four things. Three were fixed: a question laid
out before its screen was measured used the greatest finite number as
the height that shows, and a last row's choices that did not fit above
were then searched for below a point that far down, which never ended
(reproduced on Linux: the test did not finish in 60 seconds; it takes
0.19 seconds now; `LibraryQuestionPlaceTests.beforeTheScreenIsMeasuredTheChoicesGoBelowTheWords`);
docs/HANDOFF.md still called editing unreachable; and device check B2
added a category while there were four. The fourth, refusing an edit
that takes a library already outside three or four everyday categories
farther out, is declined for now: a library outside the bounds comes
only from a damaged or hand-made store, and refusing it needs fixture
libraries of each kind in the core's and the SwiftData tests (a
follow-up below; the decision's words now say so).

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
- `215dfca`: this record and the documents it makes untrue.
- The review round: CodeRabbit's three fixes, then what CI found (the
  section above).

## Verified

- **On Linux, Swift 6.2 (swift.org's toolchain), not Apple's:** the pure
  types and their Swift Testing suites, built as a package with Swift 6,
  default main-actor isolation and the project's upcoming features, and
  `String(localized:)` replaced by a stand-in: `LibraryChainsTests`,
  `LibraryQuestionPlaceTests`, `SetupAnswersPlaceTests`,
  `LibraryEditTests`, `LibraryImportTests` and `BackupCodecTests`, all
  passed, before and after the review round; `HomeLayoutEngineTests`' new short-category sweep
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
  iPhone simulators. On `215dfca` the unit tests passed (1,251 passed,
  18 strict known issues, 1 skipped) in 29 minutes for the build and
  tests; the short-category sweep took 102 seconds there. The UI
  findings of the first runs are in the section above; the results after
  the review round are in the pull request.
- **Each new test, and what would make it fail:**
  - `LibraryChainsTests.noHeldLookChangesTheLibrary`: a way back moved
    off the asking row, words among the choices, choices nearer the row
    than the way back, or Delete for Good not dimming after it deletes.
    The three `…IsFound` tests fail if the engine stops seeing the
    hazards the placements prevent (choices under a last row, Delete for
    Good under Delete Phrase, a grid of pictures).
  - `LibraryQuestionPlaceTests`: the way back off the row's frame, words
    anywhere but just under it, choices nearer the row, a last row's
    choices under the way back, a layout before the screen is measured
    that never finishes.
  - `LibraryChainsTests.thePhraseFieldChangesNothing`: the field reported
    as unknown, or scored as anything but changing nothing.
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
- **Device checks B1 and B2, and F1's covered row.** *(the owner)*
- **A library already outside three or four everyday categories:** an
  edit can take it farther out (CodeRabbit, PR #80). Refusing that needs
  fixture libraries of each kind in `LibraryEditTests` and the SwiftData
  tests, whose shared fixture has two everyday categories. *(a library
  thread)*

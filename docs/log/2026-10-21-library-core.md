# The phrase library's core: editing rules, saving and the backup format

*2026-10-21. Pull request #14 (`claude/project-thread-eqfpmu`). Thread
"Library editing and backup format", from the editing and backup memo of
2026-10-16.*

## What changed and why

Nobody using Brickson sees a change yet, except one message (the last
item). This is the code that the editing, export and import screens will
stand on, built and tested before any screen, as the memo recommends. The
rules it follows are recorded in docs/DECISIONS.md as defaults adopted on
2026-10-21, which the owner can reverse: "Every save is explicit", "The
emergency category is always there", "Editing the library", "Importing a
backup", "Replacing the library", "Backup file format", "An unreadable
library is reported, never replaced", and the new paragraph in "Starter
phrases".

- **`LibrarySnapshot`**: the whole library as plain values (categories in
  order, each with its phrases in order). Equality compares words byte for
  byte, because Swift's `==` treats "é" and "e" plus a combining accent as
  equal.
- **`LibraryEdit`** and **`LibraryRules`**: one case per kind of change
  (add, rename, re-picture, move and delete a category; add, edit, move
  and delete a phrase; merge; replace). `plan(in:)` refuses a change with a
  sentence the family can read, or returns the library as it will be, what
  changes, and whether to ask first. No edit may leave the library with no
  categories. No SwiftData involved.
- **`LibraryImport`**: merge adds only and never moves anything; a
  category joins a local one only when the names match byte for byte
  (emergency excepted), and repeats inside one backup category are kept.
  Replace rebuilds from the backup as it is, names and repeats included,
  and keeps the current emergency phrases when the backup's emergency
  category has none. Only phrases with no characters are skipped. Neither
  changes a word of the backup.
- **`LibraryEditor`**: reads the store into a snapshot, and writes a plan
  from a context of its own in one save. A failed save changes nothing,
  and `rollback()` is never called. A plan made from an older library is
  refused. A replace that would remove the person's own words runs only
  after a safety copy of the library exists; safety copies are not built,
  so today it is refused.
- **`BackupCodec`**: the `brickson.library` file, version 1. Same library,
  same bytes. A newer version, a damaged file and a file that is not a
  backup are each refused with their own sentence, and a library too large
  to read back is not written.
- **Starter phrases**: `StarterPhrases.json` is now a file in the backup
  format, with a fixed identity for every category and phrase. Same 5
  categories and 34 phrases, same words, same order.
- **Autosave off**: every path out of `PhraseLibraryLaunch.prepare` turns
  off the main context's autosave, so nothing Home holds can be saved by
  surprise.
- **Launch reads the whole library**: the starter phrases are added only
  when the store opens, every category and phrase reads, and there are no
  categories. A store that opens but cannot be read is reported (below),
  never seeded over.
- **Code audit M2**: when saved phrases exist but will not open, or open
  but cannot be read, Home now says so ("Your saved phrases couldn't be
  opened. They haven't been deleted. Restart the app to try again. Don't
  delete the app: that would erase them.") instead of only "Phrases can't
  be saved right now". The store file is never written to in that case.
  `PhraseLibraryStore.openForApp` takes test seams to make opening fail.
- **The schema is unchanged.** `PhraseLibrarySchemaV1` stays version 1;
  there is no migration.

## SwiftData questions S1 to S4

The memo listed what only a real SwiftData run can settle.
`SwiftDataBehaviourTests` asks each one; where the only possible failure
is a crash, the test says so. The answers below come from this pull
request's CI run 39592594864 (commit `ef7b3b6`): Xcode 26.6 (17F113), an
iPad Pro 13-inch (M5) simulator on iOS 26.5, in-memory stores except S3,
which uses a store on disk opened read-only. They are simulator answers
for that toolchain; a newer Xcode or iOS can change them, and the tests
will say so.

| # | Question | Test | Answer |
|---|---|---|---|
| — | Does SwiftData autosave a new main context, and does SwiftUI's `.modelContainer` leave autosave off once Brickson turns it off? | `aNewMainContextAutosaves`, `attachingTheLibraryToSwiftUIKeepsAutosaveOff` | Yes, and yes: a new main context autosaves, and attaching the library to SwiftUI leaves it off. |
| S1 | After a delete saved from another context, does the main context stop seeing it? Does touching a model object the main context still holds crash? | `s1aDeleteSavedElsewhereIsSeenByTheMainContext`, `s1aHeldObjectDeletedElsewhereCanBeTouched` | The main context stops seeing it at once. Reading a held object's `isDeleted` and `uuid` after the delete did not crash. The reference app's crash ("This model instance was invalidated") did not appear. |
| S2 | Does a category's phrase list in the main context drop a phrase deleted elsewhere? (A model-level stand-in for the memo's Home-level check, which needs an editing screen.) | `s2aPhraseDeletedElsewhereLeavesItsCategory` | Yes. |
| S3 | After SwiftData's own save fails (a store opened read-only), is the main context clean when the failing context was another one? Is the change still pending when it was the main context? | `s3aFailedSaveElsewhereLeavesTheMainContextClean`, `s3aFailedSaveInTheMainContextLeavesTheChangePending` | Yes, and yes. That second answer is why no edit is made in the main context: a later save would write the failed change. |
| S4 | Does `rollback()` crash after deleting a category and its phrases one by one (no cascade)? Does a `transaction` whose block throws write anything? | `s4RollbackAfterDeletingACategoryAndItsPhrases`, `s4ATransactionThatThrowsWritesNothing` | **`rollback()` crashes** ("Unexpected backing data for snapshot creation"), the same trap as the reference app's cascade delete. The test is now disabled, naming issue #19. A transaction that throws writes nothing. |

Brickson's code depends on none of these answers: it never holds a model
object across an edit, never calls `rollback()`, and never edits in the
main context. S4 shows why the second rule matters: explicit deletes
instead of a cascade do not make a rollback safe (docs/LESSONS.md,
"Never roll back a cascade delete"). On the same run, every kind of edit
had its save made to fail (`LibraryEditorTests.aFailedSaveChangesNothing`),
deletes included, with no crash and nothing changed.

## Commits

`665fa40` adds the core (snapshot, planner, applier, codec, starter file,
M2). The commits after it on the branch add the SwiftData tests, update
the existing tests and write these documents.

## Review findings

Codex and Copilot reviewed the first push, and Codex the second. Every
finding is fixed (the last, a repeated identity inside one backup, in
`ef7b3b6`). One asked for a decision: whether a replace may run after a
safety copy. It was first left to the owner, then decided by default the
safe way (docs/DECISIONS.md, "Replacing the library"): only after a safety
copy keeps every removed word on the device, and refused until safety
copies exist. The code is the same either way: it refuses. Copilot also asked
that the SwiftData probes not run in the required suite if they can only
fail by crashing. They run once on CI so their answers are known; a probe
that crashes is then committed disabled with an issue (docs/LESSONS.md),
and the result recorded above. One did: the S4 rollback probe, issue #19.

## Verified

- **On a Linux machine with Swift 6.4.1** (not the app's toolchain: no
  Xcode, SwiftData or UIKit): the five pure files (`LibrarySnapshot`,
  `LibraryEdit`, `LibraryRules`, `LibraryImport`, `BackupCodec`) compile
  in a scratch package with the project's concurrency settings, and the
  57 tests in `LibraryEditTests`, `LibraryImportTests` and
  `BackupCodecTests` pass. A one-line stand-in replaced
  `String(localized:)`, which Linux lacks.
- **GitHub CI, run 39592594864 on commit `ef7b3b6`** (Xcode 26.6, iPad
  Pro 13-inch (M5) simulator, iOS 26.5): the app built, and 206 of 207
  unit tests passed, including every library suite (`LibraryEditTests`,
  `LibraryImportTests`, `LibraryEditorTests`, `BackupCodecTests`,
  `PhraseLibraryTests`, `StarterPhrasesTests`, `LibraryRulesTests`). The
  one failure was the S4 rollback probe, which crashed as described
  above and is now disabled. The 8 UI tests passed.
- The commit after that run (the disabled probe, and test stores released
  before their folder is removed) is checked by the next CI run, after
  the rebase.
- Each new test's doc comment names the change that would make it fail.
  The per-kind tests run over `LibraryEdit.Kind.allCases`, and the
  fixtures' `sampleEdit` switch has no default, so a new kind of edit
  without a sample does not compile.

## Not verified

- No Mac, simulator or device run by this thread.
- The new message has not been seen on screen. With an unreadable library
  Home shows it under the "Phrases can't be saved right now" line; whether
  both should show is Home's call (thread "Phone layout and word fitting").
- New user-facing sentences (the editor's refusals, the backup refusals,
  the unreadable-library message) are not in `Localizable.xcstrings` until
  Xcode builds the catalog.
- Device checks from the memo, for when export and import are built:
  whether the file picker reads and writes iCloud Drive with no iCloud
  capability (S5), and whether a file sent by AirDrop between one
  person's devices opens Brickson by itself (S6).

## Follow-ups

- Re-enable the S4 rollback probe once when CI moves to a newer Xcode or
  iOS, and record the result on issue #19. *(Whoever moves CI.)*
- Unit tests that open stores written by every shipped schema version,
  starting with V1, so a later build is shown to open what an earlier one
  wrote (repo review, sdlc-19). Needs a store file made by the app on a
  Mac or in CI. *(Next library pull request.)*
- Safety copies, then export (share sheet) and import (file picker in the
  family area), with the privacy policy checked in the same pull request.
  *(Next library pull request.)*
- A launch repair that only adds an emergency category to a damaged store,
  and "Restore starter phrases" as a merge of the bundled file. *(Later.)*
- The Library screen, under Settings (`LibraryView()`, agreed with the
  "Settings and first run" thread). *(Editing screens, step 6.)*
- Home should hold identities, not model objects, across an edit, before
  any delete can run while Home is on screen. *(Phone layout and word
  fitting.)*
- The owner may reverse any of the adopted defaults. `brickson.library`
  follows the app's name until the first backup exists. *(Owner.)*

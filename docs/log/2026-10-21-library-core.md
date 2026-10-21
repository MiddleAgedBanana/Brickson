# The phrase library's core: editing rules, saving and the backup format

*2026-10-21. Pull request #13 (`claude/project-thread-eqfpmu`). Thread
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
  changes, and whether to ask first. No SwiftData involved.
- **`LibraryImport`**: merge adds only and never moves anything; replace
  keeps the current emergency phrases when the backup has none. Neither
  changes a word of the backup.
- **`LibraryEditor`**: reads the store into a snapshot, and writes a plan
  from a context of its own in one save. A failed save changes nothing,
  and `rollback()` is never called. A plan made from an older library is
  refused. A replace that would remove the person's own words is refused
  until safety copies exist.
- **`BackupCodec`**: the `brickson.library` file, version 1. Same library,
  same bytes. A newer version, a damaged file and a file that is not a
  backup are each refused with their own sentence.
- **Starter phrases**: `StarterPhrases.json` is now a file in the backup
  format, with a fixed identity for every category and phrase. Same 5
  categories and 34 phrases, same words, same order.
- **Autosave off**: every path out of `PhraseLibraryLaunch.prepare` turns
  off the main context's autosave, so nothing Home holds can be saved by
  surprise.
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
is a crash, the test says so. The results come from this pull request's
CI run and are filled in below when it finishes.

| # | Question | Test | Result |
|---|---|---|---|
| — | Does SwiftData autosave a new main context, and does SwiftUI's `.modelContainer` leave autosave off once Brickson turns it off? | `aNewMainContextAutosaves`, `attachingTheLibraryToSwiftUIKeepsAutosaveOff` | Pending CI |
| S1 | After a delete saved from another context, does the main context stop seeing it? Does touching a model object the main context still holds crash? | `s1aDeleteSavedElsewhereIsSeenByTheMainContext`, `s1aHeldObjectDeletedElsewhereCanBeTouched` | Pending CI |
| S2 | Does a category's phrase list in the main context drop a phrase deleted elsewhere? (A model-level stand-in for the memo's Home-level check, which needs an editing screen.) | `s2aPhraseDeletedElsewhereLeavesItsCategory` | Pending CI |
| S3 | After SwiftData's own save fails (a store opened read-only), is the main context clean when the failing context was another one? Is the change still pending when it was the main context? | `s3aFailedSaveElsewhereLeavesTheMainContextClean`, `s3aFailedSaveInTheMainContextLeavesTheChangePending` | Pending CI |
| S4 | Does `rollback()` crash after deleting a category and its phrases one by one (no cascade)? Does a `transaction` whose block throws write anything? | `s4RollbackAfterDeletingACategoryAndItsPhrases`, `s4ATransactionThatThrowsWritesNothing` | Pending CI |

If a probe crashes, it is committed disabled with an issue number
(docs/LESSONS.md, "Commit a crash reproduction, disabled"), and the result
is recorded here. Brickson's code depends on none of the answers: it never
holds a model object across an edit, never calls `rollback()`, and never
edits in the main context.

## Commits

`665fa40` adds the core (snapshot, planner, applier, codec, starter file,
M2). The commits after it on the branch add the SwiftData tests, update
the existing tests and write these documents.

## Verified

- **On a Linux machine with Swift 6.4.1** (not the app's toolchain: no
  Xcode, SwiftData or UIKit): the five pure files (`LibrarySnapshot`,
  `LibraryEdit`, `LibraryRules`, `LibraryImport`, `BackupCodec`) compile
  in a scratch package with the project's concurrency settings, and the
  50 tests in `LibraryEditTests`, `LibraryImportTests` and
  `BackupCodecTests` pass. A one-line stand-in replaced
  `String(localized:)`, which Linux lacks.
- **Everything else is checked only by this pull request's GitHub CI
  run**: the app build, the SwiftData tests (`LibraryEditorTests`,
  `PhraseLibraryTests`, `SwiftDataBehaviourTests`), the starter and
  symbol tests, and the UI tests.
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

- Read this pull request's CI run and fill in the S1 to S4 results above.
  *(This thread.)*
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

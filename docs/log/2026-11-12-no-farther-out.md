# No edit takes a damaged library farther out

*2026-11-12. Pull request (`claude/project-thread-vzhdbv`). A cloud
thread, from the Library record's last open follow-up.*

## What changed and why

Every library keeps three or four everyday categories, and four phrases
in a category once it has them (docs/DECISIONS.md, "Three or four
everyday categories" and "Four phrases in every category"). Until now
`LibraryEdit.plan` refused only an edit that crossed one of those bounds.
So a library already outside them, which only a damaged or hand-made
store can be, could be taken farther out: two everyday categories down
to one, six up to seven, an Emergency of three phrases down to one.
CodeRabbit found it on PR #80, and the Library record left it as a
follow-up (`docs/log/2026-11-05-library-screen.md`, *Follow-ups*).

Now an edit may leave a library outside the bounds only where it was
already as far out:

- **Everyday categories.** An add, merge or replace that ends above four
  is refused when it adds categories (`.homeHasRoomForFour`), and a
  delete or replace that ends below three when it removes them
  (`.homeNeedsThree`). A library of two can still gain a category, and
  one of six can still lose one; neither can go the other way.
- **Emergency under four.** A delete, move or replace that leaves an
  Emergency already short of four with fewer phrases still is refused
  (`.emergencyShortOfFour`, new, with its own words). Adding a phrase or
  changing one's words stays open.
- **A rest board under four.** The same for the everyday category Set
  Up chose as Home's rest board (`.restBoardShortOfFour`, new). Home
  shows the board whatever it holds, as it shows Emergency, so its
  empty cells are the same hazard. `LibraryEdit.plan`, `RestoreChoices`
  and `LibraryModel` now take the board (`restBoard:`), and the
  Library's screens pass `SetupRecord.restBoardCategory`.
- **Other short everyday categories are unchanged.** Home dims them,
  and a new category grows from none, so their phrases can still be
  deleted or moved out (the owner's decision of 2026-11-05).

The Library's Delete Phrase and Delete Category already dim from the
same refusal, with its reason beside them, so they show the new reasons
without new code. Inside the bounds nothing changes: each new condition
is the old one whenever the library starts inside them. A backup that
would take a library farther out is refused whole, as one that crosses
is (invariant 7).

**The test fixtures moved.** The shared fixture `LibraryFixtures.library`
has two everyday categories and an Emergency of two phrases, so several
tests had deleted a category or an Emergency phrase from it, which is
now refused. Deleting a category now uses `libraryOfFour` (two more
categories, Friends and Trips), each kind's sample edit runs in
`sampleLibrary(kind)`, and the replaces in the import and backup tests
keep at least two everyday categories. No test was weakened: each still
checks the same behaviour, on a library the rule lets it change.

## Commits

On `claude/project-thread-vzhdbv`; the pull request lists them.

## Verified

Made in a cloud session with no route to a Mac this time: nothing was
built with Xcode. On Linux (Swift 6.4.2), the pure types and their Swift
Testing tests in a throwaway package, with stand-ins for
`String(localized:)` and `HomeWordRoom` (as in
`docs/log/2026-11-05-four-phrases.md`):

- `LibraryEditTests`, `LibraryImportTests`, `BackupCodecTests`,
  `EmergencyRepairTests`, and copies of `RestoreChoicesTests`' pure
  tests and of `LibraryRulesTests` (its SF Symbol check, which needs
  UIKit, reduced to a stand-in): 114 tests passed.

Each new test, and the change that makes it fail (each mutation run on
Linux):

- `aLibraryOutsideTheBoundsGoesNoFartherOut`: putting back the old
  "only a crossing" conditions for everyday categories failed it with 6
  issues.
- `emergencyUnderFourGoesNoFartherUnder`: refusing an Emergency delete
  only from four or more, as before, failed it with 3 issues.
- `aShortRestBoardGoesNoFartherUnder`: dropping the rest board check
  failed it with 3 issues.
- `LibraryRulesTests`' message test now includes the two new reasons,
  so it fails if either has no words.

`scripts/test-docs.py`, `scripts/test-hooks.py` and
`scripts/test-privacy.py` passed, and `scripts/privacy-check.py
--outgoing --no-list` found nothing (the private list was not checked:
a cloud thread has none). The String Catalog has the two new strings,
added in Xcode's own format; a unit run on CI checks it against the code.

## Not verified

- Everything that needs Xcode: the app and its tests building with
  warnings as errors, and the SwiftData tests whose fixtures changed
  (`LibraryEditorTests`, `LibraryModelTests`, `BackupExportImportTests`,
  `SwiftDataBehaviourTests`, `LaunchOptionsTests`), and the SF Symbol
  check in `LibraryRulesTests`.
  CI runs them; until it passes, the change is untested.
- How the Library's screens look with the new reasons beside a dimmed
  Delete Phrase or Delete Category: no UI test makes a damaged library.

## Follow-ups

- **A rest board brought back short by a restore** is still not
  refused: the board was not in the library before the restore, so the
  rule has nothing to compare (docs/DECISIONS.md, "Four phrases in every
  category", *Open: a rest board with fewer than four*). *(a library
  thread, if the owner wants it closed before Q2's decision)*

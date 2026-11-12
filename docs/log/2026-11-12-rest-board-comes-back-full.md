# A deleted rest board comes back with four phrases or not at all

*2026-11-12. Pull request (`claude/project-thread-uu5bq0`). A cloud
thread, from the last follow-up of
[`2026-11-12-no-farther-out.md`](2026-11-12-no-farther-out.md).*

## What changed and why

Home shows the rest board's category whatever it holds, so a board with
fewer than four phrases leaves empty cells where a resting look meets
Clear or Put Back while typing, and a phrase that speaks while browsing
(docs/DECISIONS.md, "Four phrases in every category", *Open: a rest
board with fewer than four*). Set Up offers no short board, and since
the previous pull request no edit takes a board farther under four. One
way was left, found by that pull request and left as its follow-up:

1. A family chooses a category as the rest board in Set Up Step by Step.
2. They delete that category. The choice stays stored
   (`SetupRecord.restBoardCategory`), and Home shows every category
   while no category has that identity.
3. They restore an older backup that held the category, under the same
   identity, with fewer than four phrases. It comes back as the board,
   short.

`LibraryEdit.plan` could not see this: its rule for the board compared
the board before and after an edit, and before the restore the board
was not in the library. Now a category that is not an everyday category
of the library before an edit, comes out of it with the board's
identity and has fewer than four phrases is refused with a new reason,
`LibraryEditRejection.restBoardComesBackShort(name)`. Only Add and
Replace (a merge or a replace) can bring a category back under an
identity it had; a category the family adds gets a new random one.

The Restore question already dims Add to My Phrases and Replace My
Phrases with the reason beside each (`RestoreChoices`), so the new
reason shows there without new view code. Its words name the category,
because the family cannot see it anywhere in the library, and say what
to do: "This backup brings back “Name” with fewer than four phrases, and
Home's rest board is set to show it, so Home would show it with empty
spaces. First, in Set Up Step by Step, answer “Which phrases does Home
show?” with Every Category or another category." That question already
shows Every Category as chosen while the board's category is missing,
and choosing it again saves it, so the stored choice is cleared and the
restore then runs. The backup is refused whole, never trimmed
(invariant 7), as one that crosses a bound is.

Nothing else changes. A backup that brings the board back with four or
more phrases still makes it the board again, and the same backup with
no board chosen, or another one, brings the category back as any short
category comes, dimmed on Home until it has four. A short rest board can
now come only from a damaged or hand-made store, as a short Emergency
can, so docs/ROADMAP.md, *The quality bar*, Q2, no longer lists a
restore as a way to it.

## Why refuse, not clear the choice

Two other answers were weighed and not taken:

- **Clear the stored choice when the board's category is deleted.**
  That writes the setup record in the same step as the library, two
  stores that cannot be saved together, and it changes what a restore
  with four or more phrases does today (bring the board back). The
  delete question already says Home will show every category, which
  stays true.
- **Let Home skip a short board.** Home would then switch between the
  board's sizes and every category's as the board's phrase count
  crossed four, which moves controls (invariant 8).

Refusing keeps the rule of the previous pull request: the library never
moves farther from what Home can show safely, and the family is told how
to make the restore possible.

## Commits

On `claude/project-thread-uu5bq0`; the pull request lists them.

## Verified

Made in a cloud session; nothing was built with Xcode. On Linux (Swift
6.4.2), the pure types and their Swift Testing tests in a throwaway
package, with stand-ins for `String(localized:)`, `HomeLayout`'s two
constants and `HomeWordRoom` (as in
[`2026-11-05-four-phrases.md`](2026-11-05-four-phrases.md)):
`LibraryEditTests`, `LibraryImportTests`, `RestoreChoicesTests` and
`LibraryRulesTests` without its SF Symbol check, which needs UIKit:
79 tests passed. Before the fix, with only the new reason added, the two
new tests failed with 6 issues, which is the gap reproduced.

Each new test, and the change that makes it fail:

- `LibraryEditTests.aRestBoardComesBackWithFourOrNotAtAll`: removing the
  new check failed it with 4 issues (a merge and a replace bringing the
  board back with none or three). Refusing every new short category,
  not only the board's, failed it (a merge with no board chosen was
  refused), and many existing import tests with it.
- `RestoreChoicesTests.aBackupThatBringsTheRestBoardBackShortIsRefusedWhole`:
  removing the check failed it with 2 issues (Add and Replace offered);
  refusing every new short category failed it (Add refused with no
  board chosen).
- `LibraryRulesTests` and `RestoreChoicesTests.everyRefusalHasItsOwnWords`
  include the new reason, so each fails if its words are empty or
  repeat another reason's, and the first fails if they stop naming the
  category.

`scripts/test-docs.py`, `scripts/test-hooks.py` and
`scripts/test-privacy.py` passed, and `scripts/privacy-check.py
--outgoing --no-list` found nothing (the private list was not checked:
a cloud thread has none). The String Catalog has the new string, added
in Xcode's own format; a unit run on CI checks it against the code.

## Not verified

- Everything that needs Xcode: the app and its tests building with
  warnings as errors, the whole unit suite, and the SF Symbol check.
  CI runs them; until it passes, the change is untested.
- How the Restore question looks with the new reason beside both
  choices, at large text sizes especially: no UI test deletes a board's
  category and restores a backup.

## Follow-ups

None from this change. The short rest board that a damaged or
hand-made store can still hold stays on Q2's list for the owner's
decision after the Snap to Item check (Q12), with the short Emergency.

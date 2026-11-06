# Phrases named like Home's controls, and what Q2 still counts

*2026-11-05. Pull request (`claude/project-thread-v29fi3`). The thread
"Flag phrases named like Home's controls", the Library record's second
follow-up, on the owner's Mac.*

## What changed and why

A family can write a phrase another control on Home also answers to:
"Help", which Get Attention answers to, "Stop.", "Again!", or "Okay."
beside "Okay?". With Voice Control, saying that name then matches two
buttons, and until now nothing told the family why.

- **The words are saved as written, with a note** (docs/DECISIONS.md,
  "Phrases named like Home's controls"; work file
  [`work/phrases-named-like-controls.md`](../work/phrases-named-like-controls.md)).
  The line kept for what Save did adds: "Another button on Home answers
  to these words too, so Voice Control may ask which one is meant." It
  shows on New Phrase, Edit Phrase, New Category and Rename Category,
  and a restore that brings such a name says so too. Warn, not refuse,
  follows the owner's answer for wide words the same day and "Home's
  scan order and names", which left this to the editing thread.
- **`HomeControlNames.collisions` is now used.** It had waited for this:
  `LibrarySnapshot.sharesAName` and `.sharedNames` ask it about the
  controls showing with a phrase's category, and
  `LibraryPlan.bringsASharedName` says whether a restore adds one.
- **The keyboard goes when a note shows.** Seen in the running app, not
  in any test: on the iPhone 17 at AX5 the keyboard covered Save and the
  whole line, so the note could not be read. Save now puts the keyboard
  away when its line carries a note.
- **An exception to invariant 10, proposed to the owner.** A phrase
  Voice Control hears as "Yes", "No", "Emergency", "Get Attention" or
  "Help" ("Yes." and "help!" count, "Yes, please." does not) is expected
  to cost a Voice Control user a second command for that control. The
  app already allowed it, silently; it now says so, and docs/ROADMAP.md,
  Q24, lists it for the owner to accept or refuse. Codex's review was
  right that the thread could not adopt it, so it is proposed, with a
  recommendation to refuse those five names.
- **Also fixed on the way:** the phrase and name fields had no
  description for Apple's audit while focused (they now carry their
  label), and a category's line and a restore's now clear with the next
  change that saves, so "Added “Water”." and its note cannot outlive a
  rename.

Three docs follow-ups from pull request #81 came with it:

- **Q2 counts what is out of reach.** Q2 closes a hazard only when it is
  gone or accepted, and an Emergency already short of four phrases and a
  library with fewer than three everyday categories are neither: no edit
  makes one. Q2, R0's release gate, docs/HANDOFF.md's step 1
  and docs/DEVICE-CHECKS.md, F2, now list them, with the short rest
  board below, for the owner's decision after the Snap to Item check:
  seven open, where they said four.
- **The short rest board is measured.** "Four phrases in every
  category", *Not covered*, named it unscored, and invariant 10 asks for
  a hazard to be named, measured and recorded. It is now *Open: a rest
  board with fewer than four*:
  `LateStageProfileTests.aShortBoardsEmptyCellsMeetOnlyClearPutBackAndPhrases`
  scores 448 windows and pins two findings, as strict known issues.
  Review also found it is not quite out of reach: a chosen category
  deleted and later restored from an older backup that held it short
  comes back as the board, because the choice stays stored.
- **AGENTS.md, *Build and test*:** "Neither works in the owner's own
  checkout" read as "doesn't function there"; it now says "Use neither".

Two things only the owner's Mac could close came with it, as the owner
asked of threads there (2026-11-05):

- **The Release build** for a device compiled unsigned with no warnings
  (`scripts/test.sh device -configuration Release`), which docs/HANDOFF.md
  said had not been done since warnings became errors.
- **The rollback probe of issue #19**, run once with the test enabled
  and then disabled again: it passed. Before, it crashed on Xcode 26.6
  with iOS 26.5. It stays disabled and the rule stands, because Brickson
  also runs on iOS 26.

Stale words corrected on the way: F2 said editing was not built.

## Commits

On `claude/project-thread-v29fi3`; the pull request lists them.

## Verified

Made and run on the owner's Mac, with Xcode 27.2 (27B52), on the iPad
Pro 13-inch (M5) and iPhone 17 simulators, iOS 27.2.

- **`scripts/test.sh unit`, on the final code, iPad:** 948 tests, 937
  passed, none failed, 10 expected failures (strict known issues, the
  new sweep's among them) and the skip of issue #19's crash
  reproduction. The String Catalog is up to date.
- **`scripts/test.sh device -configuration Release`, final code:**
  compiled unsigned with no warnings.
- **`scripts/test.sh ui`, on the final code, run whole on both:** iPad,
  72 tests, 69 passed, 2 skipped, 1 failed; iPhone, 72 tests, 64 passed,
  6 skipped, 2 failed. On both, one failure is
  `LaunchTests.testLargestTextKeepsQuickControlWordsVisible`, whose four
  waits for "Speaking" to end timed out, the failure this Mac's simulators
  have shown since 2026-10-25 (docs/HANDOFF.md, *Known gaps*). It has no
  connection to this change, and it passes on CI. The iPhone's other
  failure is `LibraryTests.testCategoriesStayBetweenThreeAndFour`: after
  Save on New Category the app did not report idle for over a minute, so
  XCTest waited past Settings' 90-second reset and the screen was gone.
  Run five times each on the iPhone, this branch and unchanged `main`
  did the same: one failed and one took twice as long, in neighbouring
  runs, the others passing in 62 seconds. So it comes from `main`, and
  its cause is not known (docs/HANDOFF.md, *Known gaps*). The previous
  whole run, one small change earlier, had neither stall nor failure. A
  first run was cut off during the iPhone's turn when the desktop app
  stopped the idle session (AGENTS.md, *Gotchas*), so these started again
  from the top.
- **In the running app,** through a temporary UI test not committed:
  New Phrase and Edit Phrase with the note, at the default size and AX5,
  light and dark, in portrait, on both simulators, each screen captured
  and read, with Apple's audit on each. Its first run, with the full
  software keyboard up as the note appeared, found the keyboard covering
  the note on the iPhone at AX5 and the focused field with no
  description, and every contrast finding of the audit was on text
  behind the keyboard. Those captures were overwritten by the next run,
  so this rests on having read them. Both are fixed, and the audit then
  passed on every screen, the keyboard gone. At AX5 on the iPhone the
  line starts at the screen's foot, above the part Settings keeps: Edit
  Phrase shows "Saved. Another", New Phrase "Added “Stop.” to", and the
  note's words are a scroll away.
- **The sweep** takes about 20 seconds on its own on this Mac, in a test
  build, so about what the Emergency sweep adds on CI.
- **Four independent reviews before the first push** reported 21
  findings; a second check confirmed 14 and refuted 7. Fixed: a line that
  outlived its truth after a rename, the sweep pairing the board and the
  count, a test that could not fail, and words that overstated or
  understated what was measured. Not fixed here, and recorded below: a
  rest board can come back short through one rare restore.

Each new test but the sweep failed on this Mac for the change it names:

- `aPhraseNamedLikeAHomeControlSharesAName`: leaving the other names
  (Help, Repeat, Stop Alert) out of the check.
- `aPhraseWithOtherWordsSharesNoName`: matching part of a phrase.
- `aPhraseNamedLikeACategoryButtonSharesAName`: leaving the category row
  out of the check.
- `phrasesSaidAlikeShareANameOnlyWhereTheyShowTogether`: comparing every
  category's phrases at once.
- `anotherPhrasesNameIsNotThisOnes`: reporting any name shared on the
  screen for the saved words.
- `aCategoryNamedLikeAPhraseSharesAName`: counting Emergency's category
  as a button.
- `theStarterLibrarySharesNoNames`: a starter phrase "Yes."
- `theWordsAreKeptAsWritten`: refusing a phrase named like a control.
- `aPlanSaysWhetherItBringsASharedName`: counting names shared before
  the plan, and a restore's line that never adds the note.
- `aSavedLineSaysWhatSaveDidThenEachNote`: running the sentences
  together.
- `editPhrasesLineKeepsRoomForBothNotes`: leaving out the lines with the
  note.
- `aChangeThatSavesClearsTheLinesOfEarlierChanges`: not clearing the
  line.
- `LibraryTests.testAPhraseNamedLikeAControlIsSavedWithANote`, on the
  iPad, once for each path: leaving the keyboard up on a phrase's note,
  on a wide word's and on Rename's. Its audit of the focused field failed
  before the field had its label.
- `aShortBoardsEmptyCellsMeetOnlyClearPutBackAndPhrases` holds strict
  known issues, so it fails once placement removes either finding, and
  fails on any other finding; its counts changed when the pairing did.

## Not verified

- What Voice Control does with two matching names: it is not available
  on a simulator, and Apple's pages do not say. Device check I2, step 4.
- The notes on New Category and the Restore question on screen: the
  check and the words are unit-tested. The phrase editor's note and
  Rename's are UI-tested.
- The note at AX5 and in dark mode: checked by a temporary UI test not
  committed. The committed test runs at the default size, light, in
  portrait.
- The rest of the note at AX5 on the iPhone: no capture shows it after
  scrolling.
- The Library's editors in landscape, or in a resized iPad window.
- The whole UI suite on this Mac with no failure at all: the two
  failures above, one of them a test that passes on CI, whose Xcode and
  iOS were one release behind this Mac's on this pull request.
- The rollback probe on a store on disk, on a device, or on iOS 26 with
  this Xcode.

## Follow-ups

- **The owner:** decide the proposed exception to invariant 10
  (docs/DECISIONS.md, "Phrases named like Home's controls"); the three
  out-of-reach hazards of Q2, after the Snap to Item check.
- **Device check I2, step 4.** *(the owner)*
- **Post the rollback result on issue #19,** which the test's comment
  asks for. *(the owner, or an agent the owner lets write there)*
- **Clear a rest board's choice when its category is deleted,** so a
  later restore cannot bring it back short; it needs a save with a
  failure test of its own. *(a library or Settings thread)*
- **Save and its line behind the keyboard** on a phone at the largest
  text sizes, for a plain "Saved." or "Added" (docs/HANDOFF.md, *Known
  gaps*). *(the next library thread)*
- **The stall after New Category's Save on this Mac's iPhone simulator,**
  which `main` shows too (docs/HANDOFF.md, *Known gaps*). *(a Mac
  thread)*
- **Next for the Library:** the Figma drawings, then the emergency
  repair record's list, starting with stores from every schema version
  ([`log/2026-11-05-library-screen.md`](2026-11-05-library-screen.md),
  *Follow-ups*). *(library threads)*

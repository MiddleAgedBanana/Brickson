# Refuse a phrase with the name of a control one activation away

*2026-11-06. Pull request (`claude/project-thread-v29fi3`). The thread
"Flag phrases named like Home's controls", on the owner's Mac, after
pull request #82 merged.*

## What changed and why

Pull request #82 saved a phrase named like a Home control with a note.
For Yes, No, Emergency and Get Attention that would have been an
exception to invariant 10, which keeps them one activation away, and
Codex's review was right that a thread could not adopt it. Asked, the
owner said to make the best choice for the people using Brickson and
their caregivers, and the thread's recommendation stood (docs/DECISIONS.md,
"Phrases named like Home's controls"). #82 merged while this was being
built, so it comes here.

- **The editor refuses those names.** A phrase Voice Control hears as
  "Yes", "No", "Emergency", "Get Attention" or "Help", whole, with case,
  punctuation and symbols dropped ("Yes." and "help!" count, "Yes,
  please." and "Y E S" do not), is not saved, and the line says: "A button on Home
  that must always be one step away already answers to this. Add another
  word, such as “Help me.” or “Yes, please.”"
  (`LibraryRules.checkSafetyControlName`,
  `LibraryEditRejection.phraseNamedLikeASafetyControl`,
  `HomeControlNames.oneActivationAway`).
- **Only an edit that gives a phrase such a name is refused.** A backup's
  words come in unchanged (invariant 7), which is the one exception to
  invariant 10 left, chosen with the refusal. A phrase that has such a
  name can be moved, deleted, changed, or edited and stay what it was.
- **Other names keep #82's note,** such as "Stop", "Again" or "Okay."
  beside "Okay?".
- **The keyboard goes on a refusal too,** on the phrase and name editors
  and for a category name too wide for Home, as it goes for a note: on a
  phone at the largest text sizes it covers the line.
- **CodeRabbit's reviews:** of #82, the short-board sweep said every pair
  of category cell and count comes round, and nothing held it; it now
  checks that. Of this pull request, the check dropped word breaks, so
  "Y E S" was refused as "Yes"; word breaks now count, and "GetAttention"
  run together is still the control's name. Its "Docstring Coverage"
  check is not a rule here, so nothing changed for it.
- Device check I2's step 4 changed, because "Help" and "Yes" can no
  longer be typed: it adds "Again", and "Help" and "Yes" through a
  backup. It also measures a restored category named "Yes", and it fails
  if "Help me." or "Yes, please." costs a second command, because the
  refusal tells families to write them. The
  README, the accessibility page and docs/ACCESSIBILITY.md say what the
  editor refuses and what a restore keeps.

## Commits

On `claude/project-thread-v29fi3`; the pull request lists them. `main`
was merged in, not rebased (AGENTS.md, *Workflow rules*).

## Verified

On the owner's Mac, Xcode 27.2 (27B52), iPad Pro 13-inch (M5) and iPhone
17 simulators, iOS 27.2, on the final code (only documents and two
comments changed after):

- **`scripts/test.sh unit`, iPad:** 950 tests, 939 passed, none failed,
  10 expected failures (strict known issues) and issue #19's skip. The
  String Catalog is up to date.
- **`scripts/test.sh device -configuration Release`:** compiled unsigned
  with no warnings.
- **`scripts/test.sh ui`, run whole on both:** iPad, 72 tests, 69 passed,
  2 skipped, 1 failed; iPhone, 72 tests, 65 passed, 6 skipped, 1 failed.
  On both, the one failure is
  `LaunchTests.testLargestTextKeepsQuickControlWordsVisible`, the
  "Speaking" wait this Mac's simulators have failed since 2026-10-25
  (docs/HANDOFF.md, *Known gaps*). It passes on CI. The stall after New
  Category's Save did not come in this run.
- **In the running app,** through a temporary UI test not committed, on
  the final code: the refusal on New Phrase and Edit Phrase, and the
  older refusal of a category named like a control on Rename Category,
  at the default size and AX5, light and dark, in portrait, on
  both simulators, with Apple's audit on each of the 24 screens, which
  passed, and the keyboard gone each time. Each screen was captured, and
  a sample read. At AX5 on the iPhone only the start of the line shows,
  above the part of the screen Settings keeps, and the rest takes a
  scroll, which an earlier run of the test captured.
- **Three independent reviews before this pull request opened:** 14
  findings, 9 confirmed by a second check, each fixed here. The verifier
  then found words that went further than their evidence and one test
  not yet shown failing; those are fixed here too.
- **A last read-only check,** of the pull request's description, the
  documents, the rule and private details, by four independent readers
  with two skeptics on each finding: 13 findings, 5 of them standing,
  all about words, none about what the app does. It traced every way
  typed words become a phrase, and each goes through the check. The five
  are fixed here: device check I2 could not show what it promised about
  longer phrases, and had no step for a category. So are the smaller
  ones a skeptic agreed with.

Each new test, and the change that made it fail on this Mac:

- `theFourControlsKeepTheirNames`: leaving Help out of the names.
- `theWordsAreKeptAsWritten`: dropping word breaks ("Y E S"), seen failing
  before the fix.
- `aPhraseThatAlreadyHasSuchANameCanStillBeChanged`: refusing an edit
  that keeps the name a phrase already has, run on its own.
- `LibraryTests.testAPhraseNamedLikeAControlIsSavedWithANote`, on the
  iPad: leaving the keyboard up on the phrase editor's refusal, and on
  Rename's. `testCategoriesStayBetweenThreeAndFour`: leaving it up on
  New Category's too-wide word.
- `aShortBoardsEmptyCellsMeetOnlyClearPutBackAndPhrases`: going back to
  the pairing that moved the cell and the count together.

The other changed tests keep their earlier proofs, in the log of #82.

## Not verified

- What Voice Control does with two matching names, and so the size of
  the one exception left, which invariant 10 asks to be measured: not
  available on a simulator. Device check I2, step 4, which also checks
  that "Help me." and "Yes, please." take no second command.
- What Full Keyboard Access's type-to-find does with two matches.
- Which near spellings Voice Control hears as a name. A zero-width
  joiner or a Hangul filler inside "Yes", or a look-alike letter from
  another alphabet, gets past the check. Nobody types those by accident,
  and whether Voice Control hears them as "Yes" is not known, so they
  are left as they are.
- The Library's editors in landscape, or in a resized iPad window.
- A whole UI run on this Mac with no failure: see above.
- All of this on a real device.

## Follow-ups

- **Device check I2, step 4.** *(the owner)*
- **Clear a rest board's choice when its category is deleted,** and Save
  and a plain line behind the keyboard at the largest text: both in
  [`log/2026-11-05-phrases-named-like-controls.md`](2026-11-05-phrases-named-like-controls.md),
  *Follow-ups*. *(library threads)*

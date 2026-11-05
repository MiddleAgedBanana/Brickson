# Four phrases in every category

*2026-11-05. Pull request (`claude/project-thread-hwa1vz`). The thread
"Fix Home's short-category dwell hazard", from the Library record's
first follow-up.*

## What changed and why

The Library (PR #80) lets a family make a category with fewer phrases
than Home's grid has columns, and a new one starts with none. Scored on
the layout engine's frames, a look resting on its top row's empty cells
met Clear or Put Back while typing, and, while browsing, the category
above, after which the phrase now under the look spoke. Two independent
reviews looked for a placement that removes it and found none: a new
category has no phrases, so its grid's top row borders the controls
above it with nothing in it whatever the order of the cells, and a decoy
is forbidden.

So Home never shows such a category (docs/DECISIONS.md, "Four phrases in
every category"; work file [`work/four-phrases.md`](../work/four-phrases.md)):

- **Home dims an everyday category with fewer than four phrases** in its
  cell, as the rest board dims its other categories, with a VoiceOver
  hint, and never shows it, even where it was chosen before
  (`CategorySelection.isOffered`, `.isDimmed`, `.resolve`). Four is the
  most columns any grid has (`HomeLayout.mostColumns`), and a test fails
  if a grid ever has more.
- **A category keeps four once it has them.** `LibraryEdit.plan` refuses
  a delete, move or replace that takes a category, or Emergency, from
  four or more phrases to fewer, or that leaves Home no everyday category
  with four (`LibraryEditRejection.categoryKeepsFour`,
  `.emergencyKeepsFour`, `.homeNeedsAFullCategory`). As with "Three or
  four everyday categories", only a crossing is refused, so a new
  category grows from none and a library already under four can still
  be edited. Delete Phrase dims with the reason beside it.
- **The Library says how many more** on a category's screen
  (`LibraryRules.shortNote`), and Set Up's rest-board question dims a
  category with fewer than four, with a line saying why. The line shows
  wherever any category is short, whatever is chosen
  (`CategorySelection.restBoardChoices`): in the first version it showed
  only while something was dimmed, so where the only short category was
  the board already chosen, choosing another answer added it and moved
  the choices (Codex's review).
- **Emergency is never dimmed** (invariant 2). Only a library already
  short of four Emergency phrases, which no edit can now make, shows its
  empty cells: scored and pinned as two strict known issues
  (*Open: Emergency with fewer than four*).
- **AGENTS.md, *Workflow rules*:** a new rule, "Use the tools you
  have": read your own tool list for build, simulator and device access
  at the start of a session, and never conclude from a handoff note that
  you cannot build (asked for by the owner on 2026-11-05, after threads
  had not noticed the simulator and build tools a cloud session can
  reach on the owner's Mac).

The owner was asked the same day whether four is the floor or the hazard
is accepted, with the floor recommended, and chose the floor ("Yes, four
is the floor").

## Commits

On `claude/project-thread-hwa1vz`; the pull request lists them.

## Verified

Made in a cloud session, which cannot build the iOS app: untested until
CI runs it. On Linux (Swift 6.4.1, the pure types and their Swift
Testing tests in a throwaway package, with stand-ins for
`String(localized:)`):

- `LibraryEditTests`, `LibraryRulesTests` (without its SF Symbol check)
  and `HomeChainsTests`: 78 tests passed.
- `HomeLayoutEngineTests.aDimmedShortCategoryNeverShowsItsEmptyCells`,
  `.aShortEmergencysEmptyCellsMeetOnlyClearPutBackAndPhrases` (with its
  two known issues: 308 typing and 667 browsing findings) and
  `.noGridIsWiderThanTheMostColumns` passed, in about 58 seconds
  together, unoptimised.

Each new test, and the change that makes it fail:

- `LibraryEditTests` (*Four phrases in every category*): removing the
  `keepsFour` call from `LibraryEdit.plan` failed
  `anEverydayCategoryWithFourKeepsFour`, `emergencyWithFourKeepsFour`
  and `homeKeepsOneCategoryToOffer` (run on Linux).
  `theFloorIsTheWidestGridsColumns` fails if the floor and the grid's
  columns part.
- `HomeChainsTests.aDimmedCategoryDoesNothingAndNeverShows` and
  `HomeLayoutEngineTests.aDimmedShortCategoryNeverShowsItsEmptyCells`:
  ignoring `Frames.dimmed` in `HomeChains.map` failed both (1,648
  unexpected findings in the sweep; run on Linux).
- `HomeChainsTests.aShortCategoryShowsOnlyItsTilesAndLeavesItsTopRowEmptyCells`:
  fails if `phraseCounts` stops limiting the tiles or the top row's
  empty cells stop being resting places.
- `HomeLayoutEngineTests.aShortEmergencysEmptyCellsMeetOnlyClearPutBackAndPhrases`:
  strict known issues, so it fails once placement removes either
  finding, and fails on any other finding.
- `HomeLayoutEngineTests.noGridIsWiderThanTheMostColumns`: fails if a
  layout's grid gets a fifth column.
- `CategorySelectionTests`: `aCategoryWithTooFewPhrasesIsNeverShown`
  fails if `resolve` stops skipping a short category;
  `offeringNoEverydayCategoryHomeShowsEmergency` if it shows a dimmed
  one instead of Emergency; `aLibraryOfferingNothingFallsBackToEveryCategory`
  if a damaged library shows nothing;
  `aCategoryIsDimmedWithTooFewPhrasesOrOffTheRestBoard` if `isDimmed`
  changes; `theRestBoardShowsEvenWithTooFewPhrases` if a board is
  skipped; `setUpSaysWhyAShortCategoryIsDimmedWhateverIsChosen` if Set
  Up's line shows for some answers and not others, as it did when it
  followed what was dimmed. These use SwiftData, so only CI runs them.
- `LibraryTests.testCategoriesStayBetweenThreeAndFour` (UI): fails if a
  new category with no phrases is not dimmed on Home, or its screen does
  not say "Add 4 more."

The String Catalog has the seven new strings, written in Xcode's own
format; a unit run on CI checks it against the code.

## Not verified

- Nothing was built for iOS here: the SwiftUI changes (`HomeView`,
  `GuidedSetupView`, `LibraryCategoryView`, `LibraryEditors`) and the
  SwiftData tests run only on CI or a Mac.
- Whether Snap to Item stops on a dimmed category, which the chain
  model assumes as it does for typing's dimmed controls:
  docs/DEVICE-CHECKS.md, B2 step 3 and I8.
- How Apple's accessibility audit treats the new hint on a dimmed
  category: no UI test audits Home with a short category.
- What the extra sweeps add to the unit job's time on CI: about the
  same as the test they replace, judged from the counts of chains.

## Follow-ups

- **Device check B2 step 3.** *(the owner)*
- **A library already outside the bounds** can still be taken farther
  out by an edit, for phrases as for categories (the Library record's
  follow-up). *(a library thread)*

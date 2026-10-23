# Emergency gets its starter phrases back in a damaged library

*2026-10-23. Pull request #37 (`claude/project-thread-0k2wbl`). Thread
"Library follow-ups", the first library pull request after PR #14.*

## What changed and why

Home's Emergency control opens the library's emergency category. No edit
can remove that category or its last phrase with words (docs/DECISIONS.md,
"The emergency category is always there"), but a damaged store still
could: a file changed outside the app, say, or a future migration gone
wrong. Emergency was then disabled, or opened onto nothing to say
(invariant 2). The editing memo's R4, a launch repair that only adds, was
recorded as needed and not built.

- **`EmergencyRepair`** (plain values, no SwiftData) says what a library
  needs: nothing when the emergency category Home opens (the first one)
  has a phrase with words and an identity of its own; otherwise the
  bundled starter emergency phrases, either as a new emergency category
  after all the others or after the emergency category's own phrases,
  and a new identity for an emergency category that an earlier category
  shares its identity with. Starter identities are kept
  where free, so the additions count as untouched starter phrases, not
  the person's words, and a taken one is replaced. An empty library is
  left to the seeder, and a second emergency category is left alone.
- **A new identity where an earlier category shares it** (Codex's review
  of this pull request). Home remembers the emergency category by
  identity and shows the first category with it
  (`CategorySelection.resolve`), so in such a store Emergency opened the
  earlier category's phrases. The emergency category now gets a new
  identity, which nobody sees. Only categories with the same sort order
  and name are ordered by identity, so against those (the repair is
  given the stored sort orders) the new one must sort as the old one
  did, and another emergency category with the same identity must stay
  after it; the repair tries 64 and keeps the old identity if none fits.
  A later category sharing it changes nothing for Emergency (Home finds
  the first) and is left alone. Codex's second review found the first
  version compared against every category with the same name, sort
  order or not, so a same-named category with the largest identity
  could leave Emergency broken; that is the rule above.
- **`PhraseLibraryRepairer`** reads the store and writes what the repair
  says in a context of its own, saved once. Otherwise it inserts: no
  stored name, phrase or flag changes, and new sort orders come after the
  largest one there.
- **No room at the end** (Codex's second review). A hand-edited store
  can leave no room after its last sort order. The first version let the
  additions tie at `Int.max`, where the tie falls to name or words and
  they could sort before the person's items, and recorded that as an
  exception. Now the items beside the additions are renumbered 0, 1, 2 in
  the order they are shown, which shows them exactly as before, and the
  additions follow (`EmergencyRepair.sortOrders(adding:after:)`). A store
  with room is never renumbered.
- **Launch** (`PhraseLibraryLaunch`): a store that opens with categories
  is now repaired when it needs it. If the repair cannot be saved (a full
  disk, say), the store is left as it was for the next launch, and the app
  speaks from a copy in memory holding the person's whole library with
  the repair made, with the existing "Phrases can't be saved right now"
  line. Before, the choice would have been the starter library
  alone, hiding the person's words. If the repair cannot read the store,
  the saved phrases are reported as unreadable, exactly as when the seeder
  cannot read them.
- **The seeder inserts instead of writing by identity.** It fills only a
  store with no categories, so nothing changes for the starter library.
  The copy in memory above can come from a damaged library whose
  identities repeat, and writing by identity (`StoredLibrary.write`) would
  merge two such categories into one, showing one name in place of the
  other; inserting keeps them item for item.
- Nothing on Home changed, and no sentence was added: the family sees
  Emergency working again. The log says the repair ran, without words.

The decision is recorded in docs/DECISIONS.md, "The emergency category is
always there", as a default adopted on 2026-10-23, reversible.

## Commits

See the pull request; the branch was cut from `main` at `f34e8ae` (PR #33).

## Verified

- **Reviewed before pushing** by three independent reviewers (correctness
  and invariants, whether CI will pass, the written rules and docs). One
  built a stand-in that behaves like SwiftData where these tests depend on
  it and ran the new store tests against it. Their findings are fixed
  here: two stores the repair could not help were named rather than
  claimed (both since fixed, after Codex's reviews), both halves of the
  read check are tested, and "Every save is explicit" now covers the
  launch's own writes. A second independent review of the new identity
  (correctness, CI, records, each finding checked by two more reviewers)
  found the same over-strict rule Codex did, and three stale sentences,
  all fixed here.
- **On a Linux machine with Swift 6.4.1** (not the app's toolchain: no
  Xcode, SwiftData or UIKit), in a throwaway package with the project's
  concurrency settings: `EmergencyRepair` and its 23 tests
  (`EmergencyRepairTests`, 31 cases with arguments) pass with the
  existing `LibraryEditTests` and `BackupCodecTests`, 92 tests in all. A
  one-line stand-in replaced `String(localized:)`.
- **Each new pure test fails when its rule is broken.** Thirteen mutations
  of `EmergencyRepair` were run there, each caught: repairing an empty
  library (`anEmptyLibraryIsLeftToTheSeeder`); repairing a working one
  (`aLibraryWhoseEmergencyHasWordsNeedsNothing`,
  `aSecondEmergencyCategoryNeedsNothingWhenTheFirstHasWords`); looking at
  the last emergency category instead of the first
  (`theEmergencyCategoryHomeOpensIsTheOneRepaired`); putting the new
  category first (`aMissingEmergencyCategoryIsAddedAfterTheOthers`, which
  then crashes the run); always making new identities
  (`whatTheRepairAddsIsNotThePersonsWords` and four more); reusing taken
  ones (`takenIdentitiesAreReplacedWithNewOnes` and two more); replacing
  or preceding blank phrases instead of following them, or counting a
  blank phrase as words
  (`anEmergencyCategoryWithOnlyBlankTextGetsTheStarterPhrasesAfterIt`);
  adding blank starter text (`withoutStarterEmergencyPhrasesNothingIsAdded`);
  refusing a library whose identities repeat
  (`aLibraryWithRepeatedIdentitiesIsStillRepaired`); and normalizing
  words (`theLibrarysWordsComeThroughByteForByte`).
- **The new identity, the same way:** eight more mutations, each caught.
  Looking for a shared identity in later categories too
  (`aLaterCategoryWithTheSameIdentityLeavesEmergencyAlone`); giving no
  new identity, or not putting it in the repaired library
  (`anEmergencyCategoryShadowedByAnEarlierOneGetsANewIdentity`,
  `aShadowedEmergencyCategoryWithNothingToSayGetsBothRepairs`); giving one
  only with phrases; taking any identity offered, or ignoring the
  same-named categories before or after
  (`aNewIdentityKeepsTheCategoryAmongSameNamedOnesInPlace`); and trying
  without end (`withoutAnIdentityThatKeepsItsPlaceTheOldOneStays`).
- **The second review round, the same way:** seven more, each caught.
  Ignoring the sort orders
  (`aSameNamedCategoryWithAnotherSortOrderDoesNotLimitTheNewIdentity`);
  letting a category with the same sort order, name and identity limit
  the new identity (`aCategoryIdenticalInSortOrderNameAndIdentityDoesNotLimitIt`);
  letting another emergency category with the same identity go first
  (`anotherEmergencyCategoryWithTheSameIdentityStaysAfterIt`); trusting
  sort orders that do not match the library, which crashes the run
  (`sortOrdersThatDoNotMatchTheLibraryAreIgnored`); and always
  renumbering, never renumbering, or finding no room one place too soon
  (`sortOrdersFollowTheLastOneAndRenumberOnlyWithoutRoom`).
- **A fuzz of 40,000 random damaged stores**, in a throwaway test on the
  same Linux machine (not committed): two to six categories each, with
  repeated identities, sort orders and names (canonically equivalent
  ones included), sorted by a copy of `orderedForDisplay`, then given
  the repair's new identity. All 2,386 stores in which Emergency opened
  another category were fixed; no category moved except the emergency
  one among categories identical to it in sort order, name and identity;
  the first emergency category never changed; and no store that worked
  was given a new identity. On the first version an independent
  reviewer's fuzz left 81 of 1,221 such stores broken, 73 of them through
  the same-name rule Codex found.
- **The SwiftData side compiles against stand-ins on Linux** (types with
  SwiftData's and OSLog's shapes and no behaviour): `StarterLibrary.swift`,
  `LibraryEditor.swift`, `CategorySelection.swift` and
  `PhraseLibraryTests` from *Seeding* on, the new tests included. That
  checks names and types only; whether the tests pass is GitHub CI's to
  show.
- What each new store test would catch, by its name in
  `PhraseLibraryTests`, *Emergency repair*: a repair that is not added,
  goes anywhere but last or renumbers what is stored
  (`aStoreWithoutEmergencyGetsTheStarterOneAndKeepsEverythingElse`); one
  that removes, rewrites or renumbers a blank emergency phrase
  (`anEmergencyCategoryWithNothingToSayGetsTheStarterPhrasesAfterItsOwn`);
  a write to a working store (`aStoreWhoseEmergencyWorksIsLeftAlone`); a
  failed save that reaches the store or blocks the next try
  (`aFailedRepairChangesNothing`); a write to a store that cannot be read,
  or that reads differently, either half of the check
  (`aStoreThatCannotBeReadIsNotRepaired`,
  `aStoreThatReadsDifferentlyIsNotRepaired`); an overflow, a tie at
  `Int.max`, or a renumbering that moves something
  (`aStoreWithNoRoomAtTheEndIsRenumberedWithoutMovingAnything`,
  `anEmergencyPhraseWithNoRoomAfterItKeepsItsPlace`); a starter
  file with no emergency phrases
  (`theBundledStarterCanGiveEmergencyItsPhrasesBack`);
  a launch that skips the repair
  (`aLaunchGivesADamagedStoreItsEmergencyPhrasesBack`); a failed repair
  that falls back to the starter library alone or writes the store
  (`aRepairThatCannotBeSavedSpeaksFromACopyWithTheirWords`); a copy made
  by identity (`aCopyInMemoryKeepsCategoriesWhoseIdentitiesRepeat`); a
  repair read failure that is lost (`aRepairThatCannotReadTheStoreIsReported`);
  a crash or silence when even the copy fails
  (`whenTheRepairAndItsCopyBothFailTheStoreIsKeptAndTheProblemReported`);
  a shadowed emergency category that keeps its identity in the store, or
  any other stored change with it
  (`aShadowedEmergencyCategoryGetsANewIdentityInTheStore`); a repair not
  given the stored sort orders
  (`aSameNamedCategoryWithAnEarlierSortOrderDoesNotStopTheNewIdentity`);
  and a new identity that reaches the store when the save fails, or is
  missing from the copy (`aFailedNewIdentityChangesNothing`).
  `everyLaunchTurnsAutosaveOff` covers the two new launch paths.

## Not verified

- No Mac, simulator or device run by this thread; the app has not been
  built by it. GitHub CI on this pull request is the build and the first
  run of the SwiftData tests.
- No store damaged outside a test has been seen. The repair is reached
  only through a damaged or hand-edited store; no UI test makes one.
- The String Catalog is unchanged because no sentence was added; CI's
  catalog check confirms it.

## Follow-ups

In the order the library's records give them, for the next library pull
request (R0 item 6), from [the library-core record](2026-10-21-library-core.md):

1. Run the S4 rollback probe once on the current Xcode (issue #19) and
   record the result there. Brickson never calls `rollback()`, and every
   kind of edit, deletes included, already has its save made to fail
   without a crash (`LibraryEditorTests.aFailedSaveChangesNothing`).
   Enabling the probe crashes the whole unit run if it still crashes, so
   it needs a pull request of its own.
2. Unit tests that open stores written by every shipped schema version,
   starting with V1 (a store file made by the app on a Mac or in CI).
3. Safety copies, then export and import, with the privacy policy checked
   in the same pull request. A Replace that removes the person's own
   words stays refused until the owner decides on the safety-copy
   exception (docs/DECISIONS.md, "Replacing the library").
4. "Restore starter phrases" as a merge of the bundled file. *(Later.)*
5. The Library screen, under Settings. *(Editing screens.)*
6. A store with two emergency categories keeps both; Home opens the
   first. Folding them into one would move or rewrite stored items, so
   it waits for a reason and the owner. *(Not planned.)*
7. Two ordinary categories sharing an identity: Home's button for the
   later one shows the earlier one, so its phrases cannot be reached from
   Home. The same new-identity repair would fix it; only a hand-edited
   store gets there, and it is not an Emergency failure. *(Low priority.)*

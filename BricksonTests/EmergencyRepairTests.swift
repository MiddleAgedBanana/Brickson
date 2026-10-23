import Foundation
import Testing
@testable import Brickson

/// The launch repair that gives Emergency something to say in a damaged
/// library, checked without a store. It never deletes, moves or rewrites
/// anything in the library (invariant 7); the stored things it may change
/// are the emergency category's identity and, only where that or a full
/// store needs it, sort orders renumbered in the order they are shown.
/// Each test names the change that would make it fail.
struct EmergencyRepairTests {
    private typealias F = LibraryFixtures
    /// Stands in for the bundled starter library: its emergency category is
    /// `F.emergency`.
    private let starter = LibraryFixtures.library

    private func repair(_ library: LibrarySnapshot, starter: LibrarySnapshot? = nil) -> EmergencyRepair? {
        let ids = SequentialIDs()
        return EmergencyRepair.needed(in: library, starter: starter ?? self.starter, makeID: ids.make)
    }

    /// The category Home's Emergency control opens: the first emergency
    /// category in the library's order (`CategorySelection.emergency`).
    private func emergencyHomeOpens(_ library: LibrarySnapshot) -> LibrarySnapshot.Category? {
        library.categories.first(where: \.isEmergency)
    }

    /// What Home shows when Emergency is activated: it remembers the
    /// emergency category's identity, then shows the first category with
    /// that identity (`CategorySelection.resolve`).
    private func shownByEmergency(_ library: LibrarySnapshot) -> LibrarySnapshot.Category? {
        guard let emergency = emergencyHomeOpens(library) else { return nil }
        return library.categories.first { $0.id == emergency.id }
    }

    private func hasWords(_ category: LibrarySnapshot.Category?) -> Bool {
        category?.phrases.contains { !LibraryText.isBlank($0.text) } ?? false
    }

    /// Invariant 7: everything that was in `before` is still in `after`,
    /// with the same identity, words, emergency flag and place. Only
    /// additions are allowed.
    private func expectOnlyAdditions(from before: LibrarySnapshot, to after: LibrarySnapshot) {
        let changes = LibraryChanges(from: before, to: after)
        #expect(changes.categoriesRemoved == 0)
        #expect(changes.categoriesChanged == 0)
        #expect(changes.categoriesMoved == 0)
        #expect(changes.phrasesRemoved == 0)
        #expect(changes.phrasesChanged == 0)
        #expect(changes.phrasesMoved == 0)
        #expect(changes.categoriesAdded + changes.phrasesAdded > 0)
        #expect(after.categories.count >= before.categories.count)
        for (index, category) in before.categories.enumerated() {
            let kept = after.categories[index]
            #expect(kept.id == category.id)
            #expect(LibraryText.sameBytes(kept.name, category.name))
            #expect(LibraryText.sameBytes(kept.symbolName, category.symbolName))
            #expect(kept.isEmergency == category.isEmergency)
            #expect(Array(kept.phrases.prefix(category.phrases.count)) == category.phrases)
        }
    }

    // MARK: When nothing is needed

    /// Fails if a working library is "repaired", which would add phrases
    /// the family never chose.
    @Test func aLibraryWhoseEmergencyHasWordsNeedsNothing() {
        #expect(repair(F.library) == nil)
    }

    /// An empty library is the seeder's to fill with the whole starter
    /// library. Fails if the repair adds an emergency category on its own,
    /// which would stop the seeder from filling the store.
    @Test func anEmptyLibraryIsLeftToTheSeeder() {
        #expect(repair(.empty) == nil)
    }

    /// Home opens the first emergency category, and that one has words, so
    /// Emergency works. Fails if a second emergency category, which nothing
    /// shows, triggers a repair.
    @Test func aSecondEmergencyCategoryNeedsNothingWhenTheFirstHasWords() {
        var library = F.library
        library.categories.append(.init(id: F.id(400), name: "More", symbolName: "star.fill", isEmergency: true, phrases: []))
        #expect(repair(library) == nil)
    }

    /// Without starter emergency phrases there is nothing safe to add: the
    /// repair adds only the bundled starter words, never anything else.
    /// Fails if it invents phrases or adds an empty category.
    @Test func withoutStarterEmergencyPhrasesNothingIsAdded() {
        let damaged = LibrarySnapshot(categories: [F.basics, F.needs])
        let noEmergency = LibrarySnapshot(categories: [F.basics])
        var blankEmergency = F.emergency
        blankEmergency.phrases = [.init(id: F.id(201), text: " \n")]

        #expect(repair(damaged, starter: noEmergency) == nil)
        #expect(repair(damaged, starter: LibrarySnapshot(categories: [blankEmergency])) == nil)
    }

    // MARK: A missing emergency category

    /// The case the repair exists for: a store that lost its emergency
    /// category. Fails if the category is not added, is added anywhere but
    /// after the others, or takes new identities when the starter ones are
    /// free (then it would count as the person's words in a later replace).
    @Test func aMissingEmergencyCategoryIsAddedAfterTheOthers() throws {
        let damaged = LibrarySnapshot(categories: [F.basics, F.needs])

        let repair = try #require(repair(damaged))

        #expect(repair.place == .newCategory(id: F.emergencyID, name: "Emergency", symbolName: F.emergency.symbolName))
        #expect(repair.phrases == F.emergency.phrases)
        #expect(repair.repaired == LibrarySnapshot(categories: [F.basics, F.needs, F.emergency]))
        #expect(repair.repaired.keepsEmergencyWorking)
        #expect(repair.repaired.hasUniqueIDs)
        expectOnlyAdditions(from: damaged, to: repair.repaired)
    }

    /// The added phrases are untouched starter phrases, so a later replace
    /// does not count them as the person's words. Fails if the repair
    /// changes a starter phrase's words or identity when that identity is
    /// free.
    @Test func whatTheRepairAddsIsNotThePersonsWords() throws {
        let damaged = LibrarySnapshot(categories: [F.basics, F.needs])

        let repair = try #require(repair(damaged))

        #expect(repair.repaired.ownWords(comparedWith: starter) == damaged.ownWords(comparedWith: starter))
    }

    /// Identities stay unique: the store matches items by identity, so a
    /// taken one is never reused. Fails if the repair takes the starter's
    /// identities without checking them.
    @Test func takenIdentitiesAreReplacedWithNewOnes() throws {
        let mine = LibrarySnapshot.Category(
            id: F.emergencyID,
            name: "Mine",
            symbolName: "star.fill",
            isEmergency: false,
            phrases: [.init(id: F.id(201), text: "My own words.")]
        )
        let damaged = LibrarySnapshot(categories: [F.basics, mine])

        let repair = try #require(repair(damaged))

        let added = try #require(repair.repaired.categories.last)
        #expect(added.id == F.id(900))
        #expect(added.isEmergency)
        #expect(added.phrases.map(\.id) == [F.id(901), F.id(202)])
        #expect(added.phrases.map(\.text) == F.emergency.phrases.map(\.text))
        #expect(repair.repaired.hasUniqueIDs)
        expectOnlyAdditions(from: damaged, to: repair.repaired)
    }

    /// A damaged library can repeat an identity. It still gets an
    /// Emergency that works, and nothing it holds is touched. Fails if the
    /// repair refuses such a library, or merges its repeated items.
    @Test func aLibraryWithRepeatedIdentitiesIsStillRepaired() throws {
        var twin = F.needs
        twin.id = F.basicsID
        twin.phrases = [.init(id: F.id(101), text: "A second copy.")]
        let damaged = LibrarySnapshot(categories: [F.basics, twin])
        #expect(!damaged.hasUniqueIDs)

        let repair = try #require(repair(damaged))

        #expect(repair.repaired.categories.count == 3)
        #expect(Array(repair.repaired.categories.prefix(2)) == damaged.categories)
        #expect(hasWords(emergencyHomeOpens(repair.repaired)))
    }

    // MARK: An emergency category with nothing to say

    /// E1 says the emergency category keeps a phrase with words; a damaged
    /// store can still hold one with none. Fails if no phrases are added,
    /// or if they go anywhere but after the category's own.
    @Test func anEmptyEmergencyCategoryGetsTheStarterPhrases() throws {
        var empty = F.emergency
        empty.phrases = []
        let damaged = LibrarySnapshot(categories: [F.basics, empty, F.needs])

        let repair = try #require(repair(damaged))

        #expect(repair.place == .existingCategory(at: 1))
        #expect(repair.phrases == F.emergency.phrases)
        #expect(repair.newIdentity == nil)
        #expect(repair.renumberedCategories == nil)
        #expect(repair.repaired == F.library)
        expectOnlyAdditions(from: damaged, to: repair.repaired)
    }

    /// Imported blank text (only spaces, invisible characters) gives
    /// Emergency nothing to say. The blank phrases are the person's, so
    /// they stay first, byte for byte. Fails if they are removed, trimmed or
    /// moved, or if the starter phrases are not added after them.
    @Test(arguments: [" ", "\u{2060}", " \u{FEFF}\n"])
    func anEmergencyCategoryWithOnlyBlankTextGetsTheStarterPhrasesAfterIt(blank: String) throws {
        var blankOnly = F.emergency
        blankOnly.phrases = [.init(id: F.id(201), text: blank)]
        let damaged = LibrarySnapshot(categories: [F.basics, blankOnly])

        let repair = try #require(repair(damaged))

        let repaired = repair.repaired.categories[1]
        #expect(repaired.phrases.count == 3)
        #expect(LibraryText.sameBytes(repaired.phrases[0].text, blank))
        #expect(repaired.phrases[0].id == F.id(201))
        #expect(repaired.phrases.dropFirst().map(\.text) == F.emergency.phrases.map(\.text))
        // The starter's first identity is taken by the blank phrase.
        #expect(repaired.phrases.dropFirst().map(\.id) == [F.id(900), F.id(202)])
        #expect(repair.repaired.keepsEmergencyWorking)
        expectOnlyAdditions(from: damaged, to: repair.repaired)
    }

    /// Home opens the first emergency category, so that is the one that
    /// needs words, even when a later one has some. Fails if the repair
    /// looks at any emergency category but the first, or adds a third.
    @Test func theEmergencyCategoryHomeOpensIsTheOneRepaired() throws {
        let first = LibrarySnapshot.Category(id: F.id(400), name: "First", symbolName: "star.fill", isEmergency: true, phrases: [])
        let damaged = LibrarySnapshot(categories: [F.basics, first, F.emergency])

        let repair = try #require(repair(damaged))

        #expect(repair.place == .existingCategory(at: 1))
        #expect(repair.repaired.categories.count == 3)
        #expect(hasWords(emergencyHomeOpens(repair.repaired)))
        // F.emergency already uses the starter identities.
        #expect(repair.repaired.categories[1].phrases.map(\.id) == [F.id(900), F.id(901)])
        #expect(repair.repaired.hasUniqueIDs)
        expectOnlyAdditions(from: damaged, to: repair.repaired)
    }

    // MARK: An earlier category with the emergency category's identity

    /// A damaged store can give an earlier category the emergency
    /// category's identity, and then Emergency opens that category's
    /// phrases instead (invariant 2). Fails if the emergency category keeps
    /// its identity, if the earlier one is given the new identity instead,
    /// or if anything else changes, sort orders included.
    @Test func anEmergencyCategoryShadowedByAnEarlierOneGetsANewIdentity() throws {
        var shadowing = F.basics
        shadowing.id = F.emergencyID
        let damaged = LibrarySnapshot(categories: [shadowing, F.emergency, F.needs])
        #expect(shownByEmergency(damaged) == shadowing)

        let repair = try #require(repair(damaged))

        #expect(repair.place == .existingCategory(at: 1))
        #expect(repair.newIdentity == F.id(900))
        #expect(repair.renumberedCategories == nil)
        #expect(repair.phrases.isEmpty)
        var expected = damaged
        expected.categories[1].id = F.id(900)
        #expect(repair.repaired == expected)
        #expect(shownByEmergency(repair.repaired) == expected.categories[1])
    }

    /// Fails if a shadowed emergency category with nothing to say gets only
    /// one of the two repairs.
    @Test func aShadowedEmergencyCategoryWithNothingToSayGetsBothRepairs() throws {
        var shadowing = F.basics
        shadowing.id = F.emergencyID
        var empty = F.emergency
        empty.phrases = []
        let damaged = LibrarySnapshot(categories: [shadowing, empty, F.needs])

        let repair = try #require(repair(damaged))

        #expect(repair.place == .existingCategory(at: 1))
        #expect(repair.newIdentity == F.id(900))
        #expect(repair.phrases == F.emergency.phrases)
        var expected = F.emergency
        expected.id = F.id(900)
        #expect(repair.repaired == LibrarySnapshot(categories: [shadowing, expected, F.needs]))
        #expect(hasWords(shownByEmergency(repair.repaired)))
    }

    /// A later category with the emergency category's identity does not
    /// change what Emergency opens: Home finds the first one. Fails if the
    /// repair looks past the emergency category for a shared identity.
    @Test func aLaterCategoryWithTheSameIdentityLeavesEmergencyAlone() {
        var later = F.needs
        later.id = F.emergencyID
        let library = LibrarySnapshot(categories: [F.basics, F.emergency, later])
        #expect(shownByEmergency(library) == F.emergency)

        #expect(repair(library) == nil)
    }

    /// A category with neither the emergency category's sort order nor its
    /// name, here the one that shadows it.
    private func shadowing(_ id: UUID) -> LibrarySnapshot.Category {
        LibrarySnapshot.Category(id: id, name: "Other", symbolName: "star.fill", isEmergency: false, phrases: [])
    }

    /// A category named like the emergency category, but not one.
    private func namedLikeEmergency(_ id: UUID) -> LibrarySnapshot.Category {
        LibrarySnapshot.Category(id: id, name: F.emergency.name, symbolName: "star.fill", isEmergency: false, phrases: [])
    }

    /// Categories with the same sort order and name are shown in the order
    /// of their identities, so against those the new identity must sort as
    /// the old one did. Fails if the repair takes the first new identity it
    /// is given (930 sorts before the earlier category's 935), or one that
    /// sorts after the later category (960), or renumbers the categories
    /// when an identity fits.
    @Test func aNewIdentityKeepsTheCategoryAmongSameNamedOnesInPlace() throws {
        var emergency = F.emergency
        emergency.id = F.id(940)
        let damaged = LibrarySnapshot(categories: [
            shadowing(F.id(940)), namedLikeEmergency(F.id(935)), emergency, namedLikeEmergency(F.id(950)),
        ])
        var offered = [F.id(930), F.id(960), F.id(945)]

        let needed = EmergencyRepair.needed(in: damaged, sortOrders: [0, 1, 1, 1], starter: starter) {
            offered.removeFirst()
        }

        let repair = try #require(needed)
        #expect(repair.newIdentity == F.id(945))
        #expect(repair.renumberedCategories == nil)
        #expect(offered.isEmpty)
    }

    /// A category with the emergency category's name but another sort
    /// order is placed by sort order, never by identity, so it does not
    /// limit the new identity. Fails if the repair ignores sort orders:
    /// here no identity sorts after the largest, so the first identity
    /// offered would be refused and the categories renumbered for nothing.
    @Test func aSameNamedCategoryWithAnotherSortOrderDoesNotLimitTheNewIdentity() throws {
        let largest = try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"))
        var emergency = F.emergency
        emergency.id = F.id(500)
        let damaged = LibrarySnapshot(categories: [namedLikeEmergency(largest), shadowing(F.id(500)), emergency])

        let needed = EmergencyRepair.needed(in: damaged, sortOrders: [0, 1, 2], starter: starter, makeID: SequentialIDs().make)

        let repair = try #require(needed)
        #expect(repair.newIdentity == F.id(900))
        #expect(shownByEmergency(repair.repaired)?.isEmergency == true)
    }

    /// Codex's case on PR #37: the shadowing category also has the
    /// emergency category's name, its identity is the largest there is,
    /// and its sort order is earlier. Fails if the repair then finds no new
    /// identity among those offered, refuses the first and renumbers the
    /// categories for nothing.
    @Test func aShadowingCategoryWithTheSameNameAndTheLargestIdentityGivesWay() throws {
        let largest = try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"))
        var emergency = F.emergency
        emergency.id = largest
        let damaged = LibrarySnapshot(categories: [namedLikeEmergency(largest), emergency])

        let needed = EmergencyRepair.needed(in: damaged, sortOrders: [0, 1], starter: starter, makeID: SequentialIDs().make)

        let repair = try #require(needed)
        #expect(repair.newIdentity == F.id(900))
        #expect(shownByEmergency(repair.repaired)?.isEmergency == true)
    }

    /// A category with the same sort order, name and identity was never put
    /// before or after the emergency category by the display order (the
    /// store's fetch order did that), so it does not limit the new
    /// identity. Fails if the repair treats it like a category with an
    /// identity of its own, when no identity sorts after the largest.
    @Test func aCategoryIdenticalInSortOrderNameAndIdentityDoesNotLimitIt() throws {
        let largest = try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"))
        var emergency = F.emergency
        emergency.id = largest
        let damaged = LibrarySnapshot(categories: [namedLikeEmergency(largest), emergency])

        let needed = EmergencyRepair.needed(in: damaged, sortOrders: [3, 3], starter: starter, makeID: SequentialIDs().make)

        let repair = try #require(needed)
        #expect(repair.newIdentity == F.id(900))
    }

    /// Another emergency category with the same sort order, name and
    /// identity must stay after the one repaired, or it would become the
    /// one Home opens, still with the shadowed identity. Fails if the
    /// repair takes 600, which sorts after the old 500.
    @Test func anotherEmergencyCategoryWithTheSameIdentityStaysAfterIt() throws {
        var emergency = F.emergency
        emergency.id = F.id(500)
        var twin = emergency
        twin.phrases = []
        let damaged = LibrarySnapshot(categories: [shadowing(F.id(500)), emergency, twin])
        var offered = [F.id(600), F.id(400)]

        let needed = EmergencyRepair.needed(in: damaged, sortOrders: [0, 1, 1], starter: starter) {
            offered.removeFirst()
        }

        let repair = try #require(needed)
        #expect(repair.newIdentity == F.id(400))
        #expect(repair.place == .existingCategory(at: 1))
    }

    /// Sort orders that do not match the library are not trusted: every
    /// category is then taken to share one. Fails if they are used anyway
    /// (here they would crash the run).
    @Test func sortOrdersThatDoNotMatchTheLibraryAreIgnored() throws {
        var emergency = F.emergency
        emergency.id = F.id(940)
        let damaged = LibrarySnapshot(categories: [shadowing(F.id(940)), namedLikeEmergency(F.id(935)), emergency])

        let needed = EmergencyRepair.needed(in: damaged, sortOrders: [0], starter: starter, makeID: SequentialIDs().make)

        let repair = try #require(needed)
        // 900 to 935 sort before the same-named category at 935.
        #expect(repair.newIdentity == F.id(936))
    }

    /// When no identity tried keeps the category in place among those with
    /// its sort order and name, the categories are renumbered 0, 1, 2 in
    /// the order they are shown, which shows them exactly as before and
    /// leaves none ordered by identity, and the next new identity is taken
    /// (Codex's third review on PR #37). The phrases it needs are still
    /// added. Fails if the repair keeps the old identity (Emergency would
    /// still open the earlier category), takes a new one without
    /// renumbering, renumbers in another order, takes an identity another
    /// category has, gives up on the phrases, or keeps asking for
    /// identities without end.
    @Test func withoutAnIdentityThatKeepsItsPlaceTheCategoriesAreRenumbered() throws {
        let tried = EmergencyRepair.identityAttempts
        var empty = F.emergency
        empty.id = F.id(940)
        empty.phrases = []
        // A later category has the identity offered after the ones tried.
        var later = shadowing(F.id(tried + 1))
        later.name = "Later"
        let damaged = LibrarySnapshot(categories: [shadowing(F.id(940)), namedLikeEmergency(F.id(939)), empty, later])
        // Every identity offered sorts before 939.
        let ids = SequentialIDs(startingAt: 1)

        let needed = EmergencyRepair.needed(in: damaged, sortOrders: [0, 1, 1, 2], starter: starter, makeID: ids.make)

        let repair = try #require(needed)
        #expect(repair.renumberedCategories == [0, 1, 2, 3])
        #expect(repair.newIdentity == F.id(tried + 2))
        #expect(repair.phrases.map(\.text) == F.emergency.phrases.map(\.text))
        #expect(repair.repaired.categories.map(\.id) == [F.id(940), F.id(939), F.id(tried + 2), F.id(tried + 1)])
        #expect(shownByEmergency(repair.repaired)?.isEmergency == true)
        let next = ids.make()
        #expect(next == F.id(tried + 3))

        var withWords = damaged
        withWords.categories[2].phrases = F.emergency.phrases
        let again = EmergencyRepair.needed(in: withWords, sortOrders: [0, 1, 1, 2], starter: starter, makeID: SequentialIDs(startingAt: 1).make)
        let identityOnly = try #require(again)
        #expect(identityOnly.renumberedCategories == [0, 1, 2, 3])
        #expect(identityOnly.newIdentity == F.id(tried + 2))
        #expect(identityOnly.phrases.isEmpty)
    }

    // MARK: Sort orders for what is added

    /// Additions follow the last sort order and nothing is renumbered while
    /// there is room; without room the existing items are renumbered in the
    /// order they are shown, so none moves. Fails if a normal store is
    /// renumbered, if an addition overflows or ties at `Int.max`, or if the
    /// renumbering changes the order.
    @Test(arguments: [
        (2, [], nil, [0, 1]),
        (1, [3, 9, 1], nil, [10]),
        (1, [-5], nil, [-4]),
        (0, [Int.max], nil, []),
        (2, [Int.max - 2], nil, [Int.max - 1, Int.max]),
        (1, [5, Int.max], [0, 1], [2]),
        (2, [Int.max - 1, Int.max - 1], [0, 1], [2, 3]),
    ] as [(Int, [Int], [Int]?, [Int])])
    func sortOrdersFollowTheLastOneAndRenumberOnlyWithoutRoom(
        adding count: Int,
        after orders: [Int],
        renumbered: [Int]?,
        added: [Int]
    ) {
        let result = EmergencyRepair.sortOrders(adding: count, after: orders)

        #expect(result.renumbered == renumbered)
        #expect(result.added == added)
    }

    /// Fails if a word is rewritten on the way, even into a canonically
    /// equivalent form ("é" as one character or as "e" plus an accent).
    @Test func theLibrarysWordsComeThroughByteForByte() throws {
        let accented = LibrarySnapshot.Category(
            id: F.id(400),
            name: "Cafe\u{0301}",
            symbolName: "cup.and.saucer.fill",
            isEmergency: false,
            phrases: [.init(id: F.id(401), text: "Un cafe\u{0301}, s'il vous plai\u{0302}t.")]
        )
        let damaged = LibrarySnapshot(categories: [accented])

        let repair = try #require(repair(damaged))

        let kept = repair.repaired.categories[0]
        #expect(Array(kept.name.utf8) == Array("Cafe\u{0301}".utf8))
        #expect(Array(kept.phrases[0].text.utf8) == Array("Un cafe\u{0301}, s'il vous plai\u{0302}t.".utf8))
    }
}

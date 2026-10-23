import Foundation
import Testing
@testable import Brickson

/// The launch repair that gives Emergency something to say in a damaged
/// library, checked without a store. It may only add (invariant 7). Each
/// test names the change that would make it fail.
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

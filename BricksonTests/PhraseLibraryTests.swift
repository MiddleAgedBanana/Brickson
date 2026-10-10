import Foundation
import SwiftData
import Testing
@testable import Brickson

/// The stored library: its schema, its fixed ordering, and seeding.
struct PhraseLibraryTests {
    private let library = StarterLibrary(categories: [
        .init(name: "Basics", symbolName: "star.fill", isEmergency: false, phrases: ["Hello.", "Thank you."]),
        .init(name: "Emergency", symbolName: "exclamationmark.triangle.fill", isEmergency: true, phrases: ["I need help now."]),
    ])

    private func categories(in container: ModelContainer) throws -> [PhraseCategory] {
        PhraseCategory.orderedForDisplay(try container.mainContext.fetch(FetchDescriptor<PhraseCategory>()))
    }

    // MARK: Schema

    @Test func theFirstSchemaIsVersionOne() {
        #expect(PhraseLibrarySchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(PhraseLibraryMigrationPlan.schemas.count == 1)
        #expect(PhraseLibraryMigrationPlan.stages.isEmpty)
    }

    /// A store must open with the migration plan attached, or the next schema
    /// version could not migrate it.
    @Test func aContainerOpensWithTheMigrationPlan() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        let planIsAttached = container.migrationPlan == PhraseLibraryMigrationPlan.self
        #expect(planIsAttached)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
    }

    /// `.nullify`, not `.cascade` (FamilyVoice D28): deleting a category leaves
    /// its phrases for the deleting code to remove explicitly, in the same save.
    @Test func deletingACategoryDoesNotCascadeToItsPhrases() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        let context = container.mainContext
        let category = PhraseCategory(name: "Basics", symbolName: "star.fill", sortOrder: 0)
        context.insert(category)
        let phrase = Phrase(text: "Hello.", sortOrder: 0, category: category)
        context.insert(phrase)
        try context.save()

        context.delete(category)
        try context.save()

        let phrases = try context.fetch(FetchDescriptor<Phrase>())
        #expect(phrases.count == 1)
        #expect(phrases.first?.category == nil)
    }

    // MARK: Ordering

    /// Tied sort orders (a hand-edited backup) must still give one fixed
    /// order, launch after launch (invariant 8).
    @Test func tiedCategoriesFallBackToNameThenIdentity() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let twinB = PhraseCategory(name: "Twin", symbolName: "star.fill", sortOrder: 1, uuid: second)
        let twinA = PhraseCategory(name: "Twin", symbolName: "star.fill", sortOrder: 1, uuid: first)
        let beta = PhraseCategory(name: "Beta", symbolName: "star.fill", sortOrder: 1)
        let alpha = PhraseCategory(name: "Zulu", symbolName: "star.fill", sortOrder: 0)
        for category in [twinB, twinA, beta, alpha] {
            container.mainContext.insert(category)
        }

        let ordered = PhraseCategory.orderedForDisplay([twinB, twinA, beta, alpha])

        #expect(ordered.map(\.uuid) == [alpha.uuid, beta.uuid, first, second])
    }

    @Test func phrasesKeepTheirStoredOrder() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        let category = PhraseCategory(name: "Basics", symbolName: "star.fill", sortOrder: 0)
        container.mainContext.insert(category)
        for (order, text) in [(2, "Third."), (0, "First."), (1, "Second.")] {
            container.mainContext.insert(Phrase(text: text, sortOrder: order, category: category))
        }
        try container.mainContext.save()

        #expect(category.phrasesInOrder.map(\.text) == ["First.", "Second.", "Third."])
    }

    // MARK: Seeding

    @Test func anEmptyLibraryIsSeededInOrder() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()

        let seeded = try PhraseLibrarySeeder.seedIfEmpty(container, with: library)

        #expect(seeded)
        let stored = try categories(in: container)
        #expect(stored.map(\.name) == ["Basics", "Emergency"])
        #expect(stored.map(\.sortOrder) == [0, 1])
        #expect(stored.map(\.isEmergency) == [false, true])
        #expect(stored.first?.phrasesInOrder.map(\.text) == ["Hello.", "Thank you."])
        #expect(stored.first?.phrasesInOrder.map(\.sortOrder) == [0, 1])
    }

    /// Seeding never layers the starter phrases on top of someone's library.
    @Test func aLibraryThatHasCategoriesIsLeftAlone() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        container.mainContext.insert(PhraseCategory(name: "Mine", symbolName: "star.fill", sortOrder: 0))
        try container.mainContext.save()

        let seeded = try PhraseLibrarySeeder.seedIfEmpty(container, with: library)

        #expect(!seeded)
        #expect(try categories(in: container).map(\.name) == ["Mine"])
    }

    /// A failed save must leave nothing half-written and must not crash
    /// (invariant 5). The error reaches the caller, which shows it on Home.
    @Test func aFailedSeedLeavesTheLibraryEmpty() throws {
        struct SaveFailed: Error {}
        let container = try PhraseLibraryStore.makeInMemoryContainer()

        #expect(throws: SaveFailed.self) {
            try PhraseLibrarySeeder.seedIfEmpty(container, with: library) { _ in throw SaveFailed() }
        }

        #expect(try container.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Phrase>()) == 0)
        // And the next launch can still seed.
        #expect(try PhraseLibrarySeeder.seedIfEmpty(container, with: library))
    }

    @Test func seedingTwiceDoesNotDuplicate() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()

        try PhraseLibrarySeeder.seedIfEmpty(container, with: library)
        try PhraseLibrarySeeder.seedIfEmpty(container, with: library)

        #expect(try categories(in: container).count == 2)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Phrase>()) == 3)
    }

    // MARK: Launch

    @Test func aNormalLaunchFillsTheStore() throws {
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let prepared = PhraseLibraryLaunch.prepare(container: store, isVolatile: false, starter: { library })

        #expect(prepared.container === store)
        #expect(!prepared.isVolatile)
        #expect(prepared.issue == nil)
        #expect(try categories(in: store).map(\.name) == ["Basics", "Emergency"])
    }

    /// A store that opens but cannot be filled (a full disk) must not leave
    /// Emergency with nothing to open: the app speaks from a filled
    /// in-memory library and says changes will not be kept.
    @Test func aStoreThatCannotBeFilledFallsBackToAFilledLibraryInMemory() throws {
        struct SaveFailed: Error {}
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw SaveFailed() }
        )

        #expect(prepared.container !== store)
        #expect(prepared.isVolatile)
        #expect(prepared.issue == nil)
        #expect(try categories(in: prepared.container).contains(where: \.isEmergency))
        #expect(try store.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
    }

    @Test func unreadableStarterPhrasesAreReported() throws {
        struct Unreadable: Error {}
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let prepared = PhraseLibraryLaunch.prepare(container: store, isVolatile: false, starter: { throw Unreadable() })

        #expect(prepared.container === store)
        #expect(!prepared.isVolatile)
        #expect(prepared.issue == .starterPhrasesUnavailable)
    }

    @Test func whenTheFallbackFailsTooTheProblemIsReported() throws {
        struct Failed: Error {}
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw Failed() },
            makeFallback: { throw Failed() }
        )

        #expect(prepared.container === store)
        #expect(prepared.issue == .starterPhrasesUnavailable)
    }
}

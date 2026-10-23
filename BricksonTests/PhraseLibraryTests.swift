import Foundation
import SwiftData
import Testing
@testable import Brickson

/// The stored library: its schema, its fixed ordering, opening it at launch
/// and seeding.
struct PhraseLibraryTests {
    private typealias F = LibraryFixtures
    private let library = LibraryFixtures.library
    private struct Failed: Error {}

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

    // MARK: Opening

    /// Fails if the app's store could ever sync through iCloud: the privacy
    /// policy says phrases stay on the device.
    @Test func theAppsStoreNeverSyncs() {
        let configuration = PhraseLibraryStore.persistentConfiguration
        let never = String(describing: ModelConfiguration.CloudKitDatabase.none)
        // The comparison below can only fail if the two options describe
        // themselves differently.
        #expect(never != String(describing: ModelConfiguration.CloudKitDatabase.automatic))
        #expect(String(describing: configuration.cloudKitDatabase) == never)
        #expect(configuration.cloudKitContainerIdentifier == nil)
        #expect(!configuration.isStoredInMemoryOnly)
        #expect(configuration.allowsSave)
    }

    @Test func aStoreThatOpensIsUsed() throws {
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let opened = PhraseLibraryStore.openForApp(makeContainer: { _ in store }, storeExists: { _ in true })

        #expect(opened.container === store)
        #expect(!opened.isVolatile)
        #expect(opened.issue == nil)
    }

    /// M2: a store file that exists but will not open (damaged, or written
    /// by a newer version) may hold someone's phrases. Fails if that is
    /// reported as anything less than "your saved phrases couldn't be
    /// opened".
    @Test func savedPhrasesThatWillNotOpenAreReported() throws {
        let opened = PhraseLibraryStore.openForApp(
            makeContainer: { _ in throw Failed() },
            storeExists: { _ in true }
        )

        #expect(opened.isVolatile)
        #expect(opened.issue == .libraryUnreadable)
        #expect(try opened.container.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
    }

    /// With no store file, a failed open (a full disk on first launch) has
    /// nobody's phrases to report: only that changes will not be kept.
    @Test func aFirstLaunchThatCannotCreateTheStoreIsOnlyVolatile() {
        let opened = PhraseLibraryStore.openForApp(
            makeContainer: { _ in throw Failed() },
            storeExists: { _ in false }
        )

        #expect(opened.isVolatile)
        #expect(opened.issue == nil)
    }

    /// Fails if the file is looked for after the failed open, which might
    /// have left a file behind and so report phrases that never existed.
    @Test func theStoreFileIsLookedForBeforeOpening() {
        var steps: [String] = []
        var checkedURL: URL?

        _ = PhraseLibraryStore.openForApp(
            makeContainer: { _ in steps.append("open"); throw Failed() },
            storeExists: { url in steps.append("look"); checkedURL = url; return false }
        )

        #expect(steps == ["look", "open"])
        #expect(checkedURL == PhraseLibraryStore.persistentConfiguration.url)
    }

    // MARK: Seeding

    /// Fixed starter identities reach the store unchanged, so a backup can
    /// tell an untouched starter phrase from the person's own words.
    @Test func anEmptyLibraryIsSeededInOrderWithItsIdentities() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()

        let seeded = try PhraseLibrarySeeder.seedIfEmpty(container, with: library)

        #expect(seeded)
        let stored = try categories(in: container)
        #expect(stored.map(\.uuid) == library.categories.map(\.id))
        #expect(stored.map(\.sortOrder) == [0, 1, 2])
        #expect(stored.map(\.isEmergency) == [false, true, false])
        #expect(stored.first?.phrasesInOrder.map(\.uuid) == F.basics.phrases.map(\.id))
        #expect(stored.first?.phrasesInOrder.map(\.sortOrder) == [0, 1, 2])
        #expect(try LibraryEditor.read(container) == library)
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
    /// (invariant 5). The error reaches the caller, which falls back to a
    /// library in memory.
    @Test func aFailedSeedLeavesTheLibraryEmpty() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()

        #expect(throws: PhraseLibrarySeedError.saveFailed) {
            try PhraseLibrarySeeder.seedIfEmpty(container, with: library, save: { _ in throw Failed() })
        }

        #expect(try container.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Phrase>()) == 0)
        #expect(!container.mainContext.hasChanges)
        // And the next launch can still seed.
        #expect(try PhraseLibrarySeeder.seedIfEmpty(container, with: library))
    }

    /// When the store cannot say whether it is empty, it is never written
    /// to: it may hold someone's phrases.
    @Test func aStoreThatCannotBeReadIsNotSeeded() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        var saved = false

        #expect(throws: PhraseLibrarySeedError.storeUnreadable) {
            try PhraseLibrarySeeder.seedIfEmpty(
                container,
                with: library,
                readStore: { _ in throw Failed() },
                save: { _ in saved = true }
            )
        }

        #expect(!saved)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
    }

    @Test func seedingTwiceDoesNotDuplicate() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()

        try PhraseLibrarySeeder.seedIfEmpty(container, with: library)
        try PhraseLibrarySeeder.seedIfEmpty(container, with: library)

        #expect(try categories(in: container).count == 3)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Phrase>()) == 6)
    }

    // MARK: Launch

    @Test func aNormalLaunchFillsTheStore() throws {
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let prepared = PhraseLibraryLaunch.prepare(container: store, isVolatile: false, starter: { library })

        #expect(prepared.container === store)
        #expect(!prepared.isVolatile)
        #expect(prepared.issue == nil)
        #expect(try LibraryEditor.read(store) == library)
    }

    /// A store that opens but cannot be filled (a full disk) must not leave
    /// Emergency with nothing to open: the app speaks from a filled
    /// in-memory library and says changes will not be kept.
    @Test func aStoreThatCannotBeFilledFallsBackToAFilledLibraryInMemory() throws {
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw Failed() }
        )

        #expect(prepared.container !== store)
        #expect(prepared.isVolatile)
        #expect(prepared.issue == nil)
        #expect(try LibraryEditor.read(prepared.container).keepsEmergencyWorking)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
    }

    /// M2: a store that opens but whose phrases cannot be read is reported
    /// as unreadable, and is never written over. Fails if the failure is
    /// reported as a saving problem, or if starter phrases are written into
    /// the store.
    @Test func aStoreWhosePhrasesCannotBeReadIsReportedAndLeftAlone() throws {
        let store = try PhraseLibraryStore.makeInMemoryContainer()
        let context = ModelContext(store)
        context.insert(PhraseCategory(name: "Mine", symbolName: "star.fill", sortOrder: 0))
        try context.save()

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: false,
            starter: { library },
            readStore: { _ in throw Failed() }
        )

        #expect(prepared.container !== store)
        #expect(prepared.isVolatile)
        #expect(prepared.issue == .libraryUnreadable)
        #expect(try LibraryEditor.read(prepared.container) == library)
        #expect(try categories(in: store).map(\.name) == ["Mine"])
    }

    /// The whole launch, as the app runs it, when a saved store will not
    /// open: Emergency still has phrases, and Home is told the saved
    /// phrases exist but could not be opened.
    @Test func anUnopenableStoreStillLaunchesWithEmergencyAndSaysWhy() throws {
        let opened = PhraseLibraryStore.openForApp(
            makeContainer: { _ in throw Failed() },
            storeExists: { _ in true }
        )

        let prepared = PhraseLibraryLaunch.prepare(
            container: opened.container,
            isVolatile: opened.isVolatile,
            issue: opened.issue,
            starter: { library }
        )

        #expect(prepared.isVolatile)
        #expect(prepared.issue == .libraryUnreadable)
        #expect(try LibraryEditor.read(prepared.container).keepsEmergencyWorking)
    }

    @Test func unreadableStarterPhrasesAreReported() throws {
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let prepared = PhraseLibraryLaunch.prepare(container: store, isVolatile: false, starter: { throw Failed() })

        #expect(prepared.container === store)
        #expect(!prepared.isVolatile)
        #expect(prepared.issue == .starterPhrasesUnavailable)
    }

    /// The more serious problem wins: saved phrases that would not open
    /// are still reported when the starter phrases fail too.
    @Test func unreadableSavedPhrasesStayReportedWhenTheStarterFails() throws {
        let store = try PhraseLibraryStore.makeInMemoryContainer()

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: true,
            issue: .libraryUnreadable,
            starter: { throw Failed() }
        )

        #expect(prepared.issue == .libraryUnreadable)
    }

    @Test func whenTheFallbackFailsTooTheProblemIsReported() throws {
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

    // MARK: Explicit saves

    /// Every way a launch can end leaves the main context unable to save
    /// by itself (docs/DECISIONS.md, "Every save is explicit"). Fails if a
    /// path returns before autosave is turned off.
    @Test func everyLaunchTurnsAutosaveOff() throws {
        let normal = PhraseLibraryLaunch.prepare(
            container: try PhraseLibraryStore.makeInMemoryContainer(),
            isVolatile: false,
            starter: { library }
        )
        let fallback = PhraseLibraryLaunch.prepare(
            container: try PhraseLibraryStore.makeInMemoryContainer(),
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw Failed() }
        )
        let unreadable = PhraseLibraryLaunch.prepare(
            container: try PhraseLibraryStore.makeInMemoryContainer(),
            isVolatile: false,
            starter: { library },
            readStore: { _ in throw Failed() }
        )
        let noStarter = PhraseLibraryLaunch.prepare(
            container: try PhraseLibraryStore.makeInMemoryContainer(),
            isVolatile: false,
            starter: { throw Failed() }
        )
        let fallbackFailed = PhraseLibraryLaunch.prepare(
            container: try PhraseLibraryStore.makeInMemoryContainer(),
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw Failed() },
            makeFallback: { throw Failed() }
        )

        for prepared in [normal, fallback, unreadable, noStarter, fallbackFailed] {
            #expect(!prepared.container.mainContext.autosaveEnabled)
        }
    }
}

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

    // MARK: Emergency repair

    /// The person's own category in the damaged stores below, as stored
    /// there: sort orders 5, then 7 and 9, so a renumbering shows.
    private let mine = LibrarySnapshot.Category(
        id: LibraryFixtures.id(400),
        name: "Mine",
        symbolName: "star.fill",
        isEmergency: false,
        phrases: [
            .init(id: LibraryFixtures.id(401), text: "My own words."),
            .init(id: LibraryFixtures.id(402), text: "More of mine."),
        ]
    )

    /// A store damaged so that Emergency has nothing to open: `mine`, and
    /// no emergency category.
    private func storeWithoutEmergency(categorySortOrder: Int = 5) throws -> ModelContainer {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let category = PhraseCategory(name: mine.name, symbolName: mine.symbolName, sortOrder: categorySortOrder, uuid: mine.id)
        context.insert(category)
        context.insert(Phrase(text: mine.phrases[0].text, sortOrder: 7, category: category, uuid: mine.phrases[0].id))
        context.insert(Phrase(text: mine.phrases[1].text, sortOrder: 9, category: category, uuid: mine.phrases[1].id))
        try context.save()
        return container
    }

    /// The case the repair exists for (invariant 2). Fails if the starter
    /// emergency category is not added, goes anywhere but last, takes new
    /// identities when the starter ones are free, or if anything already
    /// stored is renumbered, changed or deleted (invariant 7).
    @Test func aStoreWithoutEmergencyGetsTheStarterOneAndKeepsEverythingElse() throws {
        let container = try storeWithoutEmergency()

        let outcome = try PhraseLibraryRepairer.repairEmergency(container, starter: library)

        let expected = LibrarySnapshot(categories: [mine, F.emergency])
        guard case let .saved(repair) = outcome else {
            Issue.record("The repair was not saved: \(outcome)")
            return
        }
        #expect(repair.repaired == expected)
        #expect(try LibraryEditor.read(container) == expected)
        let stored = try categories(in: container)
        #expect(stored.map(\.sortOrder) == [5, 6])
        #expect(stored.map(\.isEmergency) == [false, true])
        #expect(stored.first?.phrasesInOrder.map(\.sortOrder) == [7, 9])
        #expect(stored.last?.phrasesInOrder.map(\.sortOrder) == [0, 1])
        #expect(CategorySelection.emergency(in: stored)?.uuid == F.emergencyID)
    }

    /// An emergency category whose only phrase is blank gives Emergency
    /// nothing to say. The blank phrase is the person's: it keeps its
    /// place and its bytes. Fails if it is removed, rewritten or
    /// renumbered, or if the starter phrases are not added after it.
    @Test func anEmergencyCategoryWithNothingToSayGetsTheStarterPhrasesAfterItsOwn() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let emergency = PhraseCategory(name: "Help", symbolName: "star.fill", sortOrder: 0, isEmergency: true, uuid: F.emergencyID)
        context.insert(emergency)
        context.insert(Phrase(text: " \u{2060}", sortOrder: 3, category: emergency, uuid: F.id(201)))
        context.insert(PhraseCategory(name: mine.name, symbolName: mine.symbolName, sortOrder: 1, uuid: mine.id))
        try context.save()

        let outcome = try PhraseLibraryRepairer.repairEmergency(container, starter: library)

        guard case .saved = outcome else {
            Issue.record("The repair was not saved: \(outcome)")
            return
        }
        let stored = try categories(in: container)
        #expect(stored.map(\.uuid) == [F.emergencyID, mine.id])
        #expect(stored.map(\.name) == ["Help", "Mine"])
        let phrases = try #require(stored.first?.phrasesInOrder)
        #expect(phrases.map(\.text) == [" \u{2060}", "I need help now.", "Please come here."])
        #expect(phrases.map(\.sortOrder) == [3, 4, 5])
        #expect(phrases.first?.uuid == F.id(201))
        // The blank phrase holds the starter's first identity, so that
        // starter phrase gets a new one; the second keeps the starter's.
        #expect(phrases[1].uuid != F.id(201))
        #expect(phrases[2].uuid == F.id(202))
        #expect(try LibraryEditor.read(container).keepsEmergencyWorking)
    }

    /// Fails if a store whose Emergency works is written to, which would
    /// add phrases nobody chose.
    @Test func aStoreWhoseEmergencyWorksIsLeftAlone() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        try PhraseLibrarySeeder.seedIfEmpty(container, with: library)
        var saved = false

        let outcome = try PhraseLibraryRepairer.repairEmergency(
            container,
            starter: library,
            save: { _ in saved = true }
        )

        #expect(outcome == .notNeeded)
        #expect(!saved)
        #expect(try LibraryEditor.read(container) == library)
    }

    /// Invariant 5: a repair whose save fails leaves the store exactly as
    /// it was, does not crash, and hands back the repaired library to speak
    /// from. Fails if anything reaches the store, or if the next launch
    /// cannot repair it.
    @Test func aFailedRepairChangesNothing() throws {
        let container = try storeWithoutEmergency()

        let outcome = try PhraseLibraryRepairer.repairEmergency(
            container,
            starter: library,
            save: { _ in throw Failed() }
        )

        guard case let .notSaved(repair) = outcome else {
            Issue.record("The failed save was not reported: \(outcome)")
            return
        }
        #expect(repair.repaired == LibrarySnapshot(categories: [mine, F.emergency]))
        #expect(try LibraryEditor.read(container) == LibrarySnapshot(categories: [mine]))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Phrase>()) == 2)
        #expect(!container.mainContext.hasChanges)
        // And the next launch can still repair it.
        #expect(try PhraseLibraryRepairer.repairEmergency(container, starter: library) == .saved(repair))
    }

    /// When the store cannot be read, nobody can tell what it needs: it is
    /// never written to. Fails if the repair writes anyway.
    @Test func aStoreThatCannotBeReadIsNotRepaired() throws {
        let container = try storeWithoutEmergency()
        var saved = false

        #expect(throws: PhraseLibrarySeedError.storeUnreadable) {
            try PhraseLibraryRepairer.repairEmergency(
                container,
                starter: library,
                readStore: { _ in throw Failed() },
                save: { _ in saved = true }
            )
        }

        #expect(!saved)
        #expect(try LibraryEditor.read(container) == LibrarySnapshot(categories: [mine]))
    }

    /// The phrases go into the category Home opens, found again in the
    /// store. Fails if a store that reads differently from the library the
    /// repair was planned on is written to, or crashes the app: here, the
    /// read puts an empty emergency category where the store has none, or
    /// one with another identity than the store's.
    @Test(arguments: [false, true])
    func aStoreThatReadsDifferentlyIsNotRepaired(storeHasEmergency: Bool) throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(PhraseCategory(
            name: "Help",
            symbolName: "star.fill",
            sortOrder: 0,
            isEmergency: storeHasEmergency,
            uuid: F.emergencyID
        ))
        try context.save()
        let before = try LibraryEditor.read(container)
        var read = before
        read.categories[0].isEmergency = true
        read.categories[0].id = storeHasEmergency ? F.id(999) : F.emergencyID
        var saved = false

        #expect(throws: PhraseLibrarySeedError.storeUnreadable) {
            try PhraseLibraryRepairer.repairEmergency(
                container,
                starter: library,
                readStore: { _ in read },
                save: { _ in saved = true }
            )
        }

        #expect(!saved)
        #expect(try LibraryEditor.read(container) == before)
    }

    /// Fails if the next sort order overflows (a crash at launch) or
    /// renumbers what is there (docs/DECISIONS.md, "The emergency category
    /// is always there", names this store's one exception).
    @Test func aSortOrderAtTheVeryEndDoesNotOverflow() throws {
        #expect(PhraseLibraryRepairer.sortOrder(after: []) == 0)
        #expect(PhraseLibraryRepairer.sortOrder(after: [3, 9, 1]) == 10)
        #expect(PhraseLibraryRepairer.sortOrder(after: [-5]) == -4)
        #expect(PhraseLibraryRepairer.sortOrder(after: [Int.max]) == Int.max)

        let container = try storeWithoutEmergency(categorySortOrder: Int.max)

        let outcome = try PhraseLibraryRepairer.repairEmergency(container, starter: library)

        guard case .saved = outcome else {
            Issue.record("The repair was not saved: \(outcome)")
            return
        }
        let stored = try categories(in: container)
        #expect(stored.map(\.sortOrder) == [Int.max, Int.max])
        // The documented exception: tied at Int.max, the order falls back
        // to the name, so the hidden emergency category sorts first.
        #expect(stored.map(\.name) == ["Emergency", "Mine"])
        #expect(CategorySelection.emergency(in: stored)?.phrasesInOrder.map(\.text) == F.emergency.phrases.map(\.text))
    }

    /// The real starter file must offer emergency phrases, or the repair
    /// has nothing to add. Fails if the bundled emergency category is
    /// removed or left with no phrase with words.
    @Test func theBundledStarterCanGiveEmergencyItsPhrasesBack() throws {
        let bundled = try StarterLibrary.bundled()

        let repair = try #require(EmergencyRepair.needed(in: LibrarySnapshot(categories: [mine]), starter: bundled))

        #expect(repair.repaired.keepsEmergencyWorking)
        #expect(repair.repaired.categories.first == mine)
    }

    /// The whole launch, as the app runs it, on a store that lost its
    /// emergency category: the same store, repaired, kept, and nothing to
    /// report. Fails if the launch skips the repair.
    @Test func aLaunchGivesADamagedStoreItsEmergencyPhrasesBack() throws {
        let store = try storeWithoutEmergency()

        let prepared = PhraseLibraryLaunch.prepare(container: store, isVolatile: false, starter: { library })

        #expect(prepared.container === store)
        #expect(!prepared.isVolatile)
        #expect(prepared.issue == nil)
        #expect(try LibraryEditor.read(store) == LibrarySnapshot(categories: [mine, F.emergency]))
    }

    /// A repair that cannot be saved (a full disk) must neither leave
    /// Emergency with nothing to open nor hide the person's words: the app
    /// speaks from a copy in memory holding both, and says changes will not
    /// be kept. Fails if it falls back to the starter library alone, or
    /// writes to the store.
    @Test func aRepairThatCannotBeSavedSpeaksFromACopyWithTheirWords() throws {
        let store = try storeWithoutEmergency()

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw Failed() }
        )

        #expect(prepared.container !== store)
        #expect(prepared.isVolatile)
        #expect(prepared.issue == nil)
        #expect(try LibraryEditor.read(prepared.container) == LibrarySnapshot(categories: [mine, F.emergency]))
        #expect(try LibraryEditor.read(store) == LibrarySnapshot(categories: [mine]))
    }

    /// The copy in memory holds the store's categories item for item, even
    /// two that a damaged store gave one identity. Fails if the copy is
    /// written by identity (`StoredLibrary.write`), which would merge them
    /// and show one category's name in place of the other's.
    @Test func aCopyInMemoryKeepsCategoriesWhoseIdentitiesRepeat() throws {
        let store = try PhraseLibraryStore.makeInMemoryContainer()
        let context = ModelContext(store)
        let first = PhraseCategory(name: "Mine", symbolName: "star.fill", sortOrder: 0, uuid: mine.id)
        let second = PhraseCategory(name: "Also mine", symbolName: "star.fill", sortOrder: 1, uuid: mine.id)
        context.insert(first)
        context.insert(second)
        context.insert(Phrase(text: "My own words.", sortOrder: 0, category: first, uuid: F.id(401)))
        context.insert(Phrase(text: "Different words.", sortOrder: 0, category: second, uuid: F.id(401)))
        try context.save()

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw Failed() }
        )

        #expect(prepared.isVolatile)
        let copied = try categories(in: prepared.container)
        #expect(copied.map(\.name) == ["Mine", "Also mine", "Emergency"])
        #expect(copied.map { $0.phrasesInOrder.map(\.text) } == [["My own words."], ["Different words."], F.emergency.phrases.map(\.text)])
    }

    /// When the repair cannot read the store, the launch treats it as the
    /// seeder does: the saved phrases are reported, never written over.
    /// Fails if the repair's read failure is lost or reported as anything
    /// less.
    @Test func aRepairThatCannotReadTheStoreIsReported() throws {
        let store = try storeWithoutEmergency()
        var reads = 0

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: false,
            starter: { library },
            readStore: { context in
                reads += 1
                if reads > 1 { throw Failed() }
                return try StoredLibrary(context).snapshot
            }
        )

        #expect(reads == 2)
        #expect(prepared.container !== store)
        #expect(prepared.isVolatile)
        #expect(prepared.issue == .libraryUnreadable)
        #expect(try LibraryEditor.read(prepared.container) == library)
        #expect(try LibraryEditor.read(store) == LibrarySnapshot(categories: [mine]))
    }

    /// If even the copy in memory cannot be made, the person's library
    /// still shows from the store, and Home says what is missing. Fails if
    /// this path crashes or reports nothing.
    @Test func whenTheRepairAndItsCopyBothFailTheStoreIsKeptAndTheProblemReported() throws {
        let store = try storeWithoutEmergency()

        let prepared = PhraseLibraryLaunch.prepare(
            container: store,
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw Failed() },
            makeFallback: { throw Failed() }
        )

        #expect(prepared.container === store)
        #expect(!prepared.isVolatile)
        #expect(prepared.issue == .starterPhrasesUnavailable)
        #expect(try LibraryEditor.read(store) == LibrarySnapshot(categories: [mine]))
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
        let repaired = PhraseLibraryLaunch.prepare(
            container: try storeWithoutEmergency(),
            isVolatile: false,
            starter: { library }
        )
        let repairNotSaved = PhraseLibraryLaunch.prepare(
            container: try storeWithoutEmergency(),
            isVolatile: false,
            starter: { library },
            saveToStore: { _ in throw Failed() }
        )

        for prepared in [normal, fallback, unreadable, noStarter, fallbackFailed, repaired, repairNotSaved] {
            #expect(!prepared.container.mainContext.autosaveEnabled)
        }
    }
}

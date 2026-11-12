import Foundation
import SwiftData
import Testing
@testable import Brickson

/// Stores saved by every schema version the library has had, opened by
/// today's build: nothing lost, and nothing moved on Home
/// (docs/DECISIONS.md, "Versioned storage"; invariants 7 and 8).
///
/// Each version's store is a file the app wrote, kept in
/// `BricksonTests/SavedStores` and never rewritten, so each test opens a
/// store an earlier build saved, as a device updated from the App Store
/// does. `todaysSchemaWritesTheSavedContents` writes the store the newest
/// schema makes on every run and keeps it in the run's results; the pull
/// request that adds a schema version commits the store its own CI run
/// kept (docs/log/2026-11-12-stores-from-every-version.md, *Making the
/// next version's store*).
struct SavedStoreTests {
    // MARK: Every version has its store

    /// Fails when a schema version is added to the migration plan without
    /// the store it saves, or without what that store holds, or when the
    /// app opens its library with a schema other than the newest.
    @Test func everySchemaVersionHasASavedStore() {
        let versions = PhraseLibraryMigrationPlan.schemas.map { $0.versionIdentifier }
        #expect(
            SavedLibraryStore.all.map(\.version) == versions,
            "Each schema version needs its saved store's contents in SavedLibraryStore.all, oldest first"
        )
        for saved in SavedLibraryStore.all {
            #expect(
                bundledFiles(of: saved)["store"] != nil,
                "No \(saved.fileName).store in the test bundle: commit the store this suite kept on this branch's CI run (docs/DECISIONS.md, \"Versioned storage\")"
            )
        }
        #expect(PhraseLibraryStore.schema.version == versions.last)
    }

    // MARK: Opening a saved store

    /// A store saved by an earlier version, opened the way the app opens
    /// its own, three times over. First: it opens under today's schema,
    /// the launch neither seeds it nor repairs it, every row comes back
    /// byte for byte with its place, and Home shows each category and
    /// phrase where the earlier build did. Second: the same again, so what
    /// opening wrote was kept, and an edit saves. Third: the edit is there
    /// and nothing else moved.
    ///
    /// Fails if a schema change has no migration from this version (the
    /// store does not open), if a migration or the launch drops, adds or
    /// rewrites anything (a phrase in no category included), changes a
    /// word's bytes or a sort order, or if the order Home shows changes:
    /// a different tie-break among equal sort orders, say.
    @Test(arguments: SavedLibraryStore.all)
    func aSavedStoreOpensWithEverythingInItsPlace(_ saved: SavedLibraryStore) throws {
        let folder = URL.temporaryDirectory.appending(path: "SavedStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try copyBundledStore(saved, into: folder)

        // Each container lives only in its block, so it is released, as at
        // the end of a launch, before the next opens the file.
        do {
            let container = try launch(url)
            try expectRows(of: container, equal: saved)
            #expect(try homeArrangement(container) == saved.home)
            // The Library's screens and a backup read the same library.
            #expect(try LibraryEditor.read(container) == saved.library)
        }
        do {
            let container = try launch(url)
            try expectRows(of: container, equal: saved)
            #expect(try homeArrangement(container) == saved.home)

            let addedID = Self.addedID
            let edit = LibraryEdit.addPhrase(text: Self.addedText, category: saved.editedCategory)
            let plan = try edit.plan(in: LibraryEditor.read(container), makeID: { addedID })
            try LibraryEditor.apply(plan, to: container)
        }
        do {
            let container = try launch(url)
            // The first edit numbers every sort order by its place, which
            // settles the ties and gaps an older store may hold
            // (`StoredLibrary.write`): the places stay, the numbers change.
            var edited = saved
            edited.phrases.append(.init(uuid: Self.addedID, text: Self.addedText, sortOrder: 0, category: saved.editedCategory))
            try expectRows(of: container, equal: edited, comparingSortOrders: false)
            var home = saved.home
            home.grids[saved.editedCategory, default: []].append(Self.addedID)
            #expect(try homeArrangement(container) == home)
        }
    }

    // MARK: Today's store

    /// Writes the newest version's contents with today's schema and the
    /// app's own models, opens them again as a launch does, and keeps the
    /// store's files in this run's results as attachments, from which the
    /// pull request that adds a schema version commits its saved store.
    ///
    /// Fails if today's schema cannot keep everything the newest saved
    /// store holds, or if Home would show it in another order.
    @Test func todaysSchemaWritesTheSavedContents() throws {
        let saved = SavedLibraryStore.newest
        let folder = URL.temporaryDirectory.appending(path: "SavedStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "\(saved.fileName).store")

        do {
            let container = try PhraseLibraryStore.makeContainer(configuration(url))
            let context = ModelContext(container)
            context.autosaveEnabled = false
            var categories: [UUID: PhraseCategory] = [:]
            for row in saved.categories {
                let category = PhraseCategory(
                    name: row.name,
                    symbolName: row.symbolName,
                    sortOrder: row.sortOrder,
                    isEmergency: row.isEmergency,
                    uuid: row.uuid
                )
                context.insert(category)
                categories[row.uuid] = category
            }
            for row in saved.phrases {
                var category: PhraseCategory?
                if let id = row.category {
                    category = try #require(categories[id], "Phrase \(row.uuid) names a category that is not written")
                }
                context.insert(Phrase(text: row.text, sortOrder: row.sortOrder, category: category, uuid: row.uuid))
            }
            try context.save()
        }

        // The store's own files, as SQLite left them once the container
        // was released.
        let written = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.hasPrefix(url.lastPathComponent) }
            .sorted()
        #expect(written.contains(url.lastPathComponent))
        for name in written {
            Attachment.record(try Data(contentsOf: folder.appending(path: name)), named: name)
        }

        do {
            let container = try launch(url)
            try expectRows(of: container, equal: saved)
            #expect(try homeArrangement(container) == saved.home)
            #expect(try LibraryEditor.read(container) == saved.library)
        }
    }

    // MARK: Helpers

    private static let addedID = SavedLibraryStore.id(1_000_001)
    private static let addedText = "Good morning."

    /// The app's own configuration (`PhraseLibraryStore.persistentConfiguration`)
    /// at another place: on the device, never synced.
    private func configuration(_ url: URL) -> ModelConfiguration {
        ModelConfiguration(schema: PhraseLibraryStore.schema, url: url, cloudKitDatabase: .none)
    }

    /// Opens the store at `url` with today's schema and its migration plan
    /// (`PhraseLibraryStore.makeContainer`, which the app's
    /// `openForApp` uses), then readies it as every launch does
    /// (`PhraseLibraryLaunch.prepare`, with the bundled starter phrases).
    /// The saved stores are whole, so the launch must use the store itself
    /// and report nothing.
    private func launch(_ url: URL) throws -> ModelContainer {
        let container = try PhraseLibraryStore.makeContainer(configuration(url))
        let prepared = PhraseLibraryLaunch.prepare(container: container, isVolatile: false)
        #expect(prepared.container === container)
        #expect(!prepared.isVolatile)
        #expect(prepared.issue == nil)
        return container
    }

    /// Every stored category and phrase, read without the ordering code,
    /// against what `saved` holds: the same rows, no more and no fewer,
    /// each value the same, words byte for byte.
    private func expectRows(
        of container: ModelContainer,
        equal saved: SavedLibraryStore,
        comparingSortOrders: Bool = true,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let context = ModelContext(container)
        let categories = try context.fetch(FetchDescriptor<PhraseCategory>()).map {
            SavedLibraryStore.CategoryRow(
                uuid: $0.uuid,
                name: $0.name,
                symbolName: $0.symbolName,
                sortOrder: comparingSortOrders ? $0.sortOrder : 0,
                isEmergency: $0.isEmergency
            )
        }
        let phrases = try context.fetch(FetchDescriptor<Phrase>()).map {
            SavedLibraryStore.PhraseRow(
                uuid: $0.uuid,
                text: $0.text,
                sortOrder: comparingSortOrders ? $0.sortOrder : 0,
                category: $0.category?.uuid
            )
        }
        let expectedCategories = saved.categories.map { row in
            var row = row
            if !comparingSortOrders { row.sortOrder = 0 }
            return row
        }
        let expectedPhrases = saved.phrases.map { row in
            var row = row
            if !comparingSortOrders { row.sortOrder = 0 }
            return row
        }
        #expect(byIdentity(categories, \.uuid) == byIdentity(expectedCategories, \.uuid), sourceLocation: sourceLocation)
        #expect(byIdentity(phrases, \.uuid) == byIdentity(expectedPhrases, \.uuid), sourceLocation: sourceLocation)
    }

    private func byIdentity<Row>(_ rows: [Row], _ id: (Row) -> UUID) -> [Row] {
        rows.sorted { id($0).uuidString < id($1).uuidString }
    }

    /// Where Home puts each category and phrase, worked out as `HomeView`
    /// does from its two queries: the category row, the category the
    /// Emergency control opens, and each category's grid.
    private func homeArrangement(_ container: ModelContainer) throws -> SavedLibraryStore.Home {
        let context = container.mainContext
        let ordered = PhraseCategory.orderedForDisplay(try context.fetch(FetchDescriptor<PhraseCategory>()))
        let phrases = try context.fetch(FetchDescriptor<Phrase>())
        var grids: [UUID: [UUID]] = [:]
        for category in ordered {
            grids[category.uuid] = CategorySelection.phrases(of: category.uuid, in: phrases)?.map(\.id) ?? []
        }
        return SavedLibraryStore.Home(
            order: ordered.map(\.uuid),
            categoryRow: CategorySelection.shownInCategoryRow(ordered).map(\.uuid),
            emergency: CategorySelection.emergency(in: ordered)?.uuid,
            grids: grids
        )
    }

    /// The saved store's files in the test bundle, by extension: the store
    /// itself, and SQLite's write-ahead log and its index where the app
    /// left them.
    private func bundledFiles(of saved: SavedLibraryStore) -> [String: URL] {
        var files: [String: URL] = [:]
        for fileExtension in ["store", "store-wal", "store-shm"] {
            files[fileExtension] = Bundle(for: TestBundle.self).url(forResource: saved.fileName, withExtension: fileExtension)
        }
        return files
    }

    /// Copies the saved store into `folder`, so opening it never changes
    /// the kept file, and returns the copy's address.
    private func copyBundledStore(_ saved: SavedLibraryStore, into folder: URL) throws -> URL {
        let files = bundledFiles(of: saved)
        try #require(files["store"] != nil, "No \(saved.fileName).store in the test bundle")
        for (fileExtension, source) in files {
            try FileManager.default.copyItem(at: source, to: folder.appending(path: "\(saved.fileName).\(fileExtension)"))
        }
        return folder.appending(path: "\(saved.fileName).store")
    }
}

/// The test bundle, found by a class it holds. The unit tests run inside
/// the app, whose bundle is `Bundle.main`.
private final class TestBundle {}

/// What one schema version's saved store holds, and where Home shows it.
/// The rows are written in this order, which is deliberately not Home's,
/// so an order that came from the store's row order instead of the sort
/// orders would show.
nonisolated struct SavedLibraryStore: Sendable, CustomTestStringConvertible {
    nonisolated struct CategoryRow: Equatable, Sendable {
        var uuid: UUID
        var name: String
        var symbolName: String
        var sortOrder: Int
        var isEmergency: Bool

        /// Words byte for byte (`LibraryText.sameBytes`).
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.uuid == rhs.uuid
                && LibraryText.sameBytes(lhs.name, rhs.name)
                && LibraryText.sameBytes(lhs.symbolName, rhs.symbolName)
                && lhs.sortOrder == rhs.sortOrder
                && lhs.isEmergency == rhs.isEmergency
        }
    }

    nonisolated struct PhraseRow: Equatable, Sendable {
        var uuid: UUID
        var text: String
        var sortOrder: Int
        /// Nil for a phrase in no category: no edit leaves one, but a
        /// damaged store can hold one, and its words are still someone's.
        var category: UUID?

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.uuid == rhs.uuid
                && LibraryText.sameBytes(lhs.text, rhs.text)
                && lhs.sortOrder == rhs.sortOrder
                && lhs.category == rhs.category
        }
    }

    /// Where Home shows the library, as identities, written out by hand:
    /// every category in Home's order (the Library's too), the category
    /// row, the category the Emergency control opens, and each category's
    /// grid of phrases in order.
    nonisolated struct Home: Equatable, Sendable {
        var order: [UUID]
        var categoryRow: [UUID]
        var emergency: UUID?
        var grids: [UUID: [UUID]]
    }

    var version: Schema.Version
    var categories: [CategoryRow]
    var phrases: [PhraseRow]
    var home: Home
    /// The everyday category the opening test adds a phrase to.
    var editedCategory: UUID

    /// The store's file name without its extension.
    var fileName: String { "library-v\(version.major).\(version.minor).\(version.patch)" }

    var testDescription: String { fileName }

    /// The library as the Library's screens read it
    /// (`LibraryEditor.read`): the categories and their phrases in Home's
    /// order, from the rows and `home` above. A phrase in no category is
    /// in neither.
    var library: LibrarySnapshot {
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.uuid, $0) })
        let textByID = Dictionary(uniqueKeysWithValues: phrases.map { ($0.uuid, $0.text) })
        return LibrarySnapshot(categories: home.order.compactMap { id in
            guard let row = categoriesByID[id] else { return nil }
            return LibrarySnapshot.Category(
                id: id,
                name: row.name,
                symbolName: row.symbolName,
                isEmergency: row.isEmergency,
                phrases: (home.grids[id] ?? []).map { LibrarySnapshot.Phrase(id: $0, text: textByID[$0] ?? "") }
            )
        })
    }
}

nonisolated extension SavedLibraryStore {
    /// Every schema version's saved store, oldest first. A new schema
    /// version adds its own, and never changes an earlier one: that file
    /// and these contents are what an earlier build saved.
    static let all: [SavedLibraryStore] = [v1]

    static var newest: SavedLibraryStore { all[all.count - 1] }

    /// Readable identities: 00000000-0000-4000-8000-000000001000 and on.
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012ld", number))!
    }

    /// Version 1 (`PhraseLibrarySchemaV1`), saved by the app's own models
    /// on CI (docs/log/2026-11-12-stores-from-every-version.md). Neutral
    /// practical words, as the starter library holds (invariant 7), and
    /// what a store gathers that the starter library does not: words
    /// whose bytes matter (an accent stored as one character and as a
    /// letter with a combining mark, a skin-tone emoji, Japanese and Arabic,
    /// spaces at both ends, a long phrase), a category with no phrases yet,
    /// sort orders with ties and gaps such as a restored or hand-edited
    /// store holds, and a phrase in no category, such as only a damaged
    /// store holds.
    static let v1 = SavedLibraryStore(
        version: Schema.Version(1, 0, 0),
        categories: [
            // "Things" before "Places": the same sort order, so the name
            // decides, whichever row the store holds first.
            .init(uuid: id(3000), name: "Things", symbolName: "cup.and.saucer.fill", sortOrder: 3, isEmergency: false),
            .init(uuid: id(1000), name: "Basics", symbolName: "bubble.left.and.bubble.right.fill", sortOrder: 0, isEmergency: false),
            // A gap after the others, and nothing in it yet, as a category
            // the family has just added.
            .init(uuid: id(5000), name: "Outdoors", symbolName: "square.grid.2x2.fill", sortOrder: 10, isEmergency: false),
            .init(uuid: id(2000), name: "Emergency", symbolName: "exclamationmark.triangle.fill", sortOrder: 1, isEmergency: true),
            .init(uuid: id(4000), name: "Places", symbolName: "house.fill", sortOrder: 3, isEmergency: false),
        ],
        phrases: [
            .init(uuid: id(1004), text: "Wait a moment, please.", sortOrder: 3, category: id(1000)),
            .init(uuid: id(1001), text: "Hello.", sortOrder: 0, category: id(1000)),
            .init(uuid: id(1003), text: "Please.", sortOrder: 2, category: id(1000)),
            .init(uuid: id(1002), text: "Thank you.", sortOrder: 1, category: id(1000)),

            .init(uuid: id(2001), text: "I need help now.", sortOrder: 0, category: id(2000)),
            .init(uuid: id(2002), text: "Please come here.", sortOrder: 1, category: id(2000)),
            .init(uuid: id(2003), text: "Call someone, please.", sortOrder: 2, category: id(2000)),
            .init(uuid: id(2004), text: "Something is wrong.", sortOrder: 3, category: id(2000)),

            // "شكراً", after a gap.
            .init(uuid: id(4004), text: "\u{0634}\u{0643}\u{0631}\u{0627}\u{064B}", sortOrder: 5, category: id(4000)),
            // "Café au lait.", its é a letter e and a combining accent.
            .init(uuid: id(4002), text: "Cafe\u{0301} au lait.", sortOrder: 0, category: id(4000)),
            // "ありがとう。"
            .init(uuid: id(4003), text: "\u{3042}\u{308A}\u{304C}\u{3068}\u{3046}\u{3002}", sortOrder: 2, category: id(4000)),
            // "Café au lait, s'il vous plaît.", each accent one character.
            // Tied with the phrase above, it comes first by its words, read
            // as Swift compares text: the same up to the comma, which comes
            // before a full stop. Compared as bytes, the other would come
            // first.
            .init(uuid: id(4001), text: "Caf\u{00E9} au lait, s'il vous pla\u{00EE}t.", sortOrder: 0, category: id(4000)),

            // The same words with the same sort order: the identity
            // decides, so 3004 comes first, though written second.
            .init(uuid: id(3005), text: "Same words.", sortOrder: 7, category: id(3000)),
            .init(
                uuid: id(3002),
                text: "When you have a moment, could you please bring the newspaper, turn the radio down a little, open the window halfway, and then sit with me for a while so we can talk about the plans for the weekend?",
                sortOrder: 1,
                category: id(3000)
            ),
            .init(uuid: id(3004), text: "Same words.", sortOrder: 7, category: id(3000)),
            // "👍🏽"
            .init(uuid: id(3001), text: "\u{1F44D}\u{1F3FD}", sortOrder: 0, category: id(3000)),
            .init(uuid: id(3003), text: " Spaces kept at both ends. ", sortOrder: 2, category: id(3000)),

            .init(uuid: id(9001), text: "Words kept without a category.", sortOrder: 0, category: nil),
        ],
        home: Home(
            order: [id(1000), id(2000), id(4000), id(3000), id(5000)],
            categoryRow: [id(1000), id(4000), id(3000), id(5000)],
            emergency: id(2000),
            grids: [
                id(1000): [id(1001), id(1002), id(1003), id(1004)],
                id(2000): [id(2001), id(2002), id(2003), id(2004)],
                id(4000): [id(4001), id(4002), id(4003), id(4004)],
                id(3000): [id(3001), id(3002), id(3003), id(3004), id(3005)],
                id(5000): [],
            ]
        ),
        editedCategory: id(1000)
    )
}

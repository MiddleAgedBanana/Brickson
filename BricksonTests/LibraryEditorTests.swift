import Foundation
import SwiftData
import Testing
@testable import Brickson

/// Writing plans to the store. Every kind of edit is applied for real, and
/// every kind is made to fail its save, which must change nothing
/// (invariant 5; docs/LESSONS.md, "Test every rollback path").
struct LibraryEditorTests {
    private typealias F = LibraryFixtures
    private struct SaveFailed: Error {}

    private func store(with library: LibrarySnapshot = LibraryFixtures.library) throws -> ModelContainer {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        container.mainContext.autosaveEnabled = false
        try PhraseLibrarySeeder.seedIfEmpty(container, with: library)
        return container
    }

    private func makePlan(_ edit: LibraryEdit, in container: ModelContainer, starter: LibrarySnapshot? = nil) throws -> LibraryPlan {
        try edit.plan(in: LibraryEditor.read(container), starter: starter, makeID: SequentialIDs().make)
    }

    private func counts(_ container: ModelContainer) throws -> (categories: Int, phrases: Int) {
        let context = ModelContext(container)
        return (
            try context.fetchCount(FetchDescriptor<PhraseCategory>()),
            try context.fetchCount(FetchDescriptor<Phrase>())
        )
    }

    @Test func readingGivesTheLibraryThatWasStored() throws {
        let container = try store()
        #expect(try LibraryEditor.read(container) == F.library)
    }

    /// Each kind of edit, written and read back. Fails if the writer
    /// misses a field, an order or a delete.
    @Test(arguments: LibraryEdit.Kind.allCases)
    func everyKindOfEditIsWritten(kind: LibraryEdit.Kind) throws {
        let container = try store()
        // Measured against the starter, the fixture library holds none of
        // the person's own words, so a replace may run without a safety copy.
        let plan = try makePlan(F.sampleEdit(kind), in: container, starter: F.library)
        #expect(!plan.needsSafetyCopy)

        let written = try LibraryEditor.apply(plan, to: container)

        #expect(written == plan.after)
        #expect(try LibraryEditor.read(container) == plan.after)
        let stored = try counts(container)
        // Nothing is left behind: no phrase without a category.
        #expect(stored.categories == plan.after.categories.count)
        #expect(stored.phrases == plan.after.phraseCount)
    }

    /// The heart of invariant 5 for editing. Fails if an edit is applied in
    /// the main context (the change would still be pending there), or if
    /// part of it reaches the store before the save.
    @Test(arguments: LibraryEdit.Kind.allCases)
    func aFailedSaveChangesNothing(kind: LibraryEdit.Kind) throws {
        let container = try store()
        let plan = try makePlan(F.sampleEdit(kind), in: container, starter: F.library)

        #expect(throws: LibraryEditError.saveFailed) {
            try LibraryEditor.apply(plan, to: container) { _ in throw SaveFailed() }
        }

        #expect(try LibraryEditor.read(container) == F.library)
        let stored = try counts(container)
        #expect(stored.categories == 3)
        #expect(stored.phrases == 6)
        #expect(!container.mainContext.hasChanges)
        // And the same plan still applies afterwards.
        #expect(try LibraryEditor.apply(plan, to: container) == plan.after)
    }

    /// The failure seam above throws before SwiftData saves. This one makes
    /// SwiftData's own save fail, on a store opened read-only.
    @Test func aSaveSwiftDataRefusesChangesNothing() throws {
        let folder = URL.temporaryDirectory.appending(path: "LibraryEditorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        // The containers live only in this block, so they are released
        // before the folder is removed (SQLite warned "vnode unlinked while
        // in use" on CI when they outlived it).
        do {
            let url = folder.appending(path: "library.store")
            let writable = try PhraseLibraryStore.makeContainer(ModelConfiguration(
                schema: PhraseLibraryStore.schema, url: url, cloudKitDatabase: .none
            ))
            try PhraseLibrarySeeder.seedIfEmpty(writable, with: F.library)
            let readOnly = try PhraseLibraryStore.makeContainer(ModelConfiguration(
                schema: PhraseLibraryStore.schema, url: url, allowsSave: false, cloudKitDatabase: .none
            ))
            let plan = try makePlan(.deleteCategory(F.basicsID), in: readOnly)

            #expect(throws: LibraryEditError.saveFailed) {
                try LibraryEditor.apply(plan, to: readOnly)
            }
            #expect(try LibraryEditor.read(readOnly) == F.library)
            #expect(try LibraryEditor.read(writable) == F.library)
        }
    }

    /// A plan made before another edit landed is refused. Fails if apply
    /// stops comparing the store with the plan's starting point.
    @Test func aStalePlanIsRefused() throws {
        let container = try store()
        let first = try makePlan(.deletePhrase(F.id(101)), in: container)
        let second = try makePlan(.editPhrase(F.id(102), text: "Thanks."), in: container)
        try LibraryEditor.apply(first, to: container)

        #expect(throws: LibraryEditError.libraryChanged) {
            try LibraryEditor.apply(second, to: container)
        }
        #expect(try LibraryEditor.read(container) == first.after)
    }

    /// A replace that would remove the person's words cannot run
    /// (invariant 7; docs/DECISIONS.md, "Replacing the library"). Fails if
    /// apply ignores the plan's flag.
    @Test func aReplaceThatNeedsASafetyCopyIsRefused() throws {
        let container = try store()
        let plan = try makePlan(F.sampleEdit(.replace), in: container, starter: nil)
        #expect(plan.needsSafetyCopy)

        #expect(throws: LibraryEditError.safetyCopyRequired) {
            try LibraryEditor.apply(plan, to: container)
        }
        #expect(try LibraryEditor.read(container) == F.library)
    }

    /// A category's phrases go with it in the same save, because the
    /// relationship does not cascade. Fails if the writer deletes only the
    /// category, which would leave invisible phrases behind.
    @Test func deletingACategoryLeavesNoPhrasesBehind() throws {
        let container = try store()
        try LibraryEditor.apply(makePlan(.deleteCategory(F.basicsID), in: container), to: container)

        let phrases = try ModelContext(container).fetch(FetchDescriptor<Phrase>())
        #expect(phrases.count == 3)
        #expect(phrases.allSatisfy { $0.category != nil })
    }

    /// A phrase that belongs to no category is not part of the library and
    /// is never touched, so no edit can delete it (invariant 7).
    @Test func phrasesOutsideTheLibraryAreNeverTouched() throws {
        let container = try store()
        let context = ModelContext(container)
        context.insert(Phrase(text: "Kept.", sortOrder: 0, category: nil, uuid: F.id(999)))
        try context.save()

        try LibraryEditor.apply(makePlan(.deleteCategory(F.basicsID), in: container), to: container)
        try LibraryEditor.apply(makePlan(F.sampleEdit(.replace), in: container, starter: LibraryEditor.read(container)), to: container)

        let orphans = try ModelContext(container).fetch(FetchDescriptor<Phrase>()).filter { $0.category == nil }
        #expect(orphans.map(\.text) == ["Kept."])
    }

    /// Sort orders become each item's place, so tied orders from an older
    /// store are settled by the first edit and can never reorder later.
    @Test func anEditSettlesTiedSortOrders() throws {
        let container = try store(with: .empty)
        let context = ModelContext(container)
        let category = PhraseCategory(name: "Tied", symbolName: "star.fill", sortOrder: 0, uuid: F.id(100))
        context.insert(category)
        for (text, id) in [("B.", 102), ("A.", 101)] {
            context.insert(Phrase(text: text, sortOrder: 5, category: category, uuid: F.id(id)))
        }
        context.insert(PhraseCategory(name: "Emergency", symbolName: "star.fill", sortOrder: 0, isEmergency: true, uuid: F.id(200)))
        try context.save()
        let before = try LibraryEditor.read(container)

        try LibraryEditor.apply(makePlan(.addPhrase(text: "C.", category: F.id(100)), in: container), to: container)

        let stored = try ModelContext(container).fetch(FetchDescriptor<PhraseCategory>())
        let tied = try #require(stored.first { $0.uuid == F.id(100) })
        #expect(tied.phrasesInOrder.map(\.sortOrder) == [0, 1, 2])
        let tiedBefore = try #require(before.categories.first { $0.id == F.id(100) })
        #expect(tied.phrasesInOrder.map(\.text) == tiedBefore.phrases.map(\.text) + ["C."])
        #expect(Set(stored.map(\.sortOrder)) == [0, 1])
    }

    /// "Byte-lossless": export, import into an empty library, export again
    /// gives identical bytes, through the real store. Fails if the codec or
    /// the store trims, normalizes or reorders a word.
    @Test func aBackupRoundTripsThroughTheStoreByteForByte() throws {
        let exported = try BackupCodec.encode(BackupCodecTests.hardLibrary)
        let container = try store(with: .empty)
        let imported = try BackupCodec.decode(exported)
        let plan = try LibraryEdit.replace(imported).plan(in: LibraryEditor.read(container))
        #expect(!plan.needsSafetyCopy)
        try LibraryEditor.apply(plan, to: container)

        let reexported = try BackupCodec.encode(LibraryEditor.read(container))

        #expect(reexported == exported)
    }
}

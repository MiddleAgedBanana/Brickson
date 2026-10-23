import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Brickson

/// What SwiftData itself does, pinned before editing is built on it
/// (docs/DECISIONS.md, "Every save is explicit"; questions S1 to S4 in
/// docs/log/2026-10-21-library-core.md). If an iOS update changes one of
/// these, the failing test names the assumption that broke.
///
/// Where a test's only possible failure is a crash, it says so: a crash
/// is what it checks for.
struct SwiftDataBehaviourTests {
    private typealias F = LibraryFixtures
    private struct Failed: Error {}

    private func store() throws -> ModelContainer {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        container.mainContext.autosaveEnabled = false
        try PhraseLibrarySeeder.seedIfEmpty(container, with: F.library)
        return container
    }

    private func scratch(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func category(_ id: UUID, in context: ModelContext) throws -> PhraseCategory {
        try #require(try context.fetch(FetchDescriptor<PhraseCategory>()).first { $0.uuid == id })
    }

    /// Lets the main queue run, as it would between frames, until `done` is
    /// true or `limit` passes. Generous, because CI simulators can be slow.
    private func settle(for limit: Duration = .seconds(5), until done: () throws -> Bool) async throws {
        let deadline = ContinuousClock.now + limit
        while try !done(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: Autosave

    /// The documented default: SwiftData turns autosave on for a
    /// container's main context. If this starts failing, the reason for
    /// pinning it off has changed; the pin stays.
    @Test func aNewMainContextAutosaves() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        #expect(container.mainContext.autosaveEnabled)
    }

    /// The app's container reaches Home through `.modelContainer`. Fails if
    /// SwiftUI turns autosave back on when it attaches the container.
    @Test func attachingTheLibraryToSwiftUIKeepsAutosaveOff() async throws {
        let prepared = PhraseLibraryLaunch.prepare(
            container: try PhraseLibraryStore.makeInMemoryContainer(),
            isVolatile: false,
            starter: { F.library }
        )
        let probe = AutosaveProbe()
        let host = UIHostingController(rootView: AutosaveProbeView(probe: probe).modelContainer(prepared.container))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }

        try await settle { probe.autosaveEnabled != nil }

        #expect(probe.autosaveEnabled == false)
    }

    // MARK: S1: deletes saved from another context

    /// Every edit saves from a context of its own. Fails if the main
    /// context (which Home reads) keeps seeing what was deleted.
    @Test func s1aDeleteSavedElsewhereIsSeenByTheMainContext() throws {
        let container = try store()
        _ = try container.mainContext.fetch(FetchDescriptor<PhraseCategory>()).map(\.phrasesInOrder)

        let context = scratch(container)
        let basics = try category(F.basicsID, in: context)
        for phrase in basics.phrases ?? [] { context.delete(phrase) }
        context.delete(basics)
        try context.save()

        let main = container.mainContext
        #expect(try main.fetchCount(FetchDescriptor<PhraseCategory>()) == 2)
        #expect(try main.fetchCount(FetchDescriptor<Phrase>()) == 3)
        #expect(try main.fetch(FetchDescriptor<PhraseCategory>()).allSatisfy { $0.uuid != F.basicsID })
    }

    /// The reference app's experiments saw a crash when the main context
    /// read an object that another context had deleted. This test fails
    /// only by crashing. Screens still never hold model objects across an
    /// edit (docs/DECISIONS.md, "Every save is explicit").
    @Test func s1aHeldObjectDeletedElsewhereCanBeTouched() async throws {
        let container = try store()
        let held = try category(F.basicsID, in: container.mainContext)
        _ = held.phrasesInOrder.map(\.text)

        let context = scratch(container)
        let basics = try category(F.basicsID, in: context)
        for phrase in basics.phrases ?? [] { context.delete(phrase) }
        context.delete(basics)
        try context.save()
        try await settle(for: .milliseconds(200)) { false }

        _ = held.isDeleted
        _ = held.uuid
    }

    // MARK: S2: what Home reads after a delete elsewhere

    /// Home reads a category's phrases through its relationship. Fails if,
    /// after a phrase is deleted from another context, the main context's
    /// category still lists it: Home would draw a tile for a phrase that
    /// no longer exists.
    @Test func s2aPhraseDeletedElsewhereLeavesItsCategory() async throws {
        let container = try store()
        let main = container.mainContext
        #expect(try category(F.basicsID, in: main).phrasesInOrder.count == 3)

        let context = scratch(container)
        let doomed = try #require(try context.fetch(FetchDescriptor<Phrase>()).first { $0.uuid == F.id(101) })
        context.delete(doomed)
        try context.save()

        try await settle { try category(F.basicsID, in: main).phrasesInOrder.count == 2 }
        #expect(try category(F.basicsID, in: main).phrasesInOrder.map(\.text) == ["Thank you.", "Goodbye."])
    }

    // MARK: S3: failed saves

    /// A context of its own that fails to save leaves the main context with
    /// nothing pending and the store unchanged. Uses a store opened
    /// read-only, so the failure is SwiftData's own.
    @Test func s3aFailedSaveElsewhereLeavesTheMainContextClean() throws {
        try withReadOnlyStore { readOnly in
            let context = scratch(readOnly)
            context.insert(Phrase(text: "Unsaved.", sortOrder: 9, category: try category(F.needsID, in: context)))

            #expect(throws: (any Error).self) { try context.save() }

            #expect(!readOnly.mainContext.hasChanges)
            #expect(try LibraryEditor.read(readOnly) == F.library)
        }
    }

    /// Why no edit is ever made in the main context: after a failed save
    /// there, the change is still pending, ready for any later save to
    /// write. Fails if SwiftData starts discarding it.
    @Test func s3aFailedSaveInTheMainContextLeavesTheChangePending() throws {
        try withReadOnlyStore { readOnly in
            let main = readOnly.mainContext
            main.autosaveEnabled = false
            main.insert(Phrase(text: "Unsaved.", sortOrder: 9, category: try category(F.needsID, in: main)))

            #expect(throws: (any Error).self) { try main.save() }

            #expect(main.hasChanges)
        }
    }

    private func withReadOnlyStore(_ body: (ModelContainer) throws -> Void) throws {
        let folder = URL.temporaryDirectory.appending(path: "SwiftDataBehaviourTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        // The containers live only in this block, so they are released
        // before the folder is removed. On CI, removing the store's files
        // while its containers were still alive made SQLite warn "vnode
        // unlinked while in use".
        do {
            let url = folder.appending(path: "library.store")
            let writable = try PhraseLibraryStore.makeContainer(ModelConfiguration(
                schema: PhraseLibraryStore.schema, url: url, cloudKitDatabase: .none
            ))
            try PhraseLibrarySeeder.seedIfEmpty(writable, with: F.library)
            let readOnly = try PhraseLibraryStore.makeContainer(ModelConfiguration(
                schema: PhraseLibraryStore.schema, url: url, allowsSave: false, cloudKitDatabase: .none
            ))
            try body(readOnly)
        }
    }

    // MARK: S4: rollback and transaction

    /// The reference app crashed calling `rollback()` after a cascading
    /// delete (its D28). Brickson never calls `rollback()`; this records
    /// whether the same crash happens with explicit, non-cascading deletes.
    /// It fails only by crashing, or if the rollback does not restore.
    ///
    /// It does crash ("Unexpected backing data for snapshot creation"), on
    /// Xcode 26.6 with an iOS 26.5 simulator, so it is disabled: a crash
    /// would stop the whole suite (docs/LESSONS.md, "Commit a crash
    /// reproduction, disabled"). Re-enable it once on a newer Xcode or iOS
    /// to see whether Apple fixed it, and record the result on the issue.
    @Test(.disabled("Crashes SwiftData: rollback() after deletes traps (issue #19)"), .bug("https://github.com/MiddleAgedBanana/Brickson/issues/19"))
    func s4RollbackAfterDeletingACategoryAndItsPhrases() throws {
        let container = try store()
        let context = scratch(container)
        let basics = try category(F.basicsID, in: context)
        for phrase in basics.phrases ?? [] { context.delete(phrase) }
        context.delete(basics)

        context.rollback()

        #expect(!context.hasChanges)
        #expect(try category(F.basicsID, in: context).phrasesInOrder.map(\.text) == ["Hello.", "Thank you.", "Goodbye."])
    }

    /// A transaction whose block throws writes nothing to the store.
    @Test func s4ATransactionThatThrowsWritesNothing() throws {
        let container = try store()
        let context = scratch(container)

        #expect(throws: Failed.self) {
            try context.transaction {
                let basics = try category(F.basicsID, in: context)
                for phrase in basics.phrases ?? [] { context.delete(phrase) }
                context.delete(basics)
                throw Failed()
            }
        }

        #expect(try LibraryEditor.read(container) == F.library)
    }
}

private final class AutosaveProbe {
    var autosaveEnabled: Bool?
}

private struct AutosaveProbeView: View {
    @Environment(\.modelContext) private var context
    let probe: AutosaveProbe

    var body: some View {
        Color.clear.onAppear { probe.autosaveEnabled = context.autosaveEnabled }
    }
}

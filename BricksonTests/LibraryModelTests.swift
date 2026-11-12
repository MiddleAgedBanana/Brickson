import SwiftData
import Testing
@testable import Brickson

/// What the Library's screens share (`LibraryModel`) when the store cannot
/// be read. Each test names the change that would make it fail.
struct LibraryModelTests {
    /// Export shares the model's library, and Restore plans against it, so
    /// a library read before the store stopped opening must not outlive
    /// the read that failed (docs/DECISIONS.md, "Exporting and restoring a
    /// backup"). Fails if a failed read keeps the earlier library, if it
    /// says nothing, or if the next good read does not bring it back.
    @Test func aFailedReadKeepsNoLibraryAndSaysWhy() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        let model = LibraryModel()
        model.refresh(container)
        #expect(model.snapshot != nil)
        #expect(model.readFailure == nil)

        model.refresh(container, read: { (_: ModelContainer) throws(LibraryEditError) -> LibrarySnapshot in
            throw .libraryUnreadable
        })
        #expect(model.snapshot == nil)
        #expect(model.readFailure == LibraryEditError.libraryUnreadable.message)

        model.refresh(container)
        #expect(model.snapshot != nil)
        #expect(model.readFailure == nil)
    }

    /// A line says what the last change did: "Added “Water”.", with a note
    /// that a phrase has the same name, stayed after the family renamed the
    /// category and the note had stopped being true, and a restore's note
    /// the same way. Fails if a change that saves leaves either line, or if
    /// one that is refused clears them.
    @Test func aChangeThatSavesClearsTheLinesOfEarlierChanges() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        try PhraseLibrarySeeder.seedIfEmpty(container, with: LibraryFixtures.library)
        let model = LibraryModel()
        model.refresh(container)
        model.categoryResults[LibraryFixtures.needsID] = "A line."
        model.backupResult = "A restore's line."

        model.perform(.renameCategory(LibraryFixtures.needsID, name: "Basics"), in: container, restBoard: nil)
        #expect(model.categoryResults[LibraryFixtures.needsID] == "A line.")
        #expect(model.backupResult == "A restore's line.")

        model.perform(.renameCategory(LibraryFixtures.needsID, name: "Wants"), in: container, restBoard: nil)
        #expect(model.categoryResults[LibraryFixtures.needsID] == nil)
        #expect(model.backupResult == nil)
    }

    /// Every change reads the store before it plans, and that read follows
    /// the same rule. Fails if a change whose read fails keeps the library
    /// read before it, or says nothing, or if the next change that reads
    /// the store keeps the earlier failure beside its library.
    @Test func aChangeWhoseReadFailsKeepsNoLibrary() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        try PhraseLibrarySeeder.seedIfEmpty(container, with: LibraryFixtures.library)
        let model = LibraryModel()
        model.refresh(container)
        #expect(model.snapshot != nil)
        let change = LibraryEdit.addPhrase(text: "Please.", category: LibraryFixtures.basicsID)

        let refused = model.perform(change, in: container, restBoard: nil, read: { (_: ModelContainer) throws(LibraryEditError) -> LibrarySnapshot in
            throw .libraryUnreadable
        })
        #expect(refused == .refused(LibraryEditError.libraryUnreadable.message))
        #expect(model.snapshot == nil)
        #expect(model.readFailure == LibraryEditError.libraryUnreadable.message)

        let saved = model.perform(change, in: container, restBoard: nil)
        #expect(saved != refused)
        #expect(model.snapshot?.categories.first { $0.id == LibraryFixtures.basicsID }?.phrases.map(\.text).contains("Please.") == true)
        #expect(model.readFailure == nil)
    }
}

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
}

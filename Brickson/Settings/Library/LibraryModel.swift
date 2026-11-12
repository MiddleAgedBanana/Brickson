import Foundation
import Observation
import SwiftData

/// What the Library's screens share while Settings is open: the library as
/// last read or written, the words each screen keeps a line for, a backup
/// waiting for its answer, and where the row that opened a question was.
///
/// The screens hold identities and this snapshot, never stored objects:
/// every change is planned (`LibraryEdit.plan`) and written in one save of
/// its own (`LibraryEditor.apply`), or not at all, and Home's own query
/// sees it (docs/DECISIONS.md, "Editing the library").
@Observable
final class LibraryModel {
    /// What happened to a change.
    enum Outcome: Equatable {
        case saved(LibraryPlan)
        /// Nothing was changed, for this reason.
        case refused(String)
    }

    /// The library as last read or written; nil until the Library opens,
    /// and nil again when `refresh` finds the store cannot be read, so
    /// Export cannot share, and Restore cannot plan against, a library
    /// read before it failed (docs/DECISIONS.md, "Exporting and restoring
    /// a backup").
    private(set) var snapshot: LibrarySnapshot?
    /// Why the library could not be read, where it could not.
    private(set) var readFailure: String?
    /// The Library's line at its top: what the last delete of a category
    /// did.
    var libraryResult: String?
    /// The line under Restore from a Backup: why a chosen file could not
    /// be restored.
    var backupResult: String?
    /// Each category screen's line at its top: what the last delete of a
    /// phrase did.
    var categoryResults: [UUID: String] = [:]
    /// The backup chosen for the Restore question, with what each choice
    /// would do.
    var restore: RestoreChoices?
    /// Where the row that opened the question on screen now was as it was
    /// chosen: in its screen's content (`SettingsMetrics.contentSpace`),
    /// less what that screen had scrolled. Every Settings screen's content
    /// starts at the same place in the window, so this is where the row
    /// was in the question's content as it first shows, and the way back
    /// takes its place (`LibraryQuestionPlace`).
    var askedFrom: CGRect?
    /// That row was the last control of its screen, so a look anywhere
    /// under it met it too.
    var askedFromLast = false

    /// The bundled starter library, so a replace can tell untouched starter
    /// phrases from the person's own words. Without it every word counts as
    /// theirs, which only makes Replace more careful.
    let starter: LibrarySnapshot? = try? StarterLibrary.bundled()

    /// Reads the library afresh, or keeps no library and says why it could
    /// not be read. `read` exists so tests can make the read fail; the app
    /// never passes it. It runs on the main actor, as `LibraryEditor.read`
    /// does.
    func refresh(
        _ container: ModelContainer,
        read: @MainActor (ModelContainer) throws(LibraryEditError) -> LibrarySnapshot = LibraryEditor.read
    ) {
        do {
            snapshot = try read(container)
            readFailure = nil
        } catch {
            snapshot = nil
            readFailure = error.message
        }
    }

    /// Plans `edit` against the library as stored now and writes it in one
    /// save, or changes nothing and says why. It reads the store as
    /// `refresh` does, so a read that fails here keeps no library either.
    ///
    /// - Parameter restBoard: the category Home's rest board shows
    ///   (`SetupRecord.restBoardCategory`), read as the change is made,
    ///   because Home shows it whatever it holds (`LibraryEdit.plan`).
    @discardableResult
    func perform(
        _ edit: LibraryEdit,
        in container: ModelContainer,
        restBoard: UUID?,
        read: @MainActor (ModelContainer) throws(LibraryEditError) -> LibrarySnapshot = LibraryEditor.read
    ) -> Outcome {
        refresh(container, read: read)
        guard let library = snapshot else {
            return .refused(readFailure ?? LibraryEditError.libraryUnreadable.message)
        }
        let plan: LibraryPlan
        do {
            plan = try edit.plan(in: library, starter: starter, restBoard: restBoard)
        } catch {
            return .refused(error.message)
        }
        return apply(plan, in: container)
    }

    /// Writes a plan made earlier, such as a restore's, or nothing at all.
    func apply(_ plan: LibraryPlan, in container: ModelContainer) -> Outcome {
        do {
            snapshot = try LibraryEditor.apply(plan, to: container)
            // A line says what the last change did, so a later one must
            // not leave it saying something no longer true.
            categoryResults = [:]
            backupResult = nil
            return .saved(plan)
        } catch {
            refresh(container)
            return .refused(error.message)
        }
    }

    /// Settings went back to its first screen: nothing a Library screen
    /// said or was asked is kept.
    func reset() {
        libraryResult = nil
        backupResult = nil
        categoryResults = [:]
        restore = nil
        askedFrom = nil
        askedFromLast = false
    }

    // MARK: Reading the snapshot

    func category(_ id: UUID) -> LibrarySnapshot.Category? {
        snapshot?.categories.first { $0.id == id }
    }

    /// The phrase and the category that holds it.
    func phrase(_ id: UUID) -> (phrase: LibrarySnapshot.Phrase, category: LibrarySnapshot.Category)? {
        guard let snapshot, let location = snapshot.location(ofPhrase: id) else { return nil }
        let category = snapshot.categories[location.category]
        return (category.phrases[location.phrase], category)
    }

    /// Why `edit` would be refused on the library as last read, or nil
    /// where it would not: a control that would only be refused is dimmed
    /// in place, with this reason beside it. `restBoard` is as for
    /// `perform`.
    func refusal(of edit: LibraryEdit, restBoard: UUID?) -> String? {
        guard let snapshot else { return readFailure }
        do {
            _ = try edit.plan(in: snapshot, starter: starter, restBoard: restBoard)
            return nil
        } catch {
            return error.message
        }
    }
}

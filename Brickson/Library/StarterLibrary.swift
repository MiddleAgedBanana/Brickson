import Foundation
import OSLog
import SwiftData

/// The phrases a new library starts with, from the bundled
/// `StarterPhrases.json`, a file in the backup format (`BackupCodec`).
///
/// They are a starting point, not anyone's words. Everything the app ships
/// may be spoken in a person's own Personal Voice, so a starter phrase must be
/// something many people would choose to say themselves: never words about
/// their condition, never self-deprecation (invariant 7). Personal and
/// end-of-life phrases are the person's to write.
///
/// Every starter category and phrase has a fixed identity, so a backup, a
/// later "restore the starter phrases" or a replace can tell an untouched
/// starter phrase from the person's own words. An identity is never reused
/// for different words: a starter phrase whose wording changes in a later
/// version gets a new one (docs/DECISIONS.md, "Starter phrases").
nonisolated enum StarterLibrary {
    static let resourceName = "StarterPhrases"

    static func bundled(in bundle: Bundle = .main) throws -> LibrarySnapshot {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw StarterLibraryError.missingFromBundle
        }
        return try BackupCodec.decode(Data(contentsOf: url))
    }
}

nonisolated enum StarterLibraryError: Error, Equatable {
    case missingFromBundle
}

/// Why seeding stopped. Nothing was written.
nonisolated enum PhraseLibrarySeedError: Error, Equatable {
    /// The store could not be read, so whether it is empty is unknown.
    case storeUnreadable
    case saveFailed
}

/// Fills an empty library with the starter phrases.
enum PhraseLibrarySeeder {
    /// Seeds the store only when it holds no categories, and reports whether
    /// it did. An empty store is the only criterion: a stored "already
    /// seeded" flag can outlive the store (a lost file, the in-memory
    /// fallback) and must never leave someone with an empty board. Because
    /// the emergency category can never be deleted, editing cannot empty a
    /// library, so an empty store means a new install or a lost store
    /// (docs/DECISIONS.md, "The emergency category is always there").
    ///
    /// The work happens in a context of its own. If the save fails, that
    /// context is simply discarded: nothing reached the store, and no
    /// `rollback()` is needed (docs/LESSONS.md, "Never roll back a cascade
    /// delete").
    ///
    /// `readStore` and `save` exist so tests can make reading or saving
    /// fail; the app passes neither.
    @discardableResult
    static func seedIfEmpty(
        _ container: ModelContainer,
        with library: LibrarySnapshot,
        readStore: (ModelContext) throws -> LibrarySnapshot = { try StoredLibrary($0).snapshot },
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws(PhraseLibrarySeedError) -> Bool {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        // The whole library is read, not only counted: a store whose
        // categories read but whose phrases don't is unreadable too, and
        // must be reported rather than shown with phrases missing.
        let stored: LibrarySnapshot
        do {
            stored = try readStore(context)
        } catch {
            logger.error("The phrase library could not be read before seeding: \(error)")
            throw .storeUnreadable
        }
        guard stored.categories.isEmpty else { return false }
        do {
            try StoredLibrary(context).write(library, in: context)
            try save(context)
        } catch {
            logger.error("Starter phrases could not be saved: \(error)")
            throw .saveFailed
        }
        return true
    }

    private static let logger = Logger(subsystem: AppLog.subsystem, category: "library")
}

/// Readies the phrase library at launch. It fills the store it is given
/// with the starter phrases when that store is empty and, if the store
/// cannot be read or filled, falls back to a filled in-memory library: an
/// empty library would leave Emergency with nothing to open (invariant 2).
enum PhraseLibraryLaunch {
    struct Prepared {
        let container: ModelContainer
        /// True when nothing changed now will be kept. Home says so.
        let isVolatile: Bool
        let issue: PhraseLibraryIssue?
    }

    /// `issue` carries a problem found while opening the store
    /// (`PhraseLibraryStore.openForApp`). `starter`, `readStore`,
    /// `saveToStore` and `makeFallback` exist so tests can make each step
    /// fail; the app passes none of them.
    ///
    /// Whatever container it returns, its main context never saves by
    /// itself (docs/DECISIONS.md, "Every save is explicit").
    static func prepare(
        container: ModelContainer,
        isVolatile: Bool,
        issue: PhraseLibraryIssue? = nil,
        starter: () throws -> LibrarySnapshot = { try StarterLibrary.bundled() },
        readStore: (ModelContext) throws -> LibrarySnapshot = { try StoredLibrary($0).snapshot },
        saveToStore: (ModelContext) throws -> Void = { try $0.save() },
        makeFallback: () throws -> ModelContainer = { try PhraseLibraryStore.makeInMemoryContainer() }
    ) -> Prepared {
        let prepared = fill(
            container: container,
            isVolatile: isVolatile,
            issue: issue,
            starter: starter,
            readStore: readStore,
            saveToStore: saveToStore,
            makeFallback: makeFallback
        )
        // SwiftData turns autosave on for every main context. Home only
        // reads through it, and every edit is saved explicitly from a
        // context of its own, so nothing may save through it by surprise.
        prepared.container.mainContext.autosaveEnabled = false
        return prepared
    }

    private static func fill(
        container: ModelContainer,
        isVolatile: Bool,
        issue: PhraseLibraryIssue?,
        starter: () throws -> LibrarySnapshot,
        readStore: (ModelContext) throws -> LibrarySnapshot,
        saveToStore: (ModelContext) throws -> Void,
        makeFallback: () throws -> ModelContainer
    ) -> Prepared {
        let logger = Logger(subsystem: AppLog.subsystem, category: "library")
        let library: LibrarySnapshot
        do {
            library = try starter()
        } catch {
            // Only a broken build gets here: StarterPhrasesTests decodes the
            // bundled file.
            logger.error("Starter phrases could not be read: \(error)")
            return Prepared(container: container, isVolatile: isVolatile, issue: issue ?? .starterPhrasesUnavailable)
        }
        let fallbackIssue: PhraseLibraryIssue?
        do throws(PhraseLibrarySeedError) {
            try PhraseLibrarySeeder.seedIfEmpty(
                container,
                with: library,
                readStore: readStore,
                save: saveToStore
            )
            return Prepared(container: container, isVolatile: isVolatile, issue: issue)
        } catch {
            switch error {
            case .storeUnreadable:
                // The store opened but its phrases could not be read. They
                // may still be there: say so, and never write over them.
                fallbackIssue = .libraryUnreadable
            case .saveFailed:
                // The store opened but could not be filled (a full disk,
                // say). It held no categories, so nobody's words are
                // involved.
                fallbackIssue = issue
            }
        }
        // Speak from a filled in-memory library instead, and say that
        // changes will not be kept.
        do {
            let fallback = try makeFallback()
            try PhraseLibrarySeeder.seedIfEmpty(fallback, with: library)
            return Prepared(container: fallback, isVolatile: true, issue: fallbackIssue)
        } catch {
            logger.error("The in-memory starter library failed too: \(error)")
            return Prepared(container: container, isVolatile: isVolatile, issue: fallbackIssue ?? .starterPhrasesUnavailable)
        }
    }
}

/// Why the phrase library could not be prepared at launch. Shown on Home;
/// Yes and No keep working without it.
nonisolated enum PhraseLibraryIssue: Equatable, Sendable {
    case starterPhrasesUnavailable
    /// Saved phrases exist but could not be opened or read (a damaged file,
    /// or a store written by a newer version). Brickson never deletes or
    /// replaces them: it speaks from starter phrases in memory, and tries
    /// the store again at the next launch. The obvious fix, deleting and
    /// reinstalling the app, would erase them, so the message warns
    /// against it (docs/DECISIONS.md, "An unreadable library is reported,
    /// never replaced").
    case libraryUnreadable

    var message: String {
        switch self {
        case .starterPhrasesUnavailable:
            String(localized: "The starter phrases couldn't be loaded. Yes and No still work. Restart the app to try again.")
        case .libraryUnreadable:
            String(localized: "Your saved phrases couldn't be opened. They haven't been deleted. Restart the app to try again. Don't delete the app: that would erase them.")
        }
    }
}

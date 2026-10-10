import Foundation
import OSLog
import SwiftData

/// The phrases a new library starts with, decoded from the bundled
/// `StarterPhrases.json`.
///
/// They are a starting point, not anyone's words. Everything the app ships
/// may be spoken in a person's own Personal Voice, so a starter phrase must be
/// something many people would choose to say themselves: never words about
/// their condition, never self-deprecation (invariant 7). Personal and
/// end-of-life phrases are the person's to write.
nonisolated struct StarterLibrary: Codable, Equatable, Sendable {
    nonisolated struct Category: Codable, Equatable, Sendable {
        let name: String
        let symbolName: String
        let isEmergency: Bool
        let phrases: [String]
    }

    let categories: [Category]

    static let resourceName = "StarterPhrases"

    static func bundled(in bundle: Bundle = .main) throws -> StarterLibrary {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw StarterLibraryError.missingFromBundle
        }
        return try JSONDecoder().decode(StarterLibrary.self, from: Data(contentsOf: url))
    }
}

nonisolated enum StarterLibraryError: Error, Equatable {
    case missingFromBundle
}

/// Fills an empty library with the starter phrases.
enum PhraseLibrarySeeder {
    /// Seeds the store only when it holds no categories, and reports whether
    /// it did. An empty store is the only criterion: a stored "already
    /// seeded" flag can outlive the store (a lost file, the in-memory
    /// fallback) and must never leave someone with an empty board.
    ///
    /// The work happens in a context of its own. If the save fails, that
    /// context is simply discarded: nothing reached the store, and no
    /// `rollback()` is needed (docs/LESSONS.md, "Never roll back a cascade
    /// delete").
    ///
    /// `save` exists so tests can make the save fail; the app never passes it.
    @discardableResult
    static func seedIfEmpty(
        _ container: ModelContainer,
        with library: StarterLibrary,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> Bool {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        guard try context.fetchCount(FetchDescriptor<PhraseCategory>()) == 0 else {
            return false
        }
        for (categoryIndex, starter) in library.categories.enumerated() {
            let category = PhraseCategory(
                name: starter.name,
                symbolName: starter.symbolName,
                sortOrder: categoryIndex,
                isEmergency: starter.isEmergency
            )
            context.insert(category)
            for (phraseIndex, text) in starter.phrases.enumerated() {
                context.insert(Phrase(text: text, sortOrder: phraseIndex, category: category))
            }
        }
        try save(context)
        return true
    }
}

/// Readies the phrase library at launch. It fills the store it is given
/// with the starter phrases when that store is empty and, if the store
/// cannot be filled, falls back to a filled in-memory library: an empty
/// library would leave Emergency with nothing to open (invariant 2).
enum PhraseLibraryLaunch {
    struct Prepared {
        let container: ModelContainer
        /// True when nothing changed now will be kept. Home says so.
        let isVolatile: Bool
        let issue: PhraseLibraryIssue?
    }

    /// `starter`, `saveToStore` and `makeFallback` exist so tests can make
    /// each step fail; the app passes none of them.
    static func prepare(
        container: ModelContainer,
        isVolatile: Bool,
        starter: () throws -> StarterLibrary = { try StarterLibrary.bundled() },
        saveToStore: (ModelContext) throws -> Void = { try $0.save() },
        makeFallback: () throws -> ModelContainer = { try PhraseLibraryStore.makeInMemoryContainer() }
    ) -> Prepared {
        let logger = Logger(subsystem: AppLog.subsystem, category: "library")
        let library: StarterLibrary
        do {
            library = try starter()
        } catch {
            // Only a broken build gets here: StarterPhrasesTests decodes the
            // bundled file.
            logger.error("Starter phrases could not be read: \(error)")
            return Prepared(container: container, isVolatile: isVolatile, issue: .starterPhrasesUnavailable)
        }
        do {
            try PhraseLibrarySeeder.seedIfEmpty(container, with: library, save: saveToStore)
            return Prepared(container: container, isVolatile: isVolatile, issue: nil)
        } catch {
            logger.error("Starter phrases could not be saved, using memory: \(error)")
        }
        // The store opened but could not be filled (a full disk, say). Speak
        // from a filled in-memory library instead, and say that changes will
        // not be kept.
        do {
            let fallback = try makeFallback()
            try PhraseLibrarySeeder.seedIfEmpty(fallback, with: library)
            return Prepared(container: fallback, isVolatile: true, issue: nil)
        } catch {
            logger.error("The in-memory starter library failed too: \(error)")
            return Prepared(container: container, isVolatile: isVolatile, issue: .starterPhrasesUnavailable)
        }
    }
}

/// Why the phrase library could not be prepared at launch. Shown on Home;
/// Yes and No keep working without it.
nonisolated enum PhraseLibraryIssue: Equatable, Sendable {
    case starterPhrasesUnavailable

    var message: String {
        switch self {
        case .starterPhrasesUnavailable:
            String(localized: "The starter phrases couldn't be loaded. Yes and No still work. Restart the app to try again.")
        }
    }
}

import Foundation
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

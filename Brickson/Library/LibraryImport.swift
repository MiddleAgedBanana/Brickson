import Foundation

/// How a backup's library is brought into this one (docs/DECISIONS.md,
/// "Importing a backup").
///
/// Import is not editing. It never renames, trims or rewrites a word, and
/// the editor's rules (duplicate names, reserved names, the symbol list) do
/// not apply: a backup's words come in exactly as they are (invariant 7).
/// What import does enforce is structure the app depends on, and it does
/// that only by adding:
///
/// - phrases with nothing to say (empty, or only spaces and line breaks)
///   are skipped: they have no words to lose and would be blank tiles;
/// - a phrase whose exact words are already in its category is skipped,
///   which is what makes importing the same backup twice add nothing;
/// - every emergency category in the backup feeds the one emergency
///   category, so there is always exactly one;
/// - identities stay unique: an incoming item whose identity is taken gets
///   a new one.
nonisolated enum LibraryImport {
    /// Adds what `incoming` has that `library` lacks. Nothing already in
    /// `library` is moved, renamed, changed or deleted: new categories go
    /// after the existing ones, and new phrases after the existing phrases
    /// of their category.
    ///
    /// An incoming category goes to the local category with the same
    /// identity (if both are, or both are not, the emergency category);
    /// otherwise an emergency category goes to the local emergency
    /// category; otherwise a category goes to a local category of the same
    /// kind whose name matches (`LibraryText.nameKey`), so two family-made
    /// "Needs" categories from two devices end as one. Anything else is
    /// added as a new category.
    static func merge(
        _ incoming: LibrarySnapshot,
        into library: LibrarySnapshot,
        makeID: () -> UUID
    ) -> (library: LibrarySnapshot, report: LibraryImportReport) {
        var result = library
        var report = LibraryImportReport()
        var ids = LibraryIDs(library)
        // Phrases already in the library, by identity: an incoming phrase
        // with the same identity and the same words is the same phrase,
        // even if it has since been moved to another category here.
        var knownPhrases: [UUID: [UInt8]] = [:]
        for category in library.categories {
            for phrase in category.phrases {
                knownPhrases[phrase.id] = Array(phrase.text.utf8)
            }
        }

        for incomingCategory in incoming.categories {
            let target: Int
            if let match = matchingCategory(for: incomingCategory, in: result) {
                target = match
            } else {
                result.categories.append(LibrarySnapshot.Category(
                    id: ids.categoryID(preferring: incomingCategory.id, makeID),
                    name: incomingCategory.name,
                    symbolName: incomingCategory.symbolName,
                    isEmergency: incomingCategory.isEmergency,
                    phrases: []
                ))
                target = result.categories.endIndex - 1
            }

            for phrase in incomingCategory.phrases {
                let bytes = Array(phrase.text.utf8)
                if LibraryText.isBlank(phrase.text) {
                    report.blankPhrasesSkipped += 1
                    continue
                }
                let alreadyThere = result.categories[target].phrases.contains {
                    LibraryText.sameBytes($0.text, phrase.text)
                }
                if alreadyThere || knownPhrases[phrase.id] == bytes {
                    report.phrasesAlreadyThere += 1
                    continue
                }
                let id = ids.phraseID(preferring: phrase.id, makeID)
                if id != phrase.id {
                    // The same identity with different words: the local
                    // phrase stays as it is, and these words are added.
                    report.phrasesGivenNewIdentity += 1
                }
                knownPhrases[id] = bytes
                result.categories[target].phrases.append(LibrarySnapshot.Phrase(id: id, text: phrase.text))
            }
        }
        return (result, report)
    }

    /// Makes the library match `incoming`: its categories and phrases, in
    /// its order, with its identities. Exact duplicates and blank phrases
    /// are dropped as in `merge` (it is a merge into an empty library), so
    /// a backup Brickson wrote comes back exactly as it was.
    ///
    /// Emergency keeps working: if the backup has no emergency phrases, the
    /// current emergency category's phrases are kept.
    ///
    /// Whether the current library holds words the person would lose, and
    /// so needs a safety copy first, is decided by `LibraryEdit.plan`.
    static func replace(
        _ library: LibrarySnapshot,
        with incoming: LibrarySnapshot,
        makeID: () -> UUID
    ) -> (library: LibrarySnapshot, report: LibraryImportReport) {
        var (result, report) = merge(incoming, into: .empty, makeID: makeID)
        if !result.keepsEmergencyWorking,
           let current = library.categories.first(where: \.isEmergency),
           !current.phrases.isEmpty {
            let kept = merge(LibrarySnapshot(categories: [current]), into: result, makeID: makeID)
            result = kept.library
            report.keptCurrentEmergencyPhrases = true
        }
        return (result, report)
    }

    private static func matchingCategory(
        for incoming: LibrarySnapshot.Category,
        in library: LibrarySnapshot
    ) -> Int? {
        if let index = library.categories.firstIndex(where: {
            $0.id == incoming.id && $0.isEmergency == incoming.isEmergency
        }) {
            return index
        }
        if incoming.isEmergency {
            return library.categories.firstIndex(where: \.isEmergency)
        }
        let key = LibraryText.nameKey(incoming.name)
        return library.categories.firstIndex {
            !$0.isEmergency && LibraryText.nameKey($0.name) == key
        }
    }
}

/// What an import did besides adding, for the summary a family reads
/// before and after they confirm.
nonisolated struct LibraryImportReport: Equatable, Sendable {
    /// Phrases whose exact words were already in their category.
    var phrasesAlreadyThere = 0
    /// Phrases with nothing to say.
    var blankPhrasesSkipped = 0
    /// Phrases added under a new identity because theirs was taken by a
    /// phrase with different words.
    var phrasesGivenNewIdentity = 0
    /// A replace kept the current emergency phrases because the backup had
    /// none.
    var keptCurrentEmergencyPhrases = false
}

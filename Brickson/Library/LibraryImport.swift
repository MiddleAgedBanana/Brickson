import Foundation

/// How a backup's library is brought into this one (docs/DECISIONS.md,
/// "Importing a backup").
///
/// Import is not editing. It never renames, trims or rewrites a word, and
/// the editor's rules (duplicate names, reserved names, the symbol list) do
/// not apply: a backup's words come in exactly as they are, byte for byte
/// (invariant 7). What import does enforce is structure the app depends
/// on, and it does that only by adding:
///
/// - a phrase with no characters at all is skipped: it has no words to
///   lose. Anything else, even only spaces, comes in as it is;
/// - every emergency category in the backup feeds the one emergency
///   category, so there is always exactly one. This is the one place a
///   backup's category name can be left out: the emergency category has no
///   button of its own, and keeps its local name;
/// - identities stay unique: an incoming item whose identity is taken gets
///   a new one.
nonisolated enum LibraryImport {
    /// Adds what `incoming` has that `library` lacks. Nothing already in
    /// `library` is moved, renamed, changed or deleted: new categories go
    /// after the existing ones, and new phrases after the existing phrases
    /// of their category.
    ///
    /// An incoming category joins a local category only when their names
    /// are the same, byte for byte: first the one with the same identity,
    /// then any other of the same kind, so two family-made "Needs"
    /// categories from two devices end as one. An emergency category joins
    /// the local emergency category whatever its name. Anything else, a
    /// renamed category included, is added as a new category, so no name in
    /// the backup is lost.
    ///
    /// An incoming phrase is skipped when its exact words were already in
    /// that category before this import, or when the library already has a
    /// phrase with its identity and words (moved elsewhere since). That is
    /// what makes importing the same backup twice add nothing, while a
    /// backup that says the same thing twice in one category keeps both.
    static func merge(
        _ incoming: LibrarySnapshot,
        into library: LibrarySnapshot,
        makeID: () -> UUID
    ) -> (library: LibrarySnapshot, report: LibraryImportReport) {
        var result = library
        var report = LibraryImportReport()
        var ids = LibraryIDs(library)
        var knownPhrases: [UUID: [UInt8]] = [:]
        var wordsBefore: [UUID: Set<[UInt8]>] = [:]
        for category in library.categories {
            for phrase in category.phrases {
                knownPhrases[phrase.id] = Array(phrase.text.utf8)
            }
            wordsBefore[category.id, default: []].formUnion(category.phrases.map { Array($0.text.utf8) })
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
            let existing = wordsBefore[result.categories[target].id] ?? []

            for phrase in incomingCategory.phrases {
                if phrase.text.isEmpty {
                    report.emptyPhrasesSkipped += 1
                    continue
                }
                let bytes = Array(phrase.text.utf8)
                if existing.contains(bytes) || knownPhrases[phrase.id] == bytes {
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
    /// its order, with its identities, its names and its repeats. Only a
    /// phrase with no characters is skipped, several emergency categories
    /// become one (in the first one's place), and a repeated identity gets
    /// a new one, so a backup Brickson wrote comes back exactly as it was.
    ///
    /// Emergency keeps working: if the backup's emergency category has no
    /// phrase with words in it, the current emergency phrases are added to
    /// it (or kept as the emergency category, if the backup has none).
    ///
    /// Whether the current library holds words the person would lose is
    /// decided by `LibraryEdit.plan`.
    static func replace(
        _ library: LibrarySnapshot,
        with incoming: LibrarySnapshot,
        makeID: () -> UUID
    ) -> (library: LibrarySnapshot, report: LibraryImportReport) {
        var result = LibrarySnapshot.empty
        var report = LibraryImportReport()
        var ids = LibraryIDs(.empty)
        var emergency: Int?

        func phrases(_ phrases: [LibrarySnapshot.Phrase], counted: Bool) -> [LibrarySnapshot.Phrase] {
            phrases.compactMap { phrase in
                if phrase.text.isEmpty {
                    if counted { report.emptyPhrasesSkipped += 1 }
                    return nil
                }
                let id = ids.phraseID(preferring: phrase.id, makeID)
                if counted, id != phrase.id { report.phrasesGivenNewIdentity += 1 }
                return LibrarySnapshot.Phrase(id: id, text: phrase.text)
            }
        }

        for category in incoming.categories {
            let kept = phrases(category.phrases, counted: true)
            if category.isEmergency, let emergency {
                result.categories[emergency].phrases += kept
                continue
            }
            result.categories.append(LibrarySnapshot.Category(
                id: ids.categoryID(preferring: category.id, makeID),
                name: category.name,
                symbolName: category.symbolName,
                isEmergency: category.isEmergency,
                phrases: kept
            ))
            if category.isEmergency { emergency = result.categories.endIndex - 1 }
        }

        let emergencyHasWords = emergency.map { index in
            result.categories[index].phrases.contains { !LibraryText.isBlank($0.text) }
        } ?? false
        if !emergencyHasWords,
           let current = library.categories.first(where: \.isEmergency),
           !current.phrases.isEmpty {
            let kept = phrases(current.phrases, counted: false)
            if let emergency {
                result.categories[emergency].phrases += kept
            } else {
                result.categories.append(LibrarySnapshot.Category(
                    id: ids.categoryID(preferring: current.id, makeID),
                    name: current.name,
                    symbolName: current.symbolName,
                    isEmergency: true,
                    phrases: kept
                ))
            }
            report.keptCurrentEmergencyPhrases = true
        }
        return (result, report)
    }

    private static func matchingCategory(
        for incoming: LibrarySnapshot.Category,
        in library: LibrarySnapshot
    ) -> Int? {
        if incoming.isEmergency {
            return library.categories.firstIndex(where: \.isEmergency)
        }
        let sameName = { (category: LibrarySnapshot.Category) in
            !category.isEmergency && LibraryText.sameBytes(category.name, incoming.name)
        }
        if let index = library.categories.firstIndex(where: { $0.id == incoming.id && sameName($0) }) {
            return index
        }
        return library.categories.firstIndex(where: sameName)
    }
}

/// What an import did besides adding, for the summary a family reads
/// before and after they confirm.
nonisolated struct LibraryImportReport: Equatable, Sendable {
    /// Phrases whose exact words were already in their category.
    var phrasesAlreadyThere = 0
    /// Phrases with no characters at all.
    var emptyPhrasesSkipped = 0
    /// Phrases added under a new identity because theirs was taken by a
    /// phrase with different words.
    var phrasesGivenNewIdentity = 0
    /// A replace kept the current emergency phrases because the backup had
    /// none.
    var keptCurrentEmergencyPhrases = false
}

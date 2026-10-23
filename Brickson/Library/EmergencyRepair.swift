import Foundation

/// What a damaged library needs so that Emergency has something to say, and
/// the library with it added (docs/DECISIONS.md, "The emergency category is
/// always there").
///
/// No edit can remove the emergency category or its last phrase with words,
/// so a library that has lost them has been damaged: a file changed outside
/// the app, say, or a migration gone wrong. Home's Emergency control would
/// then have nothing to open (invariant 2). The repair adds the bundled
/// starter emergency phrases, which are neutral words anyone might choose,
/// and it only adds: nothing already in the library is deleted, moved,
/// renamed or rewritten, the person's own words above all (invariant 7).
///
/// Plain values, no SwiftData: `PhraseLibraryRepairer` reads the store,
/// asks `needed(in:starter:makeID:)`, and inserts what it says.
nonisolated struct EmergencyRepair: Equatable, Sendable {
    /// Where the added phrases go.
    nonisolated enum Place: Equatable, Sendable {
        /// The library has no emergency category: a new one, after all the
        /// others.
        case newCategory(id: UUID, name: String, symbolName: String)
        /// The emergency category Home opens (the first one, at this index
        /// in the library) has no phrase with words: after its own phrases.
        case existingCategory(at: Int)
    }

    let place: Place
    /// The starter emergency phrases, with the starter's identities where
    /// they are free.
    let phrases: [LibrarySnapshot.Phrase]
    /// The library with the phrases added. Everything that was there is
    /// unchanged and in its place.
    let repaired: LibrarySnapshot

    /// The repair `library` needs, or nil when Emergency already has
    /// something to say.
    ///
    /// Only the emergency category Home opens counts: the first one in the
    /// library's order (`CategorySelection.emergency`). A second emergency
    /// category is left as it is, because nothing shows it. An empty
    /// library needs nothing here: the seeder fills it with the whole
    /// starter library. Nil too when `starter` has no emergency phrase with
    /// words, because the repair never adds words of its own.
    ///
    /// The added items keep the starter's identities where no item in
    /// `library` uses them, so they count as untouched starter phrases, not
    /// the person's words (`LibrarySnapshot.ownWords(comparedWith:)`); a
    /// taken identity is replaced with one from `makeID`.
    static func needed(
        in library: LibrarySnapshot,
        starter: LibrarySnapshot,
        makeID: () -> UUID = { UUID() }
    ) -> EmergencyRepair? {
        guard !library.categories.isEmpty,
              let source = starter.categories.first(where: \.isEmergency) else { return nil }
        let words = source.phrases.filter { !LibraryText.isBlank($0.text) }
        guard !words.isEmpty else { return nil }

        var ids = LibraryIDs(library)
        var repaired = library
        let place: Place
        if let index = library.categories.firstIndex(where: \.isEmergency) {
            guard !library.categories[index].phrases.contains(where: { !LibraryText.isBlank($0.text) }) else {
                return nil
            }
            place = .existingCategory(at: index)
        } else {
            let id = ids.categoryID(preferring: source.id, makeID)
            place = .newCategory(id: id, name: source.name, symbolName: source.symbolName)
            repaired.categories.append(LibrarySnapshot.Category(
                id: id,
                name: source.name,
                symbolName: source.symbolName,
                isEmergency: true,
                phrases: []
            ))
        }
        let phrases = words.map { phrase in
            LibrarySnapshot.Phrase(id: ids.phraseID(preferring: phrase.id, makeID), text: phrase.text)
        }
        switch place {
        case let .existingCategory(at: index):
            repaired.categories[index].phrases += phrases
        case .newCategory:
            repaired.categories[repaired.categories.endIndex - 1].phrases = phrases
        }
        return EmergencyRepair(place: place, phrases: phrases, repaired: repaired)
    }
}

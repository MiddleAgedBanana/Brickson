import Foundation

/// What a damaged library needs so that Emergency has something to say, and
/// the library with it added (docs/DECISIONS.md, "The emergency category is
/// always there").
///
/// No edit can remove the emergency category or its last phrase with words,
/// so a library that has lost them has been damaged: a file changed outside
/// the app, say, or a migration gone wrong. Home's Emergency control would
/// then have nothing to open (invariant 2). The repair adds the bundled
/// starter emergency phrases, which are neutral words anyone might choose.
/// Nothing already in the library is deleted, moved, renamed or rewritten,
/// the person's own words above all (invariant 7). The one stored thing it
/// may change is an identity nobody sees (`newIdentity`).
///
/// Plain values, no SwiftData: `PhraseLibraryRepairer` reads the store,
/// asks `needed(in:starter:makeID:)`, and writes what it says.
nonisolated struct EmergencyRepair: Equatable, Sendable {
    /// Where the added phrases go.
    nonisolated enum Place: Equatable, Sendable {
        /// The library has no emergency category: a new one, after all the
        /// others.
        case newCategory(id: UUID, name: String, symbolName: String)
        /// The emergency category Home opens (the first one, at this index
        /// in the library): after its own phrases.
        case existingCategory(at: Int)
    }

    let place: Place
    /// A new identity for the emergency category at `place`, when an
    /// earlier category already uses its own. Home finds the category it
    /// shows by identity (`CategorySelection.resolve`), so until then
    /// Emergency opens that earlier category's phrases. Nil when its
    /// identity is its own.
    let newIdentity: UUID?
    /// The starter emergency phrases, with the starter's identities where
    /// they are free. Empty when the emergency category already has words
    /// and only needs `newIdentity`.
    let phrases: [LibrarySnapshot.Phrase]
    /// The library after the repair. Everything that was there is in its
    /// place with its words unchanged.
    let repaired: LibrarySnapshot

    /// How many new identities `needed(in:starter:makeID:)` tries before it
    /// keeps the old one (`identity(replacing:in:ids:makeID:)`).
    static let identityAttempts = 64

    /// The repair `library` needs, or nil when Emergency already opens
    /// something to say.
    ///
    /// Only the emergency category Home opens counts: the first one in the
    /// library's order (`CategorySelection.emergency`). A second emergency
    /// category is left as it is, because nothing shows it. It needs the
    /// starter emergency phrases when it has no phrase with words, and a
    /// new identity when an earlier category shares its own; a missing one
    /// is added after all the others. An empty library needs nothing here:
    /// the seeder fills it with the whole starter library. The repair never
    /// adds words of its own, so with no emergency phrase with words in
    /// `starter` it adds none.
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
        guard !library.categories.isEmpty else { return nil }
        let source = starter.categories.first(where: \.isEmergency)
        let words = source?.phrases.filter { !LibraryText.isBlank($0.text) } ?? []

        var ids = LibraryIDs(library)
        var repaired = library
        let place: Place
        var newIdentity: UUID?
        var phrases: [LibrarySnapshot.Phrase] = []

        if let index = library.categories.firstIndex(where: \.isEmergency) {
            let category = library.categories[index]
            if library.categories[..<index].contains(where: { $0.id == category.id }) {
                newIdentity = identity(replacing: index, in: library, ids: &ids, makeID: makeID)
            }
            if !category.phrases.contains(where: { !LibraryText.isBlank($0.text) }) {
                phrases = words.map { LibrarySnapshot.Phrase(id: ids.phraseID(preferring: $0.id, makeID), text: $0.text) }
            }
            guard newIdentity != nil || !phrases.isEmpty else { return nil }
            place = .existingCategory(at: index)
            if let newIdentity {
                repaired.categories[index].id = newIdentity
            }
            repaired.categories[index].phrases += phrases
        } else {
            guard let source, !words.isEmpty else { return nil }
            let id = ids.categoryID(preferring: source.id, makeID)
            place = .newCategory(id: id, name: source.name, symbolName: source.symbolName)
            phrases = words.map { LibrarySnapshot.Phrase(id: ids.phraseID(preferring: $0.id, makeID), text: $0.text) }
            repaired.categories.append(LibrarySnapshot.Category(
                id: id,
                name: source.name,
                symbolName: source.symbolName,
                isEmergency: true,
                phrases: phrases
            ))
        }
        return EmergencyRepair(place: place, newIdentity: newIdentity, phrases: phrases, repaired: repaired)
    }

    /// A new identity for the category at `index` that keeps it in its
    /// place, or nil if none of `identityAttempts` tries does.
    ///
    /// The display order puts categories with the same sort order and name
    /// in the order of their identities (`PhraseCategory.orderedForDisplay`).
    /// A snapshot holds no sort orders, so against every other category with
    /// the same name the new identity must sort as the old one did: after
    /// those before it, before those after it. Only a store made so that no
    /// identity fits gives nil. Brickson keeps identities unique, so none
    /// of its own stores gets here.
    private static func identity(
        replacing index: Int,
        in library: LibrarySnapshot,
        ids: inout LibraryIDs,
        makeID: () -> UUID
    ) -> UUID? {
        let name = library.categories[index].name
        let sameName = library.categories.indices.filter { $0 != index && library.categories[$0].name == name }
        for _ in 0..<identityAttempts {
            let id = ids.newCategoryID(makeID)
            let keepsPlace = sameName.allSatisfy { other in
                (library.categories[other].id.uuidString < id.uuidString) == (other < index)
            }
            if keepsPlace { return id }
        }
        return nil
    }
}

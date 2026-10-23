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
/// the person's own words above all (invariant 7). The only stored things
/// it may change are an identity nobody sees (`newIdentity`) and sort
/// orders renumbered in the order they are shown, which shows everything
/// exactly as before: where a hand-edited store leaves no room after its
/// last sort order (`sortOrders(adding:after:)`), and where no new identity
/// would keep the emergency category in its place (`renumberedCategories`).
///
/// Plain values, no SwiftData: `PhraseLibraryRepairer` reads the store,
/// asks `needed(in:sortOrders:starter:makeID:)`, and writes what it says.
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
    /// Sort orders for the library's categories, in the order they are
    /// shown, when none of the new identities tried keeps the emergency
    /// category in its place among categories with its sort order and
    /// name (`identity(replacing:in:sortOrders:ids:makeID:)`): 0, 1, 2 in
    /// the order they are shown, which shows them exactly as before and
    /// leaves no two ordered by identity, so `newIdentity` keeps its place
    /// whatever it is. Nil otherwise, which is almost always.
    let renumberedCategories: [Int]?
    /// The starter emergency phrases, with the starter's identities where
    /// they are free. Empty when the emergency category already has words
    /// and only needs `newIdentity`.
    let phrases: [LibrarySnapshot.Phrase]
    /// The library after the repair. Everything that was there is in its
    /// place with its words unchanged.
    let repaired: LibrarySnapshot

    /// How many new identities `needed(in:sortOrders:starter:makeID:)`
    /// tries before it renumbers the categories instead
    /// (`renumberedCategories`).
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
    ///
    /// `sortOrders` are the stored sort orders of `library`'s categories,
    /// in the same order. Without them (nil, or not one for each category)
    /// every category is taken to share one, which can only make a new
    /// identity harder to find.
    static func needed(
        in library: LibrarySnapshot,
        sortOrders: [Int]? = nil,
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
        var renumberedCategories: [Int]?
        var phrases: [LibrarySnapshot.Phrase] = []

        if let index = library.categories.firstIndex(where: \.isEmergency) {
            let category = library.categories[index]
            if library.categories[..<index].contains(where: { $0.id == category.id }) {
                newIdentity = identity(
                    replacing: index,
                    in: library,
                    sortOrders: sortOrders?.count == library.categories.count ? sortOrders : nil,
                    ids: &ids,
                    makeID: makeID
                )
                if newIdentity == nil {
                    renumberedCategories = Array(library.categories.indices)
                    newIdentity = ids.newCategoryID(makeID)
                }
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
        return EmergencyRepair(
            place: place,
            newIdentity: newIdentity,
            renumberedCategories: renumberedCategories,
            phrases: phrases,
            repaired: repaired
        )
    }

    /// A new identity for the emergency category at `index` that keeps it in
    /// its place and keeps it the first emergency category, or nil if none
    /// of `identityAttempts` tries does, and the categories must be
    /// renumbered instead (`renumberedCategories`).
    ///
    /// The display order compares sort orders, then names, then identities
    /// (`PhraseCategory.orderedForDisplay`), so only a category with the
    /// same sort order and name is ordered against it by identity. Against
    /// each of those the new identity must sort as the old one did: after
    /// those before it, before those after it. One that has the old
    /// identity as well was never ordered against it at all, so the new
    /// identity may put it on either side, except that another emergency
    /// category must stay after it. Those around it can leave too little
    /// room for a random identity to land in, or none at all, in a store
    /// damaged twice over: one category sharing the emergency category's
    /// identity, and others sharing its sort order and name. Brickson keeps
    /// identities and sort orders unique, so none of its own stores gets
    /// here.
    private static func identity(
        replacing index: Int,
        in library: LibrarySnapshot,
        sortOrders: [Int]?,
        ids: inout LibraryIDs,
        makeID: () -> UUID
    ) -> UUID? {
        let category = library.categories[index]
        let old = category.id.uuidString
        let tied = library.categories.indices.filter { other in
            other != index
                && library.categories[other].name == category.name
                && sortOrders.map { $0[other] == $0[index] } ?? true
        }
        for _ in 0..<identityAttempts {
            let id = ids.newCategoryID(makeID)
            let new = id.uuidString
            let keepsPlace = tied.allSatisfy { other in
                let otherCategory = library.categories[other]
                let theirs = otherCategory.id.uuidString
                if theirs == old {
                    return !otherCategory.isEmergency || new < old
                }
                return (theirs < new) == (other < index)
            }
            if keepsPlace { return id }
        }
        return nil
    }

    /// Sort orders that put `count` new items after existing ones whose
    /// sort orders, in the order they are shown, are `orders`.
    ///
    /// Normally the existing ones keep theirs (`renumbered` is nil) and the
    /// new ones follow the largest. A hand-edited store can leave no room
    /// after it, up to `Int.max`; then the existing ones are renumbered 0,
    /// 1, 2 in the order they are shown, which shows them exactly as
    /// before, and the new ones follow. Nothing ever moves.
    static func sortOrders(adding count: Int, after orders: [Int]) -> (renumbered: [Int]?, added: [Int]) {
        guard let last = orders.max() else { return (nil, Array(0..<count)) }
        if last <= Int.max - count {
            return (nil, (0..<count).map { last + 1 + $0 })
        }
        return (Array(orders.indices), (0..<count).map { orders.count + $0 })
    }
}

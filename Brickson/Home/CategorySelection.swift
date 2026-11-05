import Foundation

/// Which category Home shows. Plain logic, kept out of the view so it can be
/// tested.
enum CategorySelection {
    /// The chosen category if it still exists; otherwise the first category
    /// that is not the emergency one (people start with everyday phrases);
    /// otherwise whatever exists. `categories` must already be in display
    /// order (`PhraseCategory.orderedForDisplay`).
    static func resolve(_ categories: [PhraseCategory], selectedID: UUID?) -> PhraseCategory? {
        if let selectedID, let chosen = categories.first(where: { $0.uuid == selectedID }) {
            return chosen
        }
        return categories.first { !$0.isEmergency } ?? categories.first
    }

    /// Which category Home shows. On the rest board whose category is
    /// `restBoard` (docs/DECISIONS.md, "The late-stage profile"):
    /// Emergency's where Emergency was chosen, otherwise the board's. Every
    /// other category is dimmed there, so none can be chosen; a board no
    /// longer in the library shows as every category does.
    ///
    /// With no board, as `resolve(_:selectedID:)` among the categories Home
    /// offers (`isOffered`): a category with fewer phrases than the widest
    /// grid has columns is dimmed, so it is never shown, even when it was
    /// chosen before it lost a phrase or came from a backup; Home shows the
    /// first everyday category it offers, then Emergency's (docs/DECISIONS.md,
    /// "Four phrases in every category"). Only a damaged library that
    /// offers nothing at all falls back to every category.
    static func resolve(
        _ categories: [PhraseCategory],
        selectedID: UUID?,
        restBoard: UUID?,
        phraseCounts: [UUID: Int]
    ) -> PhraseCategory? {
        guard let restBoard, let board = categories.first(where: { $0.uuid == restBoard && !$0.isEmergency }) else {
            let offered = categories.filter { isOffered($0, phraseCounts: phraseCounts) }
            return resolve(offered, selectedID: selectedID) ?? resolve(categories, selectedID: selectedID)
        }
        if let emergency = emergency(in: categories), emergency.uuid == selectedID {
            return emergency
        }
        return board
    }

    /// What the rest board needs to know of the library, in Home's order
    /// (`RestBoard`).
    static func restBoardLibrary(_ categories: [PhraseCategory]) -> [RestBoard.Category] {
        categories.map { RestBoard.Category(id: $0.uuid, isEmergency: $0.isEmergency, phrases: $0.phrases?.count ?? 0) }
    }

    /// The phrases Home shows for the category `id`, in their fixed order,
    /// as values, read from every phrase Home's query of phrases returned
    /// (`HomeView`). Nil for no category.
    ///
    /// Home does not read a category's phrases through the category: the
    /// Library saves each edit in a context of its own, and on CI's iPad
    /// (2026-11-05) Home's category kept a phrase's old words and place
    /// after an edit saved there, until the app was opened again. A query
    /// of phrases is read again whenever a phrase changes, and values
    /// redraw the grid where the same phrase objects would not.
    static func phrases(of id: UUID?, in phrases: [Phrase]) -> [LibrarySnapshot.Phrase]? {
        guard let id else { return nil }
        return Phrase.orderedForDisplay(phrases.filter { $0.category?.uuid == id })
            .map { LibrarySnapshot.Phrase(id: $0.uuid, text: $0.text) }
    }

    /// How many phrases each category holds, by its `uuid`, from the same
    /// query of phrases. A phrase in no category counts for none.
    static func phraseCounts(_ phrases: [Phrase]) -> [UUID: Int] {
        phrases.reduce(into: [:]) { counts, phrase in
            if let id = phrase.category?.uuid {
                counts[id, default: 0] += 1
            }
        }
    }

    /// Whether Home offers `category`: Emergency always (the Emergency
    /// control opens it from every state, invariant 2), an everyday
    /// category only while it has at least `LibraryRules.fewestPhrases`
    /// phrases. Home dims one it does not offer, as it dims the rest
    /// board's other categories: its grid would leave empty cells beside
    /// the categories and the controls that take their place while typing,
    /// where a resting look would meet them (invariant 10; docs/DECISIONS.md,
    /// "Four phrases in every category"). `phraseCounts` comes from
    /// `phraseCounts(_:)`.
    static func isOffered(_ category: PhraseCategory, phraseCounts: [UUID: Int]) -> Bool {
        category.isEmergency || LibraryRules.homeOffers(phrases: phraseCounts[category.uuid] ?? 0)
    }

    /// Whether Home dims `category`'s button in its place (invariant 8):
    /// on the rest board, every category but the board's; otherwise one
    /// Home does not offer (`isOffered`). The board itself is never dimmed,
    /// even with too few phrases: Set Up offers no such board, and one
    /// chosen before a library changed stays the person's.
    static func isDimmed(_ category: PhraseCategory, restBoard: UUID?, phraseCounts: [UUID: Int]) -> Bool {
        if let restBoard {
            return restBoard != category.uuid
        }
        return !isOffered(category, phraseCounts: phraseCounts)
    }

    /// The category the Emergency control switches to.
    static func emergency(in categories: [PhraseCategory]) -> PhraseCategory? {
        categories.first { $0.isEmergency }
    }

    /// The categories with their own button in the category row. The
    /// emergency category is left out: the Emergency quick control already
    /// opens it from every state, and two buttons with the same name are
    /// ambiguous for Voice Control ("Tap Emergency") and for VoiceOver.
    static func shownInCategoryRow(_ categories: [PhraseCategory]) -> [PhraseCategory] {
        categories.filter { !$0.isEmergency }
    }

    /// What the cell at `index` of Home's `cells` category cells holds: one
    /// category each, in order, and the last cell every category from
    /// there on, so a library with more categories than cells keeps each
    /// one reachable (that cell then scrolls). Nothing for a cell past the
    /// library's end, or past the last cell.
    static func inCell<Item>(_ index: Int, of items: [Item], cells: Int) -> ArraySlice<Item> {
        guard index >= 0, index < cells, index < items.count else { return [] }
        return index == cells - 1 ? items[index...] : items[index...index]
    }
}

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

    /// Which category Home shows on the rest board whose category is
    /// `restBoard` (docs/DECISIONS.md, "The late-stage profile"): Emergency's
    /// where Emergency was chosen, otherwise the board's. Every other
    /// category is dimmed there, so none can be chosen; a board no longer in
    /// the library shows as every category does (`resolve(_:selectedID:)`).
    static func resolve(_ categories: [PhraseCategory], selectedID: UUID?, restBoard: UUID?) -> PhraseCategory? {
        guard let restBoard, let board = categories.first(where: { $0.uuid == restBoard && !$0.isEmergency }) else {
            return resolve(categories, selectedID: selectedID)
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

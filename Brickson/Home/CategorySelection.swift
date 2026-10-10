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

    /// The category the Emergency control switches to.
    static func emergency(in categories: [PhraseCategory]) -> PhraseCategory? {
        categories.first { $0.isEmergency }
    }
}

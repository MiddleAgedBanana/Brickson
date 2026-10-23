import Foundation

/// The rules a family's edits must follow (docs/DECISIONS.md, "Editing the
/// library"). They apply to edits made in the editor only. Import keeps a
/// backup's words exactly as they are (invariant 7), so none of these
/// rules apply to it.
nonisolated enum LibraryRules {
    /// The pictures a family can choose for a category. `LibraryRulesTests`
    /// checks that each one exists, because a misspelled SF Symbol name
    /// draws nothing at all, with no error.
    static let symbolChoices: [String] = [
        "square.grid.2x2.fill",
        "bubble.left.and.bubble.right.fill",
        "text.bubble.fill",
        "exclamationmark.triangle.fill",
        "hand.raised.fill",
        "hand.thumbsup.fill",
        "heart.fill",
        "star.fill",
        "face.smiling",
        "person.fill",
        "person.2.fill",
        "house.fill",
        "bed.double.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "drop.fill",
        "pills.fill",
        "cross.case.fill",
        "figure.walk",
        "car.fill",
        "phone.fill",
        "tv.fill",
        "music.note",
        "book.fill",
        "gamecontroller.fill",
        "sun.max.fill",
        "leaf.fill",
        "pawprint.fill",
        "gift.fill",
        "calendar",
        "clock.fill",
        "questionmark.circle.fill",
    ]

    /// The picture a new category starts with.
    static let newCategorySymbol = "square.grid.2x2.fill"

    /// Names of controls on Home and on the family screens' safety bar. A
    /// category with one of these names would be a second button with the
    /// same name, which Voice Control ("Tap Yes") and VoiceOver cannot tell
    /// apart. Read every name directly from Home, including aliases such
    /// as Repeat for Again, so the editor cannot drift from the controls.
    static var reservedCategoryNames: [String] {
        (HomeControlNames.fixed + HomeControlNames.wells).flatMap(\.inputLabels) + [
            String(localized: "Speak"),
        ]
    }

    /// Symbols must not disguise a Home control name. Reuse Home's spoken
    /// form and keep the existing space-insensitive reservation, so neither
    /// "Yes😀" nor "GetAttention" becomes a category button.
    private static func reservedCategoryNameKey(_ name: String) -> String {
        HomeControlNames.spokenForm(name).filter { !$0.isWhitespace }
    }

    /// The name to store for a category, or why it cannot be used.
    /// `excluding` is the category being renamed, which may keep its own name.
    static func categoryName(
        _ proposed: String,
        isEmergency: Bool,
        in library: LibrarySnapshot,
        excluding id: UUID?
    ) throws(LibraryEditRejection) -> String {
        let name = LibraryText.trimmed(proposed)
        guard !LibraryText.isBlank(name) else { throw .emptyName }
        let key = LibraryText.nameKey(name)
        // The emergency category has no button of its own: the Emergency
        // control opens it. So it may keep a name like "Emergency".
        if !isEmergency {
            let reserved = Set(reservedCategoryNames.map(reservedCategoryNameKey))
            guard !reserved.contains(reservedCategoryNameKey(name)) else { throw .reservedCategoryName }
        }
        let taken = library.categories.contains { other in
            other.id != id && LibraryText.nameKey(other.name) == key
        }
        guard !taken else { throw .duplicateCategoryName }
        return name
    }

    /// The text to store for a phrase, or why it cannot be used.
    /// `excluding` is the phrase being edited, which may keep its own words.
    static func phraseText(
        _ proposed: String,
        in category: LibrarySnapshot.Category,
        excluding id: UUID?
    ) throws(LibraryEditRejection) -> String {
        let text = LibraryText.trimmed(proposed)
        guard !LibraryText.isBlank(text) else { throw .emptyText }
        let key = LibraryText.phraseKey(text)
        let taken = category.phrases.contains { other in
            other.id != id && LibraryText.phraseKey(other.text) == key
        }
        guard !taken else { throw .duplicatePhrase }
        return text
    }

    static func symbol(_ symbolName: String) throws(LibraryEditRejection) -> String {
        guard symbolChoices.contains(symbolName) else { throw .unknownSymbol }
        return symbolName
    }
}

/// Why an edit was refused. Nothing was changed. Each case has a sentence
/// the family can read, which stays on screen until they act.
nonisolated enum LibraryEditRejection: Error, Equatable, Sendable {
    case emptyName
    case emptyText
    case duplicateCategoryName
    case duplicatePhrase
    case reservedCategoryName
    case unknownSymbol
    /// The emergency category can never be deleted (decision E1).
    case emergencyCategoryCannotBeDeleted
    /// The emergency category always keeps at least one phrase (E1).
    case emergencyCategoryNeedsAPhrase
    /// The edit would leave no categories at all.
    case libraryNeedsACategory
    /// The category or phrase is no longer in the library.
    case notFound
    /// Two items in the stored library share an identity, so an edit
    /// cannot tell which one it means. Nothing Brickson writes does this.
    case libraryNeedsRepair

    var message: String {
        switch self {
        case .emptyName:
            String(localized: "Type a name for this category.")
        case .emptyText:
            String(localized: "Type the words for this phrase.")
        case .duplicateCategoryName:
            String(localized: "Another category already has this name. Choose a different name.")
        case .duplicatePhrase:
            String(localized: "This category already has this phrase.")
        case .reservedCategoryName:
            String(localized: "A button on Home already has this name. Choose a different name.")
        case .unknownSymbol:
            String(localized: "Choose a picture from the list.")
        case .emergencyCategoryCannotBeDeleted:
            String(localized: "Emergency can't be deleted, so it's always one step away. You can change its phrases.")
        case .emergencyCategoryNeedsAPhrase:
            String(localized: "Emergency needs at least one phrase. Change this phrase's words instead.")
        case .libraryNeedsACategory:
            String(localized: "The library needs at least one category. Add another before deleting this one.")
        case .notFound:
            String(localized: "This was changed or deleted somewhere else. Go back and try again.")
        case .libraryNeedsRepair:
            String(localized: "Two items in this library have the same identity, so it can't be changed safely.")
        }
    }
}

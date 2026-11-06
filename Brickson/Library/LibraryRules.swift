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

    /// Home has a cell for four everyday categories (`HomeLayout.categoryCapacity`)
    /// and needs three, or Again can be nearest Stop's empty well
    /// (docs/DECISIONS.md, "Three or four everyday categories").
    static let mostEverydayCategories = HomeLayout.categoryCapacity
    static let fewestEverydayCategories = 3

    /// The fewest phrases a category holds for Home to show it: as many as
    /// the widest phrase grid has columns, so the grid's top row is always
    /// full and no empty cell borders the controls above it, where a
    /// resting look would meet them (docs/DECISIONS.md, "Four phrases in
    /// every category"). Every phrase counts, words or not: each takes a
    /// cell.
    static let fewestPhrases = HomeLayout.mostColumns

    /// Whether Home offers a category holding `phrases` phrases: an
    /// everyday one with fewer is dimmed in its place, so it cannot show.
    static func homeOffers(phrases: Int) -> Bool {
        phrases >= fewestPhrases
    }

    /// What a category's screen in the Library says while `category` has
    /// fewer than `fewestPhrases` phrases, so the family knows why Home
    /// dims it, or why Emergency shows empty spaces, and how many to add.
    /// Nil once it has enough.
    static func shortNote(for category: LibrarySnapshot.Category) -> String? {
        let missing = fewestPhrases - category.phrases.count
        guard missing > 0 else { return nil }
        return category.isEmergency
            ? String(localized: "Emergency should have at least four phrases, so Home never shows it with empty spaces. Add \(missing) more.")
            : String(localized: "Home shows “\(category.name)” once it has four phrases. Until then it is dimmed there. Add \(missing) more.")
    }

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

    /// What the Library adds where saved words are too wide for Home's
    /// narrowest phrase buttons (docs/DECISIONS.md, "Words wider than
    /// Home's narrowest buttons").
    static var wideWordNote: String {
        String(localized: "A word in it is wider than Home's narrowest phrase buttons, so on the narrowest screens it can wrap onto a second line.")
    }

    /// What the Library adds where saved words are a name another control
    /// on Home answers to (docs/DECISIONS.md, "Phrases named like Home's
    /// controls"). "May": Stop, Speak, Clear and Put Back show only some of
    /// the time, and what Voice Control does is a device check.
    static var sharedNameNote: String {
        String(localized: "Another button on Home answers to these words too, so Voice Control may ask which one is meant.")
    }

    /// The same, after a restore, whose words were not typed here.
    static var restoredSharedNameNote: String {
        String(localized: "Another button on Home answers to some of these words too, so Voice Control may ask which one is meant.")
    }

    /// A line kept for what Save did: `opening`, then each note that
    /// applies, in whole sentences.
    static func savedLine(_ opening: String, isWide: Bool = false, sharesAName: Bool) -> String {
        ([opening] + (isWide ? [wideWordNote] : []) + (sharesAName ? [sharedNameNote] : [])).joined(separator: " ")
    }

    /// Every line Save can leave on Edit Phrase, for the line to keep the
    /// tallest one's height: rows sit under it (`LibraryResultLine`).
    static var savedPhraseLines: [String] {
        let saved = String(localized: "Saved.")
        return [false, true].flatMap { isWide in
            [false, true].map { savedLine(saved, isWide: isWide, sharesAName: $0) }
        }
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
    /// The edit would give Home more than four everyday categories.
    case homeHasRoomForFour
    /// The edit would leave Home fewer than three everyday categories.
    case homeNeedsThree
    /// The edit would take an everyday category from four phrases or more
    /// to fewer, and Home would dim it.
    case categoryKeepsFour
    /// The edit would take Emergency from four phrases or more to fewer.
    case emergencyKeepsFour
    /// The edit would leave no everyday category with four phrases, so
    /// Home would offer none.
    case homeNeedsAFullCategory
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
        case .homeHasRoomForFour:
            String(localized: "Home has room for four categories besides Emergency, and this would make more.")
        case .homeNeedsThree:
            String(localized: "Home needs at least three categories besides Emergency, and this would leave fewer.")
        case .categoryKeepsFour:
            String(localized: "Home shows a category while it has at least four phrases, and this would leave one with fewer. Change a phrase's words instead, or add a phrase first.")
        case .emergencyKeepsFour:
            String(localized: "Emergency keeps at least four phrases, so Home never shows it with empty spaces. Change a phrase's words instead, or add a phrase first.")
        case .homeNeedsAFullCategory:
            String(localized: "Home needs at least one category besides Emergency with four phrases, and this would leave none.")
        case .notFound:
            String(localized: "This was changed or deleted somewhere else. Go back and try again.")
        case .libraryNeedsRepair:
            String(localized: "Two items in this library have the same identity, so it can't be changed safely.")
        }
    }
}

import Foundation

/// The screens inside Settings, pushed onto its `NavigationStack(path:)`.
/// A path makes the idle reset one assignment (`path = []`) and lets UI
/// tests and screen checks open any screen directly.
///
/// The Library's screens hold identities, never stored objects
/// (`LibraryModel`), and start at Family Setup's Phrases and Categories row
/// (docs/DECISIONS.md, "The Library in Settings").
nonisolated enum SettingsRoute: Hashable, Sendable {
    case familySetup
    case guidedSetup(GuidedSetupStep)
    case voice
    case reachingTheScreen
    case keepOpen
    case callsSiriAndShortcuts
    case moreAccessibility
    case privacy
    case about
    /// Phrases and Categories: every category, and the backups.
    case library
    case libraryCategory(UUID)
    case newCategory
    case categoryName(UUID)
    case categoryPicture(UUID)
    case moveCategory(UUID)
    case deleteCategory(UUID)
    case newPhrase(category: UUID)
    case phrase(UUID)
    case movePhrase(UUID)
    case deletePhrase(UUID)
    /// The question about a backup the family chose (`LibraryModel.restore`).
    case restoreBackup

    /// Whether this screen is about the category or phrase `id`, so that
    /// deleting it leaves the screen nothing to show.
    func isAbout(_ id: UUID) -> Bool {
        switch self {
        case .libraryCategory(let item), .categoryName(let item), .categoryPicture(let item),
             .moveCategory(let item), .deleteCategory(let item), .phrase(let item),
             .movePhrase(let item), .deletePhrase(let item), .newPhrase(category: let item):
            item == id
        case .familySetup, .guidedSetup, .voice, .reachingTheScreen, .keepOpen, .callsSiriAndShortcuts,
             .moreAccessibility, .privacy, .about, .library, .newCategory, .restoreBackup:
            false
        }
    }
}

/// The steps of Set Up Step by Step, in order.
nonisolated enum GuidedSetupStep: Int, CaseIterable, Hashable, Sendable {
    case access
    /// Which phrases Home shows: every category, or the rest board.
    case restBoard
    case voice
    case turnOn
    case keepOpen
    case ready

    var next: GuidedSetupStep? {
        GuidedSetupStep(rawValue: rawValue + 1)
    }

    /// "Step 2 of 6", for the screen's title area.
    var number: Int { rawValue + 1 }
    static var count: Int { allCases.count }
}

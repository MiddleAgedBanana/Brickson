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
    /// A step of Set Up Step by Step, and the control the steps were opened
    /// with, whose place the first step's Learn About Each Way takes. Every
    /// step keeps it, with no default, since the second step's layout
    /// depends on it too (`advance(_:from:entry:)`).
    case guidedSetup(GuidedSetupStep, from: GuidedSetupEntry)
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

    /// Next, on `step` of Set Up Step by Step: opens the step after it from
    /// the same control the steps were opened with, since the second step
    /// keeps its choices clear of the check-in card's place only when it
    /// knows the steps were opened after the card was answered
    /// (`SetupChoicesPlace.arrivals(from:checkInRows:)`). After the last
    /// step, back to the screen the steps were started from.
    static func advance(_ path: inout [SettingsRoute], from step: GuidedSetupStep, entry: GuidedSetupEntry) {
        if let next = step.next {
            path.append(.guidedSetup(next, from: entry))
        } else if let start = path.firstIndex(where: { if case .guidedSetup = $0 { true } else { false } }) {
            path.removeSubrange(start...)
        }
    }
}

/// The control Set Up Step by Step was opened with. The first step's Learn
/// About Each Way takes its place as Family Setup drew it, so a look still
/// resting there meets a control that only opens the guide, and the
/// answers start below every place a look can be resting on the way in
/// (`SetupAnswersPlace.arrivals(from:homesSettings:rootRow:opener:checkInRows:)`;
/// docs/DECISIONS.md, "The first step's own rows"). Opened after the
/// check-in card was answered, the second step keeps its choices clear of
/// the card's place too (`SetupChoicesPlace.arrivals(from:checkInRows:)`),
/// so Next carries the entry to every step (`SettingsRoute.advance(_:from:entry:)`).
nonisolated enum GuidedSetupEntry: Hashable, Sendable {
    /// Family Setup's Set Up Step by Step.
    case setUpStepByStep
    /// Family Setup's Set Up Step by Step, once the check-in card was
    /// answered in its place on the same visit: a look can then be resting
    /// where the card's rows were, over the passive words that keep their
    /// place.
    case setUpStepByStepAfterTheCheckIn
    /// The check-in card's Go Through Setup Again.
    case checkIn
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

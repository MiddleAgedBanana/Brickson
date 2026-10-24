/// The screens inside Settings, pushed onto its `NavigationStack(path:)`.
/// A path makes the idle reset one assignment (`path = []`) and lets UI
/// tests and screen checks open any screen directly.
///
/// The Library's screen joins here as `case library` when it lands, pushed
/// from a Family Setup row (docs/DECISIONS.md, "Settings is a cover with a
/// fixed safety bar").
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
}

/// The steps of Set Up Step by Step, in order.
nonisolated enum GuidedSetupStep: Int, CaseIterable, Hashable, Sendable {
    case access
    case voice
    case turnOn
    case keepOpen
    case ready

    var next: GuidedSetupStep? {
        GuidedSetupStep(rawValue: rawValue + 1)
    }

    /// "Step 2 of 5", for the screen's title area.
    var number: Int { rawValue + 1 }
    static var count: Int { allCases.count }
}

import Foundation

/// Settings' first screens for the chain engine (`ChainEngine`): the ones a
/// held look reaches from Home's Settings button within a few activations
/// (docs/HANDOFF.md, *Known gaps*), each with what its controls do. Settings
/// opens over Home as a cover, and Back to Talking, in the same place on
/// every screen, closes it onto Home as it was.
///
/// - Settings' first screen: Family Setup opens Family Setup.
/// - Family Setup: the standard Back button returns to the first screen;
///   Set Up Step by Step opens its first step; every other row opens a
///   screen of its own, which only navigates and is not followed further.
/// - Set Up Step by Step's first step: Back returns to Family Setup; every
///   other control saves the answers: the ways of reaching the screen,
///   Clear My Choices, and Next, which saves them before it moves on.
///
/// A control on the first screen or Family Setup that this does not know is
/// returned as unknown rather than guessed at, so a new one is described
/// here before it is scored. On the first step, anything new is taken to
/// save, which can only add hazards.
///
/// Test infrastructure only, compiled into both test targets like
/// `ChainEngine`.
nonisolated enum SettingsChains {
    /// The states, by the titles the screens show.
    static let root = HomeChains.settingsRoot
    static let familySetup = "Family Setup"
    static let firstStep = "Step 1 of 5"

    /// Controls, by the names the UI tests read them by.
    static let backToTalking = "backToTalking"
    static let back = "BackButton"
    static let familySetupRow = "familySetup"
    static let guidedSetupRow = "guidedSetup"
    /// Next, on every step of Set Up Step by Step.
    static let firstStepNext = "guidedSetupNext"
    /// Family Setup's rows that open guides and settings of their own.
    static let familySetupGuides: Set = [
        "voiceSettings", "reachingTheScreen", "keepOpen", "callsSiriAndShortcuts", "moreAccessibility", "privacyPolicy",
        "about",
    ]

    /// The controls of each screen, as it first appears. A screen not
    /// read (nil) is left out of the map, and chains reaching it end there.
    struct Screens {
        var root: [(name: String, frame: CGRect)]
        var familySetup: [(name: String, frame: CGRect)]?
        var firstStep: [(name: String, frame: CGRect)]?
    }

    /// The map of Settings' first screens, with Back to Talking leading to
    /// `home`, the Home state Settings was opened from; and the controls
    /// it does not know, each with its screen.
    static func map(_ screens: Screens, closingOnto home: String) -> (map: ChainMap, unknown: [String]) {
        var unknown: [String] = []
        func controls(
            _ list: [(name: String, frame: CGRect)], on screen: String, _ known: (String, CGRect) -> ChainControl?
        ) -> [ChainControl] {
            list.compactMap { name, frame in
                if name == backToTalking {
                    return ChainControl(name, frame, .navigates, leadsTo: home)
                }
                guard let control = known(name, frame) else {
                    unknown.append("\(name) on \(screen)")
                    return nil
                }
                return control
            }
        }
        var states: [String: [ChainControl]] = [:]
        states[root] = controls(screens.root, on: root) { name, frame in
            name == familySetupRow ? ChainControl(name, frame, .navigates, leadsTo: familySetup) : nil
        }
        if let list = screens.familySetup {
            states[familySetup] = controls(list, on: familySetup) { name, frame in
                switch name {
                case back: ChainControl(name, frame, .navigates, leadsTo: root)
                case guidedSetupRow: ChainControl(name, frame, .navigates, leadsTo: firstStep)
                case _ where familySetupGuides.contains(name): ChainControl(name, frame, .navigates, leadsTo: name)
                default: nil
                }
            }
        }
        if let list = screens.firstStep {
            states[firstStep] = controls(list, on: firstStep) { name, frame in
                name == back
                    ? ChainControl(name, frame, .navigates, leadsTo: familySetup)
                    : ChainControl(name, frame, .changesData)
            }
        }
        return (ChainMap(states: states), unknown)
    }

    /// Whether the first step, as it shows without scrolling, has anything
    /// besides Back, Back to Talking and Next: an answer, or Clear My
    /// Choices under them. On a phone at the largest text sizes its words
    /// fill the screen above Next, and a look held where Set Up Step by
    /// Step was then meets Back to Talking instead (docs/DECISIONS.md,
    /// "Settings' first row, placed from Home's frames").
    static func showsAnAnswer(_ firstStep: [(name: String, frame: CGRect)]) -> Bool {
        firstStep.contains { ![backToTalking, back, firstStepNext].contains($0.name) }
    }

    /// Where chains through Settings start in `map`: Home's Settings button
    /// chosen in `home`, and every control of Settings' first screens
    /// chosen, each with the look at its centre and across it.
    static func starts(in map: ChainMap, home: String) -> [ChainStart] {
        let screens: Set = [root, familySetup, firstStep]
        return map.everyStart().filter { start in
            screens.contains(start.state) || (start.state == home && start.chosen?.name == HomeChains.settings)
        }
    }

    /// The two kinds of hazard found through Settings (docs/DECISIONS.md,
    /// "One chain engine for dwell safety"), and anything else.
    enum Kind: String, CaseIterable, Sendable {
        /// A held look follows Set Up Step by Step into its first step and
        /// saves an answer there.
        case savesAnAnswer
        /// Settings closes under the look: once Back to Talking has closed
        /// it, a pointer gone back to where the person looks rests over
        /// Home, and near Back to Talking's edges, or wherever else a chain
        /// closed Settings from, Home has Yes, No or Get Attention.
        case closesUnderTheLook
        /// Anything else: a new hazard.
        case unexpected
    }

    /// The kind of hazard `chain` ended in; nil when it ended in none.
    static func kind(of chain: Chain) -> Kind? {
        guard let hazard = chain.hazard else { return nil }
        if hazard.state == firstStep { return .savesAnAnswer }
        let onHome = ![root, familySetup, firstStep].contains(hazard.state)
        return onHome && chain.pointer == .returnsToLook ? .closesUnderTheLook : .unexpected
    }
}

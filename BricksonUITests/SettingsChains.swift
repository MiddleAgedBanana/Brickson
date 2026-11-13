import Foundation

/// Settings' first screens for the chain engine (`ChainEngine`): the ones a
/// held look reaches from Home's Settings button within a few activations
/// (docs/HANDOFF.md, *Known gaps*), each with what its controls do. Settings
/// opens over Home as a cover, and Back to Talking, in the same place on
/// every screen, closes it onto Home as it was.
///
/// - Settings' first screen: Family Setup opens Family Setup.
/// - Family Setup: the standard Back button returns to the first screen;
///   Set Up Step by Step opens its first step; Voice Settings opens Voice
///   Settings; every other row opens a screen of its own, which only
///   navigates and is not followed further.
///   While a check-in is due, its card's three rows each save an answer to
///   it: Go Through Setup Again then opens the first step from the card,
///   and Not Now and Stop Asking leave Family Setup with the card's place
///   kept by passive words and its rows gone (`CheckInPolicy`). There, Set
///   Up Step by Step opens the first step after the check-in, which keeps
///   its answers clear of where the card's rows were.
/// - Set Up Step by Step's first step: Back returns to Family Setup; Learn
///   About Each Way opens the Reaching the Screen guide as a cover of its
///   own; Next opens the second step; every other control saves the
///   answers: the ways of reaching the screen and Clear My Choices.
/// - The guide's cover: Done, in Back to Talking's frame, returns to the
///   first step. It has no other control near the look (docs/DECISIONS.md,
///   "The first step's own rows").
/// - The second step, which phrases Home shows: Back returns to the first
///   step; Next, in the same bar as the first step's, opens the third
///   step, which is not followed further; every other control saves the
///   choice: Every Category and each everyday category (docs/DECISIONS.md,
///   "The late-stage profile").
/// - The first step opened from the check-in card, read on its own since
///   its Learn About Each Way takes Go Through Setup Again's place, and the
///   first step Set Up Step by Step opens once the card is answered, read
///   on its own since its answers start lower: each as the first step, with
///   Back returning to Family Setup with the check-in answered, and the
///   guide and the second step it leads to as the others, each returning
///   to it. The second step after the card is answered is read on its own
///   too, since its choices keep clear of where the card's rows were.
/// - Voice Settings, opened from Family Setup's Voice Settings row: the
///   standard Back button and Back to Family Setup, which takes the row's
///   place, return to Family Setup as it was (docs/DECISIONS.md, "Voice
///   Settings, reached with a held look"). Every speed sets how Brickson
///   speaks and plays a sample; Hear plays a voice; Use changes it; Ask to
///   Use Personal Voice puts iOS's question, whose answer changes which
///   voices Brickson may use; and Open Personal Voice Settings leaves
///   Brickson for the Settings app. Reached from Family Setup once its
///   check-in was answered, it returns there.
///
/// A control on the first screen, Family Setup, the guide's cover or Voice
/// Settings that this does not know is returned as unknown rather than guessed at, so a
/// new one is described here before it is scored. On the first and second
/// steps, anything new is taken to save, which can only add hazards.
///
/// Test infrastructure only, compiled into both test targets like
/// `ChainEngine`.
nonisolated enum SettingsChains {
    /// The states, by the titles the screens show.
    static let root = HomeChains.settingsRoot
    static let familySetup = "Family Setup"
    static let firstStep = "Step 1 of 6"
    /// The Reaching the Screen guide, opened from the first step.
    static let eachWay = "Each Way"
    /// Family Setup once its check-in card was answered: the card's place
    /// kept by passive words, its rows gone.
    static let familySetupAfterCheckIn = "Family Setup, check-in answered"
    /// The first step opened with the check-in card's Go Through Setup
    /// Again, and the guide and the second step reached from it.
    static let firstStepFromCheckIn = "Step 1 of 6, from the check-in"
    static let eachWayFromCheckIn = "Each Way, from the check-in"
    static let secondStepFromCheckIn = "Step 2 of 6, from the check-in"
    /// The first step Set Up Step by Step opens once the check-in card was
    /// answered in its place, and the guide and the second step reached
    /// from it.
    static let firstStepAfterCheckIn = "Step 1 of 6, after the check-in"
    static let eachWayAfterCheckIn = "Each Way, after the check-in"
    static let secondStepAfterCheckIn = "Step 2 of 6, after the check-in"
    /// Voice Settings, opened from Family Setup, and opened from Family
    /// Setup once its check-in was answered.
    static let voiceSettings = "Voice Settings"
    static let voiceSettingsAfterCheckIn = "Voice Settings, check-in answered"

    /// Controls, by the names the UI tests read them by.
    static let backToTalking = "backToTalking"
    static let back = "BackButton"
    static let familySetupRow = "familySetup"
    static let guidedSetupRow = "guidedSetup"
    /// Next, on every step of Set Up Step by Step.
    static let firstStepNext = "guidedSetupNext"
    /// Where the first step's Next leads: which phrases Home shows.
    static let secondStep = "Step 2 of 6"
    /// Where the second step's Next leads, not followed further.
    static let thirdStep = "Step 3 of 6"
    /// The first step's way into the guide, and the guide's way out.
    static let learnAboutEachWay = "learnAboutEachWay"
    static let eachWayDone = "eachWayDone"
    /// Family Setup's Phrases and Categories, which opens the Library: its
    /// screens are a surface of their own (`LibraryChains`), so a map
    /// merged with theirs follows chains on into them.
    static let libraryRow = "library"
    /// Family Setup's Voice Settings row, and Voice Settings' way back to
    /// Family Setup, in the row's place.
    static let voiceSettingsRow = "voiceSettings"
    static let voiceWayBack = "voiceSettingsWayBack"
    /// Voice Settings' Personal Voice buttons: Ask to Use Personal Voice,
    /// by its identifier, and Open Personal Voice Settings, by its label.
    static let askPersonalVoice = "askPersonalVoice"
    static let openPersonalVoiceSettings = "Open Personal Voice Settings"
    /// Family Setup's rows that open guides and settings of their own,
    /// not followed further.
    static let familySetupGuides: Set = [
        "reachingTheScreen", "keepOpen", "callsSiriAndShortcuts", "moreAccessibility", "privacyPolicy", "about",
    ]
    /// The check-in card's rows, while a check-in is due.
    static let checkInGoThrough = "checkInGoThrough"
    static let checkInNotNow = "checkInNotNow"
    static let checkInStopAsking = "checkInStopAsking"
    static let checkInRows: Set = [checkInGoThrough, checkInNotNow, checkInStopAsking]

    /// The controls of each screen, as it first appears. A screen not
    /// read (nil) is left out of the map, and chains reaching it end there.
    struct Screens {
        var root: [(name: String, frame: CGRect)]
        var familySetup: [(name: String, frame: CGRect)]?
        var firstStep: [(name: String, frame: CGRect)]?
        var eachWay: [(name: String, frame: CGRect)]? = nil
        var secondStep: [(name: String, frame: CGRect)]? = nil
        /// The first step opened from the check-in card, and the one Set
        /// Up Step by Step opens once the card is answered. Their guides
        /// are `eachWay`, which does not depend on what opened the step.
        var firstStepFromCheckIn: [(name: String, frame: CGRect)]? = nil
        var firstStepAfterCheckIn: [(name: String, frame: CGRect)]? = nil
        /// The second step reached from the first step after the check-in,
        /// whose choices keep clear of where the card's rows were
        /// (`SetupChoicesPlace.arrivals(from:checkInRows:)`); where it was
        /// not read, `secondStep`. The second step from the card is
        /// `secondStep`: a look comes to it on Next alone.
        var secondStepAfterCheckIn: [(name: String, frame: CGRect)]? = nil
        /// Voice Settings, as it first appears when Family Setup's row
        /// opens it. Where it was not read, chains reaching it end there.
        var voiceSettings: [(name: String, frame: CGRect)]? = nil
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
            let read = controls(list, on: familySetup) { name, frame in
                switch name {
                case back: ChainControl(name, frame, .navigates, leadsTo: root)
                case guidedSetupRow: ChainControl(name, frame, .navigates, leadsTo: firstStep)
                case libraryRow: ChainControl(name, frame, .navigates, leadsTo: LibraryChains.library)
                case voiceSettingsRow: ChainControl(name, frame, .navigates, leadsTo: voiceSettings)
                case _ where familySetupGuides.contains(name): ChainControl(name, frame, .navigates, leadsTo: name)
                // Each answers the check-in, so each is a hazard wherever
                // a held look meets it unasked.
                case checkInGoThrough: ChainControl(name, frame, .changesData, leadsTo: firstStepFromCheckIn)
                case checkInNotNow, checkInStopAsking: ChainControl(name, frame, .changesData, leadsTo: familySetupAfterCheckIn)
                default: nil
                }
            }
            states[familySetup] = read
            if read.contains(where: { checkInRows.contains($0.name) }) {
                states[familySetupAfterCheckIn] = read.filter { !checkInRows.contains($0.name) }.map { control in
                    switch control.name {
                    case guidedSetupRow: ChainControl(control.name, control.frame, .navigates, leadsTo: firstStepAfterCheckIn)
                    case voiceSettingsRow: ChainControl(control.name, control.frame, .navigates, leadsTo: voiceSettingsAfterCheckIn)
                    default: control
                    }
                }
            }
        }
        /// A first step, its guide and its second step, with Back from the
        /// first step leading to `familySetupState`, and the second step's
        /// controls `secondControls`.
        func steps(
            _ first: [(name: String, frame: CGRect)]?, named step: String, guide: String, second: String, back familySetupState: String,
            secondControls: [(name: String, frame: CGRect)]?
        ) {
            if let list = first {
                states[step] = controls(list, on: step) { name, frame in
                    switch name {
                    case back: ChainControl(name, frame, .navigates, leadsTo: familySetupState)
                    case learnAboutEachWay: ChainControl(name, frame, .navigates, leadsTo: guide)
                    case firstStepNext: ChainControl(name, frame, .navigates, leadsTo: second)
                    default: ChainControl(name, frame, .changesData)
                    }
                }
            }
            if let list = screens.eachWay {
                states[guide] = controls(list, on: guide) { name, frame in
                    name == eachWayDone ? ChainControl(name, frame, .navigates, leadsTo: step) : nil
                }
            }
            if let list = secondControls {
                states[second] = controls(list, on: second) { name, frame in
                    switch name {
                    case back: ChainControl(name, frame, .navigates, leadsTo: step)
                    case firstStepNext: ChainControl(name, frame, .navigates, leadsTo: thirdStep)
                    default: ChainControl(name, frame, .changesData)
                    }
                }
            }
        }
        steps(
            screens.firstStep, named: firstStep, guide: eachWay, second: secondStep, back: familySetup, secondControls: screens.secondStep
        )
        if let fromCheckIn = screens.firstStepFromCheckIn {
            steps(
                fromCheckIn, named: firstStepFromCheckIn, guide: eachWayFromCheckIn, second: secondStepFromCheckIn,
                back: familySetupAfterCheckIn, secondControls: screens.secondStep
            )
        }
        if let afterCheckIn = screens.firstStepAfterCheckIn {
            steps(
                afterCheckIn, named: firstStepAfterCheckIn, guide: eachWayAfterCheckIn, second: secondStepAfterCheckIn,
                back: familySetupAfterCheckIn, secondControls: screens.secondStepAfterCheckIn ?? screens.secondStep
            )
        }
        if let list = screens.voiceSettings {
            /// Voice Settings with both ways back leading to
            /// `familySetupState`.
            func voice(on state: String, back familySetupState: String) -> [ChainControl] {
                controls(list, on: state) { name, frame in
                    if name == back || name == voiceWayBack {
                        return ChainControl(name, frame, .navigates, leadsTo: familySetupState)
                    }
                    if name == openPersonalVoiceSettings { return ChainControl(name, frame, .leavesBrickson) }
                    // The question's answer changes which voices Brickson
                    // may use.
                    if name == askPersonalVoice { return ChainControl(name, frame, .changesData) }
                    // Each speed, by its spoken name ("Normal speed", "70%
                    // of normal speed"): it sets the speed and plays a
                    // sample.
                    if name.lowercased().hasSuffix("normal speed") { return ChainControl(name, frame, .changesData) }
                    if name.hasPrefix("Hear ") { return ChainControl(name, frame, .speaks) }
                    if name.hasPrefix("Use ") { return ChainControl(name, frame, .changesData) }
                    return nil
                }
            }
            states[voiceSettings] = voice(on: voiceSettings, back: familySetup)
            if states[familySetupAfterCheckIn] != nil {
                states[voiceSettingsAfterCheckIn] = voice(on: voiceSettingsAfterCheckIn, back: familySetupAfterCheckIn)
            }
        }
        return (ChainMap(states: states), unknown)
    }

    /// Settings' screens in the map, as against Home's states.
    static let screens: Set = [
        root, familySetup, firstStep, eachWay, secondStep,
        familySetupAfterCheckIn, firstStepFromCheckIn, eachWayFromCheckIn, secondStepFromCheckIn,
        firstStepAfterCheckIn, eachWayAfterCheckIn, secondStepAfterCheckIn, voiceSettings, voiceSettingsAfterCheckIn,
    ]

    /// Where chains through Settings start in `map`: Home's Settings button
    /// chosen in `home`, and every control of Settings' first screens, the
    /// guide's cover and the second step chosen, each with the look at its
    /// centre and across it. In state-name order, as `ChainMap.everyStart()`
    /// gives them, but built for these states alone rather than for all of
    /// Home's.
    static func starts(in map: ChainMap, home: String) -> [ChainStart] {
        return map.states.keys.sorted().flatMap { state in
            if screens.contains(state) {
                return map.starts(in: state)
            }
            if state == home {
                return map.starts(in: state).filter { $0.chosen?.name == HomeChains.settings }
            }
            return []
        }
    }

    /// The three kinds of hazard found through Settings (docs/DECISIONS.md,
    /// "One chain engine for dwell safety"), and anything else.
    enum Kind: String, CaseIterable, Sendable {
        /// A held look follows Set Up Step by Step or Go Through Setup
        /// Again into the first step and saves an answer there, through an
        /// answer or Clear My Choices, or on into the second step and saves
        /// a choice of which phrases Home shows.
        case savesAnAnswer
        /// Settings closes under the look: once Back to Talking has closed
        /// it, a pointer gone back to where the person looks rests over
        /// Home, and near Back to Talking's edges, or wherever else a chain
        /// closed Settings from, Home has Yes, No or Get Attention.
        case closesUnderTheLook
        /// A held look follows Family Setup's Voice Settings row into Voice
        /// Settings and meets a control there that acts on the voice: a
        /// speed or a voice chosen, a sample played, Personal Voice asked
        /// about, or the Settings app opened.
        case actsOnTheVoice
        /// Anything else: a new hazard, a check-in answered unasked among
        /// them.
        case unexpected
    }

    /// The steps in which a hazard saves a setup answer.
    static let stepsWithAnswers: Set = [
        firstStep, secondStep, firstStepFromCheckIn, secondStepFromCheckIn, firstStepAfterCheckIn, secondStepAfterCheckIn,
    ]

    /// The kind of hazard `chain` ended in; nil when it ended in none.
    static func kind(of chain: Chain) -> Kind? {
        guard let hazard = chain.hazard else { return nil }
        if stepsWithAnswers.contains(hazard.state) { return .savesAnAnswer }
        if hazard.state == voiceSettings || hazard.state == voiceSettingsAfterCheckIn { return .actsOnTheVoice }
        let onHome = !screens.contains(hazard.state)
        return onHome && chain.pointer == .returnsToLook ? .closesUnderTheLook : .unexpected
    }
}

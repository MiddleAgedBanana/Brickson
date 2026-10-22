import Foundation

/// Whether Brickson may speak in a Personal Voice, as iOS reports it. A
/// plain mirror of `AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus`,
/// so the guidance below is testable without AVFoundation.
nonisolated enum PersonalVoiceAccess: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case unsupported
}

/// What Settings' Voice screen says about Personal Voice, and which one
/// button it offers.
///
/// Personal Voice is Apple's feature: a person records phrases in the
/// Settings app and iOS makes a voice that sounds like them. Brickson can
/// only ask to use it. Each state names the next step in words a family
/// member can follow, and the written path is always shown, so the guidance
/// still works if iOS cannot open Settings at the right page.
nonisolated struct PersonalVoiceGuidance: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        /// Ask iOS for permission. Its button explains what happens first.
        case askPermission
        /// Open Settings > Accessibility > Personal Voice > Allow Apps to
        /// Request to Use, the only Personal Voice page iOS opens directly
        /// (`AccessibilitySettings.Feature`, checked 2026-10-21).
        case openPersonalVoiceSettings
    }

    let title: String
    let message: String
    /// Steps in the Settings app, shown as text.
    let settingsPath: String?
    let action: Action?
    /// Shown when no Personal Voice exists yet: one is made by reading aloud,
    /// so it is best made while speaking is still comfortable.
    let suggestsMakingOne: Bool

    static let personalVoicePath = String(localized: "Settings > Accessibility > Personal Voice")
    static let allowAppsPath = String(localized: "Settings > Accessibility > Personal Voice > Allow Apps to Request to Use")

    /// - Parameters:
    ///   - canAsk: Brickson can ask from this screen (otherwise it asks by
    ///     itself when it opens; docs/DECISIONS.md, "Personal Voice
    ///     permission is asked at launch, for now").
    ///   - canOpenSettings: iOS can open Personal Voice's permission page in
    ///     its Settings on this device.
    ///   - askedOnThisVisit: the Ask button was used since the screen
    ///     opened. Whatever the answer, no new button appears until the
    ///     screen opens again, so nothing new lands near the spot where the
    ///     Ask button was (AGENTS.md, invariant 10); the written path still
    ///     says where to go.
    static func make(
        access: PersonalVoiceAccess,
        hasPersonalVoice: Bool,
        canAsk: Bool,
        canOpenSettings: Bool,
        askedOnThisVisit: Bool = false
    ) -> PersonalVoiceGuidance {
        switch access {
        case .unsupported:
            return PersonalVoiceGuidance(
                title: String(localized: "Personal Voice isn't available here"),
                message: String(localized: "This iPhone or iPad can't use Personal Voice. \(AppName.display) speaks with the voice chosen below."),
                settingsPath: nil,
                action: nil,
                suggestsMakingOne: false
            )
        case .notDetermined:
            return PersonalVoiceGuidance(
                title: String(localized: "Personal Voice"),
                message: canAsk
                    ? String(localized: "\(AppName.display) can speak in a voice that sounds like you, made with Apple's Personal Voice. Choose Ask to Use Personal Voice, then Allow when iOS asks. iOS asks only once.")
                    : String(localized: "\(AppName.display) can speak in a voice that sounds like you, made with Apple's Personal Voice. iOS asks once whether \(AppName.display) may use it; choose Allow."),
                settingsPath: nil,
                action: canAsk ? .askPermission : nil,
                suggestsMakingOne: false
            )
        case .denied:
            return PersonalVoiceGuidance(
                title: String(localized: "Personal Voice is turned off for \(AppName.display)"),
                message: String(localized: "To let \(AppName.display) speak in your Personal Voice, turn \(AppName.display) on in this list:"),
                settingsPath: allowAppsPath,
                action: canOpenSettings && !askedOnThisVisit ? .openPersonalVoiceSettings : nil,
                suggestsMakingOne: false
            )
        case .authorized where hasPersonalVoice:
            return PersonalVoiceGuidance(
                title: String(localized: "Personal Voice is ready"),
                message: String(localized: "\(AppName.display) may use your Personal Voice. It is listed below; Automatic chooses it."),
                settingsPath: nil,
                action: nil,
                suggestsMakingOne: false
            )
        case .authorized:
            return PersonalVoiceGuidance(
                title: String(localized: "No Personal Voice yet"),
                message: String(localized: "\(AppName.display) may use a Personal Voice, but none is on this device. One is made in the Settings app by reading phrases aloud:"),
                settingsPath: personalVoicePath,
                // iOS can open only the permission page, which is not where
                // a voice is made, so the written path is the way there.
                action: nil,
                suggestsMakingOne: true
            )
        }
    }

    /// What the card can say once iOS answers the Ask button, one for each
    /// answer. While the button shows, the screen keeps room for the
    /// longest of these, so the answer moves nothing below the card
    /// (`VoiceSettingsView`). None offers a button (`askedOnThisVisit`).
    static func outcomesOfAsking() -> [PersonalVoiceGuidance] {
        let answers: [(access: PersonalVoiceAccess, hasPersonalVoice: Bool)] = [
            (.authorized, true),
            (.authorized, false),
            (.denied, false),
            (.unsupported, false),
        ]
        return answers.map { answer in
            make(
                access: answer.access,
                hasPersonalVoice: answer.hasPersonalVoice,
                canAsk: true,
                canOpenSettings: true,
                askedOnThisVisit: true
            )
        }
    }
}

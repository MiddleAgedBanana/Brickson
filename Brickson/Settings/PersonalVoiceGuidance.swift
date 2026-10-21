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
        /// Open Settings > Accessibility > Personal Voice.
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
    ///   - canOpenSettings: iOS can open its Settings at the Personal Voice
    ///     page on this device.
    static func make(
        access: PersonalVoiceAccess,
        hasPersonalVoice: Bool,
        canAsk: Bool,
        canOpenSettings: Bool
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
                    ? String(localized: "\(AppName.display) can speak in a voice that sounds like you, made with Apple's Personal Voice. \(AppName.display) must ask iOS before using it.")
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
                action: canOpenSettings ? .openPersonalVoiceSettings : nil,
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
                action: canOpenSettings ? .openPersonalVoiceSettings : nil,
                suggestsMakingOne: true
            )
        }
    }
}

import UIKit

/// Everything the probe reads or sets through UIKit, in this one file
/// (docs/DECISIONS.md, "Apple's current frameworks first"): SwiftUI has no
/// way to keep the screen awake, to pause VoiceOver or Switch Control, or
/// to read whether AssistiveTouch, Switch Control or Guided Access is
/// running.
enum ProbeSystem {
    /// Keeps the screen on, as Brickson does (invariant 12). The Screen
    /// station turns it off to see what locks the screen and what wakes it
    /// (A-22, A-23, G-25).
    static func setKeepsScreenAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }

    static var keepsScreenAwake: Bool {
        UIApplication.shared.isIdleTimerDisabled
    }

    /// Asks VoiceOver or Switch Control to pause while the probe speaks
    /// (A-18, B1-U7), and to resume.
    static func pause(_ pause: ProbePause) {
        guard let technology = technology(for: pause) else { return }
        UIAccessibility.post(notification: .pauseAssistiveTechnology, argument: technology)
    }

    static func resume(_ pause: ProbePause) {
        guard let technology = technology(for: pause) else { return }
        UIAccessibility.post(notification: .resumeAssistiveTechnology, argument: technology)
    }

    private static func technology(for pause: ProbePause) -> UIAccessibility.AssistiveTechnologyIdentifier? {
        switch pause {
        case .nothing: nil
        case .voiceOver: .notificationVoiceOver
        case .switchControl: .notificationSwitchControl
        }
    }

    /// UIKit's public accessibility status values (A-27, A-32), read now.
    static func readings() -> [ProbeStatusReading] {
        [
            ProbeStatusReading(
                name: "UIAccessibility.isAssistiveTouchRunning",
                value: String(UIAccessibility.isAssistiveTouchRunning)),
            ProbeStatusReading(
                name: "UIAccessibility.isSwitchControlRunning",
                value: String(UIAccessibility.isSwitchControlRunning)),
            ProbeStatusReading(
                name: "UIAccessibility.isVoiceOverRunning",
                value: String(UIAccessibility.isVoiceOverRunning)),
            ProbeStatusReading(
                name: "UIAccessibility.isGuidedAccessEnabled",
                value: String(UIAccessibility.isGuidedAccessEnabled)),
            ProbeStatusReading(
                name: "UIAccessibility.isShakeToUndoEnabled",
                value: String(UIAccessibility.isShakeToUndoEnabled)),
            ProbeStatusReading(
                name: "UIAccessibility.prefersCrossFadeTransitions",
                value: String(UIAccessibility.prefersCrossFadeTransitions)),
            ProbeStatusReading(
                name: "UIAccessibility.isReduceMotionEnabled",
                value: String(UIAccessibility.isReduceMotionEnabled)),
            ProbeStatusReading(
                name: "UIAccessibility.isDarkerSystemColorsEnabled",
                value: String(UIAccessibility.isDarkerSystemColorsEnabled)),
            ProbeStatusReading(
                name: "UIAccessibility.isBoldTextEnabled",
                value: String(UIAccessibility.isBoldTextEnabled)),
            ProbeStatusReading(
                name: "UIAccessibility.buttonShapesEnabled",
                value: String(UIAccessibility.buttonShapesEnabled)),
            ProbeStatusReading(
                name: "UIApplication.isIdleTimerDisabled",
                value: String(UIApplication.shared.isIdleTimerDisabled)),
        ]
    }
}

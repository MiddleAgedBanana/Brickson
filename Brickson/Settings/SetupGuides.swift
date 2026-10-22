import Accessibility
import SwiftUI

// Passive guides for the family. Steps name Apple's own menus, checked
// against Apple's support pages on 2026-10-21; re-check them against the
// current pages when iOS changes (docs/DECISIONS.md, "Setup answers are kept
// as offered, never as completed").

/// How each of Apple's input methods is turned on.
struct ReachingTheScreenView: View {
    var body: some View {
        SettingsScreen(title: "Reaching the Screen") {
            ReachingTheScreenContent(methods: Set(AccessMethod.allCases))
        }
    }
}

/// The guide's sections for `methods`, shared with step 3 of Set Up Step by
/// Step, which shows only the methods chosen in step 1.
struct ReachingTheScreenContent: View {
    let methods: Set<AccessMethod>

    var body: some View {
        SettingsParagraph("\(AppName.display) works with every way an iPhone or iPad can be controlled. Each is part of iOS and is turned on in the Settings app; \(AppName.display) needs no setup of its own.")

        ForEach(AccessMethod.allCases.filter(methods.contains), id: \.self) { method in
            section(for: method)
        }
    }

    @ViewBuilder
    private func section(for method: AccessMethod) -> some View {
        switch method {
        case .touch:
            SettingsHeading("Touch")
            SettingsParagraph("Nothing to turn on. If tapping is hard, AssistiveTouch and Touch Accommodations in Settings > Accessibility > Touch can help.")
        case .voiceControl:
            SettingsHeading("Voice Control")
            SettingsSteps(steps: [
                "Open Settings > Accessibility > Voice Control.",
                "Turn on Voice Control.",
                "Say the name of a button to choose it, such as “Tap Yes”.",
            ])
        case .switchControl:
            SettingsHeading("Switch Control")
            SettingsSteps(steps: [
                "Open Settings > Accessibility > Switch Control.",
                "Under Switches, add the switch that will be used.",
                "Turn on Switch Control.",
            ])
        case .eyeTracking:
            SettingsHeading("Eye Tracking")
            SettingsSteps(steps: [
                "Place the iPhone or iPad on a stable stand, about 1½ feet (45 cm) from the face.",
                "Open Settings > Accessibility > Eye Tracking and turn it on.",
                "Follow the dot with the eyes to calibrate.",
                "Dwell Control chooses a button by looking at it for a moment.",
            ])
            OpenAccessibilitySettingsButton(title: "Open Dwell Control Settings", feature: .dwellControl)
        case .headTracking:
            SettingsHeading("Head Tracking")
            SettingsSteps(steps: [
                "Open Settings > Accessibility > Head Tracking and turn it on.",
                "Move the pointer by moving the head; choose with a facial expression or Dwell Control.",
            ])
            OpenAccessibilitySettingsButton(title: "Open Dwell Control Settings", feature: .dwellControl)
        case .someoneElse:
            SettingsHeading("Someone else helps")
            SettingsParagraph("A partner can point to phrases on the screen for the person to choose with a look, a blink or a nod, then tap the one chosen.")
        }
    }
}

/// Opens one page of Accessibility settings, where iOS offers a direct link.
struct OpenAccessibilitySettingsButton: View {
    let title: LocalizedStringKey
    let feature: AccessibilitySettings.Feature
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @State private var failed = false

    var body: some View {
        if canOpen {
            Button {
                activity?.recordActivity()
                Task {
                    do {
                        try await AccessibilitySettings.openSettings(for: feature)
                        failed = false
                    } catch {
                        failed = true
                    }
                }
            } label: {
                SettingsRowLabel(title: title, systemImage: "gear")
            }
            .settingsRowStyle()
            // Its place is kept, so a failure moves nothing below it.
            SettingsParagraph("Settings could not be opened. Follow the steps above in the Settings app.")
                .opacity(failed ? 1 : 0)
                .accessibilityHidden(!failed)
        }
    }

    private var canOpen: Bool {
        if #available(iOS 26.4, *) {
            return AccessibilitySettings.canOpenSettings(for: feature)
        }
        return true
    }
}

/// Guided Access and Assistive Access: keeping the person in Brickson.
struct KeepOpenView: View {
    var body: some View {
        SettingsScreen(title: "Keep \(AppName.display) Open") {
            KeepOpenContent()
        }
    }
}

struct KeepOpenContent: View {
    var body: some View {
        SettingsParagraph("A stray touch or look can leave \(AppName.display). iOS has two ways to keep someone in it. \(AppName.display) also keeps the screen from locking while it is open.")

        SettingsHeading("Guided Access")
        SettingsParagraph("Keeps the iPhone or iPad in one app until a passcode is entered.")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Guided Access and turn it on.",
            "In Passcode Settings, set a passcode.",
            "Open \(AppName.display), then triple-click the side or top button (the Home button on older models) and choose Start.",
            "To end it, triple-click again, enter the passcode and choose End.",
        ])
        SettingsParagraph("During Guided Access, emergency calls and Crash Detection are not available. Before relying on it, check that Eye Tracking, Switch Control or Voice Control still work with it on this device.")

        SettingsHeading("Assistive Access")
        SettingsParagraph("A simpler iPhone or iPad with only the apps chosen for it.")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Assistive Access and choose Set Up Assistive Access.",
            "When asked for apps, add \(AppName.display) under Other apps.",
            "Create an Assistive Access passcode.",
            "To leave it, triple-click the side button (the Home button on older models), choose Exit Assistive Access and enter the passcode.",
        ])
    }
}

/// The app's name and version, and what it never does.
struct AboutView: View {
    var body: some View {
        SettingsScreen(title: "About \(AppName.display)") {
            SettingsHeading(verbatim: AppName.display)
            SettingsParagraph("Version \(Self.version)")
            SettingsParagraph("\(AppName.display) speaks for people who find speaking hard. It keeps what it stores on this device and never sends it to the developer. Copies leave the device only as the privacy policy explains, such as in backups. It has no accounts, no ads and no analytics.")
        }
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

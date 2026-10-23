import Accessibility
import SwiftUI

// Passive guides for the family. Steps name Apple's own menus, checked
// against Apple's iPhone, iPad and Apple Watch User Guides for iOS 26 and
// iOS 27 on 2026-10-23 (docs/log/2026-10-23-apples-doors-in-family-setup.md);
// re-check them against the current pages when iOS changes (docs/DECISIONS.md,
// "Setup answers are kept as offered, never as completed").

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
        LeaveAssistiveAccessNote()

        ForEach(AccessMethod.allCases.filter(methods.contains), id: \.self) { method in
            section(for: method)
        }
    }

    @ViewBuilder
    private func section(for method: AccessMethod) -> some View {
        switch method {
        case .touch:
            SettingsHeading("Touch")
            SettingsParagraph("Nothing to turn on. If tapping is hard, Touch Accommodations can help: Hold Duration ignores touches shorter than a set time, Ignore Repeat treats several quick touches as one, and Tap Assistance uses the first or last place touched.")
            SettingsSteps(steps: [
                "Open Settings > Accessibility > Touch > Touch Accommodations.",
                "Turn on Touch Accommodations, or choose Set Up Touch Accommodations where the screen offers it, and choose the settings that help.",
                "Check that Touch Accommodations is in Settings > Accessibility > Accessibility Shortcut, so a triple-click can turn it off again.",
            ])
            SettingsParagraph("With it on, quick taps and swipes can seem to do nothing. AssistiveTouch, in Settings > Accessibility > Touch > AssistiveTouch, puts a menu on the screen for gestures that are hard to make.")
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
                "Connect an external switch first, if one is used. A Bluetooth switch is paired in Settings > Bluetooth.",
                "Open Settings > Accessibility > Switch Control > Switches and choose Add New Switch.",
                "Choose where the switch is: External, Screen, Camera, Back Tap, Sound or AirPod Gestures.",
                "Choose what it does. With one switch, choose Select Item.",
                "Add Switch Control to Settings > Accessibility > Accessibility Shortcut: once it is on, the usual touches cannot turn it off, and a triple-click can.",
                "Turn on Switch Control last, in Settings > Accessibility > Switch Control.",
            ])
            SettingsHeading("Switch Control timing")
            SettingsParagraph("These are in Settings > Accessibility > Switch Control.")
            SettingsParagraph("Scanning Style: Auto Scanning, the usual choice, moves the highlight by itself and works with one switch. Manual Scanning needs two switches.")
            SettingsParagraph("Auto Scanning Time sets how fast the highlight moves.")
            SettingsParagraph("Hold Duration sets how long a switch must be held before it counts. Ignore Repeat ignores a press that comes again too soon.")
            SettingsParagraph("Auto Tap, under Tap Behavior, taps a selected item after a short wait, without the menu. Pressing the switch again during the wait shows the menu instead.")
        case .eyeTracking:
            SettingsHeading("Eye Tracking")
            SettingsSteps(steps: [
                "Place the iPhone or iPad on a stable stand, about 1½ feet (45 cm) from the face.",
                "Open Settings > Accessibility > Eye Tracking and turn it on.",
                "Follow the dot with the eyes to calibrate. This happens each time Eye Tracking is turned on.",
                "Dwell Control, on the same screen, chooses a button by looking at it for a moment.",
                "How long a look takes is set in Settings > Accessibility > Touch > AssistiveTouch > Dwell Control.",
            ])
            OpenAccessibilitySettingsButton(title: "Open Dwell Control Settings", feature: .dwellControl)
            SettingsHeading("Eye trackers for iPad")
            SettingsParagraph("On iPad, an eye-tracking device made for iPad can move the pointer instead of the camera. Apple describes this for iPad, not iPhone.")
            SettingsSteps(steps: [
                "Connect the device as its maker explains, and set it up in its own app.",
                "Open Settings > Accessibility > Touch > AssistiveTouch and turn on AssistiveTouch.",
                "Turn on Dwell Control there, so that holding the gaze on a button chooses it.",
                "For the device's own options, choose Devices, then its name.",
            ])
        case .headTracking:
            SettingsHeading("Head Tracking")
            SettingsSteps(steps: [
                "Open Settings > Accessibility > Head Tracking and turn it on.",
                "Move the pointer by moving the head; choose with a facial expression or Dwell Control.",
                "How long a dwell takes is set in Settings > Accessibility > Touch > AssistiveTouch > Dwell Control.",
            ])
            OpenAccessibilitySettingsButton(title: "Open Dwell Control Settings", feature: .dwellControl)
        case .someoneElse:
            SettingsHeading("Someone else helps")
            SettingsParagraph("A partner can point to phrases on the screen for the person to choose with a look, a blink or a nod, then tap the one chosen.")
        }
    }
}

/// Opens one page of Accessibility settings, where iOS offers a direct link.
/// Inside Assistive Access it shows nothing: the steps above it give the
/// written path, and `LeaveAssistiveAccessNote` says to leave Assistive
/// Access first (`SettingsAppLink`).
struct OpenAccessibilitySettingsButton: View {
    let title: LocalizedStringKey
    let feature: AccessibilitySettings.Feature
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.accessibilityAssistiveAccessEnabled) private var insideAssistiveAccess
    @State private var failed = false

    var body: some View {
        if SettingsAppLink.offersButton(insideAssistiveAccess: insideAssistiveAccess, systemCanOpen: canOpen) {
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

/// Inside Assistive Access, says that the guide's steps are done after
/// leaving it, because the full Settings app opens only outside it
/// (`SettingsAppLink`). Elsewhere it shows nothing. Assistive Access cannot
/// start or end while Brickson is open, so the words never come or go
/// under a resting pointer.
struct LeaveAssistiveAccessNote: View {
    @Environment(\.accessibilityAssistiveAccessEnabled) private var insideAssistiveAccess

    var body: some View {
        if insideAssistiveAccess {
            SettingsParagraph("Assistive Access is on, so these steps are done after leaving it: triple-click the side or top button (the Home button, on a model that has one), choose Exit Assistive Access, and enter its passcode.")
        }
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
        LeaveAssistiveAccessNote()

        SettingsHeading("Guided Access")
        SettingsParagraph("Keeps the iPhone or iPad in one app until a passcode is entered.")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Guided Access and turn it on.",
            "In Passcode Settings, set a passcode.",
            "If a triple-click is used to turn features such as Switch Control on or off, turn on Accessibility Shortcut on the same screen, so it still works during Guided Access.",
            "Open \(AppName.display), then triple-click the side or top button (the Home button, on a model that has one) and choose Start.",
            "To end it, triple-click again, enter the passcode and choose End.",
        ])
        SettingsParagraph("During Guided Access, emergency calls and Crash Detection are not available. Before relying on it, check that Eye Tracking, Switch Control or Voice Control still work with it on this device.")

        SettingsHeading("Assistive Access")
        SettingsParagraph("A simpler iPhone or iPad with only the apps chosen for it. Inside it, \(AppName.display) fills the screen above the Back button.")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Assistive Access and choose Set Up Assistive Access.",
            "When asked for apps, add \(AppName.display).",
            "Create an Assistive Access passcode.",
            "To leave it, triple-click the side or top button (the Home button, on a model that has one), choose Exit Assistive Access and enter the passcode.",
        ])
        SettingsParagraph("Most settings, these guides' steps included, are changed only after leaving Assistive Access.")

        SettingsHeading("Screen lock")
        SettingsParagraph("Auto-Lock, in Settings > Display & Brightness > Auto-Lock, sets when the screen locks in other apps. While Low Power Mode is on, Auto-Lock is 30 seconds.")
        SettingsParagraph("Guided Access has its own Display Auto-Lock, which sets when the screen locks during a session. Open Settings > Accessibility > Guided Access > Display Auto-Lock and choose the longest time offered.")
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

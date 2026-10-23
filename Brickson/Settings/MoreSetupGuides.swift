import SwiftUI

// Two more passive guides, to Apple's features beyond reaching the screen.
// Steps name Apple's own menus, checked against Apple's iPhone, iPad and
// Apple Watch User Guides for iOS 26 and iOS 27 on 2026-10-23
// (docs/log/2026-10-23-apples-doors-in-family-setup.md); re-check them
// against the current pages when iOS changes. iOS opens none of these
// pages directly (`AccessibilitySettings.Feature`), so every step is a
// written path.

/// Live Speech, Vocal Shortcuts, Siri and the Action button: Apple's own
/// ways to speak and to run the device beyond Brickson.
struct CallsSiriAndShortcutsView: View {
    var body: some View {
        SettingsScreen(title: "Calls, Siri and Shortcuts") {
            SettingsParagraph("Apple's own features for speaking in calls, for Siri, and for running the device with a sound or a button. Each is turned on in the Settings app.")
            LeaveAssistiveAccessNote()
            liveSpeech
            liveSpeechOnAppleWatch
            vocalShortcuts
            listenForAtypicalSpeech
            actionButton
        }
    }

    @ViewBuilder
    private var liveSpeech: some View {
        SettingsHeading("Live Speech")
        SettingsParagraph("Type, and iOS speaks the words aloud, in the room and into phone and FaceTime calls. It can speak in a Personal Voice.")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Live Speech and turn it on.",
            "On the same screen, save phrases used often under Phrases.",
            "To speak, triple-click the side or top button (the Home button, on a model that has one), choose Live Speech if a list appears, then type the words and choose the button that speaks them.",
        ])
        SettingsParagraph("Live Speech's phrases are its own: \(AppName.display)'s phrases are not in it, so type in the few used most.")
    }

    @ViewBuilder
    private var liveSpeechOnAppleWatch: some View {
        SettingsHeading("Live Speech on Apple Watch")
        SettingsSteps(steps: [
            "On the Apple Watch, open Settings > Accessibility > Live Speech and turn it on.",
            "Save phrases under Favorite Phrases on the same screen.",
            "To speak, triple-click the Digital Crown, choose Live Speech if a list appears, then type or choose a phrase and choose Send.",
        ])
        SettingsParagraph("Apple Watch needs watchOS 10 or later.")
    }

    @ViewBuilder
    private var vocalShortcuts: some View {
        SettingsHeading("Vocal Shortcuts")
        SettingsParagraph("The iPhone or iPad learns a word or a sound of the person's own and runs an action when it hears it. It suits someone who can still make a few sounds the same way each time. While it is on, the microphone is in use; what it hears is handled on the device.")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Vocal Shortcuts, choose Set Up, then Continue.",
            "Choose the action. For something Siri does, choose Siri Request and type the request.",
            "Type the phrase that will run it, then say it aloud as the screen asks.",
        ])
    }

    @ViewBuilder
    private var listenForAtypicalSpeech: some View {
        SettingsHeading("Listen for Atypical Speech")
        SettingsParagraph("Helps Siri understand speech that has changed. iOS offers it when the device's language is English (U.S.).")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Siri.",
            "Turn on Listen for Atypical Speech.",
        ])
        SettingsParagraph("Siri Pause Time, on the same screen, gives more time to finish speaking.")
    }

    @ViewBuilder
    private var actionButton: some View {
        SettingsHeading("The Action button")
        SettingsParagraph("On an iPhone with an Action button, pressing and holding it can use an accessibility feature or run a shortcut.")
        SettingsSteps(steps: [
            "Open Settings > Action Button.",
            "Swipe to Accessibility and choose a feature, or to Shortcut and choose a shortcut. Without a choice, the button does nothing.",
            "Press and hold the Action button to use it.",
        ])
    }
}

/// The Accessibility Shortcut, Zoom and Share Accessibility Settings.
struct MoreAccessibilityView: View {
    var body: some View {
        SettingsScreen(title: "More Accessibility Settings") {
            SettingsParagraph("Other settings in iOS that can help. Each is in Settings > Accessibility.")
            LeaveAssistiveAccessNote()
            accessibilityShortcut
            zoom
            shareAccessibilitySettings
        }
    }

    @ViewBuilder
    private var accessibilityShortcut: some View {
        SettingsHeading("Accessibility Shortcut")
        SettingsParagraph("A triple-click of the side or top button (the Home button, on a model that has one) turns chosen features on or off, such as Switch Control or Live Speech. With more than one chosen, a list appears to choose from.")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Accessibility Shortcut.",
            "Choose the features a triple-click should reach.",
        ])
        SettingsParagraph("During Guided Access, a triple-click reaches them only if Accessibility Shortcut is turned on in Settings > Accessibility > Guided Access. Assistive Access has its own Accessibility Shortcut setting, in Settings > Accessibility > Assistive Access.")
        SettingsParagraph("If a triple-click is too fast, a slower click speed is set in Settings > Accessibility > Side Button (Top Button or Home Button on some models).")
    }

    @ViewBuilder
    private var zoom: some View {
        SettingsHeading("Zoom")
        SettingsParagraph("Magnifies the screen.")
        SettingsSteps(steps: [
            "Open Settings > Accessibility > Zoom and turn on Zoom.",
            "Double-tap the screen with three fingers to zoom in or out, and drag with three fingers to move around.",
        ])
        SettingsParagraph("If three-finger gestures are hard, add Zoom to the Accessibility Shortcut, and turn on Zoom Controller in Zoom's settings.")
    }

    @ViewBuilder
    private var shareAccessibilitySettings: some View {
        SettingsHeading("Share Accessibility Settings")
        SettingsParagraph("Lends the person's accessibility settings to another iPhone or iPad for a while. Sharing ends with Stop Sharing, a triple-click or locking the device, or when the two are more than 30 feet (about 9 m) apart.")
        SettingsSteps(steps: [
            "Turn on Bluetooth and Wi-Fi on both devices.",
            "Open Settings > Accessibility > Share Accessibility Settings, then choose Continue.",
            "Choose the other device as the screen shows, then choose Accept on it.",
        ])
    }
}

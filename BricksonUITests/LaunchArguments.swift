import Foundation

// What `launchedApp` asks the app for, as plain values and one plain list
// of launch arguments. Compiled into the unit tests too, where
// `LaunchArgumentsTests` reads the list with the app's own parser
// (`LaunchOptions.parse`), so a UI test never asks for an option the app
// does not understand.

/// Dynamic Type sizes the UI tests launch at, by UIKit's names for them.
nonisolated enum UITestTextSize: String, CaseIterable, Sendable {
    /// The system's default size.
    case large = "UICTContentSizeCategoryL"
    /// The largest size without Larger Accessibility Sizes turned on.
    case xxxLarge = "UICTContentSizeCategoryXXXL"
    case ax1 = "UICTContentSizeCategoryAccessibilityM"
    case ax3 = "UICTContentSizeCategoryAccessibilityXL"
    /// The largest size of all.
    case ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    /// How failure messages and capture names say it.
    var name: String {
        switch self {
        case .large: "default text"
        case .xxxLarge: "xxxLarge text"
        case .ax1: "AX1 text"
        case .ax3: "AX3 text"
        case .ax5: "AX5 text"
        }
    }
}

/// A debug launch preference, independently checked against rendered pixels.
nonisolated enum UITestAppearance: String, Sendable {
    case light
    case dark
}

/// Home's sizes (`ProfileChoice` in the app). Tests written for touch's
/// sizes ask for them; `fromTheAnswer` has Family Setup's answer decide,
/// the largest until anyone answers, even where the owner's switch holds
/// the sizes; `asShipped` asks for nothing, as a person's launch does.
nonisolated enum UITestSizes: String, Sendable {
    case touch
    case switchControl = "switch-control"
    case headTracking = "head-tracking"
    case eyeTracking = "eye-tracking"
    case fromTheAnswer = "from-answer"
    case asShipped
}

/// Where the launched app keeps what it saves (`LaunchOptions` in the app).
nonisolated enum UITestStorage: Sendable {
    /// Test-only storage, erased first: the starter phrases, no saved
    /// settings, no draft. Never the person's own data.
    case fresh
    /// The same test-only storage, keeping what an earlier launch in this
    /// test saved, to check that something survives a relaunch.
    case kept
}

nonisolated enum UITestLaunch {
    /// The launch arguments for a UI test's launch of the app, in the
    /// app's own words (`LaunchOptions`), then the system's for text size
    /// and language, then the test's own `extra` arguments.
    ///
    /// UIKit's animations are off unless `keepsUIKitAnimations` is true:
    /// XCTest counts them to know when the app has finished animating, and
    /// on an iPad that count can lose track as the keyboard goes, after
    /// which every wait in the launch runs for a full minute
    /// (docs/DECISIONS.md, "Tests").
    static func arguments(
        textSize: UITestTextSize,
        appearance: UITestAppearance,
        storage: UITestStorage,
        sizes: UITestSizes,
        shortTimeouts: Bool,
        keepsUIKitAnimations: Bool,
        extra: [String]
    ) -> [String] {
        [storage == .fresh ? "--fresh-test-storage" : "--test-storage"]
            + (shortTimeouts ? ["--short-timeouts"] : [])
            + (sizes == .asShipped ? [] : ["--home-profile=\(sizes.rawValue)"])
            + (keepsUIKitAnimations ? [] : ["--uikit-animations=off"])
            + [
                "--appearance=\(appearance.rawValue)",
                "-UIPreferredContentSizeCategoryName", textSize.rawValue,
                // Tests find controls by their English labels.
                "-AppleLanguages", "(en)",
                "-AppleLocale", "en_US",
            ]
            + extra
    }
}

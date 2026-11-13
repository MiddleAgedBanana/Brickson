import Testing
@testable import Brickson

/// What `launchedApp` passes the app (`UITestLaunch.arguments`), read with
/// the app's own parser (`LaunchOptions.parse`), so every option
/// `launchedApp` itself passes is one the app understands; one it did not
/// would only be logged and then ignored.
struct LaunchArgumentsTests {
    private static func arguments(
        textSize: UITestTextSize = .large,
        appearance: UITestAppearance = .light,
        storage: UITestStorage = .fresh,
        sizes: UITestSizes = .touch,
        shortTimeouts: Bool = true,
        keepsUIKitAnimations: Bool = false,
        extra: [String] = []
    ) -> [String] {
        UITestLaunch.arguments(
            textSize: textSize,
            appearance: appearance,
            storage: storage,
            sizes: sizes,
            shortTimeouts: shortTimeouts,
            keepsUIKitAnimations: keepsUIKitAnimations,
            extra: extra
        )
    }

    // Dropping or misspelling an option `launchedApp` gives every UI test,
    // the UIKit animations one above all (docs/DECISIONS.md, "Tests"),
    // fails this.
    @Test func everyUITestLaunchIsUnderstoodAsAsked() {
        let options = LaunchOptions.parse(Self.arguments())
        #expect(options.unrecognized.isEmpty)
        #expect(options.storage == .freshTest)
        #expect(options.usesShortTimeouts)
        #expect(options.appearance == .light)
        #expect(options.activeHomeProfile == .touch)
        #expect(options.activeUIKitAnimations == .off)
    }

    // A test that keeps UIKit's animations, keeps storage or asks for other
    // sizes, appearance or limits, and is launched otherwise, fails this.
    @Test func eachChoiceReachesTheApp() {
        let kept = LaunchOptions.parse(Self.arguments(
            appearance: .dark, storage: .kept, sizes: .eyeTracking, shortTimeouts: false, keepsUIKitAnimations: true
        ))
        #expect(kept.unrecognized.isEmpty)
        #expect(kept.storage == .test)
        #expect(!kept.usesShortTimeouts)
        #expect(kept.appearance == .dark)
        #expect(kept.activeHomeProfile == .eyeTracking)
        #expect(kept.uikitAnimations == nil)

        let fromTheAnswer = LaunchOptions.parse(Self.arguments(sizes: .fromTheAnswer))
        #expect(fromTheAnswer.unrecognized.isEmpty)
        #expect(fromTheAnswer.activeHomeProfile == nil)
        #expect(fromTheAnswer.activeHomeFollowsAnswer)

        let asShipped = LaunchOptions.parse(Self.arguments(sizes: .asShipped))
        #expect(asShipped.unrecognized.isEmpty)
        #expect(asShipped.activeHomeProfile == nil)
        #expect(!asShipped.activeHomeFollowsAnswer)
    }

    // Every size a UI test can ask for gives the app that profile's sizes;
    // a name that drifts from the app's, or two names swapped, fails this.
    @Test func everyUITestSizeGivesItsProfile() {
        let expected: [(UITestSizes, HomeLayout.Profile)] = [
            (.touch, .touch),
            (.switchControl, .switchControl),
            (.headTracking, .headTracking),
            (.eyeTracking, .eyeTracking),
        ]
        for (sizes, profile) in expected {
            let options = LaunchOptions.parse(Self.arguments(sizes: sizes))
            #expect(options.unrecognized.isEmpty, "\(sizes.rawValue)")
            #expect(options.activeHomeProfile == profile, "\(sizes.rawValue)")
        }
    }

    // The text size and language go to the system as its own arguments,
    // never read by the app's parser; a test's own arguments come last.
    @Test func theSystemsArgumentsAndATestsOwnAreKept() {
        let arguments = Self.arguments(textSize: .ax5, extra: ["--check-in-due"])
        #expect(arguments.last == "--check-in-due")
        let textSize = arguments.firstIndex(of: "-UIPreferredContentSizeCategoryName")
        #expect(textSize.map { arguments[$0 + 1] } == UITestTextSize.ax5.rawValue)
        #expect(arguments.contains("-AppleLanguages"))
        let options = LaunchOptions.parse(arguments)
        #expect(options.unrecognized.isEmpty)
        #expect(options.activeCheckInDue == LaunchOptions.readsLaunchArguments)
    }
}

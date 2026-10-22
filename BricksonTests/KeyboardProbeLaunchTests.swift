import Testing
@testable import Brickson

/// The launch argument that opens the keyboard probe in place of Home
/// (`KeyboardProbeLaunch`). Each test's comment names the change that would
/// make it fail.
struct KeyboardProbeLaunchTests {
    /// Fails if the argument changes here but not in `KeyboardProbeTests`,
    /// which spells it out because UI tests cannot see the app's code.
    @Test func theArgumentMatchesTheUITests() {
        #expect(KeyboardProbeLaunch.argument == "--screen=keyboard-probe")
    }

    /// Fails if the probe opens without its argument: every other launch,
    /// including the UI tests' own arguments, must open Home.
    @Test func homeOpensWithoutTheArgument() {
        #expect(!KeyboardProbeLaunch.isRequested(arguments: []))
        #expect(!KeyboardProbeLaunch.isRequested(arguments: [
            "Brickson", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]))
        #expect(!KeyboardProbeLaunch.isRequested(arguments: ["Brickson", "--screen=keyboard"]))
    }

    /// Fails if the argument stops opening the probe in a debug build, or
    /// starts opening it in a release build.
    @Test func onlyADebugBuildOpensTheProbe() {
        let arguments = ["Brickson", KeyboardProbeLaunch.argument]
        #if DEBUG
        #expect(KeyboardProbeLaunch.isRequested(arguments: arguments))
        #else
        #expect(!KeyboardProbeLaunch.isRequested(arguments: arguments))
        #endif
    }
}

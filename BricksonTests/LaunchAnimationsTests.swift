import Testing
import UIKit
@testable import Brickson

/// UI-test launches turn UIKit's animations off (`--uikit-animations=off`),
/// because XCTest's count of them can lose track as the keyboard goes on an
/// iPad, and then every later wait in that launch runs for a full minute
/// (docs/DECISIONS.md, "Tests"). A person's launch never turns them off.
///
/// Each test turns animations back on before it ends, without suspending,
/// so no other test runs while they are off.
struct LaunchAnimationsTests {
    // Reading the option but not acting on it, or acting on another
    // switch than UIKit's own, fails this.
    @Test func aUITestLaunchTurnsUIKitAnimationsOff() {
        defer { UIView.setAnimationsEnabled(true) }
        #expect(UIView.areAnimationsEnabled)
        LaunchOptions.parse(["--fresh-test-storage", "--uikit-animations=off"]).applyUIKitAnimations()
        #expect(UIView.areAnimationsEnabled == !LaunchOptions.readsLaunchArguments)
    }

    // Turning animations off for a person's launch, for a test launch that
    // did not ask, or without test storage, fails this.
    @Test func otherLaunchesLeaveUIKitAnimationsOn() {
        defer { UIView.setAnimationsEnabled(true) }
        #expect(UIView.areAnimationsEnabled)
        LaunchOptions.standard.applyUIKitAnimations()
        LaunchOptions.parse(["--fresh-test-storage"]).applyUIKitAnimations()
        LaunchOptions.parse(["--uikit-animations=off"]).applyUIKitAnimations()
        #expect(UIView.areAnimationsEnabled)
    }
}

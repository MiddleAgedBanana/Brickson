import Testing
import UIKit
@testable import Brickson

/// Keyboards from other apps are refused, so only Apple's keyboard, whose
/// height `KeyboardAllowance` is built on, appears in Brickson
/// (docs/DECISIONS.md, "Third-party keyboards refused in 1.0"). Each
/// test's comment names the change that would make it fail.
struct BricksonAppDelegateTests {
    /// Fails if the delegate stops refusing custom keyboards.
    @Test func customKeyboardsAreRefused() {
        let delegate = BricksonAppDelegate()
        #expect(!delegate.application(.shared, shouldAllowExtensionPointIdentifier: .keyboard))
    }

    /// Fails if the delegate refuses every kind of extension instead of
    /// keyboards alone: anything else is allowed, as without the method.
    @Test func otherExtensionPointsAreAllowed() {
        let delegate = BricksonAppDelegate()
        let other = UIApplication.ExtensionPointIdentifier(rawValue: "com.example.not-a-keyboard")
        #expect(delegate.application(.shared, shouldAllowExtensionPointIdentifier: other))
    }

    /// Fails if the running app does not hand the delegate to SwiftUI
    /// (`UIApplicationDelegateAdaptor` in `BricksonApp`): UIKit asks the
    /// app's delegate, and SwiftUI's own delegate answers for ours. The
    /// unit tests run inside the app, so this asks the app UIKit asks.
    @Test func theRunningAppRefusesCustomKeyboards() throws {
        let appDelegate = try #require(UIApplication.shared.delegate)
        let answer = appDelegate.application?(.shared, shouldAllowExtensionPointIdentifier: .keyboard)
        #expect(answer == false)
    }
}

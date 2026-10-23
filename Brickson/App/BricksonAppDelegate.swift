import UIKit

/// The one thing Brickson needs from UIKit's app delegate: refusing
/// keyboards from other apps, so only Apple's keyboard ever appears in
/// Brickson (docs/DECISIONS.md, "Third-party keyboards refused in 1.0").
///
/// Two reasons. The room Home keeps for the keyboard is worked out from
/// Apple's keyboards as measured (`KeyboardAllowance`); another app's
/// keyboard can be taller and cover Emergency, Get Attention, Yes or No.
/// And a keyboard given Full Access can send what is typed to its maker;
/// refusing them keeps the privacy policy's promise simple. Apple's own
/// keyboards, dictation and the keyboard features of Switch Control and
/// Eye Tracking are part of the system and are not affected.
///
/// SwiftUI has no way to refuse an app extension, so `BricksonApp` hands
/// this delegate to SwiftUI with `UIApplicationDelegateAdaptor`, the way
/// Apple documents for app-delegate callbacks in a SwiftUI app
/// (docs/DECISIONS.md, "Apple's current frameworks first").
final class BricksonAppDelegate: NSObject, UIApplicationDelegate {
    /// False for custom keyboards, the only kind of app extension an app
    /// can refuse; true for anything else, as if the method were not here.
    func application(
        _ application: UIApplication,
        shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier
    ) -> Bool {
        extensionPointIdentifier != .keyboard
    }
}

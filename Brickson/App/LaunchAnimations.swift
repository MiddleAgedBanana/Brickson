import UIKit

extension LaunchOptions {
    /// Turns UIKit's animations off for the rest of this launch when a UI
    /// test asked (`--uikit-animations=off`, with test storage, in a debug
    /// build), and otherwise changes nothing, so a person's launch always
    /// animates as UIKit does.
    ///
    /// XCTest waits after every action until each UIKit animation it saw
    /// start has finished. On GitHub's iPad simulators that wait stopped
    /// being answered as the keyboard went, and every later wait in that
    /// launch then ran a full minute, until the iPad UI job reached its
    /// time limit (docs/DECISIONS.md, "Tests"). With UIKit's animations
    /// off, a change made in an animation block happens at once and starts
    /// no animation for XCTest to wait for. Apple: this "affects only those animations
    /// that are submitted after it is called", so it runs first, before
    /// any view.
    @MainActor
    func applyUIKitAnimations() {
        guard activeUIKitAnimations == .off else { return }
        UIView.setAnimationsEnabled(false)
    }
}

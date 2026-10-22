import SwiftUI

/// The one line Home shows a family on first launch.
///
/// Brickson opens straight onto Home, never onto a setup screen
/// (docs/DECISIONS.md, "First launch opens Home; setup lives in Settings"):
/// someone who needs to speak can do so the moment it opens. Until Family
/// Setup has been opened once, Home's empty message area carries this
/// quiet, passive line instead of its usual placeholder. It is not a control
/// and never covers one.
nonisolated enum FirstRunHint {
    static func isShown(for record: SetupRecord) -> Bool {
        !record.familySetupOpened
    }

    /// Does not name the app, so it stays right if the name changes.
    static var text: String {
        String(localized: "Family: help with setting up is in Settings.")
    }
}

extension EnvironmentValues {
    /// True until Family Setup has been opened once. Home reads it to show
    /// `FirstRunHint.text` in place of its message placeholder.
    @Entry var showsSetupHint: Bool = false
}

/// Whether a Settings screen offers a button that opens one page of the
/// Settings app, or only the written path to it.
///
/// Inside Assistive Access, the full Settings app opens only after leaving
/// Assistive Access, so a button there would lead nowhere the family can
/// use. The written path, which every guide shows anyway, is then the only
/// way given (docs/DECISIONS.md, "Accessibility API coverage"). Being
/// inside Assistive Access never changes Home.
nonisolated enum SettingsAppLink {
    /// - Parameters:
    ///   - insideAssistiveAccess: Brickson is running inside Assistive
    ///     Access (`accessibilityAssistiveAccessEnabled`).
    ///   - systemCanOpen: iOS says it can open the page
    ///     (`AccessibilitySettings.canOpenSettings(for:)`, iOS 26.4 and
    ///     later). Before 26.4 there is no way to ask, so the caller passes
    ///     true, and a failure to open shows text.
    static func offersButton(insideAssistiveAccess: Bool, systemCanOpen: Bool) -> Bool {
        systemCanOpen && !insideAssistiveAccess
    }
}

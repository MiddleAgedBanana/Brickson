import Foundation

/// The app's name as people see it under the icon, read from the bundle so
/// it comes from one place: `APP_DISPLAY_NAME` in project.yml
/// (docs/DECISIONS.md, "App identity"). Words people see name the app
/// through this, never as a literal, so a new name needs no code change.
nonisolated enum AppName {
    static let display: String = {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? "Brickson"
    }()
}

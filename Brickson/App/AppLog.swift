import Foundation

/// Where the app's `Logger` messages are filed. Using the bundle identifier
/// keeps one source of truth for the app's identity (project.yml).
nonisolated enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "Brickson"
}

import SwiftUI

/// How long the app waits before acting on idleness: edit mode ending
/// itself, Settings returning to its start. Each idle timer asks for its
/// limit here, giving its real value and a short one, and reads it from the
/// environment (`\.appTimeouts`):
///
///     timeouts.limit(.seconds(120), short: .seconds(3))
///
/// UI tests launched with `--short-timeouts` get the short value, so they
/// don't wait minutes for a timer. Keep one UI test on the real limit
/// (docs/LESSONS.md, "Machine load causes false failures"). Elapsed time
/// is measured with `ContinuousClock` (docs/LESSONS.md, "Timers use
/// ContinuousClock").
nonisolated struct AppTimeouts: Equatable, Sendable {
    let usesShortLimits: Bool

    /// The real limits, in every build people install.
    static let standard = AppTimeouts(usesShortLimits: false)
    /// UI tests' short limits (`LaunchOptions`, `--short-timeouts`).
    static let short = AppTimeouts(usesShortLimits: true)

    func limit(_ standard: Duration, short: Duration) -> Duration {
        usesShortLimits ? short : standard
    }
}

extension EnvironmentValues {
    /// This launch's idle limits; the real ones unless a UI test asked.
    @Entry var appTimeouts: AppTimeouts = .standard
}

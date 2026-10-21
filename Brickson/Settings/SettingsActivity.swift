import Observation
import SwiftUI

/// The live side of `SettingsIdleClock`: Settings' screens report activity
/// and holds here, and `SettingsView` resets when the clock says so. The
/// decisions themselves live in the pure clock and are tested there.
@Observable
final class SettingsActivity {
    private(set) var clock: SettingsIdleClock
    /// Goes up on every idle reset; `SettingsView` rebuilds its screens from
    /// this, so they come back scrolled to the top.
    private(set) var resetCount = 0

    init(limit: Duration = SettingsIdleClock.standardLimit) {
        clock = SettingsIdleClock(limit: limit, startedAt: .now)
    }

    func recordActivity() {
        clock.recordActivity(at: .now)
    }

    func setHold(_ hold: SettingsIdleHold, _ isHeld: Bool) {
        clock.setHold(hold, isHeld, at: .now)
    }

    /// Returns true, and starts the next wait, when Settings should go back
    /// to its first screen now.
    func resetIfDue() -> Bool {
        let now = ContinuousClock.now
        guard clock.isDue(at: now) else { return false }
        clock.didReset(at: now)
        resetCount += 1
        return true
    }
}

extension View {
    /// Keeps Settings from resetting itself while `isBusy` is true, such as
    /// while an editor or a backup task is open on a screen inside Settings.
    /// When it becomes false the full idle wait starts again. Outside
    /// Settings it does nothing.
    func holdsSettingsIdleReset(_ isBusy: Bool) -> some View {
        modifier(SettingsIdleHoldModifier(isBusy: isBusy))
    }

    /// Counts scrolling as activity, so a family member reading a long
    /// screen is never reset mid-way.
    func recordsSettingsScrolling() -> some View {
        modifier(SettingsScrollActivityModifier())
    }
}

private struct SettingsIdleHoldModifier: ViewModifier {
    let isBusy: Bool
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onChange(of: isBusy, initial: true) { _, busy in
                activity?.setHold(.screen(id), busy)
            }
            .onDisappear {
                activity?.setHold(.screen(id), false)
            }
    }
}

private struct SettingsScrollActivityModifier: ViewModifier {
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?

    func body(content: Content) -> some View {
        content.onScrollPhaseChange { _, phase in
            if phase != .idle {
                activity?.recordActivity()
            }
        }
    }
}

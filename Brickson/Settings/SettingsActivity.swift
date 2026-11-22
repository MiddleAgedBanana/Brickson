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

    /// A control was used, a screen opened or closed, or a screen scrolled.
    func recordActivity() {
        clock.recordActivity(at: .now)
    }

    /// Brickson became active again: the full wait starts again, and
    /// nothing in Settings changed.
    func restartWait() {
        clock.restartWait(at: .now)
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

    /// Holds the reset while the screen scrolls, however long one drag
    /// lasts, and starts the full wait again when it comes to rest, so a
    /// family member reading a long screen is never reset mid-way.
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
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { old, phase in
                guard SettingsScrollUse.counts(from: old, to: phase) else { return }
                activity?.recordActivity()
                activity?.setHold(.scrolling(id), phase.isScrolling)
            }
            .onDisappear {
                activity?.setHold(.scrolling(id), false)
            }
    }
}

/// Which scroll phase changes count as use (`recordsSettingsScrolling()`).
nonisolated enum SettingsScrollUse {
    /// A change into, out of or within scrolling. A scroll view that
    /// appears reports a change from idle to idle, which is not a scroll:
    /// counted, it made every screen that appeared look used, the first
    /// screen rebuilt by a reset among them.
    static func counts(from old: ScrollPhase, to new: ScrollPhase) -> Bool {
        old.isScrolling || new.isScrolling
    }
}

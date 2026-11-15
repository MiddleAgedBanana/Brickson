import Foundation

/// A countdown the Changes station starts, so a person can move their look
/// to a slot and hold it still before the slot changes (A-6, G-01).
nonisolated struct ProbeCountdown: Equatable, Sendable {
    /// Long enough to move a look across an iPad and settle.
    static let standardLength: Duration = .seconds(5)

    let startedAt: ContinuousClock.Instant
    let length: Duration

    init(startedAt: ContinuousClock.Instant, length: Duration = Self.standardLength) {
        self.startedAt = startedAt
        self.length = length
    }

    func isFinished(now: ContinuousClock.Instant) -> Bool {
        now - startedAt >= length
    }

    /// Whole seconds left, rounded up, never below zero: "3" until the
    /// last third second has passed.
    func secondsLeft(now: ContinuousClock.Instant) -> Int {
        let left = length - (now - startedAt)
        guard left > .zero else { return 0 }
        let (seconds, attoseconds) = left.components
        return Int(seconds) + (attoseconds > 0 ? 1 : 0)
    }
}

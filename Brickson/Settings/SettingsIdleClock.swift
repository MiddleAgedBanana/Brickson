import Foundation

/// Why Settings must not reset itself right now. While any of these is
/// true, the idle clock is held; when the last one ends, the full wait
/// starts again, so a reset never lands the moment a task finishes.
nonisolated enum SettingsIdleHold: Hashable, Sendable {
    /// The privacy policy's web version is open in its sheet.
    case webPage
    /// iOS is asking whether Brickson may use Personal Voice.
    case personalVoiceRequest
    /// Get Attention is sounding: the call for help must not be interrupted
    /// by the screen changing under the person who comes to answer it.
    case alarm
    /// A screen pushed inside Settings asked to be held, such as the
    /// Library's editor or a backup task (`holdsSettingsIdleReset(_:)`).
    case screen(UUID)
}

/// When an idle Settings goes back to its first screen.
///
/// A family member can walk away from Settings half-way through a task. The
/// person using Brickson may then be left on a screen of configuration they
/// cannot leave, or one where a resting look lands on a setting. After 90
/// seconds without a control being used, a screen being opened or closed, or
/// a scroll, Settings returns to its root, so the large way back to talking
/// and Get Attention are where they always are.
///
/// It **resets, never closes** (AGENTS.md, *Design rules*: "timeouts reset
/// screens, never close them"). Closing would put Home's controls under a
/// spot nobody chose, which is a dwell hazard; returning to the root puts the
/// same safe top row in front of them that opening Settings does.
///
/// Time is `ContinuousClock`, and this type never reads it: callers pass
/// `now`, so tests are exact and a wall-clock jump cannot fire or postpone a
/// reset (docs/LESSONS.md, "Timers use ContinuousClock").
nonisolated struct SettingsIdleClock: Equatable, Sendable {
    /// The reference app's value, kept: long enough to read a screen of
    /// instructions aloud to someone, short enough that a person left alone
    /// in Settings is not stranded for long.
    static let standardLimit: Duration = .seconds(90)

    let limit: Duration
    private(set) var lastActivity: ContinuousClock.Instant
    private(set) var holds: Set<SettingsIdleHold> = []

    init(limit: Duration = Self.standardLimit, startedAt start: ContinuousClock.Instant) {
        self.limit = limit
        lastActivity = start
    }

    var isHeld: Bool { !holds.isEmpty }

    /// When Settings resets if nothing else happens; nil while held.
    var deadline: ContinuousClock.Instant? {
        isHeld ? nil : lastActivity + limit
    }

    /// A control was used, a screen was pushed or popped, or the list was
    /// scrolled. Also called when Brickson becomes active again, so time
    /// spent in another app or with the screen off never counts.
    mutating func recordActivity(at now: ContinuousClock.Instant) {
        lastActivity = max(lastActivity, now)
    }

    mutating func setHold(_ hold: SettingsIdleHold, _ isHeld: Bool, at now: ContinuousClock.Instant) {
        if isHeld {
            holds.insert(hold)
        } else if holds.remove(hold) != nil {
            // The task just ended: give the family the full wait from here.
            recordActivity(at: now)
        }
    }

    func isDue(at now: ContinuousClock.Instant) -> Bool {
        guard let deadline else { return false }
        return now >= deadline
    }

    /// Settings went back to its root: the next wait starts now.
    mutating func didReset(at now: ContinuousClock.Instant) {
        recordActivity(at: now)
    }
}

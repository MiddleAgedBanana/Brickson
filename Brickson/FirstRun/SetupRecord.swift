import Foundation

/// The ways a person can reach the screen, as Family Setup asks about them.
/// These name Apple's own features: Brickson adds no input code of its own
/// (AGENTS.md, invariant 1), so an answer only tunes sizes and guidance.
nonisolated enum AccessMethod: String, Codable, CaseIterable, Hashable, Sendable {
    case touch
    case voiceControl
    case switchControl
    case eyeTracking
    case headTracking
    /// Someone else chooses for them, such as a partner pointing for them.
    case someoneElse
}

/// What Family Setup has learned, kept between launches.
///
/// Everything here is recorded as *offered or answered*, never as
/// "setup completed": a family can stop half-way, and the app must behave
/// sensibly at every point. Nothing in it is a person's own words.
///
/// `Date` is used, not `ContinuousClock`, because these times must survive
/// relaunches and restarts, which `ContinuousClock` does not
/// (docs/DECISIONS.md, "Check-ins come every three months").
nonisolated struct SetupRecord: Codable, Equatable, Sendable {
    /// Bumped only with a migration in `SetupStore`.
    static let currentVersion = 1

    var version = Self.currentVersion
    /// When this record was first made: the app's first launch, or the
    /// launch after an unreadable record was set aside.
    var createdAt: Date
    /// Family Setup has been opened at least once. Home's first-run hint
    /// stops showing after that.
    var familySetupOpened = false
    /// How the person reaches the screen. Nil means nobody has answered,
    /// which the layout reads as "use the largest sizes" (docs/DECISIONS.md,
    /// "Setup answers are kept as offered, never as completed"). An empty
    /// set means someone cleared every choice, which is treated the same way.
    var accessMethods: Set<AccessMethod>?
    /// When the access question was last answered.
    var answeredAt: Date?
    /// Not Now on a check-in: ask again after this.
    var checkInSnoozedUntil: Date?
    /// Stop Asking on a check-in.
    var checkInsStopped = false

    init(createdAt: Date) {
        self.createdAt = createdAt
    }

    /// The access methods the layout should plan for, or nil when it should
    /// fall back to the largest sizes.
    var plannedAccessMethods: Set<AccessMethod>? {
        guard let accessMethods, !accessMethods.isEmpty else { return nil }
        return accessMethods
    }

    /// Records an answer to "How is the screen reached?". Answering also
    /// clears a snoozed check-in, since the family just looked again.
    mutating func answerAccessMethods(_ methods: Set<AccessMethod>, at now: Date) {
        accessMethods = methods
        answeredAt = now
        checkInSnoozedUntil = nil
    }
}

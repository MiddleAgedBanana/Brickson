import Foundation

/// When Family Setup asks the family to look again at how the person reaches
/// the screen.
///
/// ALS changes how someone can use a device, often over months. A setup that
/// was right for touch can become tiring once Eye Tracking or a switch takes
/// over, and nobody may think to revisit it. So, three months after setup was
/// last answered (or after the first launch, if it never was), Family Setup
/// shows a passive card asking whether anything has changed. It is never a
/// pop-up and never appears on Home: only a family member opening Settings
/// sees it.
///
/// Not Now waits 30 days. Stop Asking ends it until the access question is
/// answered again. Calendar days are used, so the card comes back on the
/// same date whatever the time zone or daylight saving does.
nonisolated enum CheckInPolicy {
    static let interval = DateComponents(month: 3)
    static let snooze = DateComponents(day: 30)

    static func isDue(_ record: SetupRecord, now: Date, calendar: Calendar) -> Bool {
        if record.checkInsStopped { return false }
        if let snoozedUntil = record.checkInSnoozedUntil {
            return now >= snoozedUntil
        }
        let since = max(record.createdAt, record.answeredAt ?? record.createdAt)
        guard let due = calendar.date(byAdding: interval, to: since) else { return false }
        return now >= due
    }

    static func notNow(_ record: inout SetupRecord, now: Date, calendar: Calendar) {
        record.checkInSnoozedUntil = calendar.date(byAdding: snooze, to: now)
    }

    static func stopAsking(_ record: inout SetupRecord) {
        record.checkInsStopped = true
        record.checkInSnoozedUntil = nil
    }

    /// What the card's place says once it was answered on screen. Family
    /// Setup keeps the card's frame and puts these words in it, so the rows
    /// below never move up under the button just activated (AGENTS.md,
    /// invariant 10).
    enum Afterword: Equatable {
        /// Not Now: the card comes back in 30 days.
        case askAgainLater
        /// Stop Asking.
        case stopped
        /// Set up again: the next check-in is three months away.
        case answered
    }

    static func afterword(for record: SetupRecord) -> Afterword {
        if record.checkInsStopped { return .stopped }
        if record.checkInSnoozedUntil != nil { return .askAgainLater }
        return .answered
    }

    /// The family answered again: checking in resumes three months from now.
    static func answered(_ record: inout SetupRecord, methods: Set<AccessMethod>, now: Date) {
        record.answerAccessMethods(methods, at: now)
        record.checkInsStopped = false
    }

    /// The family chose to go through setup again from the check-in card:
    /// that answers it, with the answers as they are, which the first step
    /// then changes if anything has.
    static func wentThroughAgain(_ record: inout SetupRecord, now: Date) {
        answered(&record, methods: record.accessMethods ?? [], now: now)
    }
}

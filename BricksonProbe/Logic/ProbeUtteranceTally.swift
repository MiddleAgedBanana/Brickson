import Foundation

/// Counts one utterance's word reports and the longest wait between them,
/// so the log can compare a system voice with a Personal Voice (D-25) and
/// one utterance with several (G-30).
nonisolated struct ProbeUtteranceTally: Equatable, Sendable {
    private(set) var startedAt: ContinuousClock.Instant
    private(set) var wordReports = 0
    private(set) var lastReport: ContinuousClock.Instant?
    /// From the start to the first report, or between two reports.
    private(set) var longestGap: Duration = .zero

    init(startedAt: ContinuousClock.Instant) {
        self.startedAt = startedAt
    }

    mutating func word(at instant: ContinuousClock.Instant) {
        let gap = instant - (lastReport ?? startedAt)
        if gap > longestGap { longestGap = gap }
        wordReports += 1
        lastReport = instant
    }

    /// One log line for the utterance's end.
    func summary(endedAt instant: ContinuousClock.Instant, how: String) -> String {
        "\(how) after \(ProbeLogFormat.seconds(instant - startedAt)) s: "
            + "\(wordReports) word reports, longest gap \(ProbeLogFormat.seconds(longestGap)) s"
    }
}

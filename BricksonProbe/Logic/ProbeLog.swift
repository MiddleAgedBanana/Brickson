import Foundation
import Observation

/// One line of the probe's log: when, on which station, and what.
nonisolated struct ProbeLogEntry: Equatable, Identifiable, Sendable {
    let id: Int
    /// Since the probe started, on the continuous clock.
    let elapsed: Duration
    /// The time of day, for the person reading the log.
    let clockTime: Date
    let station: String
    let event: String
}

/// Everything the probe saw, oldest first by the time each thing
/// happened. Each station records every activation and change here with
/// its time, so a filmed session can be matched to the log afterwards. A
/// report that arrives late (a speech report held up while the main thread
/// was busy) still goes in at the time it happened.
@Observable
final class ProbeLog {
    /// The most lines kept. A longer session drops its oldest lines and
    /// says how many in the export, so nothing is lost silently.
    static let capacity = 5_000

    private(set) var entries: [ProbeLogEntry] = []
    /// Lines dropped from the start because the log was full.
    private(set) var dropped = 0
    private var nextID = 0
    /// When the probe started; every line's elapsed time counts from here.
    let start: ContinuousClock.Instant

    init(start: ContinuousClock.Instant = .now) {
        self.start = start
    }

    func record(
        _ event: String,
        station: String,
        at instant: ContinuousClock.Instant = .now,
        clockTime: Date = .now
    ) {
        let entry = ProbeLogEntry(
            id: nextID, elapsed: instant - start, clockTime: clockTime,
            station: station, event: event)
        // After every line at the same time or earlier, so lines at the
        // same time keep the order they were recorded in.
        let index = entries.lastIndex(where: { $0.elapsed <= entry.elapsed }).map { $0 + 1 } ?? 0
        entries.insert(entry, at: index)
        nextID += 1
        if entries.count > Self.capacity {
            let excess = entries.count - Self.capacity
            entries.removeFirst(excess)
            dropped += excess
        }
    }

    func clear() {
        entries.removeAll()
        dropped = 0
    }

    /// The newest line from one station, for its on-screen readout.
    func latest(on station: String) -> ProbeLogEntry? {
        entries.last(where: { $0.station == station })
    }

    /// The whole log as tab-separated text, oldest first, to share.
    var exportText: String {
        var lines = ["seconds\ttime\tstation\tevent"]
        if dropped > 0 {
            lines.append("—\t—\tlog\t\(dropped) older lines were dropped: the log keeps \(Self.capacity)")
        }
        for entry in entries {
            lines.append([
                ProbeLogFormat.seconds(entry.elapsed),
                entry.clockTime.formatted(date: .omitted, time: .standard),
                entry.station,
                entry.event,
            ].joined(separator: "\t"))
        }
        return lines.joined(separator: "\n")
    }
}

nonisolated enum ProbeLogFormat {
    /// A duration in seconds with two decimals, as "12.34".
    static func seconds(_ duration: Duration) -> String {
        let (seconds, attoseconds) = duration.components
        let value = Double(seconds) + Double(attoseconds) / 1e18
        return String(format: "%.2f", value)
    }
}

import Foundation
import Observation

/// The latest status readings, in named groups, and a log line for each
/// change. The probe reads the system's groups every second and SwiftUI's
/// whenever its environment changes, whichever station is showing, so a
/// feature turned on in Settings shows in the log when the person returns.
@Observable
final class ProbeStatusMonitor {
    static let swiftUI = "SwiftUI environment"
    static let uikit = "UIKit"
    static let accessibility = "Accessibility framework"
    static let power = "Power and heat"
    /// The groups, in the order the Status station lists them.
    static let groups = [
        ProbeStatusMonitor.swiftUI, ProbeStatusMonitor.uikit, ProbeStatusMonitor.accessibility,
        ProbeStatusMonitor.power,
    ]

    private var latest: [String: [ProbeStatusReading]] = [:]
    private let log: ProbeLog

    init(log: ProbeLog) {
        self.log = log
    }

    func readings(for group: String) -> [ProbeStatusReading] {
        latest[group] ?? []
    }

    /// Stores a group's new readings and logs what changed: every value on
    /// the first read, then only the ones that moved. Power and heat are
    /// logged under the Screen station, the rest under Status.
    func update(_ group: String, with readings: [ProbeStatusReading]) {
        let old = latest[group] ?? []
        guard old != readings else { return }
        let station = group == Self.power ? ProbeStation.screen.title : ProbeStation.status.title
        for line in ProbeStatusChanges.lines(from: old, to: readings) {
            log.record(line, station: station)
        }
        latest[group] = readings
    }
}

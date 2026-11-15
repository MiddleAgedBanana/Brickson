import Foundation

/// One value the Status station reads, by its API name.
nonisolated struct ProbeStatusReading: Equatable, Sendable {
    let name: String
    let value: String
}

/// Which readings changed between two reads, as log lines (A-27): the app
/// cannot be told that Eye Tracking or Dwell is on, so the station reads
/// every public value each second and logs any that move, appear or are
/// no longer read.
nonisolated enum ProbeStatusChanges {
    static func lines(from old: [ProbeStatusReading], to new: [ProbeStatusReading]) -> [String] {
        let before = Dictionary(old.map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first })
        let changed = new.compactMap { reading -> String? in
            guard let earlier = before[reading.name] else {
                return "\(reading.name) = \(reading.value)"
            }
            return earlier == reading.value ? nil : "\(reading.name): \(earlier) → \(reading.value)"
        }
        let stillRead = Set(new.map(\.name))
        var gone = Set<String>()
        let removed = old.compactMap { reading -> String? in
            guard !stillRead.contains(reading.name), gone.insert(reading.name).inserted else { return nil }
            return "\(reading.name): \(reading.value) → no longer read"
        }
        return changed + removed
    }

    /// Words for the thermal state, as the Screen station logs it (A-39).
    static func words(for state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}

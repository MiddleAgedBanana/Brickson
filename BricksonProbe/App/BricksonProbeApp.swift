import SwiftUI

/// Brickson Probe: a separate test app for the experiments in
/// docs/EXPERIMENTS.md. It is never part of Brickson: its own target and
/// bundle identifier, never archived, never uploaded (docs/DECISIONS.md,
/// "A probe app for the experiments, kept out of Brickson").
@main
struct BricksonProbeApp: App {
    @State private var log: ProbeLog
    @State private var options = ProbeOptions()
    @State private var speaker: ProbeSpeaker
    @State private var monitor: ProbeStatusMonitor

    init() {
        let log = ProbeLog()
        _log = State(initialValue: log)
        _speaker = State(initialValue: ProbeSpeaker(log: log))
        _monitor = State(initialValue: ProbeStatusMonitor(log: log))
        log.record("Probe started", station: "Probe")
    }

    var body: some Scene {
        WindowGroup {
            probe
        }
        // D-13: how Apple dresses standard controls inside Assistive
        // Access. Only the probe declares this scene; Brickson never does
        // (AppBundleTests).
        AssistiveAccess {
            probe
        }
    }

    private var probe: some View {
        ProbeRootView()
            .environment(log)
            .environment(options)
            .environment(speaker)
            .environment(monitor)
    }
}

#Preview("Assistive Access", traits: .assistiveAccess) {
    let log = ProbeLog()
    ProbeRootView()
        .environment(log)
        .environment(ProbeOptions())
        .environment(ProbeSpeaker(log: log))
        .environment(ProbeStatusMonitor(log: log))
}

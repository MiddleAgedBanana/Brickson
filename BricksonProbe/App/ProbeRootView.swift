import SwiftUI

/// The probe's first screen: the stations in run-sheet order, the log, and
/// every option, so no option control sits on a station's own screen.
struct ProbeRootView: View {
    @Environment(ProbeLog.self) private var log
    @Environment(ProbeOptions.self) private var options
    @Environment(ProbeSpeaker.self) private var speaker
    @Environment(ProbeStatusMonitor.self) private var monitor
    @Environment(\.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var options = options
        NavigationStack {
            List {
                Section {
                    Text(verbatim: """
                        A test app for Brickson's experiments (docs/EXPERIMENTS.md in the \
                        repository). It is never part of Brickson. Each station logs what happens \
                        with its time; share the log after a session.
                        """)
                    .font(.callout)
                }
                Section {
                    ForEach(ProbeStation.allCases) { station in
                        NavigationLink(value: station) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: station.title).font(.headline)
                                Text(verbatim: station.summary).font(.subheadline)
                                Text(verbatim: station.questions.joined(separator: ", "))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink {
                        ProbeLogView()
                    } label: {
                        Text(verbatim: "Log (\(log.entries.count) lines)").font(.headline)
                    }
                } header: {
                    Text(verbatim: "Stations")
                }
                Section {
                    Picker(selection: $options.ringTarget) {
                        ForEach(ProbeRingTarget.allCases) { target in
                            Text(verbatim: "\(target.rawValue) points").tag(target)
                        }
                    } label: {
                        Text(verbatim: "Rings: middle button")
                    }
                    Picker(selection: $options.tileSizing) {
                        ForEach(ProbeTileSizing.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: {
                        Text(verbatim: "Look: tile sizes")
                    }
                    Picker(selection: $options.tileShape) {
                        ForEach(ProbeTileShape.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: {
                        Text(verbatim: "Look: tile shape")
                    }
                    Picker(selection: $options.hover) {
                        ForEach(ProbeHover.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: {
                        Text(verbatim: "Look: hover effect")
                    }
                    Toggle(isOn: $options.motionElsewhere) { Text(verbatim: "Look: motion beside the grid") }
                    Toggle(isOn: $options.postsLayoutChanged) { Text(verbatim: "Changes: post LayoutChanged") }
                    Toggle(isOn: $options.containsGroups) { Text(verbatim: "Groups: contain each region") }
                    Toggle(isOn: $options.sortsGroups) { Text(verbatim: "Groups: right region first") }
                    Toggle(isOn: $options.autocorrectionDisabled) {
                        Text(verbatim: "Typing: autocorrection off")
                    }
                    Toggle(isOn: $options.keepsScreenAwake) { Text(verbatim: "Screen: keep the screen on") }
                } header: {
                    Text(verbatim: "Options")
                }
                Section {
                    Picker(selection: $options.voiceIdentifier) {
                        Text(verbatim: "Default voice").tag(String?.none)
                        ForEach(speaker.voices) { voice in
                            Text(verbatim: voice.isPersonal ? "\(voice.name) (Personal Voice)" : voice.name)
                                .tag(Optional(voice.id))
                        }
                    } label: {
                        Text(verbatim: "Speech: voice")
                    }
                    Button {
                        Task { await speaker.loadVoices() }
                    } label: {
                        Text(verbatim: "List voices")
                    }
                    Button {
                        Task { await speaker.askForPersonalVoice() }
                    } label: {
                        Text(verbatim: "Ask for Personal Voice (\(speaker.personalVoiceAnswer))")
                    }
                    Picker(selection: $options.speakTrait) {
                        ForEach(ProbeSpeakTrait.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: {
                        Text(verbatim: "Speech: trait on Speak sentence")
                    }
                    Picker(selection: $options.pause) {
                        ForEach(ProbePause.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: {
                        Text(verbatim: "Speech: while speaking")
                    }
                    Picker(selection: $options.indicatorEffect) {
                        ForEach(ProbeIndicatorEffect.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: {
                        Text(verbatim: "Speech: indicator effect")
                    }
                } header: {
                    Text(verbatim: "Speech options")
                }
            }
            .navigationTitle(Text(verbatim: "Brickson Probe"))
            .navigationDestination(for: ProbeStation.self) { station in
                ProbeStationView(station: station)
            }
        }
        .onChange(of: options.keepsScreenAwake, initial: true) { _, awake in
            ProbeSystem.setKeepsScreenAwake(awake)
            log.record("Keep the screen on: \(awake)", station: ProbeStation.screen.title)
        }
        .onChange(of: scenePhase) { _, phase in
            log.record("Scene is now \(String(describing: phase))", station: ProbeStation.screen.title)
            if phase == .active {
                ProbeSystem.setKeepsScreenAwake(options.keepsScreenAwake)
            }
        }
        .onChange(of: ProbeReadings.environment(environment), initial: true) { _, readings in
            monitor.update(ProbeStatusMonitor.swiftUI, with: readings)
        }
        .task {
            while !Task.isCancelled {
                monitor.update(ProbeStatusMonitor.uikit, with: ProbeSystem.readings())
                monitor.update(ProbeStatusMonitor.accessibility, with: ProbeReadings.accessibilitySettings())
                monitor.update(ProbeStatusMonitor.power, with: ProbeReadings.power())
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

/// Opens the station chosen on the list.
struct ProbeStationView: View {
    let station: ProbeStation

    var body: some View {
        switch station {
        case .snap: SnapStation()
        case .rings: RingsStation()
        case .landing: LandingStation()
        case .changes: ChangesStation()
        case .groups: GroupsStation()
        case .look: LookStation()
        case .speech: SpeechStation()
        case .screen: ScreenStation()
        case .status: StatusStation()
        case .typing: TypingStation()
        case .busy: BusyStation()
        case .ruler: RulerStation()
        case .styles: StylesStation()
        }
    }
}

/// The log, newest first, to read on the device or share as text.
struct ProbeLogView: View {
    @Environment(ProbeLog.self) private var log

    var body: some View {
        List(log.entries.reversed()) { entry in
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(ProbeLogFormat.seconds(entry.elapsed)) s · \(entry.station)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(verbatim: entry.event)
            }
        }
        .navigationTitle(Text(verbatim: "Log"))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: log.exportText) {
                    Text(verbatim: "Share")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    log.clear()
                } label: {
                    Text(verbatim: "Clear the log")
                }
            }
        }
    }
}

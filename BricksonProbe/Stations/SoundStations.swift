import SwiftUI

/// A-16, A-17, A-18, A-31, A-40, D-07, D-25, G-30 and G-32: the app's own
/// speech on the `.playback` session, with every word report logged. Stop
/// sits apart from every control that speaks.
struct SpeechStation: View {
    @Environment(ProbeLog.self) private var log
    @Environment(ProbeOptions.self) private var options
    @Environment(ProbeSpeaker.self) private var speaker
    private let station = ProbeStation.speech

    var body: some View {
        ProbeStationScreen(station: station) {
            VStack(spacing: 24) {
                indicator
                    .font(.system(size: 56))
                    .frame(height: 80)
                    .accessibilityHidden(true)
                Grid(horizontalSpacing: 16, verticalSpacing: 24) {
                    GridRow {
                        speak("Speak sentence", [ProbeSpeechScripts.sentence])
                            .accessibilityAddTraits(speakTraits)
                        speak("Speak in three parts", ProbeSpeechScripts.parts)
                    }
                    GridRow {
                        Button {
                            speaker.speak(
                                [], label: "SSML with pauses", voiceIdentifier: options.voiceIdentifier,
                                pausing: options.pause,
                                ssml: ProbeSpeechScripts.ssml(
                                    parts: ProbeSpeechScripts.parts,
                                    pauseMilliseconds: ProbeSpeechScripts.pauseMilliseconds))
                        } label: {
                            label("Speak with SSML pauses")
                        }
                        Button {
                            Task { await speaker.announce(after: .seconds(3)) }
                        } label: {
                            label("Announce in 3 seconds")
                        }
                    }
                    GridRow {
                        speak("Say a Voice Control command", [ProbeSpeechScripts.voiceControlCommand])
                        speak("Say a Siri test", [ProbeSpeechScripts.siriTest])
                    }
                }
                .padding(.horizontal, 16)
                Spacer(minLength: 0)
                HStack {
                    ProbeButton(name: ProbeSpeechScripts.counterLabel, station: station, width: 120, height: 70)
                    Spacer()
                    Button {
                        speaker.stop()
                    } label: {
                        Text(verbatim: "Stop speaking").frame(width: 140, height: 70)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .buttonStyle(.bordered)
            .padding(.top, 16)
        }
    }

    private var speakTraits: AccessibilityTraits {
        switch options.speakTrait {
        case .noTrait: []
        case .startsMediaSession: .startsMediaSession
        case .playsSound: .playsSound
        }
    }

    @ViewBuilder private var indicator: some View {
        let symbol = Image(systemName: "speaker.wave.3")
        switch options.indicatorEffect {
        case .variableColor: symbol.symbolEffect(.variableColor.iterative, isActive: speaker.isSpeaking)
        case .pulse: symbol.symbolEffect(.pulse, isActive: speaker.isSpeaking)
        case .breathe: symbol.symbolEffect(.breathe, isActive: speaker.isSpeaking)
        }
    }

    private func speak(_ title: String, _ texts: [String]) -> some View {
        Button {
            speaker.speak(
                texts, label: title, voiceIdentifier: options.voiceIdentifier,
                pausing: options.pause)
        } label: {
            label(title)
        }
    }

    /// Up to 170 points wide, narrower where the window is, so two
    /// columns fit a phone.
    private func label(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 170)
            .frame(height: 70)
    }
}

/// A-34: exactly what the keyboard delivered. Spaces show as dots and
/// Return as its mark, so an accepted correction or prediction shows as
/// words the person did not type. Clear sits apart from the field.
struct TypingStation: View {
    @Environment(ProbeLog.self) private var log
    @Environment(ProbeOptions.self) private var options
    @State private var text = ""
    private let station = ProbeStation.typing

    var body: some View {
        ProbeStationScreen(station: station) {
            VStack(alignment: .leading, spacing: 24) {
                TextField(text: $text) {
                    Text(verbatim: "Type here")
                }
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .autocorrectionDisabled(options.autocorrectionDisabled)
                .onSubmit {
                    log.record("Return with: \(ProbeVisibleText.marked(text))", station: station.title)
                }
                Text(verbatim: ProbeVisibleText.marked(text))
                    .font(.title2.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text(verbatim: "Received: \(text)"))
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Button {
                        text = ""
                        log.record("Field cleared", station: station.title)
                    } label: {
                        Text(verbatim: "Clear field").frame(width: 140, height: 60)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .onChange(of: text) { _, new in
            log.record("Field now: \(ProbeVisibleText.marked(new))", station: station.title)
        }
    }
}

/// A-22, A-23, A-32, A-39, G-25 and G-26: a running clock to film, with
/// Low Power Mode, heat and the screen-on setting. Changes to them, and
/// to the app's scene (when the screen locks), are logged by the probe as
/// a whole, whichever station is showing.
struct ScreenStation: View {
    @Environment(ProbeLog.self) private var log
    @Environment(ProbeStatusMonitor.self) private var monitor
    private let station = ProbeStation.screen

    var body: some View {
        ProbeStationScreen(station: station) {
            VStack(spacing: 24) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(verbatim: "\(ProbeLogFormat.seconds(ContinuousClock.now - log.start)) s")
                        .font(.system(size: 64, weight: .semibold).monospacedDigit())
                }
                ForEach(monitor.readings(for: ProbeStatusMonitor.power), id: \.name) { reading in
                    Text(verbatim: "\(reading.name): \(reading.value)")
                        .font(.title3)
                }
                ForEach(monitor.readings(for: ProbeStatusMonitor.uikit)
                    .filter { $0.name.hasPrefix("UIApplication") || $0.name.contains("ShakeToUndo") },
                    id: \.name
                ) { reading in
                    Text(verbatim: "\(reading.name): \(reading.value)")
                        .font(.title3)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// A-27: every public value the app can read about the accessibility
/// features in use, refreshed each second; each change is logged.
struct StatusStation: View {
    @Environment(ProbeStatusMonitor.self) private var monitor
    private let station = ProbeStation.status

    var body: some View {
        ProbeStationScreen(station: station) {
            List {
                ForEach(ProbeStatusMonitor.groups, id: \.self) { group in
                    Section {
                        ForEach(monitor.readings(for: group), id: \.name) { reading in
                            LabeledContent {
                                Text(verbatim: reading.value)
                            } label: {
                                Text(verbatim: reading.name)
                                    .font(.callout.monospaced())
                            }
                        }
                    } header: {
                        Text(verbatim: group)
                    }
                }
            }
        }
    }
}

import AVFoundation
import Foundation
import Observation
import SwiftUI

/// Local diagnostic only. Never added to Brickson or shipped.
@main
struct SystemSpeechControlApp: App {
    var body: some Scene {
        WindowGroup { ControlView() }
    }
}

private struct ControlView: View {
    @State private var control = SpeechControl()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("System Speech Control").font(.title)
                Text(control.options.summary)
                Text(control.phase).font(.headline)
                Text(control.rawFlags).monospaced()
                Text("One fixed diagnostic utterance starts automatically. Its text is omitted from the trace.")
                Text("Sampling ends after 35 seconds. No stop, cancel, pause, retry or recovery is sent.")
            }
            .padding()
        }
        .task { await control.runOnce() }
    }
}

/// Immutable configuration; separate app launches keep each comparison independent.
private nonisolated struct ControlOptions: Sendable {
    enum AudioMode: String, Sendable {
        case appPlayback = "playback"
        case systemManaged = "system-managed"

        var configuresPlayback: Bool { self != .systemManaged }
        var usesApplicationSession: Bool { self == .appPlayback }
    }

    enum VoiceMode: String, Sendable {
        case production
        case none = "nil"
    }

    let audio: AudioMode
    let voice: VoiceMode
    let isValid: Bool

    static var current: ControlOptions {
        let arguments = ProcessInfo.processInfo.arguments
        let audioValue = arguments.first { $0.hasPrefix("--audio=") }
            .map { String($0.dropFirst("--audio=".count)) } ?? AudioMode.appPlayback.rawValue
        let voiceValue = arguments.first { $0.hasPrefix("--voice=") }
            .map { String($0.dropFirst("--voice=".count)) } ?? VoiceMode.production.rawValue
        return ControlOptions(
            audio: AudioMode(rawValue: audioValue) ?? .appPlayback,
            voice: VoiceMode(rawValue: voiceValue) ?? .production,
            isValid: AudioMode(rawValue: audioValue) != nil && VoiceMode(rawValue: voiceValue) != nil
        )
    }

    var summary: String { "Audio: \(audio.rawValue); voice: \(voice.rawValue)" }
}

/// No shared mutable counters, actor hops or utterance descriptions at callback entry.
private nonisolated enum ControlTrace {
    static let origin = ContinuousClock.now

    static func emit(_ event: String, _ fields: String = "") {
        let elapsed = origin.duration(to: ContinuousClock.now)
        print("SYSTEM-SPEECH-CONTROL elapsed=\(elapsed) event=\(event) \(fields)")
    }
}

/// Callbacks deliberately do nothing except print scalars on their calling thread.
/// The app keeps this object alive for the same lifetime as its synthesizer.
@MainActor
private final class DirectSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        ControlTrace.emit("didStart")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        ControlTrace.emit("didFinish")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        ControlTrace.emit("didPause")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        ControlTrace.emit("didContinue")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        ControlTrace.emit("didCancel")
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        ControlTrace.emit("willSpeak", "through=\(characterRange.location + characterRange.length)")
    }
}

@MainActor
@Observable
private final class SpeechControl {
    let options = ControlOptions.current
    private(set) var phase = "Waiting for the automatic diagnostic start"
    private(set) var rawFlags = "No sample yet"
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = DirectSpeechDelegate()
    @ObservationIgnored private var utterance: AVSpeechUtterance?
    @ObservationIgnored private var hasStarted = false

    func runOnce() async {
        guard !hasStarted else { return }
        hasStarted = true
        guard options.isValid else {
            phase = "Invalid diagnostic options; speech was not requested"
            ControlTrace.emit("invalidOptions")
            return
        }

        synthesizer.delegate = delegate
        synthesizer.usesApplicationAudioSession = options.audio.usesApplicationSession
        ControlTrace.emit(
            "configuration",
            "audio=\(options.audio.rawValue) configurePlayback=\(options.audio.configuresPlayback) usesApplicationAudioSession=\(synthesizer.usesApplicationAudioSession) voiceMode=\(options.voice.rawValue) rate=\(AVSpeechUtteranceDefaultSpeechRate)"
        )

        if options.audio.configuresPlayback {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [])
                ControlTrace.emit("setCategorySucceeded", "category=playback mode=default options=none")
                try session.setActive(true)
                ControlTrace.emit("setActiveSucceeded")
            } catch {
                // No localizedDescription: this diagnostic never emits an arbitrary error string.
                ControlTrace.emit("sessionConfigurationFailed", "code=\((error as NSError).code)")
                phase = "Session configuration failed; speech is still requested"
            }
        } else {
            ControlTrace.emit("manualSessionConfigurationSkipped")
        }

        let request = AVSpeechUtterance(string: "Yes.")
        request.rate = AVSpeechUtteranceDefaultSpeechRate
        if options.voice == .production {
            request.voice = resolveProductionSystemVoice()
        } else {
            request.voice = nil
            ControlTrace.emit("voiceResolved", "voice=nil")
        }
        utterance = request
        ControlTrace.emit("speakBefore", flags())
        synthesizer.speak(request)
        ControlTrace.emit("speakReturned", flags())
        phase = "Sampling raw system flags"

        let clock = ContinuousClock()
        let samplingStart = clock.now
        for second in 0...35 {
            if second > 0 {
                do {
                    try await clock.sleep(until: samplingStart.advanced(by: .seconds(second)))
                } catch {
                    phase = "Sampling task cancelled; no stop was sent"
                    ControlTrace.emit("samplingCancelled", flags())
                    return
                }
            }
            rawFlags = flags()
            ControlTrace.emit("sample", "second=\(second) \(rawFlags)")
        }
        phase = "35-second sampling complete; no stop was sent"
        ControlTrace.emit("samplingComplete", flags())
    }

    private func flags() -> String {
        "isSpeaking=\(synthesizer.isSpeaking) isPaused=\(synthesizer.isPaused) delegateRetained=true utteranceRetained=\(utterance != nil)"
    }

    /// Same catalog order, pure selector, descriptor mapping and unavailable-ID retry
    /// as a fresh Brickson launch. This control intentionally uses system voices only.
    private func resolveProductionSystemVoice() -> AVSpeechSynthesisVoice? {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let installed = AVSpeechSynthesisVoice.speechVoices().map(VoiceDescriptor.init)
        var candidates = VoiceSelection.usableVoices(installed, personalVoiceAllowed: false)
        ControlTrace.emit(
            "voiceSelection",
            "language=\(language) installedCount=\(installed.count) usableSystemCount=\(candidates.count) chosenID=nil automaticPersonalVoiceID=nil personalVoicesAllowed=false"
        )
        while let descriptor = VoiceSelection.select(
            chosenID: nil,
            from: candidates,
            languageCode: language,
            automaticPersonalVoiceID: nil
        ) {
            if let voice = AVSpeechSynthesisVoice(identifier: descriptor.id) {
                // Neither a name nor a Personal Voice identifier is ever printed.
                guard !voice.voiceTraits.contains(.isPersonalVoice) else {
                    candidates.removeAll { $0.id == descriptor.id }
                    ControlTrace.emit("resolvedPersonalVoiceExcluded")
                    continue
                }
                ControlTrace.emit("voiceResolved", "systemVoiceID=\(voice.identifier) language=\(voice.language) quality=\(descriptor.quality.rawValue) novelty=\(descriptor.isNovelty)")
                return voice
            }
            candidates.removeAll { $0.id == descriptor.id }
            ControlTrace.emit("unavailableCandidateRemoved")
        }
        ControlTrace.emit("voiceResolved", "voice=nil noResolvableSystemCandidate=true")
        return nil
    }
}

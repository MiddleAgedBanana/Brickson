import AVFoundation
import Accessibility
import Observation

/// A voice the Speech station can choose.
nonisolated struct ProbeVoice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let isPersonal: Bool
}

/// The probe's speech: the same synthesizer and `.playback` session
/// Brickson uses, with every report written to the log.
@Observable
final class ProbeSpeaker {
    private(set) var isSpeaking = false
    private(set) var voices: [ProbeVoice] = []
    private(set) var personalVoiceAnswer = "not asked yet"

    private let synthesizer = AVSpeechSynthesizer()
    private let events = ProbeSpeechEvents()
    @ObservationIgnored private var spoken: [ObjectIdentifier: (label: String, tally: ProbeUtteranceTally?)] = [:]
    @ObservationIgnored private var paused = ProbePause.nothing
    @ObservationIgnored private var listening: Task<Void, Never>?
    private let log: ProbeLog
    private let station = ProbeStation.speech.title

    init(log: ProbeLog) {
        self.log = log
        synthesizer.delegate = events
        synthesizer.usesApplicationAudioSession = true
        let stream = events.stream
        listening = Task { [weak self] in
            for await event in stream {
                self?.handle(event)
            }
        }
    }

    /// Speaks each text as its own utterance, in order. `ssml` makes one
    /// utterance from SSML markup instead (G-32).
    func speak(
        _ texts: [String], label: String, voiceIdentifier: String?, pausing pause: ProbePause,
        ssml: String? = nil
    ) {
        guard activateSession() else { return }
        let voice = voiceIdentifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
        var utterances: [AVSpeechUtterance] = []
        if let ssml {
            guard let utterance = AVSpeechUtterance(ssmlRepresentation: ssml) else {
                log.record("\(label): the synthesizer refused the SSML", station: station)
                return
            }
            utterances.append(utterance)
        } else {
            utterances = texts.map(AVSpeechUtterance.init(string:))
        }
        if pause != .nothing, paused == .nothing {
            ProbeSystem.pause(pause)
            paused = pause
            log.record("Asked to pause: \(pause.rawValue)", station: station)
        }
        for (index, utterance) in utterances.enumerated() {
            utterance.voice = voice
            let part = utterances.count > 1 ? " part \(index + 1) of \(utterances.count)" : ""
            spoken[ObjectIdentifier(utterance)] = (label: label + part, tally: nil)
            synthesizer.speak(utterance)
        }
        log.record(
            "\(label): queued with \(voice?.name ?? "the default voice")", station: station)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        log.record("Stop speaking chosen", station: station)
    }

    /// Asks for Personal Voice permission, so a Personal Voice can be
    /// chosen (D-25, G-32).
    func askForPersonalVoice() async {
        let status = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
        personalVoiceAnswer = switch status {
        case .authorized: "allowed"
        case .denied: "denied"
        case .notDetermined: "not decided"
        case .unsupported: "not supported on this device"
        @unknown default: "an answer this probe does not know"
        }
        log.record("Personal Voice permission: \(personalVoiceAnswer)", station: station)
        await loadVoices()
    }

    /// Reads the voice list away from the main thread, which the system
    /// can take a while to answer (docs/DECISIONS.md, "The voice list never
    /// holds up launch").
    func loadVoices() async {
        voices = await Task.detached { ProbeSpeaker.readVoices() }.value
        log.record("\(voices.count) voices listed", station: station)
    }

    private nonisolated static func readVoices() -> [ProbeVoice] {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                !voice.voiceTraits.contains(.isNoveltyVoice)
                    && (voice.voiceTraits.contains(.isPersonalVoice) || voice.language == language)
            }
            .map { voice in
                ProbeVoice(
                    id: voice.identifier, name: voice.name,
                    isPersonal: voice.voiceTraits.contains(.isPersonalVoice))
            }
            .sorted { ($0.isPersonal ? 0 : 1, $0.name) < ($1.isPersonal ? 0 : 1, $1.name) }
    }

    /// Posts an accessibility announcement after a delay, so the person
    /// can start speech or switch features first (A-18, A-31).
    func announce(after delay: Duration) async {
        log.record("Announcement in \(ProbeLogFormat.seconds(delay)) s", station: station)
        try? await Task.sleep(for: delay)
        AccessibilityNotification.Announcement(ProbeSpeechScripts.announcement).post()
        log.record("Announcement posted", station: station)
    }

    private func activateSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            return true
        } catch {
            log.record("The audio session could not start: \(error.localizedDescription)", station: station)
            return false
        }
    }

    private func handle(_ event: ProbeSpeechEvent) {
        switch event {
        case let .started(id, instant):
            isSpeaking = true
            spoken[id]?.tally = ProbeUtteranceTally(startedAt: instant)
            log.record("\(label(id)): started", station: station, at: instant)
        case let .word(id, location, length, instant):
            spoken[id]?.tally?.word(at: instant)
            log.record("\(label(id)): word at \(location), \(length) long", station: station, at: instant)
        case let .finished(id, instant):
            end(id, how: "finished", at: instant)
        case let .cancelled(id, instant):
            end(id, how: "cancelled", at: instant)
        }
    }

    private func end(_ id: ObjectIdentifier, how: String, at instant: ContinuousClock.Instant) {
        let summary = spoken[id]?.tally?.summary(endedAt: instant, how: how) ?? how
        log.record("\(label(id)): \(summary)", station: station, at: instant)
        spoken[id] = nil
        guard spoken.isEmpty else { return }
        isSpeaking = false
        if paused != .nothing {
            ProbeSystem.resume(paused)
            log.record("Asked to resume after: \(paused.rawValue)", station: station)
            paused = .nothing
        }
    }

    private func label(_ id: ObjectIdentifier) -> String {
        spoken[id]?.label ?? "An utterance the probe did not queue"
    }
}

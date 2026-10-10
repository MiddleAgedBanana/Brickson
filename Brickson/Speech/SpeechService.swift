import AVFoundation
import Observation
import os

/// Owns the block-based audio-session observer and reduces the notification to
/// the only event speech recovery needs. The small injectable boundary keeps
/// real NotificationCenter routing under test without faking AVFoundation.
@MainActor
final class AudioSessionInterruptionObserver {
    private let notificationCenter: NotificationCenter
    private var token: (any NSObjectProtocol)?

    init(
        notificationCenter: NotificationCenter = .default,
        object: Any? = nil,
        onBegan: @escaping @MainActor @Sendable (AVAudioSession.InterruptionType) -> Void
    ) {
        self.notificationCenter = notificationCenter
        token = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: object,
            queue: .main
        ) { notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init)
            guard type == .began else { return }
            MainActor.assumeIsolated { onBegan(.began) }
        }
    }

    isolated deinit {
        if let token {
            notificationCenter.removeObserver(token)
        }
    }
}

/// The app's single text-to-speech engine. One instance is created at launch
/// and shared through the environment; it owns the only `AVSpeechSynthesizer`.
@MainActor
@Observable
final class SpeechService {
    private(set) var lastSpokenText: String?
    private(set) var personalVoiceStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = .notDetermined
    private(set) var availableVoices: [VoiceDescriptor] = []
    var speechInterruptionState: SpeechInterruptionState { speechInterruptionStatus.state }
    var speechInterruptionSequence: Int { speechInterruptionStatus.sequence }

    /// Identifier of the user-chosen voice; nil means automatic selection.
    var selectedVoiceID: String? {
        didSet { UserDefaults.standard.set(selectedVoiceID, forKey: Self.voiceIDKey) }
    }

    var speechRate: Float {
        didSet { UserDefaults.standard.set(speechRate, forKey: Self.rateKey) }
    }

    /// True from the moment an utterance is handed to the synthesizer until it
    /// finishes or is cancelled. Drives the speaking indicator on Home.
    var isSpeaking: Bool { utterances.isSpeaking }

    private var synthesizer = AVSpeechSynthesizer()
    private var speechInterruptionStatus = SpeechInterruptionStatus()
    private var utterances = SpokenUtteranceTracker<ObjectIdentifier>()
    /// Retained while active so its ObjectIdentifier cannot be reused by a new
    /// utterance before the synthesizer reports the old one finished.
    @ObservationIgnored private var activeUtterance: AVSpeechUtterance?
    @ObservationIgnored private var synthesizerEvents: SpeechSynthesizerEvents?
    @ObservationIgnored private var audioSessionInterruptionObserver: AudioSessionInterruptionObserver?
    @ObservationIgnored private let audioSafetyMonitor: AudioSafetyMonitor
    private let logger = Logger(subsystem: AppLog.subsystem, category: "speech")
    private static let voiceIDKey = "selectedVoiceID"
    private static let rateKey = "speechRate"

    init(audioSafetyMonitor: AudioSafetyMonitor = AudioSafetyMonitor()) {
        self.audioSafetyMonitor = audioSafetyMonitor
        let audioSession = AVAudioSession.sharedInstance()

        let defaults = UserDefaults.standard
        selectedVoiceID = defaults.string(forKey: Self.voiceIDKey)
        // Presence check rather than float(forKey:): an absent key reads as 0,
        // which is also AVSpeechUtteranceMinimumSpeechRate — a value a user
        // could legitimately save from the rate slider.
        if let storedRate = defaults.object(forKey: Self.rateKey) as? Float {
            speechRate = min(max(storedRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        } else {
            speechRate = AVSpeechUtteranceDefaultSpeechRate
        }

        // Set (but don't activate) the category at launch so any audio the app
        // plays — including the Get Attention tone on a fresh launch, before
        // the first utterance — already ignores the ring/silent switch.
        configurePlaybackAudioSession()

        let synthesizerEvents = SpeechSynthesizerEvents(
            onUtteranceEnded: { [weak self] id, wasCancelled in
                self?.utteranceEnded(id, wasCancelled: wasCancelled)
            },
            onUtteranceProgress: { [weak self] id, instant in
                self?.utterances.recordProgress(id, at: instant)
            }
        )
        self.synthesizerEvents = synthesizerEvents
        synthesizer.delegate = synthesizerEvents

        refreshVoices()
        NotificationCenter.default.addObserver(
            forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshVoices() }
        }
        audioSessionInterruptionObserver = AudioSessionInterruptionObserver(
            object: audioSession
        ) { [weak self] _ in
            // A call/Siri/alarm leaves the synthesizer paused on a deactivated
            // session, and the .ended notification is not guaranteed. Stop for
            // a clean state; the phrase stays in lastSpokenText so one Again
            // activation re-speaks it in full.
            guard let self else { return }
            let repeatableSpeechActive = self.utterances.isRepeatableSpeechActive
            self.stop()
            self.speechInterruptionStatus.recordInterruption(
                repeatableSpeechActive: repeatableSpeechActive
            )
        }
        audioSafetyMonitor.onMediaServicesReset { [weak self] in
            guard let self else { return }
            // The media daemon crashed; every audio object is invalid. Without
            // recreating the synthesizer, speech stays dead until relaunch —
            // for a person who cannot speak, that is the whole app dead.
            // A phrase cut off by the crash is recorded first, so Home names
            // Again rather than only "Audio failed" (invariant 4); the old
            // synthesizer's cancel callback may never come.
            let repeatableSpeechActive = self.utterances.isRepeatableSpeechActive
            self.synthesizer = AVSpeechSynthesizer()
            self.synthesizer.delegate = self.synthesizerEvents
            self.utterances.reset()
            self.activeUtterance = nil
            self.speechInterruptionStatus.recordInterruption(
                repeatableSpeechActive: repeatableSpeechActive
            )
            // Apple requires restoring configuration after a media-services
            // reset but deferring activation/playback until user action. The
            // monitor therefore stays unhealthy until the next speech (or, once
            // ported, Get Attention) attempt proves the session can activate.
            self.configurePlaybackAudioSession()
            self.refreshVoices()
        }
        requestPersonalVoiceAuthorization()
    }

    /// Runs before any synthesis. The reference app found that asking after
    /// the first utterance could miss personal voices for the rest of the
    /// session; Apple's documentation does not say so (docs/DECISIONS.md,
    /// "Personal Voice permission is asked at launch, for now").
    private func requestPersonalVoiceAuthorization() {
        // @Sendable: the completion arrives on an arbitrary queue, so it must
        // not inherit this method's MainActor isolation.
        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { @Sendable [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.personalVoiceStatus = status
                self.refreshVoices()
            }
        }
    }

    /// Speaks `text`, interrupting anything currently being spoken (no queue).
    /// The one exception: the identical sentence is still playing, which under
    /// dwell means a resting gaze re-fired the tile — let it finish rather than
    /// stutter back to the start. See `SpokenUtteranceTracker`.
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !absorbsRepeat(of: .phrase(trimmed)) else {
            logger.info("Absorbed repeat activation of the phrase still being spoken")
            return
        }
        if let spoken = synthesize(trimmed) {
            lastSpokenText = spoken
        }
    }

    /// The sentence every Settings voice sample speaks.
    static let previewSample = "This is how I will sound."

    /// Plays the voice sample for a Settings control without recording
    /// last-spoken, so Again never replays it. As with phrase tiles, a held
    /// look re-firing the same control while its sample still plays is
    /// absorbed rather than restarting it.
    func preview(from control: VoicePreviewControl) {
        guard !absorbsRepeat(of: .preview(control)) else {
            logger.info("Absorbed repeat activation of the voice sample still playing")
            return
        }
        _ = synthesize(Self.previewSample, source: .preview(control))
    }

    /// Slower and Faster: steps the rate, then plays the sample at it. A held
    /// look re-firing the same button while its sample still plays changes
    /// nothing; otherwise one long look would walk the rate to the end of its
    /// range. The cost is that a quick second tap waits for the sample to end.
    func stepRate(_ step: (Float) -> Float, from control: VoicePreviewControl) {
        guard !absorbsRepeat(of: .preview(control)) else {
            logger.info("Absorbed repeat activation of a rate button whose sample is still playing")
            return
        }
        speechRate = step(speechRate)
        _ = synthesize(Self.previewSample, source: .preview(control))
    }

    func repeatLast() {
        guard let lastSpokenText else { return }
        speak(lastSpokenText)
    }

    func stop() {
        // Forget the request before stopping the system engine. Its cancel
        // callback is not an unexpected interruption of a current phrase.
        utterances.reset()
        synthesizer.stopSpeaking(at: .immediate)
        activeUtterance = nil
    }

    private func utteranceEnded(_ id: ObjectIdentifier, wasCancelled: Bool = false) {
        if wasCancelled {
            // A system cancellation may arrive before its interruption
            // notification. Preserve recovery then, even though clearing the
            // current utterance makes the later notification look idle.
            speechInterruptionStatus.recordInterruption(
                repeatableSpeechActive: utterances.cancelled(id)
            )
        } else {
            utterances.ended(id)
        }
        if !utterances.isSpeaking {
            activeUtterance = nil
        }
    }

    private func absorbsRepeat(of source: UtteranceSource) -> Bool {
        utterances.absorbsRepeat(
            of: source,
            // isSpeaking stays true while paused; a paused utterance is not
            // audible, so a repeat must not be absorbed into it.
            synthesizerIsSpeaking: synthesizer.isSpeaking && !synthesizer.isPaused,
            now: .now
        )
    }

    /// `source` defaults to the phrase itself; samples pass their control.
    private func synthesize(_ text: String, source: UtteranceSource? = nil) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Any deliberate new utterance supersedes the interrupted one. If its
        // audio session cannot activate, the existing Audio failed warning
        // takes over instead of leaving stale repeat guidance on screen.
        speechInterruptionStatus.recordSpeechAttempt()

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        ensurePlaybackAudioSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = speechRate
        utterance.voice = resolveVoice()
        activeUtterance = utterance
        let id = ObjectIdentifier(utterance)
        utterances.began(id, source: source ?? .phrase(trimmed), at: .now)
        synthesizer.speak(utterance)
        watchForMissedFinish(of: id)
        return trimmed
    }

    /// Backstop for the speaking indicator: if the synthesizer stops without
    /// a finish/cancel callback, Home would otherwise show "speaking" forever.
    /// Checks the live state once a second while this utterance is current.
    private func watchForMissedFinish(of id: ObjectIdentifier) {
        Task { @MainActor [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.utterances.activeID == id else { return }
                if !self.synthesizer.isSpeaking {
                    self.utteranceEnded(id)
                    return
                }
            }
        }
    }

    /// Walks the selection precedence until a descriptor actually instantiates:
    /// the cached voice list can be stale (voice uninstalled or Personal Voice
    /// re-recorded while the app was suspended), and a single failed lookup
    /// must fall to the next-best voice, not to the system default.
    private func resolveVoice() -> AVSpeechSynthesisVoice? {
        var candidates = availableVoices
        var cacheWasStale = false
        var resolved: AVSpeechSynthesisVoice?
        while resolved == nil,
              let descriptor = VoiceSelection.select(
                chosenID: selectedVoiceID,
                from: candidates,
                languageCode: Self.speechLanguageCode
              ) {
            resolved = AVSpeechSynthesisVoice(identifier: descriptor.id)
            if resolved == nil {
                cacheWasStale = true
                candidates.removeAll { $0.id == descriptor.id }
            }
        }
        if cacheWasStale {
            refreshVoices()
        }
        return resolved
    }

    /// The language the app's words are written in: its current
    /// localization, not the device region (see `VoiceSelection.select`).
    private static var speechLanguageCode: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    private func refreshVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().map(VoiceDescriptor.init)
    }

    private func configurePlaybackAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        } catch {
            audioSafetyMonitor.recordAudioSessionActivation(succeeded: false)
            logger.error("Could not set playback audio category: \(error.localizedDescription)")
        }
    }

    /// `.playback` keeps audio audible with the ring/silent switch on silent —
    /// a lifeline requirement for an AAC app. Internal so the Get Attention
    /// tone player can call it before playing. Failure never blocks speaking.
    func ensurePlaybackAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            audioSafetyMonitor.recordAudioSessionActivation(succeeded: true)
        } catch {
            // During a phone/FaceTime call a non-mixable session is refused
            // (insufficient priority). A mixable one activates, so speech at
            // least plays on the local route instead of failing silently.
            do {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
                try session.setActive(true)
                audioSafetyMonitor.recordAudioSessionActivation(succeeded: true)
            } catch {
                audioSafetyMonitor.recordAudioSessionActivation(succeeded: false)
                logger.error("Could not activate playback audio session: \(error.localizedDescription)")
            }
        }
    }
}

/// Forwards the synthesizer's callbacks, which carry no actor guarantee,
/// onto the MainActor as plain utterance identities and event instants.
@MainActor
private final class SpeechSynthesizerEvents: NSObject, AVSpeechSynthesizerDelegate {
    private let onUtteranceEnded: @MainActor (ObjectIdentifier, Bool) -> Void
    private let onUtteranceProgress: @MainActor (ObjectIdentifier, ContinuousClock.Instant) -> Void

    init(
        onUtteranceEnded: @escaping @MainActor (ObjectIdentifier, Bool) -> Void,
        onUtteranceProgress: @escaping @MainActor (ObjectIdentifier, ContinuousClock.Instant) -> Void
    ) {
        self.onUtteranceEnded = onUtteranceEnded
        self.onUtteranceProgress = onUtteranceProgress
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        // AVFoundation reports each spoken unit (generally a word). Capture
        // its time before hopping actors so a delayed callback cannot make a
        // stalled synthesizer appear to have made fresh progress. Monotonic
        // time, never `Date` (docs/LESSONS.md, "Timers use ContinuousClock").
        let id = ObjectIdentifier(utterance)
        let instant = ContinuousClock.now
        Task { @MainActor [weak self] in
            self?.onUtteranceProgress(id, instant)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        forward(ObjectIdentifier(utterance), wasCancelled: false)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        forward(ObjectIdentifier(utterance), wasCancelled: true)
    }

    private nonisolated func forward(_ id: ObjectIdentifier, wasCancelled: Bool) {
        Task { @MainActor [weak self] in
            self?.onUtteranceEnded(id, wasCancelled)
        }
    }
}

extension VoiceDescriptor {
    init(_ voice: AVSpeechSynthesisVoice) {
        self.init(
            id: voice.identifier,
            name: voice.name,
            languageCode: voice.language,
            quality: VoiceQuality(voice.quality),
            isPersonalVoice: voice.voiceTraits.contains(.isPersonalVoice),
            isNovelty: voice.voiceTraits.contains(.isNoveltyVoice)
        )
    }
}

extension VoiceQuality {
    init(_ quality: AVSpeechSynthesisVoiceQuality) {
        switch quality {
        case .premium: self = .premium
        case .enhanced: self = .enhanced
        default: self = .standard
        }
    }
}

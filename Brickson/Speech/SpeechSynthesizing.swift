import AVFoundation

/// Names one request to the synthesizer. The speech service hands out a new
/// token for every utterance, in increasing order, so a late report for an
/// earlier utterance can never be mistaken for the current one. The reference
/// app keyed utterances by `ObjectIdentifier`, which the system may reuse
/// once an utterance is freed.
nonisolated struct UtteranceToken: Hashable, Sendable {
    let rawValue: UInt64
}

/// One utterance, as the speech service asks for it.
nonisolated struct SpeechRequest: Equatable, Sendable {
    let token: UtteranceToken
    let text: String
    let rate: Float
    /// Nil lets the system choose its default voice: speaking is never
    /// blocked because a voice is missing.
    let voiceIdentifier: String?
}

/// What the synthesizer reported about an utterance.
nonisolated enum SpeechSynthesisEvent: Equatable, Sendable {
    /// It is about to speak the text up to `offset`: the end of the unit
    /// (generally a word) it reported, in UTF-16 units of the utterance's
    /// text, which is what `NSRange` counts. `instant` is when the report
    /// arrived, taken before it crossed to the main actor.
    case willSpeak(through: Int, at: ContinuousClock.Instant)
    case finished(at: ContinuousClock.Instant)
    case cancelled
}

/// The speech service's view of `AVSpeechSynthesizer`, as a seam so tests can
/// report progress, finishes and cancels in any order without real speech.
@MainActor
protocol SpeechSynthesizing: AnyObject {
    /// True while an utterance is queued or speaking, including while paused.
    var isSpeaking: Bool { get }
    var isPaused: Bool { get }
    /// Every report for a request, delivered on the main actor.
    var onEvent: (@MainActor (UtteranceToken, SpeechSynthesisEvent) -> Void)? { get set }
    func speak(_ request: SpeechRequest)
    func stopSpeakingImmediately()
}

/// The real synthesizer. It keeps only the utterance most recently handed to
/// it, and reports an event only when the utterance in the report is that
/// very object (compared with `===`), so a report for an earlier utterance is
/// dropped rather than misread.
@MainActor
final class SystemSpeechSynthesizer: SpeechSynthesizing {
    var onEvent: (@MainActor (UtteranceToken, SpeechSynthesisEvent) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private let events = SpeechSynthesizerEvents()
    private var current: (utterance: AVSpeechUtterance, token: UtteranceToken)?

    init() {
        // Speak through the app's own audio session, which
        // `AudioSessionCoordinator` sets to `.playback` so speech is heard
        // with the silent switch on. This is the default; it is set here so
        // a change to it is a visible decision.
        synthesizer.usesApplicationAudioSession = true
        synthesizer.delegate = events
        events.onEvent = { [weak self] utterance, event in
            self?.receive(event, for: utterance)
        }
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }
    var isPaused: Bool { synthesizer.isPaused }

    func speak(_ request: SpeechRequest) {
        let utterance = AVSpeechUtterance(string: request.text)
        utterance.rate = request.rate
        utterance.voice = request.voiceIdentifier.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
        current = (utterance, request.token)
        synthesizer.speak(utterance)
    }

    func stopSpeakingImmediately() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func receive(_ event: SpeechSynthesisEvent, for utterance: AVSpeechUtterance) {
        guard let current, current.utterance === utterance else { return }
        onEvent?(current.token, event)
    }
}

/// Forwards the synthesizer's callbacks, which carry no thread guarantee,
/// onto the main actor together with the utterance itself. Internal, not
/// private, so `OffMainThreadCallbackTests` can call each method from a
/// background thread.
@MainActor
final class SpeechSynthesizerEvents: NSObject, AVSpeechSynthesizerDelegate {
    var onEvent: (@MainActor (AVSpeechUtterance, SpeechSynthesisEvent) -> Void)?

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        // Take the time before hopping actors, so a delayed callback cannot
        // make a stalled synthesizer look as if it just made progress.
        // Monotonic time, never `Date` (docs/LESSONS.md, "Timers use
        // ContinuousClock").
        let instant = ContinuousClock.now
        let end = characterRange.location + characterRange.length
        forward(utterance, .willSpeak(through: end, at: instant))
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        forward(utterance, .finished(at: ContinuousClock.now))
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        forward(utterance, .cancelled)
    }

    private nonisolated func forward(_ utterance: AVSpeechUtterance, _ event: SpeechSynthesisEvent) {
        let reference = UtteranceReference(utterance: utterance)
        // The main queue runs blocks in the order they were submitted;
        // separate Tasks make no such promise. A finish must never overtake
        // the progress report sent before it, or a phrase cut off just
        // after its last report would read as complete
        // (docs/DECISIONS.md, "A phrase the system cuts off").
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.onEvent?(reference.utterance, event)
            }
        }
    }
}

/// Carries an utterance across to the main actor, where it is only compared
/// by identity and never read or changed, so sharing it is safe.
private nonisolated struct UtteranceReference: @unchecked Sendable {
    let utterance: AVSpeechUtterance
}

/// The installed voices, as a seam so tests can make a chosen voice
/// disappear between the list being read and the phrase being spoken.
@MainActor
protocol SpeechVoiceCatalog {
    func installedVoices() -> [VoiceDescriptor]
    func voiceIsAvailable(identifier: String) -> Bool
}

struct SystemVoiceCatalog: SpeechVoiceCatalog {
    func installedVoices() -> [VoiceDescriptor] {
        AVSpeechSynthesisVoice.speechVoices().map(VoiceDescriptor.init)
    }

    func voiceIsAvailable(identifier: String) -> Bool {
        AVSpeechSynthesisVoice(identifier: identifier) != nil
    }
}

/// Asks for permission to use the person's Personal Voice. The completion
/// may arrive on any thread.
typealias PersonalVoiceAuthorizationRequest =
    @MainActor (@escaping @Sendable (AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> Void) -> Void

enum SystemPersonalVoice {
    static func requestAuthorization(
        _ completion: @escaping @Sendable (AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> Void
    ) {
        // @Sendable: the system calls this from an arbitrary queue, so it must
        // not inherit main-actor isolation (docs/LESSONS.md, "Closures a
        // framework may call off the main thread").
        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { @Sendable status in
            completion(status)
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

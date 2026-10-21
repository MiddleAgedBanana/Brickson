import AVFoundation
import Foundation
import Testing

@testable import Brickson

// Stand-ins for the audio session, the synthesizer, the voices, the tone
// player and the clock, so speech and Get Attention are tested without
// sound. Each records what it was asked to do and can be told to fail.

/// One `setCategory` call.
struct CategoryCall: Equatable {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
}

struct FakeAudioSessionError: Error {}

@MainActor
final class FakeAudioSession: AudioSessionControlling {
    /// Refuses a session that does not mix with other audio, as the system
    /// does during a phone or FaceTime call.
    var refusesUnmixedActivation = false
    /// Refuses every activation.
    var refusesActivation = false
    var refusesCategory = false
    private(set) var categoryCalls: [CategoryCall] = []
    private(set) var activeCalls: [Bool] = []
    private(set) var isActive = false

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        categoryCalls.append(CategoryCall(category: category, mode: mode, options: options))
        if refusesCategory { throw FakeAudioSessionError() }
    }

    func setActive(_ active: Bool, notifyingOthersOnDeactivation: Bool) throws {
        activeCalls.append(active)
        if active {
            if refusesActivation { throw FakeAudioSessionError() }
            let mixes = categoryCalls.last?.options.contains(.mixWithOthers) ?? false
            if refusesUnmixedActivation && !mixes { throw FakeAudioSessionError() }
        }
        isActive = active
    }
}

@MainActor
final class FakeSpeechSynthesizer: SpeechSynthesizing {
    var isSpeaking = false
    var isPaused = false
    var onEvent: (@MainActor (UtteranceToken, SpeechSynthesisEvent) -> Void)?
    private(set) var requests: [SpeechRequest] = []
    private(set) var stopCount = 0

    var latestToken: UtteranceToken? { requests.last?.token }

    func speak(_ request: SpeechRequest) {
        requests.append(request)
        isSpeaking = true
        isPaused = false
    }

    func stopSpeakingImmediately() {
        stopCount += 1
        isSpeaking = false
        isPaused = false
    }

    /// Reports that the latest request (or `token`) is about to speak the
    /// text up to `offset`.
    func reportProgress(through offset: Int, for token: UtteranceToken? = nil) {
        send(.willSpeak(through: offset, at: .now), for: token)
    }

    func finish(_ token: UtteranceToken? = nil) {
        if token == nil || token == latestToken { isSpeaking = false }
        send(.finished(at: .now), for: token)
    }

    func cancel(_ token: UtteranceToken? = nil) {
        if token == nil || token == latestToken { isSpeaking = false }
        send(.cancelled, for: token)
    }

    /// Goes quiet without reporting anything, as a stuck synthesizer can.
    func goQuietWithoutReporting() {
        isSpeaking = false
    }

    private func send(_ event: SpeechSynthesisEvent, for token: UtteranceToken?) {
        guard let token = token ?? latestToken else {
            Issue.record("No request to report on")
            return
        }
        onEvent?(token, event)
    }
}

@MainActor
final class FakeSynthesizerFactory {
    private(set) var made: [FakeSpeechSynthesizer] = []

    var latest: FakeSpeechSynthesizer {
        guard let last = made.last else {
            fatalError("The speech service makes its synthesizer when it starts")
        }
        return last
    }

    func make() -> any SpeechSynthesizing {
        let synthesizer = FakeSpeechSynthesizer()
        made.append(synthesizer)
        return synthesizer
    }
}

@MainActor
final class FakeVoiceCatalog: SpeechVoiceCatalog {
    var voices: [VoiceDescriptor]
    /// Voices that are listed but no longer load.
    var missingIDs: Set<String> = []
    private(set) var readCount = 0

    init(voices: [VoiceDescriptor] = []) {
        self.voices = voices
    }

    func installedVoices() -> [VoiceDescriptor] {
        readCount += 1
        return voices
    }

    func voiceIsAvailable(identifier: String) -> Bool {
        !missingIDs.contains(identifier)
    }
}

/// Keeps the Personal Voice completion so a test can call it, from any
/// thread, whenever it likes.
@MainActor
final class FakePersonalVoiceRequest {
    private(set) var completion: (@Sendable (AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> Void)?
    private(set) var requestCount = 0

    func request(
        _ completion: @escaping @Sendable (AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> Void
    ) {
        requestCount += 1
        self.completion = completion
    }
}

/// A clock the test moves by hand: each sleep waits until `wake()`.
@MainActor
final class ManualSleeper {
    private var sleepers: [(duration: Duration, continuation: CheckedContinuation<Void, Never>)] = []

    /// How many sleeps have ended and handed control back to their task.
    private(set) var resumedCount = 0

    var pendingDurations: [Duration] { sleepers.map(\.duration) }
    var isAnyoneSleeping: Bool { !sleepers.isEmpty }

    var closure: @MainActor @Sendable (Duration) async -> Void {
        { [self] duration in await self.sleep(for: duration) }
    }

    func sleep(for duration: Duration) async {
        await withCheckedContinuation { continuation in
            sleepers.append((duration, continuation))
        }
        // Every sleeper is main-actor code, so the task that just woke runs
        // on from here to its next sleep or its end without letting the test
        // in between: once the test sees this count, that step is done.
        resumedCount += 1
    }

    /// Ends every current sleep and waits until each woken task has run to
    /// its next sleep or its end. Returns whether they all did.
    func wakeAll() async -> Bool {
        let target = resumedCount + sleepers.count
        let woken = sleepers
        sleepers.removeAll()
        for sleeper in woken {
            sleeper.continuation.resume()
        }
        return await waitUntil { self.resumedCount >= target }
    }
}

/// Lets main-actor tasks run until `condition` holds. Returns whether it
/// did; a test expects that, so a change that never happens fails rather
/// than passing by not waiting.
@MainActor
func waitUntil(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<1_000 {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

/// A settings store of its own for each test.
func freshDefaults() -> UserDefaults {
    let name = "BricksonTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: name) else {
        fatalError("UserDefaults refused a test suite name")
    }
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// The audio session's notifications, posted the way the system posts them.
@MainActor
struct SessionNotifications {
    let center: NotificationCenter
    let session: NSObject

    func interruptionBegan() {
        center.post(
            name: AVAudioSession.interruptionNotification,
            object: session,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
    }

    func interruptionEnded() {
        center.post(
            name: AVAudioSession.interruptionNotification,
            object: session,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )
    }

    func routeChanged(_ reason: AVAudioSession.RouteChangeReason) {
        center.post(
            name: AVAudioSession.routeChangeNotification,
            object: session,
            userInfo: [AVAudioSessionRouteChangeReasonKey: reason.rawValue]
        )
    }

    func mediaServicesLost() {
        center.post(name: AVAudioSession.mediaServicesWereLostNotification, object: session)
    }

    func mediaServicesReset() {
        center.post(name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }
}

/// Speech and the alarm wired together as the app wires them, around fakes.
@MainActor
struct AudioHarness {
    let notifications: SessionNotifications
    let audioSession: FakeAudioSession
    let events: AudioSessionEvents
    let safety: AudioSafetyMonitor
    let coordinator: AudioSessionCoordinator
    let catalog: FakeVoiceCatalog
    let synthesizers: FakeSynthesizerFactory
    let personalVoice: FakePersonalVoiceRequest
    let speechSleeper: ManualSleeper
    let alarmSleeper: ManualSleeper
    let defaults: UserDefaults
    let speech: SpeechService
    let attention: AttentionAlertPlayer
    let tones: FakeToneFactory

    var synthesizer: FakeSpeechSynthesizer { synthesizers.latest }

    init(
        voices: [VoiceDescriptor] = [],
        defaults: UserDefaults = freshDefaults(),
        policy: AudioSessionLeasePolicy = .keepActive
    ) {
        let center = NotificationCenter()
        let sessionIdentity = NSObject()
        let audioSession = FakeAudioSession()
        let events = AudioSessionEvents(notificationCenter: center, object: sessionIdentity)
        let safety = AudioSafetyMonitor(initialOutputVolume: 0.6, readOutputVolume: { 0.6 }, events: events)
        let coordinator = AudioSessionCoordinator(
            session: audioSession,
            audioSafety: safety,
            events: events,
            policy: policy
        )
        let catalog = FakeVoiceCatalog(voices: voices)
        let synthesizers = FakeSynthesizerFactory()
        let personalVoice = FakePersonalVoiceRequest()
        let speechSleeper = ManualSleeper()
        let alarmSleeper = ManualSleeper()
        let tones = FakeToneFactory()

        notifications = SessionNotifications(center: center, session: sessionIdentity)
        self.audioSession = audioSession
        self.events = events
        self.safety = safety
        self.coordinator = coordinator
        self.catalog = catalog
        self.synthesizers = synthesizers
        self.personalVoice = personalVoice
        self.speechSleeper = speechSleeper
        self.alarmSleeper = alarmSleeper
        self.defaults = defaults
        self.tones = tones
        speech = SpeechService(
            audioSession: coordinator,
            events: events,
            makeSynthesizer: { synthesizers.make() },
            voiceCatalog: catalog,
            defaults: defaults,
            notificationCenter: center,
            requestPersonalVoiceAuthorization: { personalVoice.request($0) },
            sleep: speechSleeper.closure
        )
        attention = AttentionAlertPlayer(
            audioSession: coordinator,
            events: events,
            makePlayback: { try tones.make() },
            sleep: alarmSleeper.closure
        )
    }

    /// The policy Home would show now, with the alarm's real state.
    var issue: HomeAudioIssue? {
        AudioSafetyPolicy(
            attentionState: attention.state,
            speechInterruptionState: speech.speechInterruptionState,
            audioSessionHealthy: safety.audioSessionHealthy,
            outputVolume: safety.outputVolume
        ).issue
    }
}

@MainActor
final class FakeTonePlayback: AttentionTonePlayback {
    var eventHandler: (@MainActor (AttentionTonePlaybackEvent) -> Void)?
    var playSucceeds: Bool
    private(set) var isPlaying = false
    private(set) var volume: Float = 1
    private(set) var volumeChanges: [Float] = []
    private(set) var playCount = 0
    private(set) var stopCount = 0
    var onPlay: (() -> Void)?

    init(playSucceeds: Bool = true) {
        self.playSucceeds = playSucceeds
    }

    func setVolume(_ volume: Float, fadeDuration: TimeInterval) {
        self.volume = volume
        volumeChanges.append(volume)
    }

    func playFromBeginning() -> Bool {
        playCount += 1
        onPlay?()
        isPlaying = playSucceeds
        return playSucceeds
    }

    func stop() {
        stopCount += 1
        isPlaying = false
    }

    /// The player falls silent without telling anyone.
    func goQuietWithoutReporting() {
        isPlaying = false
    }

    func send(_ event: AttentionTonePlaybackEvent) {
        isPlaying = false
        eventHandler?(event)
    }
}

struct FakeToneError: Error {}

/// Builds tone players in the order a test lines them up, then working ones.
@MainActor
final class FakeToneFactory {
    /// Players handed out first, in order. Nil makes construction throw.
    var queue: [FakeTonePlayback?] = []
    private(set) var made: [FakeTonePlayback] = []
    private(set) var attempts = 0

    var latest: FakeTonePlayback? { made.last }

    func make() throws -> any AttentionTonePlayback {
        attempts += 1
        let next: FakeTonePlayback?
        if queue.isEmpty {
            next = FakeTonePlayback()
        } else {
            next = queue.removeFirst()
        }
        guard let next else { throw FakeToneError() }
        made.append(next)
        return next
    }
}

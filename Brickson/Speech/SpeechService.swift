import AVFoundation
import Observation
import os

/// The app's single text-to-speech engine. One instance is created at launch
/// (`AppAudio`) and shared through the environment; it owns the only
/// synthesizer.
@MainActor
@Observable
final class SpeechService {
    private(set) var lastSpokenText: String?
    /// Counts every phrase that starts speaking, including Again and the
    /// same phrase chosen again; an absorbed repeat does not count. Home
    /// keys the message's scroll position to it, so each start shows the
    /// message from its first word.
    private(set) var phraseStartCount = 0
    /// What the system says about using the person's Personal Voice. Read
    /// at launch, after every answer, and each time the app comes back to
    /// the front (`refreshPersonalVoiceAvailability()`).
    private(set) var personalVoiceStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus
    /// The voices phrases may be spoken in: every voice the system lists,
    /// except a Personal Voice without permission. The system lists those
    /// only while Brickson is allowed anyway; a list read before access was
    /// turned off is filtered too (docs/DECISIONS.md, "A Personal Voice is
    /// used only while it is allowed"). Read again after every change to
    /// `personalVoiceStatus`.
    private(set) var availableVoices: [VoiceDescriptor] = []
    /// The Personal Voice Automatic speaks in, kept while it exists so a
    /// second one never takes over (docs/DECISIONS.md, "Automatic keeps the
    /// person's Personal Voice"). Kept, not cleared, while access is off.
    private(set) var automaticPersonalVoiceID: String?
    /// The person's Personal Voices that phrases may be spoken in now, in
    /// the system's order. Empty without permission.
    var personalVoices: [VoiceDescriptor] { availableVoices.filter(\.isPersonalVoice) }
    /// True when a Personal Voice is both allowed and installed.
    var hasPersonalVoice: Bool { !personalVoices.isEmpty }
    /// The voice Automatic speaks in now; nil when no voice is listed, and
    /// the system's default voice speaks.
    var automaticVoice: VoiceDescriptor? { selectVoice(chosenID: nil, from: availableVoices) }
    /// The voice the next phrase is spoken in, as far as the voice list
    /// knows. Each phrase still checks that its voice loads, and falls to
    /// the next one if not (`resolveVoiceIdentifier`).
    var currentVoice: VoiceDescriptor? { selectVoice(chosenID: selectedVoiceID, from: availableVoices) }
    /// When the app asks for Personal Voice permission. The Voice screen
    /// offers its own Ask button only under `.fromSettings`.
    let personalVoiceAskPolicy: PersonalVoiceAskPolicy
    /// True while the Voice screen's question waits for the person's
    /// answer. Settings holds its idle reset meanwhile, and a second press
    /// of the button asks nothing more
    /// (`requestPersonalVoiceAuthorization()`).
    private(set) var isAskingForPersonalVoice = false
    var speechInterruptionState: SpeechInterruptionState { speechInterruptionStatus.state }
    var speechInterruptionSequence: Int { speechInterruptionStatus.sequence }

    /// Identifier of the user-chosen voice; nil means automatic selection.
    var selectedVoiceID: String? {
        didSet { settings.set(selectedVoiceID, forKey: Self.voiceIDKey) }
    }

    var speechRate: Float {
        didSet { settings.set(speechRate, forKey: Self.rateKey) }
    }

    /// True from the moment an utterance is handed to the synthesizer until it
    /// finishes or is cancelled. Drives the speaking indicator on Home.
    var isSpeaking: Bool { utterances.isSpeaking }

    private var speechInterruptionStatus = SpeechInterruptionStatus()
    private var utterances = SpokenUtteranceTracker<UtteranceToken>()
    @ObservationIgnored private var synthesizer: any SpeechSynthesizing
    @ObservationIgnored private var lastToken: UInt64 = 0
    /// How the audio session activated for the latest utterance. When it
    /// could not activate at all, Home already shows "Audio failed", and an
    /// unexpected end must not replace that with "Stopped — Again": Again
    /// would only fail the same way (code audit L3).
    @ObservationIgnored private var latestActivation: AudioSessionActivation?
    @ObservationIgnored private let makeSynthesizer: @MainActor () -> any SpeechSynthesizing
    @ObservationIgnored private let audioSession: AudioSessionCoordinator
    @ObservationIgnored private let voiceCatalog: any SpeechVoiceCatalog
    @ObservationIgnored private let personalVoice: any PersonalVoiceAuthorizing
    @ObservationIgnored private let settings: UserDefaults
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private let sleep: @MainActor @Sendable (Duration) async -> Void
    @ObservationIgnored private var voicesObserver: (any NSObjectProtocol)?
    private let logger = Logger(subsystem: AppLog.subsystem, category: "speech")
    static let voiceIDKey = "selectedVoiceID"
    static let rateKey = "speechRate"
    static let automaticPersonalVoiceIDKey = "automaticPersonalVoiceID"

    /// Every dependency is explicit, so tests drive speech with fakes and the
    /// app passes its real objects in one place (`AppAudio.makeForApp`).
    /// `settings` is where the voice and rate are kept: the launch-selected
    /// store, which is the person's preferences, or an isolated suite for
    /// UI tests (`LaunchOptions`). `notificationCenter` carries the system's
    /// "voices changed" notice; `personalVoice` is the Personal Voice
    /// permission, asked for at launch when `personalVoiceAskPolicy` says
    /// so; `sleep` paces the missed-finish watchdog.
    init(
        audioSession: AudioSessionCoordinator,
        events: AudioSessionEvents,
        makeSynthesizer: @escaping @MainActor () -> any SpeechSynthesizing,
        voiceCatalog: any SpeechVoiceCatalog,
        settings: UserDefaults,
        notificationCenter: NotificationCenter,
        personalVoice: any PersonalVoiceAuthorizing,
        personalVoiceAskPolicy: PersonalVoiceAskPolicy,
        sleep: @escaping @MainActor @Sendable (Duration) async -> Void
    ) {
        self.audioSession = audioSession
        self.makeSynthesizer = makeSynthesizer
        self.voiceCatalog = voiceCatalog
        self.personalVoice = personalVoice
        self.personalVoiceAskPolicy = personalVoiceAskPolicy
        self.settings = settings
        self.notificationCenter = notificationCenter
        self.sleep = sleep
        synthesizer = makeSynthesizer()

        selectedVoiceID = settings.string(forKey: Self.voiceIDKey)
        automaticPersonalVoiceID = settings.string(forKey: Self.automaticPersonalVoiceIDKey)
        // What the system already knows, before the list is read: someone
        // who allowed Brickson before speaks in their own voice from the
        // first phrase, without waiting for an answer.
        personalVoiceStatus = personalVoice.status
        // Presence check rather than float(forKey:): an absent key reads as 0,
        // which is also AVSpeechUtteranceMinimumSpeechRate — a value a user
        // could legitimately save.
        if let storedRate = settings.object(forKey: Self.rateKey) as? Float {
            speechRate = min(max(storedRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        } else {
            speechRate = AVSpeechUtteranceDefaultSpeechRate
        }

        listen(to: synthesizer)
        refreshVoices()
        voicesObserver = notificationCenter.addObserver(
            forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshVoices() }
        }
        events.subscribe { [weak self] event in
            self?.handle(event)
        }
        if personalVoiceAskPolicy.asksAtLaunch(alreadyAllowed: personalVoiceStatus == .authorized) {
            askForPersonalVoiceAtLaunch()
        }
    }

    /// Removes the voices observer, which the reference app leaked (code
    /// audit L4). The app keeps one service for its whole life, so the leak
    /// was harmless there; tests make many.
    isolated deinit {
        if let voicesObserver {
            notificationCenter.removeObserver(voicesObserver)
        }
    }

    // MARK: - Personal Voice

    /// Runs before any synthesis. The reference app found that asking after
    /// the first utterance could miss personal voices for the rest of the
    /// session; Apple's documentation does not say so (docs/DECISIONS.md,
    /// "Personal Voice permission is asked at launch, for now").
    private func askForPersonalVoiceAtLaunch() {
        // @Sendable: the completion arrives on an arbitrary queue, so it must
        // not inherit this method's main-actor isolation.
        personalVoice.requestAuthorization { @Sendable [weak self] status in
            Task { @MainActor in
                self?.receivePersonalVoiceAnswer(status)
            }
        }
    }

    /// The Voice screen's explained button: asks for permission (the system
    /// shows its question only the first time), waits for the answer, then
    /// reads the voices again so the next phrase can use the person's
    /// voice. Speaks nothing by itself. Returns the answer, for the screen to
    /// say what happens next.
    ///
    /// A second call while the first still waits, such as a double tap or a
    /// held look before the question covers the screen, asks nothing more
    /// and returns the status as it stands: one question, one answer.
    @discardableResult
    func requestPersonalVoiceAuthorization() async -> AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        guard !isAskingForPersonalVoice else {
            logger.info("Absorbed a second Personal Voice request while the first waits")
            return personalVoiceStatus
        }
        isAskingForPersonalVoice = true
        defer { isAskingForPersonalVoice = false }
        let status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = await withCheckedContinuation { continuation in
            // @Sendable, as at launch: the answer arrives on any queue.
            personalVoice.requestAuthorization { @Sendable answer in
                continuation.resume(returning: answer)
            }
        }
        receivePersonalVoiceAnswer(status)
        return status
    }

    /// Reads again whether a Personal Voice may be used, and which voices
    /// are installed. The app calls it each time it comes back to the
    /// front: access can be turned on or off, and a voice made or deleted,
    /// in the Settings app while Brickson waits, and a voice whose access
    /// was turned off must not be asked for (docs/DECISIONS.md, "A Personal
    /// Voice is used only while it is allowed"). Speaks nothing.
    func refreshPersonalVoiceAvailability() {
        personalVoiceStatus = personalVoice.status
        refreshVoices()
    }

    private func receivePersonalVoiceAnswer(_ status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) {
        personalVoiceStatus = status
        refreshVoices()
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
            phraseStartCount &+= 1
        }
    }

    /// The sentence every Settings voice sample speaks.
    static let previewSample = "This is how I will sound."

    /// Plays the voice sample for a Settings control without recording
    /// last-spoken, so Again never replays it. As with phrase tiles, a held
    /// look re-firing the same control while its sample still plays is
    /// absorbed rather than restarting it. A voice row's sample plays in
    /// that row's voice, whichever voice is chosen.
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
        synthesizer.stopSpeakingImmediately()
        releaseSessionIfIdle()
    }

    // MARK: - The synthesizer's reports

    private func listen(to synthesizer: any SpeechSynthesizing) {
        synthesizer.onEvent = { [weak self] token, event in
            self?.receive(event, for: token)
        }
    }

    private func receive(_ event: SpeechSynthesisEvent, for token: UtteranceToken) {
        switch event {
        case let .willSpeak(through: offset, at: instant):
            utterances.recordProgress(token, reaching: offset, at: instant)
        case let .finished(at: instant):
            if utterances.ended(token, at: instant) == .endedBeforeItsFinalWord {
                // Not shown on its own: some voices skip reporting the last
                // word. An interruption arriving with it confirms a cut-off
                // (docs/DECISIONS.md, "A phrase the system cuts off").
                logger.info("A phrase was reported finished before its final word")
            }
            releaseSessionIfIdle()
        case .cancelled:
            // Brickson's own cancels are never current (`stop()` and a new
            // phrase forget the old one first), so this is the system cutting
            // the phrase off. It can arrive before the interruption notice,
            // which then finds nothing speaking; record the cut-off now.
            recordCutOff(utterances.cancelled(token))
            releaseSessionIfIdle()
        }
    }

    // MARK: - The audio session's events

    private func handle(_ event: AudioSessionEvent) {
        switch event {
        case .interrupted:
            // A call, Siri or another app's alarm leaves the synthesizer
            // paused on an inactive session, and the end of the interruption
            // is not guaranteed. Stop for a clean state; the phrase stays in
            // lastSpokenText, so one Again activation re-speaks it in full.
            // Never resume by itself (invariant 4). On iOS 27 this arrives
            // twice, from the old and the new notice; the second finds
            // nothing to record.
            let cutOff = utterances.interruptionCutOffAPhrase(at: .now)
            stop()
            recordCutOff(cutOff)
        case .mediaServicesReset:
            // The media daemon restarted, and every audio object is invalid.
            // Without a new synthesizer, speech stays dead until relaunch:
            // for a person who cannot speak, that is the whole app dead. A
            // phrase cut off by the reset is recorded so Home names Again;
            // the old synthesizer's cancel may never come. Nothing speaks
            // until the person's next activation (invariant 4).
            let cutOff = utterances.interruptionCutOffAPhrase(at: .now)
            synthesizer.onEvent = nil
            synthesizer = makeSynthesizer()
            listen(to: synthesizer)
            utterances.reset()
            releaseSessionIfIdle()
            recordCutOff(cutOff)
            refreshVoices()
        case .previousOutputUnavailable:
            // Headphones unplugged or a Bluetooth speaker switched off. A
            // phrase still speaking carries on through the new output; one
            // the system ended early as the output vanished needs Again.
            recordCutOff(utterances.outputLossCutOffAPhrase(at: .now))
        case .routeChanged, .mediaServicesLost:
            break
        }
    }

    /// Shows "Stopped — Again" for a phrase that was cut off. Not when the
    /// session never activated for it: "Audio failed" is then the true
    /// message, and replacing it would send the person round a loop of
    /// Again activations that fail the same way (code audit L3).
    private func recordCutOff(_ phraseWasCutOff: Bool) {
        guard phraseWasCutOff else { return }
        guard latestActivation != .failed else {
            logger.info("A phrase stopped early while the audio session was unavailable")
            return
        }
        speechInterruptionStatus.recordInterruption(repeatableSpeechActive: true)
    }

    // MARK: - Speaking

    private func absorbsRepeat(of source: UtteranceSource) -> Bool {
        utterances.absorbsRepeat(
            of: source,
            synthesizerIsSpeaking: synthesizerIsAudible,
            now: .now
        )
    }

    /// isSpeaking stays true while paused; a paused utterance is not
    /// audible, so a repeat must not be absorbed into it, and the watchdog
    /// treats it as stopped.
    private var synthesizerIsAudible: Bool {
        synthesizer.isSpeaking && !synthesizer.isPaused
    }

    /// `source` defaults to the phrase itself; samples pass their control.
    private func synthesize(_ text: String, source: UtteranceSource? = nil) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Any deliberate new utterance supersedes the interrupted one. If its
        // audio session cannot activate, the Audio failed warning takes over
        // instead of leaving stale repeat guidance on screen.
        speechInterruptionStatus.recordSpeechAttempt()

        if synthesizer.isSpeaking {
            synthesizer.stopSpeakingImmediately()
        }
        // Never blocks speaking: whatever the outcome, the phrase is handed
        // to the synthesizer, and a failure shows "Audio failed".
        latestActivation = audioSession.acquire(for: .speech)

        lastToken &+= 1
        let token = UtteranceToken(rawValue: lastToken)
        utterances.began(token, source: source ?? .phrase(trimmed), at: .now)
        synthesizer.speak(
            SpeechRequest(
                token: token,
                text: trimmed,
                rate: speechRate,
                voiceIdentifier: resolveVoiceIdentifier(chosenID: voiceChoice(for: source))
            )
        )
        watchForMissedFinish(of: token)
        return trimmed
    }

    /// Lets go of the audio session once nothing is speaking, on every way a
    /// phrase can end, so the Get Attention tone comes back to full level.
    private func releaseSessionIfIdle() {
        if !utterances.isSpeaking {
            audioSession.release(for: .speech)
        }
    }

    /// The watchdog's pace: a check every second while an utterance is
    /// current, and a second look half a second after one finds it quiet.
    static let watchdogInterval: Duration = .seconds(1)
    static let watchdogGrace: Duration = .milliseconds(500)

    /// Backstop for a synthesizer that stops, or is left paused, without a
    /// finish or cancel report. Without it, Home would show "Speaking"
    /// forever, and a phrase that may never have been heard would fail
    /// silently. Holds the service only weakly between checks.
    private func watchForMissedFinish(of token: UtteranceToken) {
        let sleep = self.sleep
        Task { @MainActor [weak self] in
            var quietChecks = 0
            while true {
                await sleep(quietChecks == 0 ? SpeechService.watchdogInterval : SpeechService.watchdogGrace)
                guard let self, self.utterances.activeID == token else { return }
                guard !self.synthesizerIsAudible else {
                    quietChecks = 0
                    continue
                }
                // Quiet with no report. Look once more, so a report already
                // on its way can land and a phrase that simply finished is
                // not called cut off.
                quietChecks += 1
                guard quietChecks >= 2 else { continue }
                self.recoverFromMissedFinish(of: token)
                return
            }
        }
    }

    /// Treats the utterance as cut off, so Home names Again (invariants 4
    /// and 5). A voice sample is not repeatable and only clears the
    /// indicator. A synthesizer left paused is stopped, so the next phrase
    /// starts clean.
    private func recoverFromMissedFinish(of token: UtteranceToken) {
        logger.error("The synthesizer went quiet without reporting the end of an utterance")
        recordCutOff(utterances.cancelled(token))
        if synthesizer.isSpeaking {
            synthesizer.stopSpeakingImmediately()
        }
        releaseSessionIfIdle()
    }

    // MARK: - Voices

    /// The voice an utterance asks for: a voice row's own voice for its
    /// sample (nil, Automatic, ignores the chosen voice), the chosen voice
    /// for everything else.
    private func voiceChoice(for source: UtteranceSource?) -> String? {
        if case let .some(.preview(.voice(id))) = source {
            return id
        }
        return selectedVoiceID
    }

    /// Walks the selection precedence until a voice is actually available:
    /// the cached voice list can be stale (voice uninstalled or Personal Voice
    /// re-recorded while the app was suspended), and a single failed lookup
    /// must fall to the next-best voice, not to the system default.
    private func resolveVoiceIdentifier(chosenID: String?) -> String? {
        var candidates = availableVoices
        var cacheWasStale = false
        var resolved: String?
        while resolved == nil,
              let descriptor = selectVoice(chosenID: chosenID, from: candidates) {
            if voiceCatalog.voiceIsAvailable(identifier: descriptor.id) {
                resolved = descriptor.id
            } else {
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

    private func selectVoice(chosenID: String?, from candidates: [VoiceDescriptor]) -> VoiceDescriptor? {
        VoiceSelection.select(
            chosenID: chosenID,
            from: candidates,
            languageCode: Self.speechLanguageCode,
            automaticPersonalVoiceID: automaticPersonalVoiceID
        )
    }

    private func refreshVoices() {
        availableVoices = VoiceSelection.usableVoices(
            voiceCatalog.installedVoices(),
            personalVoiceAllowed: personalVoiceStatus == .authorized
        )
        keepAutomaticPersonalVoice()
    }

    /// Remembers the Personal Voice Automatic now speaks in, when it is a
    /// new one: the first one allowed, or the next one after the kept voice
    /// was deleted. Runs each time the list is read. While access is off no
    /// Personal Voice is a candidate, so the kept one is not replaced and
    /// comes back with access.
    private func keepAutomaticPersonalVoice() {
        guard let automatic = automaticVoice,
              automatic.isPersonalVoice,
              automatic.id != automaticPersonalVoiceID
        else { return }
        automaticPersonalVoiceID = automatic.id
        settings.set(automatic.id, forKey: Self.automaticPersonalVoiceIDKey)
    }
}

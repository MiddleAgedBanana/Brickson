import AVFoundation
import os

/// What the app needs from `AVAudioSession`, as a seam so tests can refuse
/// an activation or a category without real audio.
@MainActor
protocol AudioSessionControlling: AnyObject {
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
    func setActive(_ active: Bool, notifyingOthersOnDeactivation: Bool) throws
}

/// The real shared audio session.
@MainActor
final class SystemAudioSession: AudioSessionControlling {
    private let session = AVAudioSession.sharedInstance()

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        try session.setCategory(category, mode: mode, options: options)
    }

    func setActive(_ active: Bool, notifyingOthersOnDeactivation: Bool) throws {
        try session.setActive(
            active,
            options: notifyingOthersOnDeactivation ? .notifyOthersOnDeactivation : []
        )
    }
}

/// Who is holding the audio session open.
nonisolated enum AudioSessionHolder: Hashable, Sendable {
    /// A phrase or a voice sample is in progress.
    case speech
    /// Get Attention is sounding.
    case attentionAlert
}

/// How an activation went.
nonisolated enum AudioSessionActivation: Equatable, Sendable {
    /// The session is active and not mixed with other audio.
    case exclusive
    /// Activation alone was refused (during a phone or FaceTime call, for
    /// example), so the session was activated mixing with the other audio:
    /// the sound plays, but it may be quiet or on another output.
    case mixedWithOtherAudio
    /// The session could not be activated at all.
    case failed
}

/// When the session is released (docs/DECISIONS.md, "Background audio").
nonisolated enum AudioSessionLeasePolicy: Equatable, Sendable {
    /// Never deactivate: the next phrase never waits for activation, and the
    /// alarm can never be cut off by a release. Other apps' audio that speech
    /// interrupted stays paused. What 1.0 uses.
    case keepActive
    /// Deactivate, letting other apps resume, once nothing holds the
    /// session. Not used yet: it needs device checks (the first syllable
    /// over Bluetooth, the delay before a phrase).
    case releaseWhenIdle

    /// Whether to deactivate after a holder lets go. Never while anyone
    /// still holds the session: deactivating with audio running stops it.
    func deactivates(whenRemainingHolders remaining: Set<AudioSessionHolder>) -> Bool {
        switch self {
        case .keepActive: false
        case .releaseWhenIdle: remaining.isEmpty
        }
    }
}

/// The one owner of the shared audio session. Speech and the Get Attention
/// alarm each hold a lease on it while they play, so neither can configure
/// or release it underneath the other (docs/DECISIONS.md, "Background
/// audio").
///
/// The session uses `.playback`, so speech and the alarm play with the
/// silent switch on and with the screen locked (invariant 4). Its mode is
/// `.default`: `.spokenAudio` would let another app's spoken prompt (a
/// navigation direction, say) pause the person's sentence or the alarm.
@MainActor
final class AudioSessionCoordinator {
    static let category: AVAudioSession.Category = .playback
    static let mode: AVAudioSession.Mode = .default

    let policy: AudioSessionLeasePolicy
    private(set) var holders: Set<AudioSessionHolder> = []
    /// The outcome of the latest activation, for a warning that the sound is
    /// shared with a call (not shown yet).
    private(set) var lastActivation: AudioSessionActivation?

    private let session: any AudioSessionControlling
    private let audioSafety: AudioSafetyMonitor
    private let events: AudioSessionEvents
    private var holderObservers: [@MainActor () -> Void] = []
    private let logger = Logger(subsystem: AppLog.subsystem, category: "audio-session")

    init(
        session: any AudioSessionControlling,
        audioSafety: AudioSafetyMonitor,
        events: AudioSessionEvents,
        policy: AudioSessionLeasePolicy
    ) {
        self.session = session
        self.audioSafety = audioSafety
        self.events = events
        self.policy = policy
        events.subscribe { [weak self] event in
            // Every audio object is invalid after a reset. Apple asks apps to
            // restore the session's configuration at once but to wait for the
            // next user action before activating it, so only configure here.
            if event == .mediaServicesReset {
                self?.configure()
            }
        }
    }

    /// Sets the category and mode without activating, at launch and after a
    /// media-services reset, so the first sound already ignores the silent
    /// switch. A failure shows "Audio failed" until an activation succeeds.
    func configure() {
        do {
            try session.setCategory(Self.category, mode: Self.mode, options: [])
        } catch {
            audioSafety.recordAudioSessionActivation(succeeded: false)
            logger.error("Could not set the playback audio category: \(error.localizedDescription)")
        }
    }

    /// Takes a hold on the session and activates it. Never blocks the sound:
    /// the caller plays whatever the outcome, and a failure shows "Audio
    /// failed" on Home.
    @discardableResult
    func acquire(for holder: AudioSessionHolder) -> AudioSessionActivation {
        updateHolders { $0.insert(holder) }
        let activation = activate()
        lastActivation = activation
        audioSafety.recordAudioSessionActivation(succeeded: activation != .failed)
        return activation
    }

    /// Lets go of a hold. Safe to call when `holder` holds nothing.
    func release(for holder: AudioSessionHolder) {
        guard holders.contains(holder) else { return }
        updateHolders { $0.remove(holder) }
        guard policy.deactivates(whenRemainingHolders: holders) else { return }
        do {
            try session.setActive(false, notifyingOthersOnDeactivation: true)
        } catch {
            // The session simply stays active, as `keepActive` keeps it;
            // nothing the person relies on is lost.
            logger.error("Could not release the audio session: \(error.localizedDescription)")
        }
    }

    func isHeld(by holder: AudioSessionHolder) -> Bool {
        holders.contains(holder)
    }

    /// Called whenever a hold is taken or released. The alarm uses it to
    /// turn its tone down while speech holds the session.
    func onHoldersChanged(_ observer: @escaping @MainActor () -> Void) {
        holderObservers.append(observer)
    }

    private func updateHolders(_ change: (inout Set<AudioSessionHolder>) -> Void) {
        let before = holders
        change(&holders)
        guard holders != before else { return }
        for observer in holderObservers {
            observer()
        }
    }

    private func activate() -> AudioSessionActivation {
        do {
            try session.setCategory(Self.category, mode: Self.mode, options: [])
            try session.setActive(true, notifyingOthersOnDeactivation: false)
            return .exclusive
        } catch {
            // During a phone or FaceTime call a session that won't mix is
            // refused (insufficient priority). One that mixes activates, so
            // the sound at least plays instead of failing silently.
            do {
                try session.setCategory(Self.category, mode: Self.mode, options: [.mixWithOthers])
                try session.setActive(true, notifyingOthersOnDeactivation: false)
                return .mixedWithOtherAudio
            } catch {
                logger.error("Could not activate the playback audio session: \(error.localizedDescription)")
                return .failed
            }
        }
    }
}

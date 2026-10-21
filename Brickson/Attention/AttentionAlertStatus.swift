/// What one Get Attention activation does.
nonisolated enum AttentionStartDecision: Equatable, Sendable {
    /// The tone is really playing: a held look or a second press re-fired
    /// the control, and the alarm carries on untouched.
    case alreadySounding
    /// Build (or rebuild) the tone player and play it.
    case start
}

/// The Get Attention alarm's state, as a plain value so every rule about it
/// is tested without audio (the player, `AttentionAlertPlayer`, only feeds it
/// events and does what it says).
///
/// Get Attention only starts the alarm, and only a separate, differently
/// placed Stop Alert ends it (AGENTS.md, invariant 10, and "An alarm stops
/// only from a separate, differently placed control"). Speaking never
/// silences it. An alarm that stops by itself is never resumed by itself:
/// it shows "Alert stopped" and one activation restarts it (invariant 4;
/// docs/DECISIONS.md, "Get Attention").
nonisolated struct AttentionAlertStatus: Equatable, Sendable {
    /// The tone at the player's full level. The app never sets the system
    /// volume (invariant 4); this is the player's own gain.
    static let fullToneVolume: Float = 1

    /// The tone's level while a phrase is speaking, so the person's words
    /// are not lost under it while the call for help carries on. 0.32 is
    /// about 10 dB below full (the player's volume is linear). Proposed, not
    /// measured: a listening check on a device sets the real level
    /// (docs/DECISIONS.md, "Get Attention").
    static let toneVolumeWhileSpeaking: Float = 0.32

    private(set) var state: AttentionAlertState = .idle
    /// Goes up on every failed start and every unexpected stop, so each one
    /// is announced even when the state does not change
    /// (`AudioAnnouncementPolicy`).
    private(set) var failureSequence = 0

    var isSounding: Bool { state == .playing }

    /// A repeat counts as "already sounding" only while the live player
    /// confirms it is playing. If the tone stopped without telling anyone,
    /// the same activation restarts it rather than being swallowed by a
    /// stale "playing" state (the reference app's rule, which could leave
    /// "Sounding" on screen over silence).
    func startDecision(livePlayerIsPlaying: Bool) -> AttentionStartDecision {
        state == .playing && livePlayerIsPlaying ? .alreadySounding : .start
    }

    mutating func recordStart(succeeded: Bool) {
        if succeeded {
            state = .playing
        } else {
            recordFailure(.failedToStart)
        }
    }

    /// Stop Alert. An intentional stop is ordinary idle, and it never erases
    /// an unresolved failure just because some other path asked to stop.
    mutating func recordStopRequested() {
        if state == .playing {
            state = .idle
        }
    }

    /// An interruption, a media-services loss or reset, a lost output, a
    /// player error, or the health check. Only a sounding alarm can stop
    /// unexpectedly; while idle these change nothing. Returns whether the
    /// stop was recorded.
    @discardableResult
    mutating func recordUnexpectedStop() -> Bool {
        guard state == .playing else { return false }
        recordFailure(.stoppedUnexpectedly)
        return true
    }

    /// The health check, once a second while sounding and on returning to
    /// the foreground: the state says playing but the live player has gone
    /// quiet and nobody asked it to. Reports that once.
    @discardableResult
    mutating func recordHealthCheck(livePlayerIsPlaying: Bool) -> Bool {
        guard !livePlayerIsPlaying else { return false }
        return recordUnexpectedStop()
    }

    /// The tone's level for whether speech is in progress. Taken from the
    /// speech engine's hold on the audio session, which every ending of a
    /// phrase releases (a finish, a cancel, the missed-finish watchdog, an
    /// interruption, a reset), so the tone always comes back up.
    static func toneVolume(whileSpeechIsActive speechIsActive: Bool) -> Float {
        speechIsActive ? toneVolumeWhileSpeaking : fullToneVolume
    }

    private mutating func recordFailure(_ failure: AttentionAlertState) {
        state = failure
        failureSequence &+= 1
    }
}

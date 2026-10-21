import AVFoundation
import Foundation
import Observation

/// One observable source of truth for audio conditions that can make both
/// speech and Get Attention inaudible. It observes system-owned volume without
/// ever attempting to change it, and keeps media-service failures unhealthy
/// until the app has actually re-established its playback session.
@MainActor
@Observable
final class AudioSafetyMonitor {
    private(set) var outputVolume: Float
    private(set) var audioSessionHealthy = true

    @ObservationIgnored private let readOutputVolume: @MainActor () -> Float
    @ObservationIgnored private var outputVolumeObservation: NSKeyValueObservation?

    /// The app's monitor: the shared session's volume, and its events.
    convenience init(events: AudioSessionEvents) {
        let audioSession = AVAudioSession.sharedInstance()
        self.init(
            initialOutputVolume: audioSession.outputVolume,
            readOutputVolume: { audioSession.outputVolume },
            events: events
        )

        // AVAudioSession documents outputVolume as KVO-observable, but the
        // callback has no actor or ordering guarantee. Schedule a live read on
        // MainActor rather than carrying a possibly stale sample across it.
        // Explicitly @Sendable so the handler is nonisolated: a closure
        // inferred as MainActor-isolated would trap if KVO delivered the
        // change on another thread.
        let handler = outputVolumeChangeHandler
        outputVolumeObservation = audioSession.observe(
            \.outputVolume,
            options: [.initial, .new]
        ) { @Sendable _, _ in
            handler()
        }
    }

    init(
        initialOutputVolume: Float,
        readOutputVolume: @escaping @MainActor () -> Float,
        events: AudioSessionEvents
    ) {
        outputVolume = initialOutputVolume
        self.readOutputVolume = readOutputVolume
        events.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    isolated deinit {
        outputVolumeObservation?.invalidate()
    }

    /// The KVO change handler, safe to call from any thread.
    nonisolated var outputVolumeChangeHandler: @Sendable () -> Void {
        { [weak self] in self?.outputVolumeDidChange() }
    }

    /// Called from KVO's unspecified callback context. Each queued task reads
    /// the live value, so callback reordering cannot restore an older sample.
    @discardableResult
    nonisolated func outputVolumeDidChange() -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            self?.refreshOutputVolume()
        }
    }

    func refreshOutputVolume() {
        outputVolume = readOutputVolume()
    }

    func recordAudioSessionActivation(succeeded: Bool) {
        audioSessionHealthy = succeeded
        refreshOutputVolume()
    }

    private func handle(_ event: AudioSessionEvent) {
        switch event {
        case .routeChanged, .previousOutputUnavailable:
            refreshOutputVolume()
        case .mediaServicesLost:
            audioSessionHealthy = false
        case .mediaServicesReset:
            // Reset invalidates every audio object. The coordinator restores
            // the configuration now, but health stays visibly unresolved until
            // a later user action proves that activation works.
            audioSessionHealthy = false
            refreshOutputVolume()
        case .interrupted:
            // An interruption is reported by what it stopped (speech or the
            // alarm), not as a broken session.
            break
        }
    }
}

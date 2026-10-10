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
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private var outputVolumeObservation: NSKeyValueObservation?
    @ObservationIgnored private var observerTokens: [NSObjectProtocol] = []
    @ObservationIgnored private var mediaServicesResetHandler: (@MainActor () -> Void)?

    convenience init() {
        let audioSession = AVAudioSession.sharedInstance()
        self.init(
            initialOutputVolume: audioSession.outputVolume,
            readOutputVolume: { audioSession.outputVolume },
            notificationCenter: .default,
            notificationObject: audioSession
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
        notificationCenter: NotificationCenter,
        notificationObject: AnyObject
    ) {
        outputVolume = initialOutputVolume
        self.readOutputVolume = readOutputVolume
        self.notificationCenter = notificationCenter

        observerTokens.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: notificationObject,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshOutputVolume() }
            })

        observerTokens.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.mediaServicesWereLostNotification,
                object: notificationObject,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.audioSessionHealthy = false
                }
            })

        observerTokens.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: notificationObject,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    // Reset invalidates every audio object. Restore configuration
                    // now, but stay visibly unhealthy until a later user action
                    // proves that reactivation works.
                    self.audioSessionHealthy = false
                    self.refreshOutputVolume()
                    self.mediaServicesResetHandler?()
                }
            })
    }

    isolated deinit {
        outputVolumeObservation?.invalidate()
        for token in observerTokens {
            notificationCenter.removeObserver(token)
        }
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

    func onMediaServicesReset(_ handler: @escaping @MainActor () -> Void) {
        mediaServicesResetHandler = handler
    }
}

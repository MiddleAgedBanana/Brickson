import AVFoundation
import Foundation

/// What happened to the shared audio session, in the terms speech, the
/// alarm and the audio warnings act on.
nonisolated enum AudioSessionEvent: Equatable, Sendable {
    /// The system took the session away: a phone call, Siri, another app's
    /// alarm. Whatever was playing has stopped. Brickson never resumes by
    /// itself afterwards; the person's next activation does (invariant 4).
    case interrupted
    /// The output in use disappeared (headphones unplugged, a Bluetooth
    /// speaker switched off) and the system chose another.
    case previousOutputUnavailable
    /// Any other route change: only the volume needs reading again.
    case routeChanged
    case mediaServicesLost
    /// Every audio object is now invalid and must be rebuilt.
    case mediaServicesReset
}

/// Reads the session's notifications. Pure, so each mapping is tested with
/// plain dictionaries.
nonisolated enum AudioSessionEventMapping {
    /// The legacy interruption notice (iOS 26 and earlier; deprecated from
    /// iOS 27, still observed there as a second source). Only a beginning
    /// matters: an ending would only be a cue to resume, which Brickson
    /// never does by itself.
    static func interruptionEvent(userInfo: [AnyHashable: Any]?) -> AudioSessionEvent? {
        let type = (userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
            .flatMap(AVAudioSession.InterruptionType.init)
        return type == .began ? .interrupted : nil
    }

    static func routeChangeEvent(userInfo: [AnyHashable: Any]?) -> AudioSessionEvent {
        let reason = (userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
            .flatMap(AVAudioSession.RouteChangeReason.init)
        return reason == .oldDeviceUnavailable ? .previousOutputUnavailable : .routeChanged
    }

    /// iOS 27's life-cycle notice that the session became inactive. Brickson
    /// never deactivates the session itself (`AudioSessionLeasePolicy`), so
    /// an inactive session is the system's doing unless the notice says the
    /// app asked for it.
    static func deactivationEvent(deactivatedByApp: Bool) -> AudioSessionEvent? {
        deactivatedByApp ? nil : .interrupted
    }
}

/// The one observer of the shared audio session's notifications. It turns
/// them into `AudioSessionEvent`s and hands each to every subscriber, in the
/// order they subscribed, so speech, the alarm and the audio warnings never
/// keep observers of their own that could disagree.
///
/// iOS 27 adds life-cycle notifications and deprecates the interruption
/// notice, because the old notice can lose its ending (Apple, "Handling
/// audio interruptions"). Built with the iOS 27 SDK and running on iOS 27,
/// this observes the new notice as well as the old one, which Apple still
/// documents; each subscriber treats a second report of the same
/// interruption as nothing new, so seeing both is safe and missing one is
/// not.
@MainActor
final class AudioSessionEvents {
    private let notificationCenter: NotificationCenter
    private var tokens: [any NSObjectProtocol] = []
    private var subscribers: [@MainActor (AudioSessionEvent) -> Void] = []

    /// The app's adapter: the shared session, on the default center.
    convenience init() {
        self.init(notificationCenter: .default, object: AVAudioSession.sharedInstance())
    }

    /// `object` is the session whose notifications count; tests pass a
    /// private center and a stand-in object.
    init(notificationCenter: NotificationCenter, object: AnyObject) {
        self.notificationCenter = notificationCenter

        observe(AVAudioSession.interruptionNotification, from: object) { notification in
            AudioSessionEventMapping.interruptionEvent(userInfo: notification.userInfo)
        }
        observe(AVAudioSession.routeChangeNotification, from: object) { notification in
            AudioSessionEventMapping.routeChangeEvent(userInfo: notification.userInfo)
        }
        observe(AVAudioSession.mediaServicesWereLostNotification, from: object) { _ in
            .mediaServicesLost
        }
        observe(AVAudioSession.mediaServicesWereResetNotification, from: object) { _ in
            .mediaServicesReset
        }
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            observe(AVAudioSession.didBecomeInactiveNotification, from: object) { notification in
                let context = notification.userInfo?[AVAudioSession.deactivationContextKey]
                    as? AVAudioSession.DeactivationContext
                return AudioSessionEventMapping.deactivationEvent(
                    deactivatedByApp: context?.source == .app
                )
            }
        }
        #endif
    }

    isolated deinit {
        for token in tokens {
            notificationCenter.removeObserver(token)
        }
    }

    /// Subscribers are kept for the adapter's life; capture the subscriber
    /// weakly.
    func subscribe(_ subscriber: @escaping @MainActor (AudioSessionEvent) -> Void) {
        subscribers.append(subscriber)
    }

    /// Hands `event` to every subscriber. Internal so tests can drive a
    /// subscriber with an event no notification can be built for.
    func deliver(_ event: AudioSessionEvent) {
        for subscriber in subscribers {
            subscriber(event)
        }
    }

    /// The session posts on the main queue (Apple's documentation); the
    /// block is still `@Sendable` and hops explicitly, so a delivery on
    /// another thread could never run main-actor code there (docs/LESSONS.md,
    /// "Closures a framework may call off the main thread").
    private func observe(
        _ name: Notification.Name,
        from object: AnyObject,
        map: @escaping @Sendable (Notification) -> AudioSessionEvent?
    ) {
        let token = notificationCenter.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { [weak self] notification in
            guard let event = map(notification) else { return }
            MainActor.assumeIsolated {
                self?.deliver(event)
            }
        }
        tokens.append(token)
    }
}

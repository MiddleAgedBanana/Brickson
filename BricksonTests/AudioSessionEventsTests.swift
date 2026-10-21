import AVFoundation
import Foundation
import Testing

@testable import Brickson

@MainActor
struct AudioSessionEventsTests {
    // MARK: Reading the notices

    @Test func onlyTheBeginningOfAnInterruptionCounts() {
        let began = [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        let ended = [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]

        #expect(AudioSessionEventMapping.interruptionEvent(userInfo: began) == .interrupted)
        #expect(AudioSessionEventMapping.interruptionEvent(userInfo: ended) == nil)
        #expect(AudioSessionEventMapping.interruptionEvent(userInfo: nil) == nil)
        #expect(AudioSessionEventMapping.interruptionEvent(userInfo: [AVAudioSessionInterruptionTypeKey: "began"]) == nil)
    }

    @Test func aVanishedOutputIsToldApartFromOtherRouteChanges() {
        func event(_ reason: AVAudioSession.RouteChangeReason) -> AudioSessionEvent {
            AudioSessionEventMapping.routeChangeEvent(
                userInfo: [AVAudioSessionRouteChangeReasonKey: reason.rawValue]
            )
        }

        #expect(event(.oldDeviceUnavailable) == .previousOutputUnavailable)
        #expect(event(.newDeviceAvailable) == .routeChanged)
        #expect(event(.categoryChange) == .routeChanged)
        #expect(event(.override) == .routeChanged)
        #expect(AudioSessionEventMapping.routeChangeEvent(userInfo: nil) == .routeChanged)
    }

    /// iOS 27's "became inactive" notice. Brickson never deactivates the
    /// session itself, so anything but the app's own deactivation is the
    /// system taking it away.
    @Test func aDeactivationIsAnInterruptionUnlessTheAppAskedForIt() {
        #expect(AudioSessionEventMapping.deactivationEvent(deactivatedByApp: false) == .interrupted)
        #expect(AudioSessionEventMapping.deactivationEvent(deactivatedByApp: true) == nil)
    }

    // MARK: The adapter

    /// Fails if a subscriber misses an event, or sees one from another
    /// object's notification.
    @Test func eachNoticeFromTheSessionReachesEverySubscriberInOrder() {
        let (events, notifications) = makeEvents()
        var received: [String] = []
        events.subscribe { received.append("first \($0)") }
        events.subscribe { received.append("second \($0)") }

        notifications.interruptionBegan()
        notifications.routeChanged(.oldDeviceUnavailable)
        notifications.routeChanged(.newDeviceAvailable)
        notifications.mediaServicesLost()
        notifications.mediaServicesReset()

        #expect(received == [
            "first interrupted", "second interrupted",
            "first previousOutputUnavailable", "second previousOutputUnavailable",
            "first routeChanged", "second routeChanged",
            "first mediaServicesLost", "second mediaServicesLost",
            "first mediaServicesReset", "second mediaServicesReset",
        ])
    }

    @Test func noticesFromAnotherObjectAreIgnored() {
        let (events, notifications) = makeEvents()
        var received: [AudioSessionEvent] = []
        events.subscribe { received.append($0) }
        let other = SessionNotifications(center: notifications.center, session: NSObject())

        other.interruptionBegan()
        other.mediaServicesReset()
        notifications.interruptionEnded()

        #expect(received.isEmpty)
        notifications.interruptionBegan()
        #expect(received == [.interrupted])
    }

    #if compiler(>=6.4)
    /// On iOS 27 the "became inactive" notice is observed too. A notice
    /// without its context is read as the system's doing. Runs only on an
    /// iOS 27 simulator; on iOS 26 the notice does not exist.
    @Test(.enabled(if: ProcessInfo.processInfo.isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
    ), "The life-cycle notices exist from iOS 27"))
    func theIOS27InactiveNoticeIsAnInterruption() {
        guard #available(iOS 27.0, *) else {
            Issue.record("Enabled only from iOS 27")
            return
        }
        let (events, notifications) = makeEvents()
        var received: [AudioSessionEvent] = []
        events.subscribe { received.append($0) }

        notifications.center.post(
            name: AVAudioSession.didBecomeInactiveNotification,
            object: notifications.session
        )

        #expect(received == [.interrupted])
    }
    #endif

    private func makeEvents() -> (AudioSessionEvents, SessionNotifications) {
        let center = NotificationCenter()
        let session = NSObject()
        return (
            AudioSessionEvents(notificationCenter: center, object: session),
            SessionNotifications(center: center, session: session)
        )
    }
}

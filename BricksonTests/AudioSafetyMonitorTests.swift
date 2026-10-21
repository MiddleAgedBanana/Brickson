import AVFoundation
import Foundation
import Testing

@testable import Brickson

@MainActor
struct AudioSafetyMonitorTests {
    @Test func deferredVolumeChangeReadsTheLatestValue() async {
        let currentVolume = MutableVolume(0.6)
        let monitor = makeMonitor(readOutputVolume: { currentVolume.value }).monitor

        currentVolume.value = 0.1
        let refresh = monitor.outputVolumeDidChange()
        currentVolume.value = 0.8
        await refresh.value

        #expect(monitor.outputVolume == 0.8)
    }

    @Test(arguments: [AVAudioSession.RouteChangeReason.newDeviceAvailable, .oldDeviceUnavailable, .categoryChange])
    func routeChangeRefreshesOutputVolume(reason: AVAudioSession.RouteChangeReason) {
        let currentVolume = MutableVolume(0.6)
        let (monitor, notifications) = makeMonitor(readOutputVolume: { currentVolume.value })

        currentVolume.value = 0.1
        notifications.routeChanged(reason)

        #expect(monitor.outputVolume == 0.1)
    }

    @Test func mediaLossStaysUnhealthyUntilAudioIsProvenWorkingAgain() {
        let (monitor, notifications) = makeMonitor()

        notifications.mediaServicesLost()
        #expect(monitor.audioSessionHealthy == false)

        notifications.mediaServicesReset()
        #expect(monitor.audioSessionHealthy == false)

        monitor.recordAudioSessionActivation(succeeded: true)
        #expect(monitor.audioSessionHealthy)
    }

    /// Apple asks apps to wait for the person's next action before
    /// activating after a reset, so health stays unresolved until then.
    /// Fails if a reset marks the session healthy.
    @Test func aResetAloneNeverMarksTheSessionHealthy() {
        let (monitor, notifications) = makeMonitor()

        notifications.mediaServicesReset()

        #expect(monitor.audioSessionHealthy == false)
    }

    /// An interruption is shown by what it stopped, not as a broken
    /// session. Fails if it turns on "Audio failed".
    @Test func anInterruptionIsNotABrokenSession() {
        let (monitor, notifications) = makeMonitor()

        notifications.interruptionBegan()

        #expect(monitor.audioSessionHealthy)
    }

    @Test func failedActivationSurfacesUnhealthyState() {
        let monitor = makeMonitor().monitor

        monitor.recordAudioSessionActivation(succeeded: false)

        #expect(monitor.audioSessionHealthy == false)
    }

    /// A media-services reset that cuts off a phrase leaves Home naming
    /// Again, not only the generic "Audio failed" (invariant 4).
    @Test func aMediaResetDuringAPhraseNamesAgain() {
        let harness = AudioHarness()
        harness.speech.speak("Hello.")

        harness.notifications.mediaServicesReset()

        #expect(harness.speech.speechInterruptionState == .stoppedUnexpectedly)
        #expect(harness.issue == .speechStopped)
        #expect(harness.speech.lastSpokenText == "Hello.")
    }

    private func makeMonitor(
        readOutputVolume: @escaping @MainActor () -> Float = { 0.6 }
    ) -> (monitor: AudioSafetyMonitor, notifications: SessionNotifications) {
        let center = NotificationCenter()
        let session = NSObject()
        let events = AudioSessionEvents(notificationCenter: center, object: session)
        let monitor = AudioSafetyMonitor(
            initialOutputVolume: 0.6,
            readOutputVolume: readOutputVolume,
            events: events
        )
        // The monitor holds no reference to the adapter; keep it alive for
        // the test, as the coordinator does in the app.
        retainedEvents.append(events)
        return (monitor, SessionNotifications(center: center, session: session))
    }
}

/// The adapters made by `makeMonitor`, kept for the test run.
@MainActor private var retainedEvents: [AudioSessionEvents] = []

@MainActor
private final class MutableVolume {
    var value: Float

    init(_ value: Float) {
        self.value = value
    }
}

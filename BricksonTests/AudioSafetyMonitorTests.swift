import AVFoundation
import Foundation
import Testing

@testable import Brickson

@MainActor
struct AudioSafetyMonitorTests {
    @Test func deferredVolumeChangeReadsTheLatestValue() async {
        let currentVolume = MutableVolume(0.6)
        let monitor = makeMonitor(readOutputVolume: { currentVolume.value })

        currentVolume.value = 0.1
        let refresh = monitor.outputVolumeDidChange()
        currentVolume.value = 0.8
        await refresh.value

        #expect(monitor.outputVolume == 0.8)
    }

    @Test func routeChangeRefreshesOutputVolume() {
        let center = NotificationCenter()
        let sessionIdentity = NSObject()
        let currentVolume = MutableVolume(0.6)
        let monitor = makeMonitor(
            readOutputVolume: { currentVolume.value },
            notificationCenter: center,
            notificationObject: sessionIdentity
        )

        currentVolume.value = 0.1
        center.post(
            name: AVAudioSession.routeChangeNotification,
            object: sessionIdentity
        )

        #expect(monitor.outputVolume == 0.1)
    }

    @Test func mediaLossStaysUnhealthyUntilAudioIsProvenWorkingAgain() {
        let center = NotificationCenter()
        let sessionIdentity = NSObject()
        let monitor = makeMonitor(
            notificationCenter: center,
            notificationObject: sessionIdentity
        )

        center.post(
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: sessionIdentity
        )
        #expect(monitor.audioSessionHealthy == false)

        center.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: sessionIdentity
        )
        #expect(monitor.audioSessionHealthy == false)

        monitor.recordAudioSessionActivation(succeeded: true)
        #expect(monitor.audioSessionHealthy)
    }

    /// A media-services reset that cuts off a phrase leaves Home naming
    /// Again, not only the generic "Audio failed" (invariant 4).
    @Test func aMediaResetDuringAPhraseNamesAgain() {
        let center = NotificationCenter()
        let sessionIdentity = NSObject()
        let monitor = makeMonitor(
            notificationCenter: center,
            notificationObject: sessionIdentity
        )
        let speech = SpeechService(audioSafetyMonitor: monitor)
        speech.speak("Hello.")

        center.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: sessionIdentity
        )

        #expect(speech.speechInterruptionState == .stoppedUnexpectedly)
        #expect(speech.lastSpokenText == "Hello.")
    }

    @Test func failedActivationSurfacesUnhealthyState() {
        let monitor = makeMonitor()

        monitor.recordAudioSessionActivation(succeeded: false)

        #expect(monitor.audioSessionHealthy == false)
    }

    @Test func resetHandlerRunsButHealthWaitsForLaterUserActivation() {
        let center = NotificationCenter()
        let sessionIdentity = NSObject()
        var resetHandlerCallCount = 0
        let monitor = makeMonitor(
            notificationCenter: center,
            notificationObject: sessionIdentity
        )
        monitor.onMediaServicesReset {
            resetHandlerCallCount += 1
        }

        center.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: sessionIdentity
        )

        #expect(resetHandlerCallCount == 1)
        #expect(monitor.audioSessionHealthy == false)

        monitor.recordAudioSessionActivation(succeeded: true)
        #expect(monitor.audioSessionHealthy)
    }

    private func makeMonitor(
        readOutputVolume: @escaping @MainActor () -> Float = { 0.6 },
        notificationCenter: NotificationCenter = NotificationCenter(),
        notificationObject: AnyObject = NSObject()
    ) -> AudioSafetyMonitor {
        AudioSafetyMonitor(
            initialOutputVolume: 0.6,
            readOutputVolume: readOutputVolume,
            notificationCenter: notificationCenter,
            notificationObject: notificationObject
        )
    }
}

@MainActor
private final class MutableVolume {
    var value: Float

    init(_ value: Float) {
        self.value = value
    }
}

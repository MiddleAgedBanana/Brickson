import AVFoundation
import Foundation
import Testing
@testable import Brickson

/// With the project's default main-actor isolation, a closure handed to a
/// system framework silently becomes main-actor isolated, and Swift 6 traps
/// at run time if the framework calls it from another thread. The reference
/// app crashed this way (docs/LESSONS.md, "Closures a framework may call off
/// the main thread"). Every such callback gets a test that calls it from a
/// background thread.
struct OffMainThreadCallbackTests {
    /// AVAudioSession documents outputVolume as KVO-observable but gives no
    /// thread guarantee. The observation must tolerate a background delivery.
    @Test func outputVolumeChangeCanArriveOnABackgroundThread() async {
        let events = AudioSessionEvents(notificationCenter: NotificationCenter(), object: NSObject())
        let monitor = AudioSafetyMonitor(
            initialOutputVolume: 0.5,
            readOutputVolume: { 0.1 },
            events: events
        )
        let handler = monitor.outputVolumeChangeHandler

        await Task.detached { handler() }.value
        // The handler only schedules a main-actor read; wait for it to land.
        for _ in 0..<100 where monitor.outputVolume != 0.1 {
            await Task.yield()
        }

        #expect(monitor.outputVolume == 0.1)
        withExtendedLifetime(events) {}
    }

    /// AVSpeechSynthesizer gives no thread guarantee for its delegate. Each
    /// report must reach the main actor intact from a background thread.
    @Test @MainActor func synthesizerReportsCanArriveOnABackgroundThread() async {
        let events = SpeechSynthesizerEvents()
        var received: [SpeechSynthesisEvent] = []
        events.onEvent = { _, event in received.append(event) }
        let synthesizer = Unchecked(AVSpeechSynthesizer())
        let utterance = Unchecked(AVSpeechUtterance(string: "Hello there."))

        await Task.detached {
            events.speechSynthesizer(
                synthesizer.value,
                willSpeakRangeOfSpeechString: NSRange(location: 6, length: 5),
                utterance: utterance.value
            )
            events.speechSynthesizer(synthesizer.value, didFinish: utterance.value)
            events.speechSynthesizer(synthesizer.value, didCancel: utterance.value)
        }.value
        let arrived = await waitUntil { received.count == 3 }

        #expect(arrived)
        #expect(received.contains { if case .willSpeak(through: 11, at: _) = $0 { true } else { false } })
        #expect(received.contains { if case .finished = $0 { true } else { false } })
        #expect(received.contains(.cancelled))
    }

    /// The Personal Voice answer arrives on an arbitrary queue.
    @Test @MainActor func thePersonalVoiceAnswerCanArriveOnABackgroundThread() async throws {
        let harness = AudioHarness()
        let completion = try #require(harness.personalVoice.completion)

        await Task.detached { completion(.denied) }.value
        let arrived = await waitUntil { harness.speech.personalVoiceStatus == .denied }

        #expect(arrived)
    }

    /// AVAudioPlayer gives no thread guarantee for its delegate either.
    @Test @MainActor func toneReportsCanArriveOnABackgroundThread() async throws {
        let playback = try SystemAttentionTonePlayback.bundled()
        var received: [AttentionTonePlaybackEvent] = []
        playback.eventHandler = { received.append($0) }
        let url = try #require(Bundle.main.url(forResource: "AttentionTone", withExtension: "wav"))
        let player = Unchecked(try AVAudioPlayer(contentsOf: url))

        await Task.detached {
            playback.audioPlayerDidFinishPlaying(player.value, successfully: false)
            playback.audioPlayerDecodeErrorDidOccur(player.value, error: nil)
        }.value
        let arrived = await waitUntil { received.count == 2 }

        #expect(arrived)
        #expect(Set(received) == [.unexpectedFinish, .decodeError])
    }

    /// The audio session's notices are posted on the main queue, Apple
    /// says; the adapter must still be safe if one is posted elsewhere.
    @Test @MainActor func sessionNoticesPostedOnABackgroundThreadReachSubscribers() async {
        let center = NotificationCenter()
        let session = NSObject()
        let events = AudioSessionEvents(notificationCenter: center, object: session)
        var received: [AudioSessionEvent] = []
        events.subscribe { received.append($0) }
        let posting = Unchecked((center: center, session: session))

        await Task.detached {
            posting.value.center.post(
                name: AVAudioSession.mediaServicesWereResetNotification,
                object: posting.value.session
            )
        }.value
        let arrived = await waitUntil { received == [.mediaServicesReset] }

        #expect(arrived)
    }
}

/// Carries a framework object to a background thread for a test that calls
/// a delegate method there, as the framework would.
private struct Unchecked<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

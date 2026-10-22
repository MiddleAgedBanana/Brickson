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

    /// Reports sent one after another from a background thread arrive in
    /// that order. A finish that overtook the progress before it would hide
    /// a cut-off phrase. Fails if the hop stops preserving order.
    @Test @MainActor func synthesizerReportsKeepTheirOrderAcrossTheHop() async {
        let events = SpeechSynthesizerEvents()
        var received: [SpeechSynthesisEvent] = []
        events.onEvent = { _, event in received.append(event) }
        let synthesizer = Unchecked(AVSpeechSynthesizer())
        let utterance = Unchecked(AVSpeechUtterance(string: "Hello there."))
        let pairs = 50

        await Task.detached {
            for index in 0..<pairs {
                events.speechSynthesizer(
                    synthesizer.value,
                    willSpeakRangeOfSpeechString: NSRange(location: index, length: 1),
                    utterance: utterance.value
                )
                events.speechSynthesizer(synthesizer.value, didCancel: utterance.value)
            }
        }.value
        let arrived = await waitUntil { received.count == pairs * 2 }

        #expect(arrived)
        let progress = received.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
        let cancels = received.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
        #expect(cancels.allSatisfy { $0 == .cancelled })
        #expect(progress.enumerated().allSatisfy { item in
            if case let .willSpeak(through: offset, at: _) = item.element { offset == item.offset + 1 } else { false }
        })
    }

    /// The Personal Voice answer arrives on an arbitrary queue.
    @Test @MainActor func thePersonalVoiceAnswerCanArriveOnABackgroundThread() async throws {
        let harness = AudioHarness()
        let completion = try #require(harness.personalVoice.completion)

        await Task.detached { completion(.denied) }.value
        let arrived = await waitUntil { harness.speech.personalVoiceStatus == .denied }

        #expect(arrived)
    }

    /// The Voice screen's request waits for the same answer, which can also
    /// arrive on any queue. Fails if the wait traps or never ends.
    @Test @MainActor func theRequestedPersonalVoiceAnswerCanArriveOnABackgroundThread() async throws {
        let harness = AudioHarness(askPolicy: .fromSettings)
        let speech = harness.speech
        let asked = harness.personalVoice.requestCount
        let request = Task { await speech.requestPersonalVoiceAuthorization() }
        #expect(await waitUntil { harness.personalVoice.requestCount == asked + 1 })
        let completion = try #require(harness.personalVoice.completion)

        await Task.detached { completion(.authorized) }.value

        // Waits for the request only once its answer has landed, so a
        // broken hop fails here instead of waiting for ever.
        let landed = await waitUntil { harness.speech.personalVoiceStatus == .authorized }
        #expect(landed)
        guard landed else { return }
        let answer = await request.value
        #expect(answer == .authorized)
    }

    /// The closure the system itself calls with its answer, built by
    /// `SystemPersonalVoice.forwardingAnswer(to:)`, which is what
    /// `requestAuthorization` hands to AVFoundation. Fails if that closure
    /// becomes main-actor isolated.
    @Test func theSystemsPersonalVoiceAnswerCanArriveOnABackgroundThread() async {
        let answer: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = await withCheckedContinuation { continuation in
            let forward = SystemPersonalVoice.forwardingAnswer { status in
                continuation.resume(returning: status)
            }
            Task.detached { forward(.authorized) }
        }

        #expect(answer == .authorized)
    }

    /// The UI tests' stand-in for the permission answers from another
    /// queue, as the system does, after its status has changed. Fails if
    /// it answers on the main thread, answers something else, or answers
    /// before its status says so.
    @Test @MainActor func theStandInPersonalVoiceAnswersFromAnotherThread() async {
        let standIn = StandInPersonalVoice(answer: .denied)
        #expect(standIn.status == .notDetermined)

        let answer: (status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus, onMain: Bool) =
            await withCheckedContinuation { continuation in
                standIn.requestAuthorization { status in
                    continuation.resume(returning: (status, Thread.isMainThread))
                }
            }

        #expect(answer.status == .denied)
        #expect(!answer.onMain)
        #expect(standIn.status == .denied)
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
private nonisolated struct Unchecked<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

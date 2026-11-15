import AVFoundation

/// One of the synthesizer's reports, with the time it arrived.
nonisolated enum ProbeSpeechEvent: Sendable {
    case started(ObjectIdentifier, ContinuousClock.Instant)
    case word(ObjectIdentifier, location: Int, length: Int, ContinuousClock.Instant)
    case finished(ObjectIdentifier, ContinuousClock.Instant)
    case cancelled(ObjectIdentifier, ContinuousClock.Instant)
}

/// The synthesizer's delegate. Its reports may arrive on any thread, so it
/// is not main-actor isolated (AGENTS.md, *Code Review Rules*): it notes
/// the time at once and passes each report on, in order, through a stream
/// the speaker reads on the main actor (`OffMainThreadCallbackTests`).
nonisolated final class ProbeSpeechEvents: NSObject, AVSpeechSynthesizerDelegate, Sendable {
    let stream: AsyncStream<ProbeSpeechEvent>
    private let continuation: AsyncStream<ProbeSpeechEvent>.Continuation

    override init() {
        let made = AsyncStream.makeStream(of: ProbeSpeechEvent.self)
        stream = made.stream
        continuation = made.continuation
        super.init()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        continuation.yield(.started(ObjectIdentifier(utterance), .now))
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        continuation.yield(.word(
            ObjectIdentifier(utterance), location: characterRange.location,
            length: characterRange.length, .now))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        continuation.yield(.finished(ObjectIdentifier(utterance), .now))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        continuation.yield(.cancelled(ObjectIdentifier(utterance), .now))
    }
}

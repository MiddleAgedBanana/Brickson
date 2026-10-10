import Testing

@testable import Brickson

struct SpeechServiceTests {
    /// Home resets the message's scroll position on every phrase start, so
    /// a start that repeats the same words must still count. Fails if
    /// `phraseStartCount` only changes with `lastSpokenText`.
    @Test func everyPhraseStartIsCountedEvenWithTheSameWords() {
        let speech = SpeechService()
        let before = speech.phraseStartCount

        speech.speak("Hello.")
        #expect(speech.phraseStartCount == before + 1)

        speech.stop()
        speech.speak("Hello.")
        #expect(speech.phraseStartCount == before + 2)
        #expect(speech.lastSpokenText == "Hello.")

        speech.stop()
        speech.repeatLast()
        #expect(speech.phraseStartCount == before + 3)

        speech.stop()
    }

    /// Nothing to say is not a start. Fails if blank text is counted.
    @Test func blankTextIsNotAStart() {
        let speech = SpeechService()
        let before = speech.phraseStartCount

        speech.speak("   ")

        #expect(speech.phraseStartCount == before)
        #expect(speech.lastSpokenText == nil)
    }
}

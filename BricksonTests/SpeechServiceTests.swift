import AVFoundation
import Foundation
import Testing

@testable import Brickson

struct SpeechServiceTests {
    /// Test launches must restore their own speech preferences. Reading
    /// UserDefaults.standard instead of the supplied suite fails this;
    /// zero is a valid stored rate, not a missing preference.
    @Test func restoresVoiceAndRateFromTheProvidedSettings() throws {
        let suiteName = "SpeechServiceTests-\(UUID().uuidString)"
        let settings = try #require(UserDefaults(suiteName: suiteName))
        defer { settings.removePersistentDomain(forName: suiteName) }
        let voiceID = "test-voice-\(UUID().uuidString)"
        settings.set(voiceID, forKey: "selectedVoiceID")
        settings.set(AVSpeechUtteranceMinimumSpeechRate, forKey: "speechRate")

        let speech = SpeechService(settings: settings)

        #expect(speech.selectedVoiceID == voiceID)
        #expect(speech.speechRate == AVSpeechUtteranceMinimumSpeechRate)
    }

    /// Preference changes must survive a new service using the same test
    /// suite. Writing either preference to a different store fails this.
    /// Choosing automatic voice must remove the old choice, not revive it
    /// on the next launch.
    @Test func savesAndClearsPreferencesInTheProvidedSettings() throws {
        let suiteName = "SpeechServiceTests-\(UUID().uuidString)"
        let settings = try #require(UserDefaults(suiteName: suiteName))
        defer { settings.removePersistentDomain(forName: suiteName) }
        let speech = SpeechService(settings: settings)
        let voiceID = "test-voice-\(UUID().uuidString)"
        let rate: Float = 0.3

        speech.selectedVoiceID = voiceID
        speech.speechRate = rate

        #expect(settings.string(forKey: "selectedVoiceID") == voiceID)
        #expect(settings.float(forKey: "speechRate") == rate)
        let reloaded = SpeechService(settings: settings)
        #expect(reloaded.selectedVoiceID == voiceID)
        #expect(reloaded.speechRate == rate)

        reloaded.selectedVoiceID = nil

        #expect(settings.object(forKey: "selectedVoiceID") == nil)
        #expect(SpeechService(settings: settings).selectedVoiceID == nil)
    }

    /// A fresh test launch must forget speech preferences too. Retaining
    /// old settings, or treating a missing rate as zero, fails this.
    @Test func freshTestStorageResetsSpeechPreferences() throws {
        let suiteName = "SpeechServiceTests-\(UUID().uuidString)"
        let settings = try #require(UserDefaults(suiteName: suiteName))
        defer { settings.removePersistentDomain(forName: suiteName) }
        settings.set("test-voice", forKey: "selectedVoiceID")
        settings.set(Float(0.3), forKey: "speechRate")
        let directory = URL.temporaryDirectory.appending(path: suiteName, directoryHint: .isDirectory)

        LaunchOptions.parse(["--fresh-test-storage"])
            .prepareStorage(directory: directory, settingsSuite: suiteName)
        let speech = SpeechService(settings: settings)

        #expect(speech.selectedVoiceID == nil)
        #expect(speech.speechRate == AVSpeechUtteranceDefaultSpeechRate)
    }

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

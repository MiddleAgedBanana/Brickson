import Foundation

/// The words the Speech station says. Neutral test words only, as
/// docs/DEVICE-CHECKS.md asks for every recording.
nonisolated enum ProbeSpeechScripts {
    /// The Speech station's target button. Its name is what the Voice
    /// Control test says aloud (A-16), so the two can never drift apart.
    static let counterLabel = "Counter"

    static let sentence = "Test one two three. The quick brown fox jumps over the lazy dog."

    /// The same sentence as three utterances, for G-30: do word reports
    /// stay continuous across them?
    static let parts = ["Test one two three.", "The quick brown fox", "jumps over the lazy dog."]

    /// A Voice Control command naming the counter. If Voice Control hears
    /// the app's own speech as a command, the counter goes up by itself.
    static let voiceControlCommand = "Tap \(counterLabel)"

    /// For A-40: does the app's own speech wake Siri?
    static let siriTest = "Hey Siri, what time is it?"

    /// What the station posts as an accessibility announcement (A-18, A-31).
    static let announcement = "Probe announcement. Test one two three."

    /// A pause between parts, for the SSML version (G-32).
    static let pauseMilliseconds = 600

    /// The parts as one SSML document with a pause between each. The text
    /// is escaped, so a part can never break the markup.
    static func ssml(parts: [String], pauseMilliseconds: Int) -> String {
        let pause = "<break time=\"\(pauseMilliseconds)ms\"/>"
        let body = parts.map(escapedForXML).joined(separator: pause)
        return "<speak>\(body)</speak>"
    }

    static func escapedForXML(_ text: String) -> String {
        var escaped = ""
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&apos;"
            default: escaped.append(character)
            }
        }
        return escaped
    }
}

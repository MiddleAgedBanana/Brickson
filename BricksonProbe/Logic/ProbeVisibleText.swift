import Foundation

/// Text with its invisible characters made visible, so the Typing station
/// shows exactly what the keyboard delivered (A-34): an accepted
/// autocorrection or inline prediction shows as words the person did not
/// type, and a stray space or Return as its mark.
nonisolated enum ProbeVisibleText {
    static func marked(_ text: String) -> String {
        var shown = ""
        for character in text {
            switch character {
            case " ": shown += "·"
            case "\u{00A0}": shown += "⍽"
            case "\t": shown += "⇥"
            case "\n", "\r\n", "\r": shown += "⏎"
            default: shown.append(character)
            }
        }
        return shown
    }
}

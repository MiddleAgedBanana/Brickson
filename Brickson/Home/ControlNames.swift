import Foundation

/// The names a person can say to reach one of Home's controls with Voice
/// Control, or type to find it with Full Keyboard Access
/// (`accessibilityInputLabels`).
///
/// The words the control shows always come first: Voice Control shows the
/// first name when a person says "Show names", people say what they read on
/// the screen, and VoiceOver reads the same words. Another name is added
/// only where people commonly use a different word for the same action,
/// never one for a different action (docs/DECISIONS.md, "Home's scan order
/// and names").
nonisolated struct ControlNames: Equatable, Sendable {
    /// The words the control shows.
    let visible: String
    /// Other names Voice Control and Full Keyboard Access accept.
    let others: [String]

    init(_ visible: String, others: [String] = []) {
        self.visible = visible
        self.others = others
    }

    /// Every name, the visible words first, for `accessibilityInputLabels`.
    var inputLabels: [String] { [visible] + others }
}

/// The names of the controls Home always shows, and the check that no two
/// controls on one screen answer to the same name. When two do, Voice
/// Control stops to ask which one is meant, and the person needs another
/// command every time.
nonisolated enum HomeControlNames {
    static var yes: ControlNames {
        ControlNames(String(localized: "Yes"))
    }

    static var no: ControlNames {
        ControlNames(String(localized: "No"))
    }

    static var emergency: ControlNames {
        ControlNames(String(localized: "Emergency"))
    }

    static var again: ControlNames {
        ControlNames(
            String(localized: "Again", comment: "Repeats the last thing spoken."),
            others: [String(
                localized: "Repeat",
                comment: "Another name a person can say for the Again control with Voice Control."
            )]
        )
    }

    /// The controls Home always shows, in the order assistive technologies
    /// reach them (`HomeRegion`).
    static var fixed: [ControlNames] {
        [yes, no, emergency, again]
    }

    /// Every control on Home while `phrases` show, each by its names: the
    /// fixed controls, the category buttons in `categoryRow`, and the phrase
    /// tiles. Categories and phrases answer to their own words only, and
    /// Brickson never renames them (invariant 7).
    static func onHome(categoryRow: [String], phrases: [String]) -> [[String]] {
        fixed.map(\.inputLabels) + categoryRow.map { [$0] } + phrases.map { [$0] }
    }

    /// The names, as Voice Control hears them (`spokenForm`), that more than
    /// one control in `controls` answers to, in alphabetical order. Each
    /// element of `controls` is one control's names. A control that lists a
    /// name twice does not collide with itself, and a name with nothing to
    /// say is never compared.
    static func collisions(among controls: [[String]]) -> [String] {
        var owners: [String: Int] = [:]
        for names in controls {
            for form in Set(names.map(spokenForm)) where !form.isEmpty {
                owners[form, default: 0] += 1
            }
        }
        return owners.filter { $0.value > 1 }.keys.sorted()
    }

    /// A name as Voice Control hears it: its letters and digits, in lower
    /// case without accents, one space between words. Punctuation and
    /// symbols are dropped, so "Yes." is "yes" and "I'm okay." is "im okay".
    static func spokenForm(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
        var form = ""
        var betweenWords = false
        for character in folded {
            if character.isLetter || character.isNumber {
                if betweenWords && !form.isEmpty {
                    form.append(" ")
                }
                betweenWords = false
                form.append(character)
            } else if character.isWhitespace {
                betweenWords = true
            }
        }
        return form
    }
}

import Foundation

/// How a label fits its slot without breaking a word (AGENTS.md, "Words
/// never break"). Plain logic, tested without a screen.
///
/// A label is drawn at one of a list of text sizes, largest first: the
/// person's own text size, then each smaller step down to the default size.
/// It never goes below the default, and never below the person's own size
/// when that is smaller. `choices` lists, in order of preference, the ways the
/// label may be drawn whose widest word fits the width:
///
/// 1. the person's size with its icon,
/// 2. the person's size without the icon (the decorative icon goes before
///    the words shrink),
/// 3. each smaller size, without the icon.
///
/// `FittedLabel` then draws the first choice whose height fits (`first(of:)`),
/// by `LabelFont`'s measure of the wrapped words. The last choice is always
/// the smallest size without the icon: it is drawn even when it does not
/// fit, because nothing smaller is allowed.
nonisolated enum WordFit {
    /// A way to draw a label: a step in the list of text sizes, and whether
    /// its icon shows.
    struct Choice: Hashable, Sendable {
        /// 0 is the person's own size; each step after it is smaller.
        var step: Int
        var showsIcon: Bool
    }

    /// Room kept beside the widest word. SwiftUI's measured widths come out
    /// up to half a point wider than UIKit's, rounded up, for the same font
    /// (`StarterLabelFitTests`); this covers that with room to spare.
    static let widthSlack: CGFloat = 2

    /// - Parameters:
    ///   - stepCount: how many text sizes there are, largest first.
    ///   - hasIcon: whether the label has a decorative icon.
    ///   - width: the width the label is given.
    ///   - widestWord: the width of the label's widest word at a step.
    ///   - iconAdvance: the width the icon and the gap after it take at a step.
    static func choices(
        stepCount: Int,
        hasIcon: Bool,
        width: CGFloat,
        widestWord: (_ step: Int) -> CGFloat,
        iconAdvance: (_ step: Int) -> CGFloat
    ) -> [Choice] {
        guard stepCount > 0 else { return [] }
        func fits(_ step: Int, withIcon: Bool) -> Bool {
            let needed = widestWord(step) + (withIcon ? iconAdvance(step) : 0)
            return width > 0 && needed <= width - widthSlack
        }

        var result: [Choice] = []
        if hasIcon, fits(0, withIcon: true) {
            result.append(Choice(step: 0, showsIcon: true))
        }
        for step in 0..<stepCount where fits(step, withIcon: false) {
            result.append(Choice(step: step, showsIcon: false))
        }
        let smallest = Choice(step: stepCount - 1, showsIcon: false)
        if result.last != smallest {
            result.append(smallest)
        }
        return result
    }

    /// The first of `choices` whose height fits, or the last when none does.
    ///
    /// The choice is worked out rather than left to SwiftUI's `ViewThatFits`,
    /// so a label stays one view whatever size it is drawn at. Apple's
    /// accessibility audit grows the text and compares each label with
    /// itself; `ViewThatFits` replaced the label with another view as the
    /// text grew, and the audit then reported it as clipped or as not
    /// following Dynamic Type (docs/log/2026-10-21-phone-layout.md).
    static func first(of choices: [Choice], whereHeightFits fits: (Choice) -> Bool) -> Choice {
        choices.first(where: fits) ?? choices.last ?? Choice(step: 0, showsIcon: false)
    }

    /// `text` set in lines no wider than `width` less `widthSlack`, each
    /// holding as many whole words as fit. A word wider than that keeps a
    /// line of its own, whole. `FittedLabel` draws these lines as they are,
    /// so the system never has to decide where a line breaks, and never
    /// breaks a word.
    static func lines(of text: String, width: CGFloat, measure: (String) -> CGFloat) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in words(in: text) {
            let candidate = current.isEmpty ? String(word) : current + " " + word
            if current.isEmpty || measure(candidate) <= width - widthSlack {
                current = candidate
            } else {
                lines.append(current)
                current = String(word)
            }
        }
        if !current.isEmpty {
            lines.append(current)
        }
        return lines
    }

    /// The words of a label: it may break between them, never inside one.
    static func words(in text: String) -> [Substring] {
        text.split(whereSeparator: \.isWhitespace)
    }
}

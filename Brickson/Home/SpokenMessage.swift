import SwiftUI

// Marking the word being spoken in Home's message (docs/DECISIONS.md, "The
// word being spoken is marked"). While a phrase is spoken, the words already
// said are drawn in full ink, the word being said in full ink with a bar
// under it, and the words still to come dimmed. Only the synthesizer's own
// word reports move the mark (`SpeechService.phraseInProgress`); nothing
// guesses timing, and a voice that reports no words leaves the whole message
// dimmed until it ends.
//
// The words are laid out once, from the message alone: each is its own
// `Text` segment tagged with its index, and the renderer only changes how
// brightly each is drawn and draws the bar, so no word moves, grows or
// changes weight while marked. The mark is drawn, never announced: the
// message keeps one accessibility label, the whole message, so VoiceOver
// does not talk over the voice. Everything that decides how a word is drawn
// is plain, nonisolated and Sendable, so SwiftUI may draw on whichever
// thread it renders on (`OffMainThreadCallbackTests`).

/// Where a word of a message stands while the message is spoken.
nonisolated enum SpokenWordState: Equatable, Sendable {
    /// Already said: full ink.
    case spoken
    /// Being said now: full ink, with the bar under it.
    case beingSpoken
    /// Still to come: dimmed.
    case toCome
}

/// The words of a message and where each sits in it, in UTF-16 units (what
/// the synthesizer's reports count). A word is a run of characters between
/// spaces or line breaks, the split Home sets the message's lines by
/// (`WordFit.words(in:)`), so a marked word is always one whole drawn word,
/// punctuation and all.
nonisolated struct MessageWords: Equatable, Sendable {
    let message: String
    /// Each word's place in `message`, in order.
    let places: [Range<Int>]

    init(_ message: String) {
        self.message = message
        places = WordFit.words(in: message).map { word in
            word.startIndex.utf16Offset(in: message)..<word.endIndex.utf16Offset(in: message)
        }
    }

    /// The marking while the message is spoken and its voice last reported
    /// `place` (nil: no word yet). Every word the place overlaps is being
    /// spoken, the words wholly before it are spoken, and the rest are to
    /// come. A place past the end names no word of this message and marks
    /// none; one running past the end is cut there; an empty one marks no
    /// word as being spoken.
    func marking(reported place: Range<Int>?) -> WordMarking {
        guard let place else { return .nothingReported }
        let length = message.utf16.count
        guard place.lowerBound < length else { return .nothingReported }
        let reported = place.lowerBound..<min(place.upperBound, length)
        let spoken = places.prefix { $0.upperBound <= reported.lowerBound }.count
        let beingSpoken = places[spoken...].prefix { $0.lowerBound < reported.upperBound && reported.lowerBound < $0.upperBound }.count
        return WordMarking(spoken: spoken, beingSpoken: beingSpoken)
    }
}

/// Which words of a message are spoken, being spoken and to come, by their
/// order in the message: the first `spoken` words are said, the next
/// `beingSpoken` are being said, and every later one is to come.
nonisolated struct WordMarking: Equatable, Sendable {
    let spoken: Int
    let beingSpoken: Int

    /// Speaking, with no word reported yet: every word is to come.
    static let nothingReported = WordMarking(spoken: 0, beingSpoken: 0)

    func state(ofWord index: Int) -> SpokenWordState {
        if index < spoken { return .spoken }
        if index < spoken + beingSpoken { return .beingSpoken }
        return .toCome
    }
}

/// How one word is drawn: at what share of its ink, and whether with the bar.
nonisolated struct SpokenWordLook: Equatable, Sendable {
    let opacity: Double
    let hasBar: Bool
}

/// The marking's measures, in the message's own ink: the words to come at a
/// share of it that keeps them at 4.5:1 or better on the screen in every
/// appearance (`PaletteTests`), and a bar in full ink under the word being
/// spoken. Increase Contrast darkens the dimmed words and thickens the bar.
/// The bar is a shape, so the mark does not depend on colour or on
/// brightness alone, which is all Differentiate Without Colour asks; it is
/// drawn in every setting.
nonisolated struct SpokenWordStyle: Equatable, Sendable {
    let increasedContrast: Bool

    /// The share of the ink the words still to come are drawn with.
    var dimOpacity: Double { increasedContrast ? 0.75 : 0.6 }
    /// The bar's thickness, in points.
    var barHeight: CGFloat { increasedContrast ? 4 : 3 }
    /// The room between the bottom of a line and the top of the bar, in
    /// points: the bar sits clear of the descenders.
    static let barGap: CGFloat = 1
    /// How far the bar reaches below the line it marks, which the text's
    /// drawing and Home's message both keep room for.
    var roomBelow: CGFloat { Self.barGap + barHeight }
    /// The most room the bar takes below a line, in any setting.
    static let mostRoomBelow = SpokenWordStyle(increasedContrast: true).roomBelow

    func look(for state: SpokenWordState?) -> SpokenWordLook {
        switch state {
        case .toCome: SpokenWordLook(opacity: dimOpacity, hasBar: false)
        case .beingSpoken: SpokenWordLook(opacity: 1, hasBar: true)
        case .spoken, nil: SpokenWordLook(opacity: 1, hasBar: false)
        }
    }

    /// The bar under a word drawn at `word` (its typographic bounds) on a
    /// line with the given baseline and descent: as wide as the word, from
    /// `barGap` below the line's descent.
    func bar(underWordAt word: CGRect, baseline: CGFloat, descent: CGFloat) -> CGRect {
        CGRect(x: word.minX, y: baseline + descent + Self.barGap, width: word.width, height: barHeight)
    }
}

/// Tags a word of the message with its order, for the renderer.
nonisolated struct SpokenWordIndex: TextAttribute {
    let index: Int
}

/// Draws the message's words by their marking (nil: not being spoken, so
/// every word is drawn as it always is). It has nothing SwiftUI can animate,
/// so the mark steps from word to word in every setting, Reduce Motion
/// included.
nonisolated struct SpokenWordRenderer: TextRenderer {
    let marking: WordMarking?
    let style: SpokenWordStyle

    /// Room for the bar below the last line, so it is never clipped.
    var displayPadding: EdgeInsets {
        EdgeInsets(top: 0, leading: 0, bottom: style.roomBelow, trailing: 0)
    }

    /// The look of the word at `index` (nil: a space between words, drawn
    /// as it always is).
    func look(ofWord index: Int?) -> SpokenWordLook {
        guard let marking, let index else { return style.look(for: nil) }
        return style.look(for: marking.state(ofWord: index))
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            let bounds = line.typographicBounds
            for run in line {
                let look = look(ofWord: run[SpokenWordIndex.self]?.index)
                if look.opacity < 1 {
                    var dimmed = context
                    dimmed.opacity = look.opacity
                    dimmed.draw(run)
                } else {
                    context.draw(run)
                }
                if look.hasBar {
                    let bar = style.bar(underWordAt: run.typographicBounds.rect, baseline: bounds.origin.y, descent: bounds.descent)
                    context.fill(Path(bar), with: .foreground)
                }
            }
        }
    }
}

/// The message as one `Text` of tagged words, built from the message alone
/// and never from its marking.
enum SpokenMessageText {
    /// `message` set in `lines` (Home's `MessageFit`), words joined by a
    /// space and lines by a line break, or as written where it is not set
    /// in lines. Each word is tagged with its order (`SpokenWordIndex`).
    static func text(for message: String, setIn lines: [String]?) -> Text {
        var segments: [Text] = []
        var index = 0
        func word(_ word: Substring) {
            segments.append(Text(verbatim: String(word)).customAttribute(SpokenWordIndex(index: index)))
            index += 1
        }
        if let lines {
            for (number, line) in lines.enumerated() {
                if number > 0 { segments.append(Text(verbatim: "\n")) }
                for (position, each) in WordFit.words(in: line).enumerated() {
                    if position > 0 { segments.append(Text(verbatim: " ")) }
                    word(each)
                }
            }
        } else {
            var rest = message[...]
            for each in WordFit.words(in: message) {
                let gap = rest[..<each.startIndex]
                if !gap.isEmpty { segments.append(Text(verbatim: String(gap))) }
                word(each)
                rest = message[each.endIndex...]
            }
            if !rest.isEmpty { segments.append(Text(verbatim: String(rest))) }
        }
        return joined(segments)
    }

    /// The most segments one interpolation joins. SwiftUI drew nothing of
    /// a text that interpolated more than 128 (measured on iOS 27.2), so
    /// longer messages are joined in groups, and the groups joined again.
    static let mostJoinedAtOnce = 64

    /// `texts` as one `Text`, by interpolation: `+` on `Text` is
    /// deprecated. The interpolation's only key is "%@", which the String
    /// Catalog keeps as not to be translated.
    private static func joined(_ texts: [Text]) -> Text {
        guard texts.count > mostJoinedAtOnce else {
            var joined = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: texts.count)
            for text in texts {
                joined.appendInterpolation(text)
            }
            return Text(
                LocalizedStringKey(stringInterpolation: joined),
                comment: "Joins the words of a person's message for Home's message. Nothing to translate."
            )
        }
        let groups = stride(from: 0, to: texts.count, by: mostJoinedAtOnce).map { start in
            joined(Array(texts[start..<min(start + mostJoinedAtOnce, texts.count)]))
        }
        return joined(groups)
    }
}

/// The message's words drawn with their marking: the view Home's message
/// shows, and the one the tests draw.
struct SpokenMessageWords: View {
    let content: Text
    let marking: WordMarking?
    let style: SpokenWordStyle

    var body: some View {
        content.textRenderer(SpokenWordRenderer(marking: marking, style: style))
    }
}

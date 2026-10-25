import SwiftUI
import UIKit

/// A text style and weight that SwiftUI draws and UIKit measures at the same
/// size, so what `WordFit` measures is what people see.
///
/// Labels are drawn with the style itself at one of Apple's text sizes
/// (`steps(downFrom:)`), never at a made-up point size, so SwiftUI lays them
/// out with the style's own line spacing. UIKit measures them: its widths
/// match SwiftUI's to within half a point, and `textHeight` is never less
/// than the height SwiftUI draws (`StarterLabelFitTests`).
struct LabelFont: Equatable {
    enum Weight: Equatable {
        case regular
        case semibold

        var uiFontWeight: UIFont.Weight {
            switch self {
            case .regular: .regular
            case .semibold: .semibold
            }
        }

        var fontWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .semibold: .semibold
            }
        }
    }

    let textStyle: Font.TextStyle
    let weight: Weight
    /// Whether Bold Text is on, so labels are measured at the heavier weight
    /// SwiftUI draws them in (`legible(_:)`).
    var boldText = false

    /// The weight measured when Bold Text is on, for every weight: the
    /// heaviest, so the measure is never narrower than what is drawn. Apple
    /// does not document how much heavier Bold Text draws, and on CI SwiftUI
    /// drew semibold labels up to 4.6% wider than UIKit's bold measures them
    /// ("Conversation" in headline at AX5: 342pt drawn, 327pt measured at
    /// bold). `StarterLabelFitTests` checks SwiftUI's Bold Text widths and
    /// heights against this measure.
    static let boldTextUIFontWeight = UIFont.Weight.black

    /// The message the listener reads.
    static let message = LabelFont(textStyle: .title, weight: .semibold)
    /// Yes, No, Emergency and Again.
    static let quickControl = LabelFont(textStyle: .title3, weight: .semibold)
    /// Category buttons.
    static let category = LabelFont(textStyle: .headline, weight: .semibold)
    /// Phrase tiles where tiles are narrow (compact widths).
    static let compactTile = LabelFont(textStyle: .headline, weight: .semibold)
    /// Phrase tiles everywhere else.
    static let regularTile = LabelFont(textStyle: .title2, weight: .semibold)
    /// The status line under the message.
    static let status = LabelFont(textStyle: .subheadline, weight: .semibold)

    /// The gap between a label's icon and its words, as a share of the point
    /// size, so it grows with the text.
    static let iconSpacingRatio: CGFloat = 0.3

    /// The text sizes a label may use, largest first: the person's own size,
    /// then each of Apple's sizes below it down to the default (Large). A
    /// person who chose a size smaller than the default gets only their own.
    static func steps(downFrom size: DynamicTypeSize) -> [DynamicTypeSize] {
        guard size > .large else { return [size] }
        return DynamicTypeSize.allCases.filter { $0 >= .large && $0 <= size }.reversed()
    }

    /// The font SwiftUI draws. Its size comes from the view's text size,
    /// which `FittedLabel` sets to the chosen step.
    var font: Font {
        .system(textStyle, weight: weight.fontWeight)
    }

    /// This font as measured under the person's Bold Text setting. Views
    /// pass their `legibilityWeight`: measuring a bold label at the regular
    /// weight would choose a size or set lines its wider words do not fit.
    func legible(_ legibilityWeight: LegibilityWeight?) -> LabelFont {
        var font = self
        font.boldText = legibilityWeight == .bold
        return font
    }

    /// The style's point size at a text size.
    func pointSize(at size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        return UIFont.preferredFont(forTextStyle: uiTextStyle, compatibleWith: traits).pointSize
    }

    /// The width of the widest word of `text` on one line at a text size.
    func widestWord(_ text: String, at size: DynamicTypeSize) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: uiFont(at: size)]
        let widest = WordFit.words(in: text)
            .map { (String($0) as NSString).size(withAttributes: attributes).width }
            .max() ?? 0
        return widest.rounded(.up)
    }

    /// At least the height of one line of the style at a text size as
    /// SwiftUI draws it. UIKit's line height comes out a fraction of a point
    /// under SwiftUI's (headline at the default size: 20.3 against 20.5,
    /// measured on CI), so this rounds up and adds a point
    /// (`StarterLabelFitTests`).
    func lineHeight(at size: DynamicTypeSize) -> CGFloat {
        uiFont(at: size).lineHeight.rounded(.up) + 1
    }

    /// `text` set in lines that fit `width` at a text size, whole words
    /// only (`WordFit.lines`).
    func lines(_ text: String, width: CGFloat, at size: DynamicTypeSize) -> [String] {
        WordFit.lines(of: text, width: width, measure: { lineWidth($0, at: size) })
    }

    /// At least the height SwiftUI draws `text` in at a text size, set in
    /// lines that fit `width` (`lines`). Each line after the first is given
    /// UIKit's line height plus 15%, more than the leading SwiftUI adds
    /// (headline at the default size: 22pt a line against UIKit's 20.3,
    /// measured on CI).
    func textHeight(_ text: String, width: CGFloat, at size: DynamicTypeSize) -> CGFloat {
        let count = max(1, lines(text, width: width, at: size).count)
        return lineHeight(at: size) + CGFloat(count - 1) * (uiFont(at: size).lineHeight * 1.15).rounded(.up)
    }

    /// The width of `text` on one line at a text size.
    func lineWidth(_ text: String, at size: DynamicTypeSize) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: uiFont(at: size)]).width.rounded(.up)
    }

    /// The width a symbol takes beside text at a text size. Labels give
    /// their icon exactly this width, so what is measured is what is laid
    /// out.
    func iconWidth(_ systemImage: String, at size: DynamicTypeSize) -> CGFloat {
        let font = uiFont(at: size)
        let configuration = UIImage.SymbolConfiguration(font: font)
        let symbolWidth = UIImage(systemName: systemImage, withConfiguration: configuration)?.size.width ?? font.pointSize
        return symbolWidth.rounded(.up)
    }

    /// The width a symbol and the gap after it take beside text at a text size.
    func iconAdvance(_ systemImage: String, at size: DynamicTypeSize) -> CGFloat {
        iconWidth(systemImage, at: size) + iconSpacing(at: size)
    }

    /// The gap between the icon and the words at a text size.
    func iconSpacing(at size: DynamicTypeSize) -> CGFloat {
        (pointSize(at: size) * Self.iconSpacingRatio).rounded()
    }

    /// The ways `text` may be drawn in `width`, best first (`WordFit`).
    func choices(
        for text: String, systemImage: String?, steps: [DynamicTypeSize], width: CGFloat
    ) -> [WordFit.Choice] {
        WordFit.choices(
            stepCount: steps.count,
            hasIcon: systemImage != nil,
            width: width,
            widestWord: { widestWord(text, at: steps[$0]) },
            iconAdvance: { step in systemImage.map { iconAdvance($0, at: steps[step]) } ?? 0 }
        )
    }

    /// How `FittedLabel` draws `text` in `size`: the first of `choices` whose
    /// wrapped words fit the height (`WordFit.first(of:whereHeightFits:)`).
    func choice(
        for text: String, systemImage: String?, steps: [DynamicTypeSize], size: CGSize
    ) -> WordFit.Choice {
        let candidates = choices(for: text, systemImage: systemImage, steps: steps, width: size.width)
        return WordFit.first(of: candidates, whereHeightFits: { choice in
            let step = steps[choice.step]
            let icon = choice.showsIcon ? systemImage.map { iconAdvance($0, at: step) } ?? 0 : 0
            return textHeight(text, width: size.width - icon, at: step) <= size.height
        })
    }

    /// How `FittedLine` draws `text` on one line of `width`: the person's
    /// size with its icon, then without, then each smaller size; the
    /// smallest when none fits, which then wraps.
    func lineChoice(
        for text: String, systemImage: String, steps: [DynamicTypeSize], width: CGFloat
    ) -> WordFit.Choice {
        WordFit.choices(
            stepCount: steps.count,
            hasIcon: true,
            width: width,
            widestWord: { lineWidth(text, at: steps[$0]) },
            iconAdvance: { iconAdvance(systemImage, at: steps[$0]) }
        ).first ?? WordFit.Choice(step: 0, showsIcon: false)
    }

    /// How a passage that scrolls when it is long, such as Home's message,
    /// fits `width` at the person's text size `size` (`MessageFit`).
    func messageFit(for text: String, at size: DynamicTypeSize, width: CGFloat) -> MessageFit {
        let steps = Self.steps(downFrom: size)
        let smallest = steps.last ?? size
        guard let step = choices(for: text, systemImage: nil, steps: steps, width: width).first?.step else {
            return MessageFit(lines: nil, smallestScale: 1, cap: smallest)
        }
        let own = pointSize(at: size)
        let scale = own > 0 ? min(1, pointSize(at: smallest) / own) : 1
        return MessageFit(lines: lines(text, width: width, at: steps[step]), smallestScale: scale, cap: size)
    }

    private func uiFont(at size: DynamicTypeSize) -> UIFont {
        .systemFont(ofSize: pointSize(at: size), weight: boldText ? Self.boldTextUIFontWeight : weight.uiFontWeight)
    }

    private var uiTextStyle: UIFont.TextStyle {
        switch textStyle {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}

/// How a passage that scrolls when it is long fits its width, by
/// `FittedLabel`'s steps: it shrinks only as far as its widest word needs,
/// never below the default size (AGENTS.md, "Words never break"), and only
/// the width matters. Where that word fits at one of the text sizes from the
/// person's own down to the default, the passage is set in the lines it
/// takes at the largest such size and drawn at the person's own size,
/// which SwiftUI scales down to fit (`minimumScaleFactor`), so it keeps
/// following Dynamic Type for Apple's accessibility audit. A cap on its text
/// size instead was reported as "Dynamic Type font sizes are partially
/// unsupported" once Phrases and Type narrowed Home's message on phones.
/// Where no size fits that word, it is capped at the default size and
/// wraps as it must.
struct MessageFit: Equatable {
    /// The lines the passage is set in, or nil where its widest word fits no
    /// size.
    let lines: [String]?
    /// The smallest scale SwiftUI may draw it at: the default size's share
    /// of the person's own, or 1 where it is not set in lines.
    let smallestScale: CGFloat
    /// The largest text size it is drawn at (`textSize`): the person's own
    /// where it is set in lines, which limits nothing.
    let cap: DynamicTypeSize
}

extension View {
    /// Draws the view at no more than `size`, one of the steps below the
    /// person's own text size. At the person's own size the limit changes
    /// nothing, so text that fits keeps following Dynamic Type as usual. It
    /// is always the same modifier, whichever step is chosen, so the text
    /// stays one view as it grows (Apple's accessibility audit compares each
    /// text with itself at larger sizes).
    func textSize(_ size: DynamicTypeSize) -> some View {
        dynamicTypeSize(...size)
    }
}

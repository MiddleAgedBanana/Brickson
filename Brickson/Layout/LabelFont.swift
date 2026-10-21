import SwiftUI
import UIKit

/// A text style and weight that SwiftUI draws and UIKit measures at the same
/// size, so what `WordFit` measures is what people see.
///
/// Labels are drawn with the style itself at one of Apple's text sizes
/// (`steps(downFrom:)`), never at a made-up point size, so SwiftUI lays them
/// out with the style's own line spacing. UIKit measures only widths, which
/// match SwiftUI's to within half a point (`StarterLabelFitTests`); SwiftUI
/// measures heights itself (`FittedLabel`).
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

    /// The width of `text` on one line at a text size.
    func lineWidth(_ text: String, at size: DynamicTypeSize) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: uiFont(at: size)]).width.rounded(.up)
    }

    /// The width a symbol and the gap after it take beside text at a text size.
    func iconAdvance(_ systemImage: String, at size: DynamicTypeSize) -> CGFloat {
        let font = uiFont(at: size)
        let configuration = UIImage.SymbolConfiguration(font: font)
        let symbolWidth = UIImage(systemName: systemImage, withConfiguration: configuration)?.size.width ?? font.pointSize
        return symbolWidth.rounded(.up) + iconSpacing(at: size)
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

    private func uiFont(at size: DynamicTypeSize) -> UIFont {
        .systemFont(ofSize: pointSize(at: size), weight: weight.uiFontWeight)
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

extension View {
    /// Draws the view at `size` when it is smaller than the person's own text
    /// size `current`, and otherwise leaves the person's size untouched, so
    /// text that fits keeps following the system's Dynamic Type as usual
    /// (Apple's accessibility audit reports text pinned to a fixed size).
    @ViewBuilder
    func textSize(_ size: DynamicTypeSize, from current: DynamicTypeSize) -> some View {
        if size == current {
            self
        } else {
            dynamicTypeSize(size)
        }
    }
}

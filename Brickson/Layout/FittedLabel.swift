import SwiftUI

/// A control's label that fills the space its control gives it and fits
/// itself: the person's text size with its icon when that fits, then without
/// the icon, then each of Apple's smaller text sizes in turn, never below the
/// default size (`WordFit`).
///
/// `WordFit` rules out every size at which a word would not fit the width,
/// and the first remaining size whose words, set in whole-word lines, fit
/// the height is chosen (`LabelFont.choice`). The smallest size is chosen
/// even when it does not fit, because nothing smaller is allowed: Home's
/// sizes are chosen so the starter library always fits
/// (`StarterLabelFitTests`).
///
/// The words are then drawn at the person's own text size, in the lines
/// set for the chosen size, and SwiftUI shrinks them only as far as they
/// need to fit (`minimumScaleFactor`), never below the default size. So the
/// text keeps following Dynamic Type, which Apple's accessibility audit
/// checks: a label drawn at a smaller text size (`dynamicTypeSize`) is
/// reported as not supporting it. With one line per set line, a word can
/// never be broken: a line that wrapped would need a line more than the
/// label allows, so SwiftUI shrinks the words instead.
///
/// The words are drawn with `Text(verbatim:)`: callers pass text that is
/// already localized (`String(localized:)`) or a person's own words, which
/// are never translated. The icon is decorative and hidden from VoiceOver,
/// so a control's accessibility label is exactly its visible words, which is
/// also what Voice Control users say.
struct FittedLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight

    let title: String
    let systemImage: String?
    let font: LabelFont
    let alignment: TextAlignment

    init(_ title: String, systemImage: String? = nil, font: LabelFont, alignment: TextAlignment = .center) {
        self.title = title
        self.systemImage = systemImage
        self.font = font
        self.alignment = alignment
    }

    var body: some View {
        GeometryReader { proxy in
            let font = measured
            let steps = LabelFont.steps(downFrom: dynamicTypeSize)
            let choice = font.choice(for: title, systemImage: systemImage, steps: steps, size: proxy.size)
            let chosen = steps[choice.step]
            let iconRoom = choice.showsIcon ? systemImage.map { font.iconAdvance($0, at: chosen) } ?? 0 : 0
            let lines = isOneWord ? [title] : font.lines(title, width: proxy.size.width - iconRoom, at: chosen)
            label(showingIcon: choice.showsIcon, lines: lines, smallestScale: smallestScale(steps))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: frameAlignment)
        }
    }

    private func label(showingIcon: Bool, lines: [String], smallestScale: CGFloat) -> some View {
        let font = measured
        return HStack(spacing: font.iconSpacing(at: dynamicTypeSize)) {
            // The icon shows only at the person's own size (`WordFit`).
            if showingIcon, let systemImage {
                Image(systemName: systemImage)
                    // Exactly the width WordFit measured, and never taller
                    // than a line of the words, so the icon only ever takes
                    // the room it was measured for.
                    .frame(
                        width: font.iconWidth(systemImage, at: dynamicTypeSize),
                        height: font.lineHeight(at: dynamicTypeSize)
                    )
                    .accessibilityHidden(true)
            }
            Text(verbatim: lines.joined(separator: "\n"))
                .multilineTextAlignment(alignment)
                // One line per set line. A single word that cannot fit even
                // at the default size is cut short with an ellipsis rather
                // than broken in two; the starter library has none
                // (`StarterLabelFitTests`).
                .lineLimit(max(lines.count, 1))
                .minimumScaleFactor(smallestScale)
                // The words without the line breaks, for VoiceOver, Voice
                // Control and the UI tests.
                .accessibilityLabel(Text(verbatim: title))
        }
        .font(font.font)
    }

    /// The default size's share of the person's own: SwiftUI never shrinks
    /// the words below the default size.
    private func smallestScale(_ steps: [DynamicTypeSize]) -> CGFloat {
        let own = font.pointSize(at: dynamicTypeSize)
        guard own > 0, let smallest = steps.last else { return 1 }
        return min(1, font.pointSize(at: smallest) / own)
    }

    /// The font measured as drawn, heavier when Bold Text is on.
    private var measured: LabelFont {
        font.legible(legibilityWeight)
    }

    private var isOneWord: Bool {
        WordFit.words(in: title).count == 1
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}

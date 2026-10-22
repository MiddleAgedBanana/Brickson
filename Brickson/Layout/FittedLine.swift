import SwiftUI

/// One line of passive text with a decorative icon, such as Home's status
/// line, that keeps to one line by the same steps as `FittedLabel`: the
/// person's text size with its icon, then without it, then each of Apple's
/// smaller text sizes, never below the default size, measured against the
/// width it is given (`LabelFont.lineChoice`).
///
/// If even the default size is too wide, the text wraps between words at that
/// size instead of shrinking further. Like `FittedLabel`, it is the same view
/// whichever step is chosen.
struct FittedLine: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight

    let text: String
    let systemImage: String
    let font: LabelFont
    /// The width the line is laid out in.
    let width: CGFloat

    var body: some View {
        // Measured at the weight drawn, heavier when Bold Text is on.
        let font = self.font.legible(legibilityWeight)
        let steps = LabelFont.steps(downFrom: dynamicTypeSize)
        let choice = font.lineChoice(for: text, systemImage: systemImage, steps: steps, width: width)
        let size = steps[choice.step]
        HStack(spacing: font.iconSpacing(at: size)) {
            if choice.showsIcon {
                Image(systemName: systemImage)
                    .frame(width: font.iconWidth(systemImage, at: size), height: font.lineHeight(at: size))
                    .accessibilityHidden(true)
            }
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(font.font)
        .textSize(size)
        .frame(width: width, alignment: .leading)
    }
}

import SwiftUI

/// One line of passive text with a decorative icon, such as Home's status
/// line, that keeps to one line by the same steps as `FittedLabel`: the
/// person's text size with its icon, then without it, then each of Apple's
/// smaller text sizes, never below the default size. SwiftUI's
/// `ViewThatFits` measures each step's width.
///
/// If even the default size is too wide, the text wraps between words at that
/// size instead of shrinking further.
struct FittedLine: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let text: String
    let systemImage: String
    let font: LabelFont

    var body: some View {
        let steps = LabelFont.steps(downFrom: dynamicTypeSize)
        ViewThatFits(in: .horizontal) {
            line(showingIcon: true, at: steps[0])
            ForEach(steps, id: \.self) { step in
                line(showingIcon: false, at: step)
                    // The smallest size reports no width of its own, so it
                    // is chosen when nothing else fits, and then wraps.
                    .frame(idealWidth: step == steps.last ? 0 : nil, alignment: .leading)
            }
        }
    }

    private func line(showingIcon: Bool, at size: DynamicTypeSize) -> some View {
        HStack(spacing: font.iconSpacing(at: size)) {
            if showingIcon {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(verbatim: text)
        }
        .font(font.font)
        .textSize(size, from: dynamicTypeSize)
    }
}

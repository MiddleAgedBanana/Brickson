import SwiftUI

/// A control's label that fills the space its control gives it and fits
/// itself: the person's text size with its icon when that fits, then without
/// the icon, then each of Apple's smaller text sizes in turn, never below the
/// default size (`WordFit`).
///
/// `WordFit` rules out every size at which a word would not fit the width,
/// and SwiftUI's `ViewThatFits` then picks the first remaining size whose
/// height fits, measured by SwiftUI itself. The smallest size is drawn even
/// when it does not fit, because nothing smaller is allowed: Home's sizes are
/// chosen so the starter library always fits (`StarterLabelFitTests`).
///
/// The words are drawn with `Text(verbatim:)`: callers pass text that is
/// already localized (`String(localized:)`) or a person's own words, which
/// are never translated. The icon is decorative and hidden from VoiceOver,
/// so a control's accessibility label is exactly its visible words, which is
/// also what Voice Control users say.
struct FittedLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            let steps = LabelFont.steps(downFrom: dynamicTypeSize)
            let choices = font.choices(for: title, systemImage: systemImage, steps: steps, width: proxy.size.width)
            // A single word stays on one line, so SwiftUI also checks its
            // width as drawn: the icon SwiftUI draws can be wider than the
            // one UIKit measured, and a word that does not fit beside it
            // would be cut short. Words that wrap are checked by height only.
            ViewThatFits(in: isOneWord ? [.horizontal, .vertical] : .vertical) {
                ForEach(choices, id: \.self) { choice in
                    let isLast = choice == choices.last
                    label(showingIcon: choice.showsIcon, at: steps[choice.step])
                        // The last choice is the smallest size allowed. It
                        // reports no size of its own, so it is chosen when
                        // nothing else fits rather than leaving the choice to
                        // ViewThatFits.
                        .frame(idealWidth: isLast && isOneWord ? 0 : nil, idealHeight: isLast ? 0 : nil)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: frameAlignment)
        }
    }

    private func label(showingIcon: Bool, at size: DynamicTypeSize) -> some View {
        HStack(spacing: font.iconSpacing(at: size)) {
            if showingIcon, let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(verbatim: title)
                .multilineTextAlignment(alignment)
                // A single word that cannot fit even at the default size is
                // cut short with an ellipsis rather than broken in two. The
                // starter library has none (`StarterLabelFitTests`).
                .lineLimit(isOneWord ? 1 : nil)
        }
        .font(font.font)
        .textSize(size, from: dynamicTypeSize)
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

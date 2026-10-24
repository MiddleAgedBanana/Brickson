import SwiftUI

/// The look of every control on Home: a measured fill with white words, a
/// rounded rectangle, and a narrow, known margin around the label.
///
/// It replaces `.borderedProminent` on Home for two measured failures
/// (docs/DECISIONS.md, "Home version 0 is a stand-in"): that style's own
/// margins left too little width in a phone's three-column phrase grid for
/// the starter words at their default size, so they would have broken; and
/// its dimmed disabled look fails Apple's contrast audit, as Again's did.
///
/// What it draws in each state, and with Show Borders, is `HomeButtonLook`:
///
/// - Enabled: white words on `fill`. Every fill carries white text at 4.5:1
///   or better (`PaletteTests`).
/// - Disabled: the same words in primary ink on the screen with a
///   primary-ink border, unfilled, so it reads as off and stays readable.
/// - Selected (a category, or Emergency while its phrases show): an inner
///   ring, a few points inside the edge.
/// - Pressed: a primary-ink ring inside the edge, with the words and fill
///   unchanged. Fading would lighten the fill under the words below 4.5:1,
///   and shrinking would draw them below their default size.
/// - Show Borders on: a primary-ink border at every control's edge, a wider
///   pressed ring, and the selection ring in the screen's colour.
///
/// Every ring is black or white and clears 3:1 on every fill in every
/// appearance (`PaletteTests.everyRingInkStandsOutFromEveryFill`), and every
/// ring is drawn inside the frame, so no state or setting moves a control.
/// A pointer (a trackpad, AssistiveTouch, head or eye tracking) highlights
/// the control it rests on, so a person can see what a dwell will choose.
struct HomeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityShowBorders) private var showsBorders
    @Environment(\.colorScheme) private var colorScheme

    let fill: Color
    /// Shown with an inner ring as well as the caller's check mark, so the
    /// selection never depends on colour alone, even where the label had to
    /// drop its icon to fit.
    var isSelected = false
    /// The room beside the label: the usual inset, or the wider one of a
    /// control that shows selected (`HomeLayout.selectableSideInset`).
    var sideInset = HomeLayout.labelInset.horizontal

    /// Small enough that the label inset (`HomeLayout.labelInset`) stays
    /// clear of the curve.
    static let cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        let look = HomeButtonLook(
            isEnabled: isEnabled,
            isSelected: isSelected,
            isPressed: configuration.isPressed,
            showsBorders: showsBorders
        )
        configuration.label
            // Room between the label and the edge. Small on purpose: the label
            // fits itself to what is left (`FittedLabel`).
            .padding(.horizontal, sideInset)
            .padding(.vertical, HomeLayout.labelInset.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(look.isFilled ? Color.white : Color.primary)
            .background(look.isFilled ? fill : Color.clear, in: shape)
            .overlay {
                // In order, each over the ones before.
                ZStack {
                    ForEach(look.rings.indices, id: \.self) { index in
                        let ring = look.rings[index]
                        shape.inset(by: ring.inset).strokeBorder(color(of: ring.ink), lineWidth: ring.width)
                    }
                }
            }
            .contentShape(shape)
            .contentShape(.hoverEffect, shape)
            .hoverEffect(.highlight)
    }

    /// The colour `HomeButtonLook` measures for `ink` in this appearance.
    private func color(of ink: HomeButtonLook.Ink) -> Color {
        ink.isWhite(inDarkMode: colorScheme == .dark) ? .white : .black
    }
}

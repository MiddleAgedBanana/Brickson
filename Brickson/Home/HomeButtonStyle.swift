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
/// - Enabled: white words on `fill`. Every fill carries white text at 4.5:1
///   or better (`PaletteTests`).
/// - Disabled: the same words in primary ink on the screen with a
///   primary-ink border, unfilled, so it reads as off and stays readable.
/// - Selected (a category, or Emergency while its phrases show): an inner
///   white ring, a few points inside the edge.
/// - Pressed: a primary-ink ring inside the edge, with the words and fill
///   unchanged. Fading would lighten the fill under the words below 4.5:1,
///   and shrinking would draw them below their default size. The ring
///   clears 3:1 on every fill in every appearance
///   (`PaletteTests.pressedRingStandsOutFromEveryFill`).
/// - A pointer (a trackpad, AssistiveTouch, head or eye tracking) highlights
///   the control it rests on, so a person can see what a dwell will choose.
struct HomeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let fill: Color
    /// Shown with an inner white ring as well as the caller's check mark,
    /// so the selection never depends on colour alone, even where the label
    /// had to drop its icon to fit. White clears 4.5:1 on every fill.
    var isSelected = false

    /// Small enough that the label inset (`HomeShape.labelInset`) stays clear
    /// of the curve.
    static let cornerRadius: CGFloat = 12
    static let selectionInset: CGFloat = 2

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        configuration.label
            // Room between the label and the edge. Small on purpose: the label
            // fits itself to what is left (`FittedLabel`).
            .padding(.horizontal, HomeShape.labelInset.horizontal)
            .padding(.vertical, HomeShape.labelInset.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(isEnabled ? Color.white : Color.primary)
            .background(isEnabled ? fill : Color.clear, in: shape)
            .overlay {
                if isSelected && isEnabled {
                    shape.inset(by: Self.selectionInset).strokeBorder(Color.white, lineWidth: 3)
                }
            }
            .overlay {
                if !isEnabled {
                    shape.strokeBorder(Color.primary, lineWidth: 2)
                } else if configuration.isPressed {
                    shape.strokeBorder(Color.primary, lineWidth: 3)
                }
            }
            .contentShape(shape)
            .contentShape(.hoverEffect, shape)
            .hoverEffect(.highlight)
    }
}

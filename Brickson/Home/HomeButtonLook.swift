import Foundation

/// What a Home control draws around its words in each state: whether it is
/// filled, and the rings inside its edge. Plain logic, tested without a
/// screen (`HomeButtonLookTests`); `HomeButtonStyle` draws it, and
/// `PaletteTests` measures every ink against every fill.
///
/// Every ring is drawn inside the control's frame, so no state and no
/// setting moves or resizes a control, and none reaches the words
/// (`maximumDepth`).
///
/// - Off: unfilled, with a primary-ink border.
/// - Selected: a ring a few points inside the edge.
/// - Pressed: a primary-ink ring at the edge, never a fade or a shrink.
/// - Show Borders (`accessibilityShowBorders`): a primary-ink border at the
///   edge of every control, which stands out from the screen far more than
///   a fill's own edge does (3.5:1 on black). The pressed ring is then
///   twice the border's width, and the selection ring takes the screen's
///   ink, so pressed, selected and neither still look different in both
///   appearances: in dark mode, primary ink and the usual selection ring
///   are both white (docs/DECISIONS.md, "The Large Content Viewer and Show
///   Borders on Home").
nonisolated struct HomeButtonLook: Equatable, Sendable {
    /// The colours a ring is drawn in, each black or white.
    /// `PaletteTests` measures each against every fill in light and dark
    /// mode, with and without Increase Contrast, and checks that primary
    /// ink and the screen's ink are the system colours they stand for.
    enum Ink: CaseIterable, Equatable, Sendable {
        /// The system's primary ink, its label colour: black in light mode,
        /// white in dark. A control that is off shows its words in it.
        case primary
        /// White in both appearances.
        case white
        /// The colour of the screen behind Home, the opposite of primary
        /// ink: white in light mode, black in dark.
        case screen

        /// Whether this ink is white in dark mode (or, when false, in
        /// light mode). Every other ink is black.
        func isWhite(inDarkMode darkMode: Bool) -> Bool {
            switch self {
            case .primary: darkMode
            case .white: true
            case .screen: !darkMode
            }
        }
    }

    /// A ring drawn inside the control's edge.
    struct Ring: Equatable, Sendable {
        let ink: Ink
        /// How far inside the edge the ring starts.
        let inset: CGFloat
        let width: CGFloat

        /// How far inside the edge the ring ends.
        var depth: CGFloat { inset + width }
    }

    /// The border of a control that is off, and of every control with Show
    /// Borders on.
    static let borderWidth: CGFloat = 2
    /// The pressed ring with Show Borders off.
    static let pressedWidth: CGFloat = 3
    /// The pressed ring with Show Borders on: twice the border, so a press
    /// still shows.
    static let pressedWidthWithBorders: CGFloat = 2 * borderWidth
    static let selectionInset: CGFloat = 2
    static let selectionWidth: CGFloat = 3
    /// The deepest any ring may reach: the label inset, plus half the room
    /// `WordFit` keeps beside a label's widest line, so no ring ever covers
    /// a word.
    static let maximumDepth = HomeShape.labelInset.horizontal + WordFit.widthSlack / 2

    /// Whether the control's fill is drawn. A control that is off is not
    /// filled: its words are primary ink on the screen.
    let isFilled: Bool
    /// The rings, drawn in order, each over the ones before.
    let rings: [Ring]

    init(isEnabled: Bool, isSelected: Bool, isPressed: Bool, showsBorders: Bool) {
        guard isEnabled else {
            // Bordered with or without Show Borders, and never selected or
            // pressed while off.
            isFilled = false
            rings = [Ring(ink: .primary, inset: 0, width: Self.borderWidth)]
            return
        }
        var rings: [Ring] = []
        if showsBorders {
            rings.append(Ring(ink: .primary, inset: 0, width: Self.borderWidth))
        }
        if isSelected {
            rings.append(Ring(
                ink: showsBorders ? .screen : .white,
                inset: Self.selectionInset,
                width: Self.selectionWidth
            ))
        }
        if isPressed {
            rings.append(Ring(
                ink: .primary,
                inset: 0,
                width: showsBorders ? Self.pressedWidthWithBorders : Self.pressedWidth
            ))
        }
        isFilled = true
        self.rings = rings
    }

    /// The ink showing `depth` points inside the edge: the last ring drawn
    /// there, or nil where the fill (or, on a control that is off, the
    /// screen) shows.
    func ink(atDepth depth: CGFloat) -> Ink? {
        rings.last { $0.inset <= depth && depth < $0.depth }?.ink
    }
}

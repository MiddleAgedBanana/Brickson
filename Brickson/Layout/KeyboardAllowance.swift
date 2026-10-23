import Foundation

/// The room Home keeps at the bottom of its window for Apple's software
/// keyboard, worked out from the window's size alone. Plain logic, tested
/// without a screen.
///
/// Typing is a state of Home: the keyboard covers Home's lower part, and
/// everything a person must reach while typing (the message, Emergency,
/// Get Attention, Yes, No, Speak and the way back) sits in a band above it,
/// which the keyboard never reaches and which never moves when it appears
/// (docs/DECISIONS.md, "Typing is a state of Home"). An app cannot ask how
/// tall the keyboard will be before it appears, so the band's limit has to
/// come from what Home already knows: the window's size. Never the device:
/// a window is all the layout is given (AGENTS.md, *Layout on every device
/// and window*).
///
/// The rule. A window is one of three shapes, and each shape has a
/// reference: the tallest keyboard measured on a window of that shape, and
/// the height of that window (`Reference`). A window no taller than its
/// shape's reference window keeps room for the whole reference keyboard,
/// because a shorter window has not been seen to bring a shorter keyboard
/// (Display Zoom took the 13-inch iPad's landscape window from 1032 to 774
/// points tall, and its keyboard stayed 498 points tall). A taller window
/// keeps room for a keyboard grown in proportion to its height. Text size
/// is not an input: the keyboard measured the same at the default and the
/// largest text size.
///
/// What it does not cover yet, because nothing has measured it: an iPad
/// window smaller than its screen (Stage Manager, Slide Over, windowed
/// apps), where the keyboard follows the screen, not the window; the
/// floating and split iPad keyboards; a keyboard in another language; and
/// the iPhone Duo's inner display. Those are device check 6 in
/// docs/log/2026-10-21-typing-foundation.md. Keyboards from other apps
/// never appear in Brickson (`BricksonAppDelegate`), so the measured
/// keyboards are the only ones the band meets.
///
/// `KeyboardAllowanceTests` holds every measured keyboard as a row and
/// checks that each fits; `KeyboardProbeTests` measures CI's windows again
/// on every UI run and fails if the live keyboard reaches higher than this
/// allows, or if Home's safety row reaches lower. The UI tests compile
/// this file too, so they work it out the same way.
nonisolated struct KeyboardAllowance: Equatable, Sendable {
    /// How far up from the window's bottom Apple's keyboard may reach, in
    /// points, rounded up to a whole point. Never more than the window.
    let height: CGFloat
    /// The window's height less `height`: in points from the window's top,
    /// the lowest a control in the band may reach.
    let bandLimit: CGFloat

    init(windowSize: CGSize) {
        let windowHeight = max(0, windowSize.height)
        let reference = Reference.forWindow(windowSize)
        let inProportion = reference.keyboardHeight * windowHeight / reference.windowHeight
        height = min(windowHeight, max(reference.keyboardHeight, inProportion).rounded(.up))
        bandLimit = windowHeight - height
    }

    /// The tallest keyboard measured on a window of one shape, and the
    /// height of the window it was measured on. Simulator measurements with
    /// the full software keyboard (US English, predictions on), from
    /// `KeyboardProbeTests` on CI and from the reference app; each is a row
    /// in `KeyboardAllowanceTests`. Measure again with each new iOS.
    struct Reference: Equatable, Sendable {
        let keyboardHeight: CGFloat
        let windowHeight: CGFloat

        /// Windows wider than they are tall. Measured on a 13-inch iPad in
        /// landscape, Full Screen (1376 × 1032, iOS 26.5 and 27.0); the same
        /// iPad with Display Zoom set to Larger Text (1032 × 774) had a
        /// keyboard just as tall.
        static let wide = Reference(keyboardHeight: 498, windowHeight: 1032)
        /// Windows at least as tall as they are wide and at least
        /// `narrowWidth` wide. Measured on a 13-inch iPad in portrait, Full
        /// Screen (1032 × 1376, iOS 26.5 and 27.0).
        static let tall = Reference(keyboardHeight: 403, windowHeight: 1376)
        /// Windows at least as tall as they are wide and narrower than
        /// `narrowWidth`. Measured on an iPhone 17 Pro in portrait
        /// (402 × 874, iOS 27.0).
        static let narrow = Reference(keyboardHeight: 328, windowHeight: 874)

        /// The reference for a window of this size.
        static func forWindow(_ size: CGSize) -> Reference {
            if size.width > size.height { return .wide }
            return size.width < KeyboardAllowance.narrowWidth ? .narrow : .tall
        }
    }

    /// Below this width, a window at least as tall as it is wide takes the
    /// narrow reference. It lies between the widest window an iPhone gives
    /// an app in portrait (440 points) and the narrowest full screen an iPad
    /// gives one (744 points), so each full-screen window takes the keyboard
    /// measured on a screen like its own; it chooses by width, never by
    /// device.
    static let narrowWidth: CGFloat = 600
}

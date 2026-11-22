#if DEBUG
import SwiftUI

/// What the design review sheet shows (`DesignReviewScreen`), as plain
/// values: every colour token, every step of the spacing scale, each kind
/// of corner, and Home's and Settings' controls in each of their states.
/// Debug builds only, like the screen.
///
/// The sheet is built from these lists, and these lists from the app's own
/// (`Palette.fills`, `Spacing.steps`, `CornerRule.Kind`), so a token or a
/// step added to the app shows on the sheet, and `DesignReviewTests` fails
/// if one is left out. Every specimen has an accessibility identifier, so
/// the capture script (`scripts/design-review/`) finds each one's frame and
/// measures its pixels.
enum DesignReviewCatalogue {
    /// A colour role: the fill's colour set, the word the sheet writes on
    /// it, and the symbol a Home control of that role shows.
    struct Role: Equatable, Sendable {
        let asset: String
        let name: String
        let systemImage: String
    }

    /// One role for each of `Palette`'s fills, in `Palette.fills`' order.
    static let roles: [Role] = [
        Role(asset: "AccentColor", name: "Phrase", systemImage: "text.bubble.fill"),
        Role(asset: "ControlFill", name: "Control", systemImage: "square.grid.2x2.fill"),
        Role(asset: "EmergencyFill", name: "Emergency", systemImage: "exclamationmark.triangle.fill"),
        Role(asset: "AttentionFill", name: "Get Attention", systemImage: "bell.fill"),
        Role(asset: "StopFill", name: "Stop", systemImage: "bell.slash.fill"),
    ]

    /// The states a Home control draws (`HomeButtonLook`). The sheet shows
    /// the first three as they are; the capture script holds a touch on
    /// each `pressed` specimen while it takes the screenshot, so the
    /// pressed look is the real one, never drawn.
    enum State: String, CaseIterable, Sendable {
        case on
        case selected
        case off
        case pressed
    }

    /// The states Settings' rows draw (`SettingsRowButtonStyle`): the
    /// system's bordered prominent button, and the look drawn over it while
    /// it is off.
    static let settingsStates: [State] = [.on, .off]

    /// The fills Settings' rows are drawn in today (`settingsRowStyle`).
    static let settingsRoles: [Role] = roles.filter { ["ControlFill", "AccentColor"].contains($0.asset) }

    /// A kind of corner, with the name the sheet and its identifiers use.
    struct Corner: Equatable, Sendable {
        let name: String
        let kind: CornerRule.Kind
    }

    /// The three kinds of corner (docs/DECISIONS.md, "Concentric corners"):
    /// Home's fixed corner today, a capsule, and a concentric corner with
    /// the app's minimum.
    static let corners: [Corner] = [
        Corner(name: "fixed", kind: .fixed(CornerRule.minimum)),
        Corner(name: "capsule", kind: .capsule),
        Corner(name: "concentric", kind: .concentric(minimum: CornerRule.minimum)),
    ]

    /// The container the concentric specimen sits in, and how far in: as
    /// `CornerShapesTests` draws it, so the inner corner measures 30.
    static let containerRadius: CGFloat = 40
    static let containerInset: CGFloat = 10

    /// The steps of the spacing scale, smallest first.
    static let spacing: [CGFloat] = Spacing.steps

    /// A neutral phrase for the phrase tile specimens, in the length of the
    /// starter library's longer ones.
    static let tileWords = "Could you open the window?"

    // MARK: - Identifiers

    static let readout = "review.readout"

    static func colour(_ role: Role) -> String { "review.colour.\(role.asset)" }
    static let primaryInk = "review.ink.primary"
    static let statusInk = "review.ink.status"
    static func spacing(_ step: CGFloat) -> String { "review.spacing.\(Int(step))" }
    static func corner(_ corner: Corner) -> String { "review.corner.\(corner.name)" }
    static func control(_ role: Role, _ state: State) -> String { "review.control.\(role.asset).\(state.rawValue)" }
    static func tile(_ role: Role) -> String { "review.tile.\(role.asset)" }
    static func settingsRow(_ role: Role, _ state: State) -> String { "review.settings.\(role.asset).\(state.rawValue)" }

    /// Every specimen's identifier, in the order the sheet shows them.
    static var identifiers: [String] {
        roles.map(colour)
            + [primaryInk, statusInk]
            + spacing.map(spacing)
            + corners.map(corner)
            + roles.flatMap { role in State.allCases.map { control(role, $0) } }
            + [tile(roles[0]), tile(roles[2])]
            + settingsRoles.flatMap { role in settingsStates.map { settingsRow(role, $0) } }
    }
}

/// The settings the app received, as the one line the sheet prints at its
/// top, in `name=value` words the capture script reads back
/// (`scripts/design-review/`), so a capture taken while a setting had not
/// reached the app is refused rather than saved under that setting's name.
struct DesignReviewReadoutLine: Equatable {
    var dark = false
    var increasedContrast = false
    var reduceTransparency = false
    var showBorders = false
    var differentiateWithoutColour = false
    var boldText = false
    var textSize = DynamicTypeSize.large
    var active = true
    var window = CGSize.zero

    var text: String {
        [
            "scheme=" + (dark ? "dark" : "light"),
            "contrast=" + (increasedContrast ? "increased" : "standard"),
            "transparency=" + (reduceTransparency ? "reduced" : "standard"),
            "borders=" + onOff(showBorders),
            "differentiate=" + onOff(differentiateWithoutColour),
            "bold=" + onOff(boldText),
            "text=" + Self.name(of: textSize),
            "window=" + (active ? "active" : "inactive"),
            "space=\(Int(window.width.rounded()))x\(Int(window.height.rounded()))",
        ].joined(separator: " ")
    }

    private func onOff(_ value: Bool) -> String { value ? "on" : "off" }

    /// Apple's name for each text size, the way Settings and Xcode's
    /// Environment Overrides shorten them.
    static func name(of size: DynamicTypeSize) -> String {
        switch size {
        case .xSmall: "xSmall"
        case .small: "small"
        case .medium: "medium"
        case .large: "large"
        case .xLarge: "xLarge"
        case .xxLarge: "xxLarge"
        case .xxxLarge: "xxxLarge"
        case .accessibility1: "AX1"
        case .accessibility2: "AX2"
        case .accessibility3: "AX3"
        case .accessibility4: "AX4"
        case .accessibility5: "AX5"
        @unknown default: "unknown"
        }
    }
}
#endif

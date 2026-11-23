import CoreGraphics

/// Brickson's spacing scale: the gaps between views, and the margins and
/// insets around them, are these steps or are worked out from them
/// (docs/DECISIONS.md, "One spacing scale"). Views and the layout engines
/// read the steps by name, so the same room is the same number everywhere,
/// and a later look can change a step in one place.
///
/// The steps are the values the app already drew, on a two-point grid:
/// moving the app onto them changed no frame. They are points, not a
/// device's pixels, and nothing here depends on the device, the window or
/// the orientation.
///
/// A step stays the same at every text size. The words, and the controls
/// that hold them, grow with the person's text size (the layout engine
/// measures one line of each label at that size); a gap is room for a
/// finger, a pointer or a look to land between two targets, and that does
/// not depend on the size of the words. The one spacing that grows with the
/// words is a label's gap between its icon and its words, a share of the
/// font's size (`LabelFont.iconSpacing(at:)`).
///
/// Off the scale on purpose, each with its reason in that entry: Eye
/// Tracking's gap between controls (`HomeLayout.Profile.controlSpacing`), a
/// physical size held at the densest screen like the profile's floors; and
/// the inset of a dimmed Settings row's words (`SettingsRowButtonStyle`),
/// which is the system button's own. Distances that are not room between
/// views are not steps either: the margins the dwell checks keep between a
/// look and a control, measuring slack, and the widths and insets of
/// borders and rings.
nonisolated enum Spacing {
    /// 2 points: between a line and the smaller line under it.
    static let xxxSmall: CGFloat = 2
    /// 4 points: between a message and its status line, and beside a
    /// label's words inside a Home control.
    static let xxSmall: CGFloat = 4
    /// 6 points: above and below a label's words inside a Home control, and
    /// around the words of Home's message field.
    static let xSmall: CGFloat = 6
    /// 8 points: touch's gap between controls, Home's top and bottom
    /// margins, and between lines of a list.
    static let small: CGFloat = 8
    /// 12 points: touch's gap between Home's regions, the switch and head
    /// gap between controls, and inside a card or a field.
    static let medium: CGFloat = 12
    /// 16 points: Home's side margins, Settings' gutter and its gap between
    /// rows.
    static let large: CGFloat = 16
    /// 24 points: above a group that starts a new part of a screen.
    static let xLarge: CGFloat = 24

    /// Every step, smallest first.
    static let steps: [CGFloat] = [xxxSmall, xxSmall, xSmall, small, medium, large, xLarge]
}

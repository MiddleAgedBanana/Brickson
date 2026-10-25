import Foundation

/// Where a Settings screen sits in the window: its navigation bar, and its
/// content as it shows unscrolled, from the top of its first view to the
/// foot of what shows without scrolling. Plain logic, tested without a
/// screen; `SettingsScreen` gives it what it measures, and the root's
/// Family Setup row is placed from it (`SettingsRowPlace`).
///
/// Every Settings screen is a page of the cover's navigation stack, which
/// starts under the safety bar. The stack's frame in the window comes from
/// the cover (`SettingsView`); what the navigation bar takes at its top
/// comes from the screen's own safe area, which is what the system keeps
/// for the bar. Nothing here names a device or assumes the bar's height.
nonisolated struct SettingsScreenFrames: Equatable, Sendable {
    /// The navigation bar, in the window: the top of the stack, as tall as
    /// the safe area the screen keeps for it.
    let navigationBar: CGRect
    /// The content, in the window.
    let content: CGRect

    /// - Parameters:
    ///   - stack: the navigation stack's frame, in the window.
    ///   - safeArea: what the screen keeps at each edge of the stack: the
    ///     navigation bar at the top.
    ///   - gutter: the room between the screen's edges and its content
    ///     (`SettingsMetrics.gutter`).
    init(stack: CGRect, safeArea: HomeLayout.Insets, gutter: CGFloat) {
        navigationBar = CGRect(x: stack.minX, y: stack.minY, width: stack.width, height: safeArea.top)
        content = CGRect(
            x: stack.minX + safeArea.leading + gutter,
            y: stack.minY + safeArea.top + gutter,
            width: max(0, stack.width - safeArea.leading - safeArea.trailing - 2 * gutter),
            height: max(0, stack.height - safeArea.top - safeArea.bottom - 2 * gutter)
        )
    }
}

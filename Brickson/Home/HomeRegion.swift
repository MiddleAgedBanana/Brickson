/// Home's regions, in the order VoiceOver, Switch Control and Full Keyboard
/// Access reach them: Yes, No, Emergency and Get Attention first, because
/// every step a switch scan spends before them is waiting time, then Again;
/// then the message, Phrases and Type; then Stop while the alarm sounds,
/// the categories and Settings; then the phrases (docs/DECISIONS.md,
/// "Home's scan order and names", "Settings on Home", "Get Attention and
/// Stop on Home" and "Typing on Home").
///
/// Each region is an accessibility container, so its controls are reached
/// together, one region after another, and Switch Control can offer it as
/// a group. The order is fixed: it never depends on Home's state, the
/// library or use (invariant 8). The regions are C, A, B and D of "Home's
/// slot plan", which stand top to bottom as A, C, B, D.
nonisolated enum HomeRegion: CaseIterable, Sendable {
    /// C: Yes, No, Emergency, Get Attention and Again.
    case safety
    /// A: the message and its status line (the field while typing), then
    /// Phrases and Type beside them.
    case message
    /// B: Stop's well, the category buttons and Settings.
    case categories
    /// D: the phrase grid.
    case phrases

    /// Names the region for the UI tests. Never spoken.
    var identifier: String {
        switch self {
        case .safety: "homeRegion.safety"
        case .message: "homeRegion.message"
        case .categories: "homeRegion.categories"
        case .phrases: "homeRegion.phrases"
        }
    }

    /// For `accessibilitySortPriority`: higher is reached first. SwiftUI
    /// otherwise orders elements by where they are, which would put the
    /// message, above the quick controls, first. Every region is above zero,
    /// the default, so the library warnings, outside the regions, come last.
    var sortPriority: Double {
        switch self {
        case .safety: 4
        case .message: 3
        case .categories: 2
        case .phrases: 1
        }
    }

    /// For `accessibilitySortPriority` inside a region: a control given it
    /// is reached after the region's others, which keep the default of
    /// zero. Again comes after Yes, No, Emergency and Get Attention, though
    /// it sits at the leading end of their second row, and Settings after
    /// the category buttons, though it stands level with their first row.
    static let lastInRegion: Double = -1

    /// For `accessibilitySortPriority` in the categories region: Stop is
    /// reached first, then the first category, then the others in order.
    /// In the band those two stand one above the other at its leading end,
    /// and the others start level with Stop, so by where they are the first
    /// category would come after the last (`HomeLayout.CategoryArrangement`).
    /// In the safety row, Yes and then No are reached first, then Emergency
    /// and Get Attention, wherever they stand: on regular widths Emergency
    /// leads the row (docs/DECISIONS.md, "Typing on Home").
    static let firstInRegion: Double = 2
    static let secondInRegion: Double = 1
}

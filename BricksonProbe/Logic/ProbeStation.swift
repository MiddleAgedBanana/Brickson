import Foundation

/// The probe's test stations, in the order docs/EXPERIMENTS.md runs them.
/// Each names the study questions it serves, so a result can be filed
/// under its question. The probe is a measuring tool, never part of
/// Brickson (docs/DECISIONS.md, "A probe app for the experiments, kept out
/// of Brickson").
nonisolated enum ProbeStation: String, CaseIterable, Identifiable, Hashable, Sendable {
    case snap
    case rings
    case landing
    case changes
    case groups
    case look
    case speech
    case screen
    case status
    case typing
    case busy
    case ruler
    case styles

    var id: String { rawValue }

    /// The name on the probe's list and in the log.
    var title: String {
        switch self {
        case .snap: "Snap"
        case .rings: "Rings"
        case .landing: "Landing"
        case .changes: "Changes"
        case .groups: "Groups"
        case .look: "Look"
        case .speech: "Speech"
        case .screen: "Screen"
        case .status: "Status"
        case .typing: "Typing"
        case .busy: "Busy"
        case .ruler: "Ruler"
        case .styles: "Styles"
        }
    }

    /// One line for the list: what the station holds.
    var summary: String {
        switch self {
        case .snap:
            "An enabled, a dimmed and a hidden button, plain and interactive words, an empty place, custom actions, a toggle, a segmented picker and a round shape, well apart."
        case .rings:
            "One button in the middle of rings drawn 25 to 300 points out, to see how far Snap to Item reaches."
        case .landing:
            "A button whose activation point sits over another button, and buttons with hover effects."
        case .changes:
            "After a countdown, a button becomes available, appears, changes its words, moves and disappears."
        case .groups:
            "Two regions of three buttons, contained or not, with sort priority on or off, to read scan and focus order."
        case .look:
            "Twelve tiles for a steady look: same or varied sizes, rounded or capsule, with or without motion and hover."
        case .speech:
            "The app's own speech, with VoiceOver, Voice Control and Siri listening, and every word report logged."
        case .screen:
            "Keeping the screen on, Low Power Mode, heat and shake to undo, with a running clock to film."
        case .status:
            "Every public value an app can read about the accessibility features in use, logged when it changes."
        case .typing:
            "A text field that shows exactly what the keyboard delivered, spaces and Return included."
        case .busy:
            "A button that holds the app busy for three seconds, and a counter to press during it."
        case .ruler:
            "A grid drawn every 20 points, numbered every 100, with no controls: for corners, edges and pointer drift."
        case .styles:
            "Apple's own button styles, sizes, shapes, toggles and glass, enabled and dimmed, on one scrolling page."
        }
    }

    /// The study questions the station serves, as docs/EXPERIMENTS.md
    /// names them.
    var questions: [String] {
        switch self {
        case .snap: ["A-1", "A-1a", "A-3", "A-7", "A-9", "A-11", "A-21", "A-30", "D-03", "D-04"]
        case .rings: ["A-2", "A-3", "B-4", "G-21"]
        case .landing: ["A-8", "A-28", "D-18"]
        case .changes: ["A-6", "A-42", "A-44", "G-01"]
        case .groups: ["A-10", "A-45"]
        case .look: ["D-10", "D-11", "D-18", "D-19", "G-21"]
        case .speech: ["A-16", "A-17", "A-18", "A-31", "A-40", "D-07", "D-25", "G-30", "G-32"]
        case .screen: ["A-22", "A-23", "A-32", "A-39", "G-25", "G-26"]
        case .status: ["A-27"]
        case .typing: ["A-34"]
        case .busy: ["A-43"]
        case .ruler: ["A-12", "A-29", "A-36", "B-4"]
        case .styles: ["A-1a", "A-33", "D-01", "D-02", "D-13", "D-16", "D-17", "D-20", "D-21", "D-24"]
        }
    }
}

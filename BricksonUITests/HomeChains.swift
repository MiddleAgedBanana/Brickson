import Foundation

/// Home for the chain engine: its states, what each control does in each,
/// and the state each leads to (`ChainEngine`). Positions never change with
/// state (invariant 8), so one set of frames serves every state; Stop shows
/// only while the alarm sounds, and its well is a place a look can rest on
/// while it is empty.
///
/// The names are the ones the UI tests read Home's controls by
/// (`screenControls(in:)`): the accessibility identifier where a control
/// has one, its label otherwise. The unit tests build it from the layout's
/// frames (`HomeShape.slotFrames`), the UI tests from the running app's.
///
/// Test infrastructure only, compiled into both test targets like
/// `ChainEngine`.
nonisolated enum HomeChains {
    static let yes = "Yes"
    static let no = "No"
    static let emergency = "Emergency"
    static let again = "Again"
    static let getAttention = "getAttention"
    static let stop = "stopAlert"
    static let settings = "settings"
    static let phraseTile = "phraseTile"
    /// Stop's well while the alarm is quiet: empty, and hidden from
    /// accessibility, but a look can rest on it.
    static let emptyWell = "Stop's empty well"
    /// The state Home's Settings leads to: Settings' first screen.
    static let settingsRoot = "Settings"

    /// One of Home's states: what changes what its controls do.
    struct State: Hashable, Sendable {
        /// Whether anything has been spoken. Again is disabled before.
        var hasSpoken = false
        /// The everyday category showing, by its place in the library, or
        /// nil while the emergency phrases show. Choosing the one showing
        /// again does nothing.
        var showing: Int? = 0
        /// Whether the alarm sounds. Stop shows in its well, and Get
        /// Attention does nothing more: it never stops the alarm.
        var sounding = false
    }

    /// Home's controls' frames.
    struct Frames {
        var yes: CGRect
        var no: CGRect
        var emergency: CGRect
        var again: CGRect
        var getAttention: CGRect
        /// Stop's well, which Stop fills while the alarm sounds. Nil where
        /// it is not known: the running app hides the empty well from
        /// accessibility, so a screen read while the alarm is quiet has no
        /// frame for it, and the map then has no Stop and no empty well.
        var stop: CGRect?
        var settings: CGRect
        /// The everyday categories, in the library's order.
        var categories: [(name: String, frame: CGRect)]
        /// The phrase tiles of the category showing. Every state gets
        /// them: a tile that another category would not have is one more
        /// control that speaks, so it can only add hazards, never hide one.
        var tiles: [CGRect] = []
    }

    /// Home's frames from controls read off the running app by name
    /// (`screenControls(in:)`), with the everyday categories named in
    /// the library's order. Nil when a control of the safety row,
    /// Settings or a category is missing.
    static func frames(from controls: [(name: String, frame: CGRect)], categories: [String]) -> Frames? {
        func frame(_ name: String) -> CGRect? {
            controls.first { $0.name == name }?.frame
        }
        guard let yes = frame(Self.yes), let no = frame(Self.no), let emergency = frame(Self.emergency),
              let again = frame(Self.again), let getAttention = frame(Self.getAttention), let settings = frame(Self.settings)
        else { return nil }
        var found: [(name: String, frame: CGRect)] = []
        for name in categories {
            guard let category = frame(name) else { return nil }
            found.append((name, category))
        }
        return Frames(
            yes: yes, no: no, emergency: emergency, again: again, getAttention: getAttention,
            stop: frame(Self.stop), settings: settings, categories: found,
            tiles: controls.filter { $0.name == Self.phraseTile }.map(\.frame)
        )
    }

    /// Where Home starts: nothing spoken, the first everyday category
    /// showing, the alarm quiet.
    static func atRest(categoryCount: Int) -> State {
        State(hasSpoken: false, showing: categoryCount > 0 ? 0 : nil, sounding: false)
    }

    /// Every state, for a library of `categoryCount` everyday categories.
    static func states(categoryCount: Int) -> [State] {
        let showing: [Int?] = [nil] + (0..<categoryCount).map { Optional($0) }
        return [false, true].flatMap { hasSpoken in
            showing.flatMap { shown in
                [false, true].map { State(hasSpoken: hasSpoken, showing: shown, sounding: $0) }
            }
        }
    }

    /// A state's name, as findings print it.
    static func name(of state: State, categories: [String]) -> String {
        let shown = state.showing.map { categories.indices.contains($0) ? categories[$0] : "category \($0 + 1)" } ?? "Emergency"
        return "Home, \(state.hasSpoken ? "spoken" : "nothing spoken"), \(shown) showing, \(state.sounding ? "sounding" : "quiet")"
    }

    /// Home's map: every state, each control with what it does there.
    /// `resting` adds places a look can rest on in every state (the
    /// message, read from the running app); Stop's empty well is one in
    /// every quiet state.
    static func map(_ frames: Frames, resting extra: [(name: String, frame: CGRect)] = []) -> ChainMap {
        let names = frames.categories.map(\.name)
        var states: [String: [ChainControl]] = [:]
        var resting: [String: [(name: String, frame: CGRect)]] = [:]
        for state in Self.states(categoryCount: names.count) {
            func after(_ change: (inout State) -> Void) -> String {
                var next = state
                change(&next)
                return name(of: next, categories: names)
            }
            let spoken = after { $0.hasSpoken = true }
            var controls = [
                ChainControl(yes, frames.yes, .speaks, leadsTo: spoken),
                ChainControl(no, frames.no, .speaks, leadsTo: spoken),
                state.showing == nil
                    ? ChainControl(emergency, frames.emergency, .nothing)
                    : ChainControl(emergency, frames.emergency, .navigates, leadsTo: after { $0.showing = nil }),
                state.hasSpoken
                    ? ChainControl(again, frames.again, .speaks)
                    : ChainControl(again, frames.again, .nothing),
                state.sounding
                    ? ChainControl(getAttention, frames.getAttention, .nothing)
                    : ChainControl(getAttention, frames.getAttention, .alarms, leadsTo: after { $0.sounding = true }),
                ChainControl(settings, frames.settings, .navigates, leadsTo: settingsRoot),
            ]
            for (index, category) in frames.categories.enumerated() {
                controls.append(
                    state.showing == index
                        ? ChainControl(category.name, category.frame, .nothing)
                        : ChainControl(category.name, category.frame, .navigates, leadsTo: after { $0.showing = index })
                )
            }
            if state.sounding, let well = frames.stop {
                controls.append(ChainControl(stop, well, .alarms, leadsTo: after { $0.sounding = false }))
            }
            controls += frames.tiles.map { ChainControl(phraseTile, $0, .speaks, leadsTo: spoken) }
            let here = name(of: state, categories: names)
            states[here] = controls
            let well = state.sounding ? nil : frames.stop.map { (name: emptyWell, frame: $0) }
            resting[here] = (well.map { [$0] } ?? []) + extra
        }
        return ChainMap(states: states, resting: resting)
    }
}

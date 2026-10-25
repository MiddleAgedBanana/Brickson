import Foundation

/// Home for the chain engine: its states, what each control does in each,
/// and the state each leads to (`ChainEngine`). Positions never change with
/// state (invariant 8), so one set of frames serves every state; Stop shows
/// only while the alarm sounds, and its well is a place a look can rest on
/// while it is empty.
///
/// Typing is a state of Home (docs/DECISIONS.md, "Typing on Home"): the
/// field takes the message's frame, Speak Again's, Clear and Put Back two
/// category cells (`HomeLayout.typingCells`), and the other categories
/// and the phrase tiles are dimmed in place, so each does nothing. Type
/// chooses it, and Phrases, Emergency and Settings leave it; Phrases and
/// Type each do nothing while their own mode is on. The draft is kept
/// while browsing, so every state has one: empty, written (Speak and Clear
/// act), or cleared (Put Back acts).
///
/// The names are the ones the UI tests read Home's controls by
/// (`screenControls(in:)`): the accessibility identifier where a control
/// has one, its label otherwise. The unit tests build it from the layout's
/// frames (`HomeLayout.frame(_:)`), the UI tests from the running app's.
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
    static let phrases = "phrases"
    static let type = "type"
    /// Again's slot while typing.
    static let speak = "Speak"
    static let clear = "clear"
    static let putBack = "putBack"
    /// The typing field, in the message's frame while typing.
    static let field = "messageField"
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
        /// Whether Home is typing.
        var typing = false
        /// The draft, kept while browsing too.
        var draft = Draft.empty
    }

    /// What the draft holds, as far as Home's controls care.
    enum Draft: Hashable, Sendable, CaseIterable {
        /// Nothing to speak, clear or put back.
        case empty
        /// Words: Speak and Clear act on them.
        case written
        /// Nothing, just after Clear: Put Back brings the words back.
        case cleared
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
        /// The phrase tiles of the category showing, in every state: they
        /// speak while browsing and are dimmed while typing. Browsing, a
        /// tile that another category would not have is one more control
        /// that speaks, so it can only add hazards. Typing, it is one more
        /// place a look rests on that does nothing, so it can hide one: the
        /// empty cells a shorter category leaves (docs/DECISIONS.md,
        /// "Typing on Home", *Open: by centre, dimmed phrases border Clear
        /// and Put Back*).
        var tiles: [CGRect] = []
        /// Phrases and Type, beside the message. Nil where they are not
        /// known; the map then has neither.
        var phrases: CGRect?
        var type: CGRect?
        /// What typing shows, where it is known. Nil: the map has no typing
        /// states, and a chain that chooses Type ends there.
        var typing: Typing?
    }

    /// Home's frames while typing.
    struct Typing {
        /// The field, in the message's frame.
        var field: CGRect
        /// The category cells Clear and Put Back take, by the categories'
        /// order (`HomeLayout.typingCells`).
        var clearCell: Int
        var putBackCell: Int
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
            tiles: controls.filter { $0.name == Self.phraseTile }.map(\.frame),
            phrases: frame(Self.phrases), type: frame(Self.type)
        )
    }

    /// Where Home starts: nothing spoken, the first everyday category
    /// showing, the alarm quiet.
    static func atRest(categoryCount: Int) -> State {
        State(hasSpoken: false, showing: categoryCount > 0 ? 0 : nil, sounding: false)
    }

    /// Every state, for a library of `categoryCount` everyday categories:
    /// with `typing`, typing and browsing with each draft; without it,
    /// browsing with an empty draft.
    static func states(categoryCount: Int, typing: Bool = false) -> [State] {
        let showing: [Int?] = [nil] + (0..<categoryCount).map { Optional($0) }
        let modes = typing ? [false, true] : [false]
        let drafts = typing ? Draft.allCases : [.empty]
        return [false, true].flatMap { hasSpoken in
            showing.flatMap { shown in
                [false, true].flatMap { sounding in
                    modes.flatMap { isTyping in
                        drafts.map { State(hasSpoken: hasSpoken, showing: shown, sounding: sounding, typing: isTyping, draft: $0) }
                    }
                }
            }
        }
    }

    /// A state's name, as findings print it. Browsing with an empty draft
    /// has no more words than before typing came to Home.
    static func name(of state: State, categories: [String]) -> String {
        let shown = state.showing.map { categories.indices.contains($0) ? categories[$0] : "category \($0 + 1)" } ?? "Emergency"
        var name = "Home, \(state.hasSpoken ? "spoken" : "nothing spoken"), \(shown) showing, \(state.sounding ? "sounding" : "quiet")"
        if state.typing { name += ", typing" }
        switch state.draft {
        case .empty: break
        case .written: name += ", draft written"
        case .cleared: name += ", draft cleared"
        }
        return name
    }

    /// Home's map: every state, each control with what it does there.
    /// `resting` adds places a look can rest on in every state (the
    /// message, read from the running app); Stop's empty well is one in
    /// every quiet state.
    static func map(_ frames: Frames, resting extra: [(name: String, frame: CGRect)] = []) -> ChainMap {
        let names = frames.categories.map(\.name)
        var states: [String: [ChainControl]] = [:]
        var resting: [String: [(name: String, frame: CGRect)]] = [:]
        for state in Self.states(categoryCount: names.count, typing: frames.typing != nil) {
            func after(_ change: (inout State) -> Void) -> String {
                var next = state
                change(&next)
                return name(of: next, categories: names)
            }
            let spoken = after { $0.hasSpoken = true }
            let typing = state.typing ? frames.typing : nil
            var controls = [
                ChainControl(yes, frames.yes, .speaks, leadsTo: spoken),
                ChainControl(no, frames.no, .speaks, leadsTo: spoken),
                // While typing, Emergency leaves typing for the emergency
                // phrases, even when they were showing before.
                state.showing == nil && typing == nil
                    ? ChainControl(emergency, frames.emergency, .nothing)
                    : ChainControl(emergency, frames.emergency, .navigates, leadsTo: after { $0.showing = nil; $0.typing = false }),
                typing == nil
                    ? (state.hasSpoken ? ChainControl(again, frames.again, .speaks) : ChainControl(again, frames.again, .nothing))
                    : (state.draft == .written ? ChainControl(speak, frames.again, .speaks, leadsTo: spoken) : ChainControl(speak, frames.again, .nothing)),
                state.sounding
                    ? ChainControl(getAttention, frames.getAttention, .nothing)
                    : ChainControl(getAttention, frames.getAttention, .alarms, leadsTo: after { $0.sounding = true }),
                ChainControl(settings, frames.settings, .navigates, leadsTo: settingsRoot),
            ]
            for (index, category) in frames.categories.enumerated() {
                if let typing, index == typing.clearCell {
                    controls.append(
                        state.draft == .written
                            ? ChainControl(clear, category.frame, .changesData, leadsTo: after { $0.draft = .cleared })
                            : ChainControl(clear, category.frame, .nothing)
                    )
                } else if let typing, index == typing.putBackCell {
                    controls.append(
                        state.draft == .cleared
                            ? ChainControl(putBack, category.frame, .changesData, leadsTo: after { $0.draft = .written })
                            : ChainControl(putBack, category.frame, .nothing)
                    )
                } else if typing != nil {
                    // Dimmed while typing: choosing one would leave typing
                    // and turn the dimmed tiles under a look resting there
                    // into phrases that speak.
                    controls.append(ChainControl(category.name, category.frame, .nothing))
                } else {
                    controls.append(
                        state.showing == index
                            ? ChainControl(category.name, category.frame, .nothing)
                            : ChainControl(category.name, category.frame, .navigates, leadsTo: after { $0.showing = index })
                    )
                }
            }
            if state.sounding, let well = frames.stop {
                controls.append(ChainControl(stop, well, .alarms, leadsTo: after { $0.sounding = false }))
            }
            if let phrases = frames.phrases {
                controls.append(
                    state.typing
                        ? ChainControl(Self.phrases, phrases, .navigates, leadsTo: after { $0.typing = false })
                        : ChainControl(Self.phrases, phrases, .nothing)
                )
            }
            if let type = frames.type {
                controls.append(
                    state.typing
                        ? ChainControl(Self.type, type, .nothing)
                        : ChainControl(Self.type, type, .navigates, leadsTo: after { $0.typing = true })
                )
            }
            if let typing {
                controls.append(ChainControl(field, typing.field, .nothing))
                controls += frames.tiles.map { ChainControl(phraseTile, $0, .nothing) }
            } else {
                controls += frames.tiles.map { ChainControl(phraseTile, $0, .speaks, leadsTo: spoken) }
            }
            let here = name(of: state, categories: names)
            states[here] = controls
            let well = state.sounding ? nil : frames.stop.map { (name: emptyWell, frame: $0) }
            resting[here] = (well.map { [$0] } ?? []) + extra
        }
        return ChainMap(states: states, resting: resting)
    }
}

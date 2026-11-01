import Foundation

/// The one chain engine for dwell safety (AGENTS.md, invariant 10;
/// docs/LESSONS.md, "Score chains, not single hops" and "One chain engine,
/// not five scripts"; docs/DECISIONS.md, "One chain engine for dwell
/// safety").
///
/// Under AssistiveTouch Dwell, head tracking, Eye Tracking and Switch
/// Control's auto-select, an activation can repeat while the pointer stays
/// put. So what a person chooses can be followed by whatever is nearest
/// that spot once the screen has changed, then by whatever is nearest after
/// that, and so on. The engine takes a screen's controls in each of its
/// states (a `ChainMap`), with what each control does there and which state
/// it leads to, and follows every such chain from a start, under each rule a
/// pointer might pick a target by and each place it might rest:
///
/// - **Rules.** Snap to Item moves the pointer to the item "closest to where
///   you're looking" (Apple's Eye Tracking guide). Whether that means the
///   nearest centre or the nearest edge is a device check (docs/HANDOFF.md,
///   *Checks that need a real device*), so both are scored, and every
///   control within half a point of the nearest counts as a tie and is
///   followed.
/// - **Pointers.** After an activation the pointer either stays on the
///   control just activated, at its centre, where Snap to Item drew it, or
///   goes back to where the person is looking. Both are followed.
///
/// Test infrastructure only, never in the app. It is compiled into the UI
/// tests, which feed it frames read from the running app, and into the unit
/// tests, which feed it the layout's own frames and test the engine itself
/// (`ChainEngineTests`). It is plain Foundation, so its tests also run on a
/// Linux Swift toolchain.
nonisolated enum ChainEngine {
    /// Controls within this distance of the nearest are a tie, and each is
    /// followed, so a tie never hides a hazard.
    static let tie: CGFloat = 0.5

    /// Activations a chain is followed for, the one the person chose
    /// included. Settings' longest known chain takes four: Home's Settings,
    /// then Family Setup, Set Up Step by Step and an answer
    /// (docs/HANDOFF.md, *Known gaps*).
    static let depth = 6

    /// The items nearest `point` by `rule`, with every item within `tie` of
    /// the nearest, in their original order.
    static func nearest<Item>(
        to point: CGPoint, among items: [Item], by rule: NearestRule, frame: (Item) -> CGRect
    ) -> [Item] {
        nearest(to: point, among: items.map(frame), by: rule).map { items[$0] }
    }

    /// The places in `frames` of the frames nearest `point` by `rule`, with
    /// every one within `tie` of the nearest, in their original order.
    /// Plain loops over frames: the sweeps ask this millions of times, in
    /// test builds that are not optimised.
    static func nearest(to point: CGPoint, among frames: [CGRect], by rule: NearestRule) -> [Int] {
        guard !frames.isEmpty else { return [] }
        var distances: [CGFloat] = []
        distances.reserveCapacity(frames.count)
        for frame in frames {
            distances.append(rule.distance(from: point, to: frame))
        }
        // As `min()` finds it: the first, then any that is less.
        var closest = distances[0]
        for distance in distances where distance < closest {
            closest = distance
        }
        var found: [Int] = []
        for index in distances.indices where distances[index] - closest < tie {
            found.append(index)
        }
        return found
    }

    /// What a held activation meets at `point` among `frames`, by nearest
    /// centre and by nearest edge, ties counted.
    static func nearest<ID: Hashable>(
        to point: CGPoint, among frames: [ID: CGRect]
    ) -> (byCentre: Set<ID>, byEdge: Set<ID>) {
        let items = Array(frames)
        return (
            Set(nearest(to: point, among: items, by: .centre, frame: \.value).map(\.key)),
            Set(nearest(to: point, among: items, by: .edge, frame: \.value).map(\.key))
        )
    }

    /// Points spread across `frame`: `columns` steps across its width and
    /// `rows` down its height, half a point in from its edges, so each lies
    /// inside it.
    static func points(across frame: CGRect, columns: Int = 8, rows: Int = 4) -> [CGPoint] {
        var points: [CGPoint] = []
        for column in 0...columns {
            for row in 0...rows {
                points.append(CGPoint(
                    x: frame.minX + 0.5 + (frame.width - 1) * CGFloat(column) / CGFloat(max(columns, 1)),
                    y: frame.minY + 0.5 + (frame.height - 1) * CGFloat(row) / CGFloat(max(rows, 1))
                ))
            }
        }
        return points
    }

    /// The looks `ChainMap.everyStart()` takes across a frame: its centre,
    /// its corners and the middles of its edges, half a point in.
    static func looks(across frame: CGRect) -> [CGPoint] {
        points(across: frame, columns: 2, rows: 2)
    }
}

/// What activating a control does. The first four are hazards when a held
/// activation meets them unasked (docs/LESSONS.md, "Anything that moves
/// things is a hazard"); the last two are not, and a chain goes on through
/// them.
nonisolated enum ChainEffect: String, CaseIterable, Sendable {
    /// Says something aloud: Yes, No, Again, a phrase, a voice sample.
    case speaks
    /// Starts or stops the Get Attention alarm.
    case alarms
    /// Changes what is stored: a setting, a setup answer, an edit.
    case changesData
    /// Moves controls: reordering, merging, a text size, entering edit mode.
    case movesThings
    /// Only shows something else: another screen, or which phrases show.
    case navigates
    /// Nothing at all: a disabled control, or one already in the state it
    /// sets.
    case nothing

    var isHazard: Bool {
        switch self {
        case .speaks, .alarms, .changesData, .movesThings: true
        case .navigates, .nothing: false
        }
    }
}

/// How a pointer picks the control nearest a point.
nonisolated enum NearestRule: String, CaseIterable, Sendable {
    /// The control whose centre is nearest.
    case centre
    /// The control whose nearest edge is nearest, zero inside it.
    case edge

    func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        switch self {
        case .centre:
            return hypot(point.x - frame.midX, point.y - frame.midY)
        case .edge:
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            return hypot(dx, dy)
        }
    }
}

/// Where the pointer rests after an activation.
nonisolated enum ChainPointer: String, CaseIterable, Sendable {
    /// On the control just activated, at its centre.
    case staysOnControl
    /// Back where the person is looking: the start's look, for the whole
    /// chain.
    case returnsToLook
}

/// A control in one state, as the engine sees it.
nonisolated struct ChainControl: Equatable, Sendable, CustomStringConvertible {
    /// Its accessibility identifier, or its label where it has none, as the
    /// UI tests read it.
    let name: String
    let frame: CGRect
    /// What activating it does in this state.
    let effect: ChainEffect
    /// The state activating it leads to; nil when the state stays the same.
    let leadsTo: String?

    init(_ name: String, _ frame: CGRect, _ effect: ChainEffect, leadsTo: String? = nil) {
        self.name = name
        self.frame = frame
        self.effect = effect
        self.leadsTo = leadsTo
    }

    var centre: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
    var description: String { "\(name) (\(effect.rawValue))" }
}

/// Where a chain starts.
nonisolated struct ChainStart: Equatable, Sendable, CustomStringConvertible {
    let state: String
    /// Where the person is looking.
    let look: CGPoint
    /// The control the person chose by looking there. Its activation is the
    /// one they asked for; every later one is not.
    let chosen: ChainControl?
    /// For a look resting on something that is not a control (words, an
    /// empty well), its name. Every activation from such a look is unasked,
    /// the first included: reading is pointing.
    let restingOn: String?

    /// The person chooses `control`, looking at `look` (its centre unless
    /// given). Under a rule that does not pick `control` at `look`, the
    /// start does not exist and has no chains.
    static func choosing(_ control: ChainControl, in state: String, lookingAt look: CGPoint? = nil) -> ChainStart {
        ChainStart(state: state, look: look ?? control.centre, chosen: control, restingOn: nil)
    }

    /// The person's look rests at `look`, on `region`, which is not a
    /// control.
    static func resting(at look: CGPoint, on region: String, in state: String) -> ChainStart {
        ChainStart(state: state, look: look, chosen: nil, restingOn: region)
    }

    /// Where it starts, without the exact look, so the chains from one
    /// control or region read as one finding.
    var summary: String {
        if let chosen { return "choosing \(chosen.name)" }
        return "resting on \(restingOn ?? "the screen")"
    }

    var description: String { "\(summary) in \(state), looking at (\(look.x), \(look.y))" }
}

/// One activation in a chain.
nonisolated struct ChainStep: Equatable, Sendable {
    let state: String
    let control: ChainControl
    /// Whether the person asked for it: only a chosen start's first step.
    let asked: Bool
}

/// How a chain ended.
nonisolated enum ChainEnd: Equatable, Sendable, CustomStringConvertible {
    /// An unasked activation that speaks, alarms, changes data or moves
    /// things.
    case hazard
    /// The control met is the one just activated, unchanged, so activating
    /// it again does what it just did: after a choice, the person's own
    /// choice again (a repeat of the phrase still being spoken is absorbed,
    /// `SpokenUtteranceTracker`). A control that turns into another, or
    /// does something else or leads somewhere else in its new state, is
    /// not a repeat.
    case repeats
    /// The state and the pointer came back to where they had been, so
    /// nothing new can happen.
    case settles
    /// The state the last activation leads to is not in the map, so scoring
    /// stops there.
    case leaves(String)
    /// The state holds no control at all.
    case nothingNear
    /// It ran to the depth it was followed for.
    case tooLong

    var description: String {
        switch self {
        case .hazard: "hazard"
        case .repeats: "repeats"
        case .settles: "settles"
        case .leaves(let state): "leaves for \(state)"
        case .nothingNear: "meets nothing"
        case .tooLong: "too long"
        }
    }
}

/// A chain of held activations from one start, under one rule and one
/// pointer.
nonisolated struct Chain: Equatable, Sendable, CustomStringConvertible {
    let start: ChainStart
    let rule: NearestRule
    let pointer: ChainPointer
    let steps: [ChainStep]
    let end: ChainEnd

    /// The unasked activation that made it a hazard.
    var hazard: ChainStep? { end == .hazard ? steps.last : nil }

    /// The chain without its states, exact look, rule or pointer: where it
    /// started and each control it met. Findings are grouped by it.
    var path: String {
        let met = steps.filter { !$0.asked }.map(\.control.description)
        return ([start.summary] + met).joined(separator: " → ")
    }

    var description: String {
        let met = steps.map { "\($0.control) in \($0.state)\($0.asked ? ", chosen" : "")" }
        return "\(start), by \(rule.rawValue), pointer \(pointer.rawValue): \(met.joined(separator: " → ")); \(end)"
    }
}

/// A screen's states, each with its controls, and the places in each where
/// a look can rest on something that is not a control.
nonisolated struct ChainMap: Sendable {
    /// Each state's controls, by the state's name.
    var states: [String: [ChainControl]]
    /// Each state's resting places: words, an empty well, by name.
    var resting: [String: [(name: String, frame: CGRect)]]

    init(states: [String: [ChainControl]], resting: [String: [(name: String, frame: CGRect)]] = [:]) {
        self.states = states
        self.resting = resting
    }

    /// This map with `other`'s states and resting places added, so chains
    /// cross from one screen to the next. A state in both keeps `other`'s.
    func merging(_ other: ChainMap) -> ChainMap {
        ChainMap(
            states: states.merging(other.states) { _, new in new },
            resting: resting.merging(other.resting) { _, new in new }
        )
    }

    /// Starts from every control of every state, chosen with the look at
    /// its centre and at the other points `lookPoints` gives across it, and
    /// from those points across every resting place. In state-name order,
    /// so results read the same on every run.
    func everyStart(lookPoints: (CGRect) -> [CGPoint] = ChainEngine.looks(across:)) -> [ChainStart] {
        states.keys.sorted().flatMap { starts(in: $0, lookPoints: lookPoints) }
    }

    /// `everyStart()`'s starts in `state` alone, in the same order, so a
    /// sweep that scores a few states of a large map builds only theirs.
    func starts(in state: String, lookPoints: (CGRect) -> [CGPoint] = ChainEngine.looks(across:)) -> [ChainStart] {
        var found: [ChainStart] = []
        for control in states[state] ?? [] {
            found.append(.choosing(control, in: state))
            for look in lookPoints(control.frame) where look != control.centre {
                found.append(.choosing(control, in: state, lookingAt: look))
            }
        }
        for region in resting[state] ?? [] {
            for look in lookPoints(region.frame) {
                found.append(.resting(at: look, on: region.name, in: state))
            }
        }
        return found
    }

    /// Every chain from `starts`, under every rule and pointer given.
    /// While the pointer stays on the control, a chosen start's chains do
    /// not depend on where on the control the person looked, so they are
    /// followed from its centre only.
    func chains(
        from starts: [ChainStart],
        rules: [NearestRule] = NearestRule.allCases,
        pointers: [ChainPointer] = ChainPointer.allCases,
        depth: Int = ChainEngine.depth
    ) -> [Chain] {
        chains(from: starts, rules: rules, pointers: pointers, depth: depth, hazardsOnly: false)
    }

    /// The hazards among the chains from `starts`, under both rules and
    /// both pointers. Every chain is followed; only the hazards are kept,
    /// which saves building the rest when many windows are scored.
    func hazards(from starts: [ChainStart], depth: Int = ChainEngine.depth) -> [Chain] {
        chains(from: starts, rules: NearestRule.allCases, pointers: ChainPointer.allCases, depth: depth, hazardsOnly: true)
    }

    private func chains(
        from starts: [ChainStart], rules: [NearestRule], pointers: [ChainPointer], depth: Int, hazardsOnly: Bool
    ) -> [Chain] {
        let compiled = CompiledMap(self)
        var walk = Walk(map: compiled, depth: depth, hazardsOnly: hazardsOnly)
        var previous: (start: ChainStart, place: (state: Int, chosen: Int?)?)?
        for start in starts {
            // `everyStart()` gives each control's starts one after another:
            // where the state and the control are the ones before, so is
            // the place.
            let place: (state: Int, chosen: Int?)?
            if let previous, previous.start.state == start.state, previous.start.chosen == start.chosen {
                place = previous.place
            } else {
                place = compiled.place(of: start)
            }
            previous = (start, place)
            for pointer in pointers {
                if pointer == .staysOnControl, let chosen = start.chosen, start.look != chosen.centre {
                    continue
                }
                for rule in rules {
                    walk.follow(start, at: place, rule: rule, pointer: pointer)
                }
            }
        }
        return walk.found
    }

    /// The chains from `start` under one rule and one pointer: more than
    /// one where a tie branches it. A chosen start has none where the rule
    /// does not pick its control alone at its look: where the rule picks
    /// another, nobody chose it from there, and where it ties, which one
    /// the pointer takes is aiming, not a chain (`ChainEngine.tie`).
    func follow(_ start: ChainStart, rule: NearestRule, pointer: ChainPointer, depth: Int = ChainEngine.depth) -> [Chain] {
        let compiled = CompiledMap(self)
        var walk = Walk(map: compiled, depth: depth, hazardsOnly: false)
        walk.follow(start, at: compiled.place(of: start), rule: rule, pointer: pointer)
        return walk.found
    }
}

/// A map made ready for following: states by number, each control's next
/// state by number, and what the pointer meets at a spot worked out once
/// per arrangement of frames. A screen's states often share their frames
/// and differ only in what the controls do (on Home, every state but those
/// with Stop), so a run asks the same question many times. Each state is
/// made ready the first time a chain needs it: a sweep through Settings
/// merges all of Home's states into its map and reaches few of them.
private nonisolated final class CompiledMap {
    private struct Key: Hashable {
        let layout: Int
        let x: Double
        let y: Double
    }

    let names: [String]
    let controls: [[ChainControl]]
    private let numbers: [String: Int]
    /// For each state made ready, each control's next state by number; nil
    /// when the map does not hold it.
    private var targets: [[Int?]]
    /// For each state made ready, its controls' places in its list by name.
    private var byName: [[String: [Int]]]
    /// For each state, its arrangement of frames by number, shared by the
    /// states with the same frames; -1 until the state is made ready.
    private var layouts: [Int]
    private var arrangements: [[CGRect]] = []
    /// What the pointer meets, one table for each rule.
    private var byCentre: [Key: [Int]] = [:]
    private var byEdge: [Key: [Int]] = [:]

    init(_ map: ChainMap) {
        let names = map.states.keys.sorted()
        self.names = names
        numbers = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })
        controls = names.map { map.states[$0] ?? [] }
        targets = Array(repeating: [], count: names.count)
        byName = Array(repeating: [:], count: names.count)
        layouts = Array(repeating: -1, count: names.count)
    }

    /// Makes `state` ready, once.
    private func ready(_ state: Int) {
        guard layouts[state] < 0 else { return }
        let list = controls[state]
        targets[state] = list.map { control in
            guard let name = control.leadsTo else { return state }
            return numbers[name]
        }
        byName[state] = Dictionary(grouping: list.indices, by: { list[$0].name })
        let frames = list.map(\.frame)
        if let known = arrangements.firstIndex(of: frames) {
            layouts[state] = known
        } else {
            arrangements.append(frames)
            layouts[state] = arrangements.count - 1
        }
    }

    /// Where `start` is: its state by number, nil when the map does not
    /// hold it; and for a chosen start, its control's place in that
    /// state's list, nil when the state does not hold that control.
    func place(of start: ChainStart) -> (state: Int, chosen: Int?)? {
        guard let state = numbers[start.state] else { return nil }
        guard let chosen = start.chosen else { return (state, nil) }
        ready(state)
        let index = byName[state][chosen.name]?.first { controls[state][$0] == chosen }
        return (state, index)
    }

    func target(of control: Int, in state: Int) -> Int? {
        ready(state)
        return targets[state][control]
    }

    /// The controls of `state` nearest `spot` by `rule`, by their place in
    /// the state's list, ties included.
    func met(at spot: CGPoint, in state: Int, by rule: NearestRule) -> [Int] {
        ready(state)
        let layout = layouts[state]
        let key = Key(layout: layout, x: Double(spot.x), y: Double(spot.y))
        switch rule {
        case .centre:
            if let known = byCentre[key] { return known }
        case .edge:
            if let known = byEdge[key] { return known }
        }
        let found = ChainEngine.nearest(to: spot, among: arrangements[layout], by: rule)
        switch rule {
        case .centre: byCentre[key] = found
        case .edge: byEdge[key] = found
        }
        return found
    }
}

/// Following starts one at a time, under one rule and one pointer each,
/// depth first: the steps and the spots met so far grow as a chain goes on
/// and shrink as it comes back to follow the next branch of a tie. One walk
/// follows every start of a run and keeps the chains found in order.
private nonisolated struct Walk {
    /// One activation of the chain so far, made into a `ChainStep` only
    /// for a chain that is kept.
    struct Step {
        let state: Int
        let control: Int
        let asked: Bool
    }

    /// A state and spot the chain has met a control at.
    struct Visit {
        let state: Int
        let spot: CGPoint
    }

    let map: CompiledMap
    let depth: Int
    /// Whether to keep only the chains that end in a hazard.
    let hazardsOnly: Bool
    /// The start, rule and pointer being followed.
    var start = ChainStart(state: "", look: .zero, chosen: nil, restingOn: nil)
    var rule = NearestRule.centre
    var pointer = ChainPointer.staysOnControl
    /// The chain so far: its first `stepCount` steps. Kept in place and
    /// overwritten rather than appended and removed, which costs more in
    /// test builds that are not optimised.
    var steps: [Step]
    var stepCount = 0
    /// Each state and spot the chain has met a control at, the first
    /// `visitCount`, the latest last: coming back to one, nothing new can
    /// happen.
    var visited: [Visit]
    var visitCount = 0
    var found: [Chain] = []

    init(map: CompiledMap, depth: Int, hazardsOnly: Bool) {
        self.map = map
        self.depth = depth
        self.hazardsOnly = hazardsOnly
        // A chain has at most `depth` steps, and one more spot met than
        // steps followed on from: the start's.
        steps = Array(repeating: Step(state: 0, control: 0, asked: false), count: max(depth, 1))
        visited = Array(repeating: Visit(state: 0, spot: .zero), count: max(depth, 1) + 1)
    }

    /// Follows `start`, at `place` in the map (`CompiledMap.place(of:)`),
    /// under `rule` and `pointer`.
    mutating func follow(_ start: ChainStart, at place: (state: Int, chosen: Int?)?, rule: NearestRule, pointer: ChainPointer) {
        self.start = start
        self.rule = rule
        self.pointer = pointer
        guard let place else {
            if !hazardsOnly {
                found.append(Chain(start: start, rule: rule, pointer: pointer, steps: [], end: .leaves(start.state)))
            }
            return
        }
        let met = map.met(at: start.look, in: place.state, by: rule)
        visited[0] = Visit(state: place.state, spot: start.look)
        visitCount = 1
        if start.chosen != nil {
            guard let index = place.chosen, met.count == 1, met[0] == index else { return }
            activate(index, in: place.state, asked: true)
        } else if met.isEmpty {
            record(.nothingNear)
        } else {
            for index in met {
                activate(index, in: place.state, asked: false)
            }
        }
    }

    mutating func record(_ end: ChainEnd) {
        if !hazardsOnly || end == .hazard {
            let made = steps[..<stepCount].map { ChainStep(state: map.names[$0.state], control: map.controls[$0.state][$0.control], asked: $0.asked) }
            found.append(Chain(start: start, rule: rule, pointer: pointer, steps: made, end: end))
        }
    }

    /// Activates control `index` of `state`, then follows what the pointer
    /// meets next.
    mutating func activate(_ index: Int, in state: Int, asked: Bool) {
        let control = map.controls[state][index]
        steps[stepCount] = Step(state: state, control: index, asked: asked)
        stepCount += 1
        defer { stepCount -= 1 }
        if !asked && control.effect.isHazard { return record(.hazard) }
        if stepCount >= depth { return record(.tooLong) }
        guard let next = map.target(of: index, in: state) else { return record(.leaves(control.leadsTo ?? "")) }
        let spot = pointer == .staysOnControl ? control.centre : start.look
        for position in 0..<visitCount where visited[position].state == next && visited[position].spot == spot {
            return record(.settles)
        }
        let met = map.met(at: spot, in: next, by: rule)
        if met.isEmpty { return record(.nothingNear) }
        visited[visitCount] = Visit(state: next, spot: spot)
        visitCount += 1
        defer { visitCount -= 1 }
        for other in met {
            if map.controls[next][other] == control {
                record(.repeats)
            } else {
                activate(other, in: next, asked: false)
            }
        }
    }
}

/// The hazards among `chains`, one per path: where a chain started and the
/// controls it met, whatever the state, the exact look, the rule or the
/// pointer, with every rule and pointer that found it and the first chain
/// that did.
nonisolated struct ChainFinding: Equatable, Sendable, CustomStringConvertible {
    let path: String
    /// Each rule and pointer that found it, as "centre, staysOnControl".
    let under: [String]
    let example: Chain

    static func findings(in chains: [Chain]) -> [ChainFinding] {
        var order: [String] = []
        var found: [String: (under: [String], example: Chain)] = [:]
        for chain in chains where chain.end == .hazard {
            let key = "\(chain.rule.rawValue), \(chain.pointer.rawValue)"
            if var existing = found[chain.path] {
                if !existing.under.contains(key) { existing.under.append(key) }
                found[chain.path] = existing
            } else {
                order.append(chain.path)
                found[chain.path] = ([key], chain)
            }
        }
        return order.sorted().compactMap { path in
            found[path].map { ChainFinding(path: path, under: $0.under.sorted(), example: $0.example) }
        }
    }

    var description: String { "\(path) [\(under.joined(separator: "; "))], first: \(example)" }
}

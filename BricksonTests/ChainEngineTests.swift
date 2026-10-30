import Foundation
import Testing
@testable import Brickson

/// The chain engine itself (`ChainEngine`), on small made-up screens, so
/// each rule it follows is pinned before any real screen relies on it. Each
/// test names the change to the engine that would make it fail.
struct ChainEngineTests {
    private static let square = CGSize(width: 40, height: 40)

    private static func frame(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 40, _ height: CGFloat = 40) -> CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: Nearest

    /// Fails if the two rules are swapped or either distance is wrong: a
    /// point inside a wide control's end is nearest that control by its
    /// edge, but nearer a small neighbour's centre.
    @Test func theNearestCentreAndTheNearestEdgeCanDiffer() {
        let wide = (name: "wide", frame: Self.frame(0, 0, 200, 40))
        let small = (name: "small", frame: Self.frame(208, 0, 40, 40))
        let point = CGPoint(x: 195, y: 20)
        #expect(ChainEngine.nearest(to: point, among: [wide, small], by: .centre, frame: \.frame).map(\.name) == ["small"])
        #expect(ChainEngine.nearest(to: point, among: [wide, small], by: .edge, frame: \.frame).map(\.name) == ["wide"])
        let both = ChainEngine.nearest(to: point, among: ["wide": wide.frame, "small": small.frame])
        #expect(both.byCentre == ["small"] && both.byEdge == ["wide"])
    }

    /// Fails if a tie within half a point is dropped, or the tie widens:
    /// two controls 0.4pt apart in distance are both met; 0.6pt apart, only
    /// the nearer.
    @Test func aTieWithinHalfAPointCountsBoth() {
        let left = (name: "left", frame: Self.frame(0, 0))
        let right = (name: "right", frame: Self.frame(80, 0))
        let near = ChainEngine.nearest(to: CGPoint(x: 59.8, y: 20), among: [left, right], by: .centre, frame: \.frame)
        #expect(near.map(\.name) == ["left", "right"])
        let apart = ChainEngine.nearest(to: CGPoint(x: 59.7, y: 20), among: [left, right], by: .centre, frame: \.frame)
        #expect(apart.map(\.name) == ["left"])
    }

    /// Fails if points leave the frame they are spread across, or the grid
    /// loses its corners or its centre.
    @Test func pointsAcrossAFrameStayInsideIt() {
        let frame = Self.frame(10, 20, 101, 41)
        let points = ChainEngine.points(across: frame, columns: 4, rows: 2)
        #expect(points.count == 15)
        #expect(points.allSatisfy { frame.contains($0) })
        #expect(points.contains(CGPoint(x: 10.5, y: 20.5)) && points.contains(CGPoint(x: 110.5, y: 60.5)))
        #expect(points.contains(CGPoint(x: frame.midX, y: frame.midY)))
    }

    // MARK: Chains

    /// Fails if a control that turns into its opposite in place is taken
    /// for a repeat of the one chosen: Start becomes Stop at the same frame,
    /// so a held look stops what it started, by both rules and both
    /// pointers (invariant 10).
    @Test func aControlThatTurnsIntoItsOppositeInPlaceIsAHazard() {
        let spot = Self.frame(0, 0)
        let start = ChainControl("start", spot, .alarms, leadsTo: "sounding")
        let map = ChainMap(states: [
            "quiet": [start],
            "sounding": [ChainControl("stop", spot, .alarms, leadsTo: "quiet")],
        ])
        let chains = map.chains(from: [.choosing(start, in: "quiet")])
        #expect(chains.count == 4)
        #expect(chains.allSatisfy { $0.end == .hazard && $0.hazard?.control.name == "stop" && $0.steps.count == 2 })
    }

    /// Fails if a toggle is taken for a repeat because its name, frame and
    /// effect stay the same: a second activation leads somewhere else, so
    /// it undoes the first.
    @Test func aToggleIsNotARepeat() {
        let spot = Self.frame(0, 0)
        let on = ChainControl("borders", spot, .changesData, leadsTo: "on")
        let map = ChainMap(states: [
            "off": [on],
            "on": [ChainControl("borders", spot, .changesData, leadsTo: "off")],
        ])
        let chains = map.chains(from: [.choosing(on, in: "off")], rules: [.edge], pointers: [.staysOnControl])
        #expect(chains.map(\.end) == [.hazard])
    }

    /// Fails if the person's own choice, met again unchanged, is scored as
    /// a hazard, or if the chain goes on past it: Yes said once is said
    /// again only by a look still held on Yes, and a repeat of the phrase
    /// still being spoken is absorbed (`SpokenUtteranceTracker`).
    @Test func theSameControlUnchangedIsTheOwnChoiceRepeated() {
        let spot = Self.frame(0, 0)
        let yes = ChainControl("Yes", spot, .speaks, leadsTo: "spoken")
        let map = ChainMap(states: ["quiet": [yes], "spoken": [yes]])
        let chains = map.chains(from: [.choosing(yes, in: "quiet")])
        #expect(chains.count == 4)
        #expect(chains.allSatisfy { $0.end == .repeats && $0.steps.count == 1 })
    }

    /// Fails if only the first hop is scored (docs/LESSONS.md, "Score
    /// chains, not single hops"): a screen opens, a row nearest the spot
    /// opens the next, and the row nearest there saves an answer, three
    /// activations after the one chosen. It is found at the engine's
    /// depth, and not when only three activations are followed.
    @Test func chainsAreFollowedPastTheFirstHop() {
        let spot = Self.frame(0, 0)
        let open = ChainControl("open", spot, .navigates, leadsTo: "first")
        let map = ChainMap(states: [
            "home": [open],
            "first": [ChainControl("row", spot, .navigates, leadsTo: "second")],
            "second": [ChainControl("next", Self.frame(0, 2), .navigates, leadsTo: "third")],
            "third": [ChainControl("answer", Self.frame(0, 4), .changesData)],
        ])
        let deep = map.chains(from: [.choosing(open, in: "home")], rules: [.centre], pointers: [.staysOnControl])
        #expect(deep.count == 1)
        #expect(deep.first?.end == .hazard)
        #expect(deep.first?.path == "choosing open → row (navigates) → next (navigates) → answer (changesData)")
        let shallow = map.chains(from: [.choosing(open, in: "home")], rules: [.centre], pointers: [.staysOnControl], depth: 3)
        #expect(shallow.map(\.end) == [.tooLong])
    }

    /// Fails if only one pointer is followed. The chosen control is wide;
    /// the person looked at its leading end. On the next screen a control
    /// that speaks sits under the chosen one's centre, and one that does
    /// nothing under the look: the pointer that stays meets the first, the
    /// one that goes back to the look the second. A second map swaps them.
    @Test func bothPointersAreFollowed() {
        let wide = ChainControl("open", Self.frame(0, 0, 200, 40), .navigates, leadsTo: "next")
        let look = CGPoint(x: 10, y: 20)
        let underCentre = Self.frame(80, 0)
        let underLook = Self.frame(0, 0)
        func ends(speakingAt speaking: CGRect, quietAt quiet: CGRect) -> [ChainPointer: [ChainEnd]] {
            let map = ChainMap(states: [
                "first": [wide],
                "next": [ChainControl("speak", speaking, .speaks), ChainControl("quiet", quiet, .nothing)],
            ])
            var ends: [ChainPointer: [ChainEnd]] = [:]
            for pointer in ChainPointer.allCases {
                ends[pointer] = map.follow(.choosing(wide, in: "first", lookingAt: look), rule: .edge, pointer: pointer).map(\.end)
            }
            return ends
        }
        let one = ends(speakingAt: underCentre, quietAt: underLook)
        #expect(one[.staysOnControl] == [.hazard])
        #expect(one[.returnsToLook] == [.settles])
        let other = ends(speakingAt: underLook, quietAt: underCentre)
        #expect(other[.staysOnControl] == [.settles])
        #expect(other[.returnsToLook] == [.hazard])
    }

    /// Fails if a look resting on words is treated as a choice: every
    /// activation from it is unasked, the first included, so a control
    /// that speaks beside the words is a hazard at once (reading is
    /// pointing).
    @Test func aRestingLookCountsItsFirstActivation() {
        let yes = ChainControl("Yes", Self.frame(0, 60), .speaks, leadsTo: "spoken")
        let map = ChainMap(states: ["home": [yes], "spoken": [yes]], resting: ["home": [("the message", Self.frame(0, 0, 200, 50))]])
        let starts = map.everyStart().filter { $0.restingOn != nil }
        #expect(starts.count == 9)
        let chains = map.chains(from: starts)
        #expect(!chains.isEmpty && chains.allSatisfy { $0.end == .hazard && $0.steps.count == 1 && !$0.steps[0].asked })
        #expect(ChainFinding.findings(in: chains).map(\.path) == ["resting on the message → Yes (speaks)"])
    }

    /// Fails if a chosen start is followed where its rule would have picked
    /// another control: looking at a wide control's end, the nearest centre
    /// is its small neighbour's, so under that rule nobody chose the wide
    /// one from there.
    @Test func aChosenStartExistsOnlyWhereItsRulePicksIt() {
        let wide = ChainControl("wide", Self.frame(0, 0, 200, 40), .navigates, leadsTo: "elsewhere")
        let small = ChainControl("small", Self.frame(208, 0), .nothing)
        let map = ChainMap(states: ["here": [wide, small]])
        let start = ChainStart.choosing(wide, in: "here", lookingAt: CGPoint(x: 195, y: 20))
        #expect(map.follow(start, rule: .centre, pointer: .returnsToLook).isEmpty)
        #expect(map.follow(start, rule: .edge, pointer: .returnsToLook).map(\.end) == [.leaves("elsewhere")])
    }

    /// Fails if a look the rule ties between two controls counts as
    /// choosing one of them: which one the pointer takes there is aiming,
    /// not a chain, so the start has no chains under that rule.
    @Test func aLookTiedBetweenTwoControlsChoosesNeither() {
        let left = ChainControl("left", Self.frame(0, 0), .navigates, leadsTo: "elsewhere")
        let right = ChainControl("right", Self.frame(80, 0), .speaks)
        let map = ChainMap(states: ["here": [left, right]])
        let start = ChainStart.choosing(left, in: "here", lookingAt: CGPoint(x: 59.8, y: 20))
        #expect(map.follow(start, rule: .centre, pointer: .returnsToLook).isEmpty)
        #expect(map.follow(.choosing(left, in: "here", lookingAt: CGPoint(x: 59.4, y: 20)), rule: .centre, pointer: .returnsToLook).map(\.end) == [.leaves("elsewhere")])
    }

    /// Fails if a tie hides a hazard: the spot left after an activation is
    /// as near a control that speaks as one that does nothing, and both are
    /// followed. The one that does nothing, met again unchanged, ends its
    /// branch.
    @Test func aTieBranchesTheChain() {
        let open = ChainControl("open", Self.frame(40, 0), .navigates, leadsTo: "next")
        let map = ChainMap(states: [
            "first": [open],
            "next": [ChainControl("quiet", Self.frame(0, 0), .nothing), ChainControl("speak", Self.frame(80, 0), .speaks)],
        ])
        let chains = map.follow(.choosing(open, in: "first"), rule: .centre, pointer: .staysOnControl)
        #expect(chains.map(\.end) == [.repeats, .hazard])
    }

    /// Fails if a chain into a state the map does not hold is dropped
    /// instead of reported, so a screen nobody scored never reads as safe.
    @Test func leavingTheMapIsReported() {
        let open = ChainControl("open", Self.frame(0, 0), .navigates, leadsTo: "Voice Settings")
        let map = ChainMap(states: ["here": [open]])
        #expect(map.follow(.choosing(open, in: "here"), rule: .edge, pointer: .staysOnControl).map(\.end) == [.leaves("Voice Settings")])
    }

    /// Fails if a chain that comes back to a state and spot it has met a
    /// control at runs on until its depth instead of settling: Back and
    /// Forward under the same spot only take the look between two screens.
    @Test func aLoopSettles() {
        let spot = Self.frame(0, 0)
        let forward = ChainControl("forward", spot, .navigates, leadsTo: "two")
        let map = ChainMap(states: [
            "one": [forward],
            "two": [ChainControl("back", spot, .navigates, leadsTo: "one")],
        ])
        let chains = map.chains(from: [.choosing(forward, in: "one")], rules: [.centre], pointers: [.staysOnControl])
        #expect(chains.map(\.end) == [.settles])
        #expect(chains.first?.steps.map(\.control.name) == ["forward", "back"])
    }

    /// Fails if a control that does nothing in the state it leaves stops a
    /// chain from settling, or is counted as a hazard.
    @Test func aControlThatDoesNothingSettles() {
        let category = ChainControl("Needs", Self.frame(0, 0), .navigates, leadsTo: "Needs showing")
        let map = ChainMap(states: [
            "Basics showing": [category],
            "Needs showing": [ChainControl("Needs", Self.frame(0, 0), .nothing)],
        ])
        let chains = map.chains(from: [.choosing(category, in: "Basics showing")])
        #expect(chains.count == 4)
        #expect(chains.allSatisfy { $0.end == .settles && $0.hazard == nil })
    }

    /// Fails if every control and resting place does not get its starts:
    /// the centre and the points across each.
    @Test func everyStartCoversEveryControlAndRestingPlace() {
        let one = ChainControl("one", Self.frame(0, 0), .nothing)
        let two = ChainControl("two", Self.frame(60, 0), .nothing)
        let map = ChainMap(states: ["a": [one], "b": [two]], resting: ["b": [("words", Self.frame(0, 60))]])
        let starts = map.everyStart()
        #expect(starts.count == 9 + 9 + 9)
        #expect(starts.filter { $0.chosen == one }.count == 9)
        #expect(starts.filter { $0.restingOn == "words" && $0.state == "b" }.count == 9)
    }

    /// Fails if findings stop grouping one path's chains, or lose a rule or
    /// pointer that found it.
    @Test func findingsGroupChainsByPath() {
        let message = ChainMap(
            states: ["home": [ChainControl("Yes", Self.frame(0, 60), .speaks)]],
            resting: ["home": [("the message", Self.frame(0, 0, 40, 50))]]
        )
        let findings = ChainFinding.findings(in: message.chains(from: message.everyStart()))
        #expect(findings.count == 1)
        #expect(findings.first?.under == [
            "centre, returnsToLook", "centre, staysOnControl", "edge, returnsToLook", "edge, staysOnControl",
        ])
    }
}

/// Home's states for the engine (`HomeChains`): what each control does in
/// each, as Home's code does it.
struct HomeChainsTests {
    private static let frames = HomeChains.Frames(
        yes: CGRect(x: 0, y: 0, width: 40, height: 40),
        no: CGRect(x: 48, y: 0, width: 40, height: 40),
        emergency: CGRect(x: 96, y: 0, width: 88, height: 40),
        again: CGRect(x: 0, y: 48, width: 88, height: 40),
        getAttention: CGRect(x: 96, y: 48, width: 88, height: 40),
        stop: CGRect(x: 0, y: 100, width: 40, height: 40),
        settings: CGRect(x: 144, y: 100, width: 40, height: 40),
        categories: [("Basics", CGRect(x: 48, y: 100, width: 40, height: 40)), ("Needs", CGRect(x: 96, y: 100, width: 40, height: 40))]
    )

    private static func controls(_ state: HomeChains.State) -> [String: ChainControl] {
        let map = HomeChains.map(frames)
        let name = HomeChains.name(of: state, categories: ["Basics", "Needs"])
        return Dictionary((map.states[name] ?? []).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Fails if a state goes missing: spoken or not, each category or the
    /// emergency phrases showing, the alarm sounding or quiet.
    @Test func everyStateIsInTheMap() {
        #expect(HomeChains.map(Self.frames).states.count == 2 * 3 * 2)
        #expect(HomeChains.states(categoryCount: 0).count == 4)
    }

    /// Fails if Again speaks before anything has been spoken (it is
    /// disabled then), or stops speaking after.
    @Test func againSpeaksOnlyOnceSomethingHasBeenSpoken() {
        #expect(Self.controls(HomeChains.State())[HomeChains.again]?.effect == .nothing)
        #expect(Self.controls(HomeChains.State(hasSpoken: true))[HomeChains.again]?.effect == .speaks)
    }

    /// Fails if Get Attention does anything while the alarm sounds (it never
    /// stops it), if Stop shows while it is quiet, or if Stop's empty well
    /// stops being a resting place.
    @Test func getAttentionOnlyStartsAndStopOnlyShowsWhileSounding() {
        let quiet = Self.controls(HomeChains.State())
        #expect(quiet[HomeChains.getAttention]?.effect == .alarms)
        #expect(quiet[HomeChains.stop] == nil)
        let sounding = Self.controls(HomeChains.State(sounding: true))
        #expect(sounding[HomeChains.getAttention]?.effect == .nothing)
        #expect(sounding[HomeChains.stop]?.effect == .alarms)
        let map = HomeChains.map(Self.frames)
        let quietName = HomeChains.name(of: HomeChains.State(), categories: ["Basics", "Needs"])
        let soundingName = HomeChains.name(of: HomeChains.State(sounding: true), categories: ["Basics", "Needs"])
        #expect(map.resting[quietName]?.map(\.name) == [HomeChains.emptyWell])
        #expect(map.resting[soundingName]?.isEmpty == true)
    }

    /// Fails if choosing what already shows does anything, or choosing
    /// another category or Emergency does more than navigate.
    @Test func choosingWhatShowsDoesNothing() {
        let basics = Self.controls(HomeChains.State(showing: 0))
        #expect(basics["Basics"]?.effect == .nothing)
        #expect(basics["Needs"]?.effect == .navigates)
        #expect(basics[HomeChains.emergency]?.effect == .navigates)
        let emergency = Self.controls(HomeChains.State(showing: nil))
        #expect(emergency[HomeChains.emergency]?.effect == .nothing)
        #expect(emergency["Basics"]?.effect == .navigates)
        #expect(emergency[HomeChains.settings]?.leadsTo == HomeChains.settingsRoot)
    }
}

extension HomeChainsTests {
    /// Fails if Home's frames read off the running app lose a control, keep
    /// a phrase tile out, or invent Stop's well when the screen has no Stop:
    /// the UI tests build Home's map this way (`SettingsOnHomeTests`).
    @Test func framesComeFromTheRunningAppsControls() throws {
        let read: [(name: String, frame: CGRect)] = [
            (HomeChains.yes, Self.frames.yes), (HomeChains.no, Self.frames.no),
            (HomeChains.emergency, Self.frames.emergency), (HomeChains.again, Self.frames.again),
            (HomeChains.getAttention, Self.frames.getAttention), (HomeChains.settings, Self.frames.settings),
            ("Basics", CGRect(x: 48, y: 100, width: 40, height: 40)), ("Needs", CGRect(x: 96, y: 100, width: 40, height: 40)),
            (HomeChains.phraseTile, CGRect(x: 0, y: 148, width: 88, height: 60)),
            (HomeChains.phraseTile, CGRect(x: 96, y: 148, width: 88, height: 60)),
        ]
        let frames = try #require(HomeChains.frames(from: read, categories: ["Basics", "Needs"]))
        #expect(frames.stop == nil)
        #expect(frames.categories.map(\.name) == ["Basics", "Needs"])
        #expect(frames.tiles.count == 2)
        #expect(HomeChains.frames(from: read, categories: ["Basics", "Needs", "Feelings"]) == nil)

        let map = HomeChains.map(frames)
        let sounding = HomeChains.name(of: HomeChains.State(sounding: true), categories: ["Basics", "Needs"])
        let quiet = HomeChains.name(of: HomeChains.State(), categories: ["Basics", "Needs"])
        #expect(map.states[sounding]?.contains { $0.name == HomeChains.stop } == false)
        #expect(map.resting[quiet]?.isEmpty == true)
        #expect(map.states[quiet]?.filter { $0.name == HomeChains.phraseTile }.allSatisfy { $0.effect == .speaks } == true)
    }
}

/// Typing on Home for the engine (`HomeChains`, docs/DECISIONS.md, "Typing
/// on Home"): what each control does while typing and while browsing with a
/// draft, as Home's code does it.
struct HomeChainsTypingTests {
    private static let names = ["Basics", "Needs", "Feelings", "Conversation"]
    private static let frames = HomeChains.Frames(
        yes: CGRect(x: 0, y: 100, width: 40, height: 40),
        no: CGRect(x: 48, y: 100, width: 40, height: 40),
        emergency: CGRect(x: 96, y: 100, width: 88, height: 40),
        again: CGRect(x: 0, y: 148, width: 88, height: 40),
        getAttention: CGRect(x: 96, y: 148, width: 88, height: 40),
        stop: CGRect(x: 0, y: 200, width: 40, height: 40),
        settings: CGRect(x: 144, y: 248, width: 40, height: 40),
        categories: [
            ("Basics", CGRect(x: 48, y: 200, width: 40, height: 40)), ("Needs", CGRect(x: 96, y: 200, width: 88, height: 40)),
            ("Feelings", CGRect(x: 0, y: 248, width: 40, height: 40)), ("Conversation", CGRect(x: 48, y: 248, width: 88, height: 40)),
        ],
        tiles: [CGRect(x: 0, y: 300, width: 88, height: 60)],
        phrases: CGRect(x: 96, y: 0, width: 88, height: 40),
        type: CGRect(x: 96, y: 48, width: 88, height: 40),
        typing: HomeChains.Typing(field: CGRect(x: 0, y: 0, width: 88, height: 88), clearCell: 1, putBackCell: 3)
    )

    private static func controls(_ state: HomeChains.State) -> [String: ChainControl] {
        let map = HomeChains.map(frames)
        let name = HomeChains.name(of: state, categories: names)
        return Dictionary((map.states[name] ?? []).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func typing(_ draft: HomeChains.Draft = .empty, showing: Int? = 0, hasSpoken: Bool = false) -> HomeChains.State {
        HomeChains.State(hasSpoken: hasSpoken, showing: showing, sounding: false, typing: true, draft: draft)
    }

    /// Fails if a typing state goes missing, or a map without typing's
    /// frames gains states: typing or not, with each draft, on top of
    /// spoken or not, each category or Emergency, and the alarm.
    @Test func typingStatesAreInTheMapOnlyWithTypingsFrames() {
        #expect(HomeChains.map(Self.frames).states.count == 2 * 5 * 2 * 2 * 3)
        var browsing = Self.frames
        browsing.typing = nil
        #expect(HomeChains.map(browsing).states.count == 2 * 5 * 2)
    }

    /// Fails if Speak speaks with nothing to say (it is disabled then), if
    /// it stops speaking a written draft, or if the field does anything.
    @Test func speakSpeaksOnlyAWrittenDraft() {
        #expect(Self.controls(Self.typing(.empty))[HomeChains.speak]?.effect == .nothing)
        #expect(Self.controls(Self.typing(.cleared))[HomeChains.speak]?.effect == .nothing)
        #expect(Self.controls(Self.typing(.written))[HomeChains.speak]?.effect == .speaks)
        #expect(Self.controls(Self.typing(.written))[HomeChains.again] == nil)
        #expect(Self.controls(Self.typing(.written))[HomeChains.field]?.effect == .nothing)
    }

    /// Fails if Clear or Put Back acts when it cannot (each is disabled
    /// then), if either stops changing the draft when it can, or if they
    /// leave their cells.
    @Test func clearAndPutBackActOnlyWhenTheyCan() {
        let written = Self.controls(Self.typing(.written))
        #expect(written[HomeChains.clear]?.effect == .changesData)
        #expect(written[HomeChains.clear]?.leadsTo == HomeChains.name(of: Self.typing(.cleared), categories: Self.names))
        #expect(written[HomeChains.putBack]?.effect == .nothing)
        #expect(written[HomeChains.clear]?.frame == Self.frames.categories[1].frame)
        #expect(written[HomeChains.putBack]?.frame == Self.frames.categories[3].frame)
        let cleared = Self.controls(Self.typing(.cleared))
        #expect(cleared[HomeChains.clear]?.effect == .nothing)
        #expect(cleared[HomeChains.putBack]?.effect == .changesData)
        #expect(cleared[HomeChains.putBack]?.leadsTo == HomeChains.name(of: Self.typing(.written), categories: Self.names))
        let empty = Self.controls(Self.typing(.empty))
        #expect(empty[HomeChains.clear]?.effect == .nothing && empty[HomeChains.putBack]?.effect == .nothing)
    }

    /// Fails if a category does anything while typing (dimmed: choosing one
    /// would turn the dimmed tiles under a look resting there into phrases
    /// that speak), or if Emergency stops leaving typing for the emergency
    /// phrases.
    @Test func whileTypingTheCategoriesAreDimmedAndEmergencyLeaves() {
        let typing = Self.controls(Self.typing(.written))
        #expect(typing["Basics"]?.effect == .nothing && typing["Feelings"]?.effect == .nothing)
        #expect(typing["Needs"] == nil && typing["Conversation"] == nil)
        var leaving = Self.typing(.written)
        leaving.typing = false
        leaving.showing = nil
        #expect(typing[HomeChains.emergency]?.leadsTo == HomeChains.name(of: leaving, categories: Self.names))
        // Even with the emergency phrases showing before typing.
        let fromEmergency = Self.controls(Self.typing(.written, showing: nil))
        #expect(fromEmergency[HomeChains.emergency]?.effect == .navigates)
        #expect(typing[HomeChains.settings]?.leadsTo == HomeChains.settingsRoot)
    }

    /// Fails if Phrases or Type stop working like a segmented control's
    /// segments: each only picks its own mode, keeps the draft, and does
    /// nothing while its mode is on.
    @Test func phrasesAndTypeEachPickTheirOwnMode() {
        var browsing = Self.typing(.written)
        browsing.typing = false
        let typing = Self.controls(Self.typing(.written))
        #expect(typing[HomeChains.type]?.effect == .nothing)
        #expect(typing[HomeChains.phrases]?.leadsTo == HomeChains.name(of: browsing, categories: Self.names))
        let browse = Self.controls(browsing)
        #expect(browse[HomeChains.phrases]?.effect == .nothing)
        #expect(browse[HomeChains.type]?.leadsTo == HomeChains.name(of: Self.typing(.written), categories: Self.names))
        #expect(browse[HomeChains.again] != nil && browse[HomeChains.speak] == nil)
        #expect(browse["Needs"]?.effect == .navigates && browse[HomeChains.phraseTile]?.effect == .speaks)
    }

    /// Fails if a phrase tile goes while typing, leaving empty space a look
    /// rests on beside Clear and Put Back, or does anything while typing
    /// (docs/DECISIONS.md, "Typing on Home"); or if a tile stops
    /// speaking while the phrases show. Only Stop's well is a resting place
    /// either way.
    @Test func whileTypingThePhraseTilesStayDimmedInPlace() {
        let map = HomeChains.map(Self.frames)
        let typing = HomeChains.name(of: Self.typing(), categories: Self.names)
        var browsing = Self.typing()
        browsing.typing = false
        let browse = HomeChains.name(of: browsing, categories: Self.names)
        func tiles(_ state: String) -> [ChainControl] {
            (map.states[state] ?? []).filter { $0.name == HomeChains.phraseTile }
        }
        #expect(tiles(typing).map(\.frame) == Self.frames.tiles)
        #expect(tiles(typing).allSatisfy { $0.effect == .nothing })
        #expect(tiles(browse).map(\.frame) == Self.frames.tiles)
        #expect(tiles(browse).allSatisfy { $0.effect == .speaks })
        #expect(map.resting[typing]?.map(\.name) == [HomeChains.emptyWell])
        #expect(map.resting[browse]?.map(\.name) == [HomeChains.emptyWell])
        // Browsing with an empty draft keeps the name it had before typing.
        #expect(browse == "Home, nothing spoken, Basics showing, quiet")
    }
}

/// Settings' first screens for the engine (`SettingsChains`): what each
/// control does, and the two kinds of hazard found through them.
struct SettingsChainsTests {
    private static let home = "Home"
    private static let backToTalking = CGRect(x: 209, y: 70, width: 177, height: 78)
    private static let back = CGRect(x: 16, y: 166, width: 44, height: 44)

    private static func row(_ y: CGFloat) -> CGRect {
        CGRect(x: 16, y: y, width: 370, height: 78)
    }

    private static let screens = SettingsChains.Screens(
        root: [(SettingsChains.backToTalking, backToTalking), (SettingsChains.familySetupRow, CGRect(x: 16, y: 236, width: 370, height: 110))],
        familySetup: [
            (SettingsChains.backToTalking, backToTalking), (SettingsChains.back, back),
            (SettingsChains.guidedSetupRow, row(362)), ("voiceSettings", row(456)),
        ],
        firstStep: [
            (SettingsChains.backToTalking, backToTalking), (SettingsChains.back, back),
            (SettingsChains.learnAboutEachWay, row(362)), ("Touch", row(572)), ("Voice Control", row(666)),
            (SettingsChains.firstStepNext, CGRect(x: 0, y: 694.3, width: 402, height: 110)),
        ],
        eachWay: [(SettingsChains.eachWayDone, backToTalking)]
    )

    private static func controls(_ map: ChainMap, _ state: String) -> [String: ChainControl] {
        Dictionary((map.states[state] ?? []).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Fails if Back to Talking stops closing Settings onto Home from any
    /// screen, a row opens the wrong screen, anything on the first step but
    /// Back, Learn About Each Way and Next stops counting as saving an
    /// answer, or the guide's Done stops returning to the first step.
    @Test func eachControlDoesWhatSettingsDoes() {
        let built = SettingsChains.map(Self.screens, closingOnto: Self.home)
        #expect(built.unknown.isEmpty)
        let root = Self.controls(built.map, SettingsChains.root)
        let familySetup = Self.controls(built.map, SettingsChains.familySetup)
        let firstStep = Self.controls(built.map, SettingsChains.firstStep)
        let eachWay = Self.controls(built.map, SettingsChains.eachWay)
        for screen in [root, familySetup, firstStep] {
            #expect(screen[SettingsChains.backToTalking]?.leadsTo == Self.home)
            #expect(screen[SettingsChains.backToTalking]?.effect == .navigates)
        }
        #expect(root[SettingsChains.familySetupRow]?.leadsTo == SettingsChains.familySetup)
        #expect(familySetup[SettingsChains.back]?.leadsTo == SettingsChains.root)
        #expect(familySetup[SettingsChains.guidedSetupRow]?.leadsTo == SettingsChains.firstStep)
        #expect(familySetup["voiceSettings"]?.leadsTo == "voiceSettings")
        #expect(familySetup["voiceSettings"]?.effect == .navigates)
        #expect(firstStep[SettingsChains.back]?.leadsTo == SettingsChains.familySetup)
        #expect(firstStep[SettingsChains.learnAboutEachWay]?.leadsTo == SettingsChains.eachWay)
        #expect(firstStep[SettingsChains.learnAboutEachWay]?.effect == .navigates)
        #expect(firstStep["Touch"]?.effect == .changesData)
        #expect(firstStep[SettingsChains.firstStepNext]?.effect == .navigates)
        #expect(firstStep[SettingsChains.firstStepNext]?.leadsTo == SettingsChains.secondStep)
        #expect(eachWay.count == 1)
        #expect(eachWay[SettingsChains.eachWayDone]?.leadsTo == SettingsChains.firstStep)
        #expect(eachWay[SettingsChains.eachWayDone]?.effect == .navigates)
    }

    /// Fails if a control the chains do not know is scored as harmless
    /// instead of reported, or a screen not read gets into the map. The
    /// guide's Open Dwell Control Settings, far down its page, is one: it
    /// opens the Settings app.
    @Test func aControlItDoesNotKnowIsReported() {
        var screens = Self.screens
        screens.root.append(("somethingNew", Self.row(400)))
        screens.familySetup?.append(("anotherNew", Self.row(550)))
        screens.firstStep = nil
        screens.eachWay?.append(("Open Dwell Control Settings", Self.row(600)))
        let built = SettingsChains.map(screens, closingOnto: Self.home)
        #expect(built.unknown == ["somethingNew on Settings", "anotherNew on Family Setup", "Open Dwell Control Settings on Each Way"])
        #expect(Self.controls(built.map, SettingsChains.root)["somethingNew"] == nil)
        #expect(Self.controls(built.map, SettingsChains.eachWay)["Open Dwell Control Settings"] == nil)
        #expect(built.map.states[SettingsChains.firstStep] == nil)
        screens.eachWay = nil
        #expect(SettingsChains.map(screens, closingOnto: Self.home).map.states[SettingsChains.eachWay] == nil)
    }

    /// Fails if a hazard is put in the wrong kind: one on the first step
    /// saves an answer; one on Home is Settings closing under the look only
    /// while the pointer goes back to the look; anything else, the guide's
    /// cover included, is new.
    @Test func hazardsAreSortedIntoTheirKinds() {
        let tile = ChainControl("phraseTile", Self.row(400), .speaks)
        let answer = ChainControl("Touch", Self.row(335), .changesData)
        let backToTalking = ChainControl(SettingsChains.backToTalking, Self.backToTalking, .navigates, leadsTo: Self.home)
        func chain(_ state: String, _ control: ChainControl, _ pointer: ChainPointer, _ end: ChainEnd = .hazard) -> Chain {
            Chain(
                start: .choosing(backToTalking, in: SettingsChains.root), rule: .centre, pointer: pointer,
                steps: [
                    ChainStep(state: SettingsChains.root, control: backToTalking, asked: true),
                    ChainStep(state: state, control: control, asked: false),
                ],
                end: end
            )
        }
        #expect(SettingsChains.kind(of: chain(SettingsChains.firstStep, answer, .staysOnControl)) == .savesAnAnswer)
        #expect(SettingsChains.kind(of: chain(Self.home, tile, .returnsToLook)) == .closesUnderTheLook)
        #expect(SettingsChains.kind(of: chain(Self.home, tile, .staysOnControl)) == .unexpected)
        #expect(SettingsChains.kind(of: chain(Self.home, tile, .returnsToLook, .settles)) == nil)
        #expect(SettingsChains.kind(of: chain(SettingsChains.eachWay, answer, .returnsToLook)) == .unexpected)
    }

    /// Main's CI frames for an iPhone at the default text size before typing
    /// came to Home (Home as it launched, Settings' first screen and Family
    /// Setup as they first showed; the first step's rows placed as Step 2's
    /// are, since CI had not captured it). Fails if the chains through them
    /// meet a hazard of a new kind, or stop finding the two kinds known
    /// then: Home's Settings, Family Setup and Set Up Step by Step lead a
    /// held look to save Touch (docs/HANDOFF.md, *Known gaps*), and Back to
    /// Talking's corner closes Settings over No.
    @Test func aPhoneAsCIReadsItHasOnlyTheKnownKinds() throws {
        let categories = ["Basics", "Needs", "Conversation", "Feelings"]
        var read: [(name: String, frame: CGRect)] = [
            (HomeChains.yes, CGRect(x: 16, y: 172.7, width: 86.7, height: 64)),
            (HomeChains.no, CGRect(x: 110.7, y: 172.7, width: 86.3, height: 64)),
            (HomeChains.emergency, CGRect(x: 205, y: 172.7, width: 181, height: 64)),
            (HomeChains.getAttention, CGRect(x: 205, y: 244.7, width: 181, height: 64)),
            (HomeChains.again, CGRect(x: 16, y: 244.7, width: 181, height: 64)),
            ("Basics", CGRect(x: 142, y: 320.7, width: 118, height: 48)),
            ("Needs", CGRect(x: 268, y: 320.7, width: 118, height: 48)),
            ("Conversation", CGRect(x: 16, y: 376.7, width: 118, height: 48)),
            ("Feelings", CGRect(x: 142, y: 376.7, width: 118, height: 48)),
            (HomeChains.settings, CGRect(x: 268, y: 376.7, width: 118, height: 48)),
        ]
        for (column, row) in [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2)] {
            read.append((HomeChains.phraseTile, CGRect(x: 16 + 126 * CGFloat(column), y: 436.7 + 134 * CGFloat(row), width: 118, height: 126)))
        }
        let atRest = HomeChains.name(of: HomeChains.State(), categories: categories)
        let home = HomeChains.map(try #require(HomeChains.frames(from: read, categories: categories)))
        var screens = Self.screens
        screens.familySetup = [
            (SettingsChains.backToTalking, Self.backToTalking), (SettingsChains.back, Self.back),
            (SettingsChains.guidedSetupRow, Self.row(362)), ("voiceSettings", Self.row(456)),
            ("reachingTheScreen", Self.row(550)), ("keepOpen", Self.row(644)),
            ("callsSiriAndShortcuts", Self.row(738)), ("moreAccessibility", Self.row(832)),
        ]
        screens.firstStep = [
            (SettingsChains.backToTalking, Self.backToTalking), (SettingsChains.back, Self.back),
            ("Touch", Self.row(335)), ("Voice Control", Self.row(429)), ("Switch Control", Self.row(523)),
            ("Eye Tracking", Self.row(617)), ("Head Tracking", Self.row(711)), ("Someone else helps", Self.row(805)),
            (SettingsChains.firstStepNext, CGRect(x: 0, y: 694.3, width: 402, height: 110)),
        ]
        screens.eachWay = nil
        let settings = SettingsChains.map(screens, closingOnto: atRest)
        #expect(settings.unknown.isEmpty)
        let map = home.merging(settings.map)
        let hazards = map.hazards(from: SettingsChains.starts(in: map, home: atRest))
        func paths(_ kind: SettingsChains.Kind) -> [String] {
            ChainFinding.findings(in: hazards.filter { SettingsChains.kind(of: $0) == kind }).map(\.path)
        }
        #expect(paths(.unexpected) == [])
        #expect(paths(.savesAnAnswer).contains("choosing settings → familySetup (navigates) → guidedSetup (navigates) → Touch (changesData)"))
        #expect(paths(.closesUnderTheLook).contains("choosing backToTalking → No (speaks)"))
    }

    /// A window CI runs, as PR #53's and PR #56's runs drew Settings in it,
    /// for the chains through Settings laid out as the app now lays it out.
    struct ModelledWindow {
        let name: String
        let size: CGSize
        let safeArea: HomeLayout.Insets
        let text: HomeLayout.Text
        /// The root's row with its words on one line, and its height at a
        /// width: one line where it is that wide, wrapped below.
        let rowIdealWidth: CGFloat
        let rowHeights: (oneLine: CGFloat, wrapped: CGFloat)
        /// Set Up Step by Step with its words on one line, and its height at
        /// a width: one line where it is that wide, wrapped below. Modelled
        /// from the Family Setup row CI measured, since PR #53 was the first
        /// to draw it narrower than the content: its words are about half
        /// as wide again (9.82 ems to 6.66, `SweptFamilySetup`), and two
        /// lines of them fit within the row's 64-point least height at the
        /// default text size. On the phone at the largest size CI drew it
        /// three lines tall, across the content. The first step's Learn
        /// About Each Way, whose words are about as wide, takes its frame.
        let guidedIdealWidth: CGFloat
        let guidedHeights: (oneLine: CGFloat, wrapped: CGFloat)
        /// The standard Back button on the screens below the root.
        let back: CGRect
        /// Family Setup's opening words: their height across the content
        /// where CI measured it, otherwise the 110 points CI drew the block
        /// at, which they fit within. Narrower, they keep their area.
        let words: CGFloat
        /// Family Setup's rows: how tall, and how far apart.
        let familyRow: (height: CGFloat, step: CGFloat)
        /// The first step's question and its sentence across the content,
        /// as CI measured them above the answers on main. Narrower, they
        /// keep their area.
        let question: CGFloat
        /// The first step's answers: the first's height, Touch's, which is
        /// shorter where the others' words take two lines, and the others'.
        /// Clear My Choices is as tall as the others, 24 points further
        /// down.
        let answerHeights: (first: CGFloat, others: CGFloat)
        /// Next, at the foot of every step, as CI measured it.
        let next: CGRect

        static let phone = ModelledWindow(
            name: "iPhone 17", size: CGSize(width: 402, height: 874), safeArea: .init(top: 62, leading: 0, bottom: 34, trailing: 0),
            text: HomeLayoutEngineTests.defaultText, rowIdealWidth: 185, rowHeights: (78, 110),
            guidedIdealWidth: 245, guidedHeights: (78, 78),
            back: CGRect(x: 16, y: 152, width: 44, height: 44), words: 110, familyRow: (78, 94),
            question: 84.67, answerHeights: (78, 78), next: CGRect(x: 0, y: 694.33, width: 402, height: 110)
        )
        static let phoneLargest = ModelledWindow(
            name: "iPhone 17, AX5", size: CGSize(width: 402, height: 874), safeArea: .init(top: 62, leading: 0, bottom: 34, trailing: 0),
            text: HomeLayoutEngineTests.largestText, rowIdealWidth: 442, rowHeights: (80, 144.67),
            guidedIdealWidth: 604, guidedHeights: (80, 209.67),
            back: CGRect(x: 16, y: 187, width: 44, height: 44), words: 745.33, familyRow: (144.67, 160.67),
            question: 588.33, answerHeights: (79.67, 144.67), next: CGRect(x: 0, y: 593.33, width: 402, height: 111.67)
        )
        static let padPortrait = ModelledWindow(
            name: "iPad portrait", size: CGSize(width: 1032, height: 1376), safeArea: .init(top: 32, leading: 0, bottom: 20, trailing: 0),
            text: HomeLayoutEngineTests.defaultText, rowIdealWidth: 185, rowHeights: (78, 110),
            guidedIdealWidth: 245, guidedHeights: (78, 78),
            back: CGRect(x: 10, y: 146, width: 44, height: 44), words: 110, familyRow: (78, 94),
            question: 63, answerHeights: (78, 78), next: CGRect(x: 0, y: 1210, width: 1032, height: 110)
        )
        static let padPortraitLargest = ModelledWindow(
            name: "iPad portrait, AX5", size: CGSize(width: 1032, height: 1376), safeArea: .init(top: 32, leading: 0, bottom: 20, trailing: 0),
            text: HomeLayoutEngineTests.largestText, rowIdealWidth: 442, rowHeights: (80, 144.67),
            guidedIdealWidth: 604, guidedHeights: (80, 144.67),
            back: CGRect(x: 10, y: 157, width: 44, height: 44), words: 249.5, familyRow: (80, 96),
            question: 208.5, answerHeights: (80, 80), next: CGRect(x: 0, y: 1164, width: 1032, height: 112)
        )
        static let padLandscape = ModelledWindow(
            name: "iPad landscape", size: CGSize(width: 1376, height: 1032), safeArea: .init(top: 32, leading: 0, bottom: 20, trailing: 0),
            text: HomeLayoutEngineTests.defaultText, rowIdealWidth: 185, rowHeights: (78, 110),
            guidedIdealWidth: 245, guidedHeights: (78, 78),
            back: CGRect(x: 10, y: 146, width: 44, height: 44), words: 110, familyRow: (78, 94),
            question: 63, answerHeights: (78, 78), next: CGRect(x: 0, y: 866, width: 1376, height: 110)
        )

        static let all = [phone, phoneLargest, padPortrait, padPortraitLargest, padLandscape]
        static let answerNames = ["Touch", "Voice Control", "Switch Control", "Eye Tracking", "Head Tracking", "Someone else helps"]
    }

    /// The first step's answers and Clear My Choices from `top`, `gap`
    /// apart, as `SetupAccessQuestion` stacks them.
    static func answers(
        x: CGFloat, width: CGFloat, top: CGFloat, heights: (first: CGFloat, others: CGFloat), gap: CGFloat = 16
    ) -> [(name: String, frame: CGRect)] {
        var y = top
        var list: [(name: String, frame: CGRect)] = []
        for (index, name) in ModelledWindow.answerNames.enumerated() {
            let height = index == 0 ? heights.first : heights.others
            list.append((name, CGRect(x: x, y: y, width: width, height: height)))
            y += height + gap
        }
        return list + [("Clear My Choices", CGRect(x: x, y: y + 24, width: width, height: heights.others))]
    }

    /// The guide Learn About Each Way opens: a cover of its own, with Done
    /// in Back to Talking's frame, as the app draws it (`EachWayCover`), or
    /// pushed onto Settings' stack like Family Setup's other guides, with
    /// only Back and Back to Talking near the look.
    enum Guide {
        case cover, pushed
    }

    struct Model {
        let map: ChainMap
        let starts: [ChainStart]
        let row: CGRect
        let guided: CGRect
        let firstStep: [(name: String, frame: CGRect)]
    }

    /// Home's frames from the layout engine in `window`, typing states
    /// included, with Settings over it laid out as the app lays it out:
    /// the navigation stack starts 8 points under Back to Talking and ends
    /// above the 40-point sound line, and its bar keeps 64 points, as CI
    /// drew them (`SettingsScreenFrames`); the root's row sits where
    /// `SettingsRowPlace` puts it; on Family Setup, Set Up Step by Step
    /// takes its frame, at least as tall, with the opening words beside it,
    /// above it or under it, and the other rows after them
    /// (`SettingsLeadIn`); on the first step, Learn About Each Way takes Set
    /// Up Step by Step's frame, with the question beside it, above it or
    /// under it, and the answers start below both and where
    /// `SetupAnswersPlace` puts them, from Home's Settings, the root's row
    /// and Set Up Step by Step. Only what shows in the window is kept, as
    /// the UI test reads it.
    static func modelled(_ window: ModelledWindow, guide: Guide = .cover) -> Model {
        let layout = HomeLayout(space: .init(size: window.size, safeArea: window.safeArea), text: window.text, modes: .phrasesAndTyping)
        let backToTalking = layout.backToTalking
        let stackTop = backToTalking.maxY + 8
        let screen = SettingsScreenFrames(
            stack: CGRect(
                x: window.safeArea.leading, y: stackTop, width: window.size.width - window.safeArea.leading - window.safeArea.trailing,
                height: window.size.height - window.safeArea.bottom - 40 - stackTop
            ),
            safeArea: .init(top: 64, leading: 0, bottom: 0, trailing: 0), gutter: 16
        )
        let rootRow = SettingsRowPlace(
            home: layout, rowIdealWidth: window.rowIdealWidth,
            rowHeight: { $0 >= window.rowIdealWidth ? window.rowHeights.oneLine : window.rowHeights.wrapped },
            content: screen.content, navigationBar: screen.navigationBar
        ).row
        let content = screen.content
        let guidedHeight = { (width: CGFloat) in width >= window.guidedIdealWidth ? window.guidedHeights.oneLine : window.guidedHeights.wrapped }
        let leadIn = SettingsLeadIn(
            width: content.width, spacing: 16,
            control: SettingsLeadIn.control(
                inPlaceOf: rootRow.offsetBy(dx: -content.minX, dy: -content.minY), width: content.width, height: guidedHeight
            ),
            besideWidth: window.guidedIdealWidth,
            wordsHeight: { window.words * max(1, content.width / $0) }
        )
        let guided = leadIn.control.offsetBy(dx: content.minX, dy: content.minY)
        let familyRows = ["voiceSettings", "reachingTheScreen", "keepOpen", "callsSiriAndShortcuts", "moreAccessibility", "privacyPolicy", "about"]
            .enumerated().map { index, name in
                (name, CGRect(
                    x: content.minX, y: content.minY + leadIn.size.height + 16 + window.familyRow.step * CGFloat(index),
                    width: content.width, height: window.familyRow.height
                ))
            }
        let question = SettingsLeadIn(
            width: content.width, spacing: 16,
            control: SettingsLeadIn.control(
                inPlaceOf: guided.offsetBy(dx: -content.minX, dy: -content.minY), width: content.width, height: guidedHeight
            ),
            besideWidth: window.guidedIdealWidth,
            // CI measured the question and its first sentence before the
            // sentence on sizes came; that one is modelled as the sweep
            // models it (`SweptFamilySetup.sizesHeight`).
            wordsHeight: {
                window.question * max(1, content.width / $0)
                    + SweptFamilySetup.sizesHeight($0, body: 17 + (50 - 17) * (window.text.categoryLine - 22) / (65 - 22))
            }
        )
        let link = question.control.offsetBy(dx: content.minX, dy: content.minY)
        let place = SetupAnswersPlace(
            arrivals: [layout.frame(.settings), rootRow, guided], link: link,
            answersMinX: content.minX, answersWidth: content.width, answerHeight: 64, earliest: link.maxY + 16
        )
        let firstStep = [(SettingsChains.learnAboutEachWay, link)]
            + Self.answers(
                x: content.minX, width: content.width, top: max(content.minY + question.size.height + 16, place.top),
                heights: window.answerHeights
            )
            + [(SettingsChains.firstStepNext, window.next)]
        let shown = CGRect(origin: .zero, size: window.size)
        func onScreen(_ controls: [(name: String, frame: CGRect)]) -> [(name: String, frame: CGRect)] {
            controls.filter { $0.frame.intersects(shown) }
        }
        let screens = SettingsChains.Screens(
            root: [(SettingsChains.backToTalking, backToTalking), (SettingsChains.familySetupRow, rootRow)],
            familySetup: onScreen(
                [(SettingsChains.backToTalking, backToTalking), (SettingsChains.back, window.back), (SettingsChains.guidedSetupRow, guided)]
                    + familyRows
            ),
            firstStep: onScreen([(SettingsChains.backToTalking, backToTalking), (SettingsChains.back, window.back)] + firstStep),
            eachWay: guide == .cover
                ? [(SettingsChains.eachWayDone, backToTalking)]
                : [(SettingsChains.backToTalking, backToTalking), (SettingsChains.back, window.back)]
        )
        let categories = (1...HomeLayout.categoryCapacity).map { "category \($0)" }
        let atRest = HomeChains.name(of: HomeChains.State(), categories: categories)
        var settings = SettingsChains.map(screens, closingOnto: atRest).map
        if guide == .pushed {
            // The chains know only the cover's Done there: pushed, the
            // guide's Back returns to the first step.
            settings.states[SettingsChains.eachWay] = settings.states[SettingsChains.eachWay]?.map { control in
                control.name == SettingsChains.back
                    ? ChainControl(control.name, control.frame, .navigates, leadsTo: SettingsChains.firstStep) : control
            }
        }
        let map = HomeLayoutEngineTests.chainMap(layout, typing: true).merging(settings)
        return Model(
            map: map, starts: SettingsChains.starts(in: map, home: atRest), row: rootRow, guided: guided,
            firstStep: screens.firstStep ?? []
        )
    }

    private static func paths(_ kind: SettingsChains.Kind, in model: Model) -> [String] {
        let hazards = model.map.hazards(from: model.starts)
        return ChainFinding.findings(in: hazards.filter { SettingsChains.kind(of: $0) == kind }).map(\.path)
    }

    /// On CI's iPhone and 13-inch iPad, in portrait at the default and the
    /// largest text sizes and in landscape, with the root's row where
    /// `SettingsRowPlace` puts it, Set Up Step by Step in its place on
    /// Family Setup and the first step drawn as the app draws it: fails if
    /// any chain closes Settings under the look, meets anything new, or
    /// saves an answer (docs/DECISIONS.md, "Settings' first row, placed
    /// from Home's frames", "The first step's own rows"). With the first
    /// step's answers where main drew them, across the top of the content,
    /// Home's Settings, Family Setup and Set Up Step by Step led a held
    /// look to save Touch on every window, and on the phone at the largest
    /// size a held look through the first step closed Settings onto No and
    /// Get Attention. With Next saving the answers, as it did, a look at
    /// the lower edge of Home's Settings on the phone at the largest size
    /// met Next and saved them unchanged.
    @Test func theFirstStepsOwnRowsCloseNothingAndSaveNothingUnderTheLook() {
        for window in ModelledWindow.all {
            let model = Self.modelled(window)
            let context = "\(window.name), row \(model.row), Set Up Step by Step \(model.guided)"
            #expect(Self.paths(.unexpected, in: model) == [], "\(context)")
            #expect(Self.paths(.closesUnderTheLook, in: model) == [], "\(context)")
            #expect(Self.paths(.savesAnAnswer, in: model) == [], "\(context), first step \(model.firstStep)")
        }
    }

    /// Why the guide is a cover of its own (docs/DECISIONS.md, "The first
    /// step's own rows"): pushed like Family Setup's other guides, it has
    /// only Back and Back to Talking near the look, so a held look on
    /// Learn About Each Way closes Settings, and the closed Settings leaves
    /// the look over Home's Get Attention on the phone: the alarm sounds
    /// unasked. Fails once a pushed guide no longer sounds it, so a pushed
    /// guide can be scored to come back.
    @Test func aPushedGuideWouldSoundTheAlarm() {
        let phone = Self.modelled(.phone, guide: .pushed)
        #expect(Self.paths(.closesUnderTheLook, in: phone).contains("choosing learnAboutEachWay → backToTalking (navigates) → getAttention (alarms)"))
        #expect(Self.paths(.closesUnderTheLook, in: Self.modelled(.phone)) == [])
    }

    /// Family Setup and the first step as the sweep draws them over a
    /// window of `SettingsRowPlaceTests.everyWindow`, with the root's row
    /// where `SettingsRowPlace` puts it. The words are modelled, since CI
    /// draws only its own windows:
    /// - A row's words at a text size: Family Setup's row with its words on
    ///   one line, as `SettingsRowPlaceTests` models it from CI, less the
    ///   icon, its gap and the button's insets (`overhead`), is 6.66 ems of
    ///   SF Pro Semibold; Set Up Step by Step's words are 9.82 ems, wrapped
    ///   between words, and each line is a category line tall over the
    ///   row's least height of 64 points, with 14 points of insets. Learn
    ///   About Each Way's words are about as wide, so it takes Set Up Step
    ///   by Step's frame.
    /// - Family Setup's opening words (190 characters, rounded up from the
    ///   sentence's 179 with the app's name): each character 0.4
    ///   of the body size wide and each line 1.25 of it tall, with the body
    ///   size from 17 points at the default size to 50 at AX5 in proportion
    ///   to the category line; at AX5 across CI's iPad they are 250 points
    ///   tall, where CI measured 249.5.
    /// - The first step's question and its sentences: each word half its
    ///   letters' size wide per letter, wrapped between words, each line 1.2
    ///   of the size tall, the question at 1.25 of the body size and 16
    ///   points above each sentence. Across CI's phone and iPad at the
    ///   default size and AX5 the question and its first sentence are 82,
    ///   601, 62 and 211 points tall, where CI measured 84.67, 588.33, 63
    ///   and 208.5. The sentence on sizes, shown only once Home's sizes
    ///   follow the answer, is modelled the same way and not yet measured.
    /// - Back is 44 points square, 16 points in and 10 down from the bar's
    ///   top, and Family Setup's other rows are as tall as the root's row
    ///   across the content, 16 points apart. Only what shows above the
    ///   sound line is kept.
    /// - The first step's answers: Touch on one line, the others as tall as
    ///   the root's row across the content, 16 points apart, and Clear My
    ///   Choices 24 points further down. Next is one line, with 16 points
    ///   around it, across the stack, above the sound line: one line of the
    ///   subheadline size (15 points at the default size to 49 at AX5, in
    ///   proportion to the category line) 1.3 of it tall, or two where its
    ///   longest message, 12.5 of that size wide, is wider than the content,
    ///   with 8 points above and below. CI measured the line 35.67, 80 and
    ///   135 points tall on the phone and the iPad at the default size and
    ///   the phone at AX5, where this gives 35.5, 79.7 and 143.4. Everything
    ///   in the window is kept, as the UI test reads it.
    /// - The guide's cover: Done, in Back to Talking's frame.
    struct SweptFamilySetup {
        let guided: CGRect
        let screens: SettingsChains.Screens

        static let guidedWords: [CGFloat] = [1.74, 1.16, 2.32, 1.16, 2.32]
        static let question = "How is the screen reached?"
        static let sentence = "Choose every way that is used now. Each answer is saved as soon as it is chosen."
        static let sizes = "Home's buttons take the size the answers need, as large as this screen has room for, and are largest until something is chosen. The new size shows when Settings closes."

        /// How many lines `text` takes in `room` at `size`, wrapped between
        /// words.
        static func lines(_ text: String, room: CGFloat, size: CGFloat) -> CGFloat {
            var lines: CGFloat = 1
            var current: CGFloat = 0
            for word in text.split(separator: " ") {
                let width = CGFloat(word.count) * 0.5 * size
                let next = current == 0 ? width : current + 0.28 * size + width
                if next > room, current > 0 {
                    lines += 1
                    current = width
                } else {
                    current = next
                }
            }
            return lines
        }

        /// The question and its two sentences at `width`.
        static func questionHeight(_ width: CGFloat, body: CGFloat) -> CGFloat {
            lines(question, room: width, size: 1.25 * body) * 1.2 * 1.25 * body + 16 + lines(sentence, room: width, size: body) * 1.2 * body
                + sizesHeight(width, body: body)
        }

        /// The sentence on Home's sizes, 16 points under the first, shown
        /// only once Home's sizes follow the answer
        /// (`ProfileChoice.followsTheAnswer`). While they are held the
        /// sweep scores the first step as everyone gets it; the
        /// `--home-profile=from-answer` UI test shows the sentence but
        /// scores no chain, and the pull request that switches the sizes
        /// on scores it here.
        static func sizesHeight(_ width: CGFloat, body: CGFloat) -> CGFloat {
            guard ProfileChoice.followsTheAnswer else { return 0 }
            return 16 + lines(sizes, room: width, size: body) * 1.2 * body
        }

        init(_ window: SettingsRowPlaceTests.Window, text: HomeLayout.Text, row: CGRect) {
            let line = text.categoryLine
            let overhead = 36 + line
            let em = (window.rowIdealWidth(text: text) - overhead) / 6.66
            let guidedIdeal = overhead + em * (Self.guidedWords.reduce(0, +) + 0.28 * CGFloat(Self.guidedWords.count - 1))
            func guidedHeight(_ width: CGFloat) -> CGFloat {
                let room = (width - overhead) / em
                var lines: CGFloat = 1
                var current: CGFloat = 0
                for word in Self.guidedWords {
                    let next = current == 0 ? word : current + 0.28 + word
                    if next > room, current > 0 {
                        lines += 1
                        current = word
                    } else {
                        current = next
                    }
                }
                return max(64, lines * line) + 14
            }
            let body = 17 + (50 - 17) * (line - 22) / (65 - 22)
            let content = window.content
            let leadIn = SettingsLeadIn(
                width: content.width, spacing: 16,
                control: SettingsLeadIn.control(
                    inPlaceOf: row.offsetBy(dx: -content.minX, dy: -content.minY), width: content.width, height: guidedHeight
                ),
                besideWidth: guidedIdeal,
                wordsHeight: { ceil(190 / max(1, $0 / (0.4 * body))) * 1.25 * body }
            )
            guided = leadIn.control.offsetBy(dx: content.minX, dy: content.minY)
            let back = CGRect(x: window.navigationBar.minX + 16, y: window.navigationBar.minY + 10, width: 44, height: 44)
            let rowHeight = window.rowHeight(text: text, width: content.width)
            let rows = ["voiceSettings", "reachingTheScreen", "keepOpen", "callsSiriAndShortcuts", "moreAccessibility", "privacyPolicy", "about"]
                .enumerated().map { index, name in
                    (name, CGRect(
                        x: content.minX, y: content.minY + leadIn.size.height + 16 + (rowHeight + 16) * CGFloat(index),
                        width: content.width, height: rowHeight
                    ))
                }
            let shown = CGRect(x: 0, y: 0, width: window.size.width, height: content.maxY + 16)
            let backToTalking = window.home.backToTalking

            let question = SettingsLeadIn(
                width: content.width, spacing: 16,
                control: SettingsLeadIn.control(
                    inPlaceOf: guided.offsetBy(dx: -content.minX, dy: -content.minY), width: content.width, height: guidedHeight
                ),
                besideWidth: guidedIdeal,
                wordsHeight: { Self.questionHeight($0, body: body) }
            )
            let link = question.control.offsetBy(dx: content.minX, dy: content.minY)
            let place = SetupAnswersPlace(
                arrivals: [window.home.frame(.settings), row, guided], link: link,
                answersMinX: content.minX, answersWidth: content.width, answerHeight: 64, earliest: link.maxY + 16
            )
            let subheadline = 15 + (49 - 15) * (line - 22) / (65 - 22)
            let soundLine = 16 + ceil(12.5 * subheadline / content.width) * 1.3 * subheadline
            let nextHeight = max(64, line) + 14 + 32
            // The stack's foot, over this sound line rather than the 40
            // points the content is cut at.
            let next = CGRect(
                x: window.navigationBar.minX, y: content.maxY + 16 + 40 - soundLine - nextHeight,
                width: window.navigationBar.width, height: nextHeight
            )
            let answers = SettingsChainsTests.answers(
                x: content.minX, width: content.width, top: max(content.minY + question.size.height + 16, place.top),
                heights: (max(64, line) + 14, rowHeight)
            )
            let inWindow = CGRect(origin: .zero, size: window.size)
            screens = SettingsChains.Screens(
                root: [(SettingsChains.backToTalking, backToTalking), (SettingsChains.familySetupRow, row)],
                familySetup: ([(SettingsChains.backToTalking, backToTalking), (SettingsChains.back, back), (SettingsChains.guidedSetupRow, guided)] + rows)
                    .filter { $0.1.intersects(shown) },
                firstStep: ([(SettingsChains.backToTalking, backToTalking), (SettingsChains.back, back), (SettingsChains.learnAboutEachWay, link)]
                    + answers + [(SettingsChains.firstStepNext, next)])
                    .filter { $0.1.intersects(inWindow) },
                eachWay: [(SettingsChains.eachWayDone, backToTalking)]
            )
        }
    }

    /// Across `SettingsRowPlaceTests.everyWindow` at the default size, AX3
    /// and AX5, Bold Text off, every 32 points of width: fails if any chain
    /// through Settings' first screen, Family Setup, the first step and the
    /// guide's cover closes Settings under the look, meets anything new or
    /// saves an answer (docs/DECISIONS.md, "Settings' first row, placed
    /// from Home's frames", "The first step's own rows"), with the words
    /// modelled as `SweptFamilySetup` says. With Next saving the answers,
    /// as it did, a held look saved them through Next on 212 of the
    /// windows (135 at AX5, 75 at AX3 and two 568 points tall at the
    /// default size), where Home's Settings lies low enough that a look at
    /// its lower part is nearer Next than Learn About Each Way. With Set Up
    /// Step by Step across the width at the row's top instead, 90 of the
    /// 630 windows close Settings under the look; with the opening words
    /// over it, as before PR #53, 213 do, onto Home's Get Attention or No.
    @Test func noSweptWindowClosesSettingsOrSavesAnAnswerUnderTheLook() {
        let categories = (1...HomeLayout.categoryCapacity).map { "category \($0)" }
        let atRest = HomeChains.name(of: HomeChains.State(), categories: categories)
        let lines = Set(HomeLayoutEngineTests.textSizes.filter { ["default", "AX3", "AX5"].contains($0.name) }.map(\.text.categoryLine))
        var scored = 0
        for (window, text, place) in SettingsRowPlaceTests.everyWindow
        where !text.boldText && lines.contains(text.categoryLine) && Int(window.size.width - 320) % 32 == 0 {
            scored += 1
            let swept = SweptFamilySetup(window, text: text, row: place.row)
            let map = HomeLayoutEngineTests.chainMap(window.home, typing: true)
                .merging(SettingsChains.map(swept.screens, closingOnto: atRest).map)
            let hazards = map.hazards(from: SettingsChains.starts(in: map, home: atRest))
            let found = ChainFinding.findings(in: hazards)
            #expect(found.map(\.path) == [], "\(window.context): row \(place.row), Set Up Step by Step \(swept.guided)")
        }
        #expect(scored == 630)
    }

    /// `ChainEngine` edge cases, `CustomStringConvertible` descriptions,
    /// `HomeChains` fallbacks, and `SettingsChains.kind(of:)` on Settings' own
    /// screens.
    @Test func chainEngineEdgeCasesDescriptionsAndChainHelpersHold() {
        let emptyControls: [String: CGRect] = [:]
        let nearestEmpty = ChainEngine.nearest(to: CGPoint(x: 10, y: 10), among: emptyControls)
        #expect(nearestEmpty.byCentre.isEmpty && nearestEmpty.byEdge.isEmpty)

        // Empty state produces `.nothingNear` from a resting start, and an
        // unmapped state produces `.leaves(state)`.
        let emptyStateMap = ChainMap(
            states: ["empty": []],
            resting: ["empty": [(name: "blank", frame: CGRect(x: 0, y: 0, width: 40, height: 40))]]
        )
        let fromRestingInEmpty = emptyStateMap.chains(
            from: [ChainStart(state: "empty", look: CGPoint(x: 10, y: 10), chosen: nil, restingOn: nil)]
        )
        #expect(fromRestingInEmpty.allSatisfy { $0.end == .nothingNear })
        #expect(fromRestingInEmpty.first?.start.description == "resting on the screen in empty, looking at (10.0, 10.0)")

        let unmappedStart = ChainStart(state: "outside", look: CGPoint(x: 5, y: 5), chosen: nil, restingOn: "margin")
        let fromUnmapped = emptyStateMap.chains(from: [unmappedStart])
        #expect(fromUnmapped.count == 4)
        #expect(fromUnmapped.allSatisfy { $0.end == .leaves("outside") })
        #expect(fromUnmapped.first?.end.description == "leaves for outside")
        #expect(emptyStateMap.hazards(from: [unmappedStart]).isEmpty)

        // Control navigating into an empty state ends at `.nothingNear`.
        let navToEmpty = ChainControl("goEmpty", CGRect(x: 0, y: 0, width: 44, height: 44), .navigates, leadsTo: "empty")
        let mapToEmpty = ChainMap(states: ["start": [navToEmpty], "empty": []])
        let chainsToEmpty = mapToEmpty.chains(from: [.choosing(navToEmpty, in: "start")])
        #expect(chainsToEmpty.allSatisfy { $0.end == .nothingNear })
        #expect(chainsToEmpty.first?.end.description == "meets nothing")

        // `ChainEffect.movesThings` is a hazard, and `CustomStringConvertible`
        // formats controls, starts, ends, chains, and findings.
        #expect(ChainEffect.movesThings.isHazard)
        let moving = ChainControl("reorder", CGRect(x: 0, y: 0, width: 44, height: 44), .movesThings)
        #expect(moving.description == "reorder (movesThings)")
        #expect(ChainEnd.hazard.description == "hazard")
        #expect(ChainEnd.repeats.description == "repeats")
        #expect(ChainEnd.settles.description == "settles")
        #expect(ChainEnd.tooLong.description == "too long")

        // `ChainMap.merging(_:)` overwrites shared keys with the other map's entries.
        let merged = emptyStateMap.merging(ChainMap(
            states: ["empty": [moving]],
            resting: ["empty": [(name: "replaced", frame: CGRect(x: 0, y: 0, width: 20, height: 20))]]
        ))
        #expect(merged.states["empty"] == [moving])
        #expect(merged.resting["empty"]?.map(\.name) == ["replaced"])

        // `HomeChains.atRest(categoryCount:)`, `HomeChains.name(of:categories:)`
        // fallback for out-of-range category index and `.cleared` draft, and
        // `HomeChains.frames(from:categories:)` returning `nil` when a fixed
        // control is missing.
        #expect(HomeChains.atRest(categoryCount: 4) == HomeChains.State(hasSpoken: false, showing: 0, sounding: false))
        #expect(HomeChains.atRest(categoryCount: 0) == HomeChains.State(hasSpoken: false, showing: nil, sounding: false))
        let outOfRange = HomeChains.State(hasSpoken: true, showing: 9, sounding: true, typing: true, draft: .cleared)
        #expect(HomeChains.name(of: outOfRange, categories: ["Basics"]) == "Home, spoken, category 10 showing, sounding, typing, draft cleared")
        #expect(HomeChains.frames(from: [], categories: ["Basics"]) == nil)

        // `SettingsChains.kind(of:)` returns `.unexpected` when a hazard occurs
        // on `SettingsChains.root` or `SettingsChains.familySetup`.
        let rootHazard = ChainControl("surprise", Self.row(300), .speaks)
        let back = ChainControl(SettingsChains.back, Self.back, .navigates, leadsTo: SettingsChains.root)
        let chainOnRoot = Chain(
            start: .choosing(back, in: SettingsChains.familySetup),
            rule: .centre,
            pointer: .staysOnControl,
            steps: [
                ChainStep(state: SettingsChains.familySetup, control: back, asked: true),
                ChainStep(state: SettingsChains.root, control: rootHazard, asked: false),
            ],
            end: .hazard
        )
        #expect(SettingsChains.kind(of: chainOnRoot) == .unexpected)
        #expect(chainOnRoot.description.contains("surprise (speaks)"))
        let findings = ChainFinding.findings(in: [chainOnRoot])
        #expect(findings.count == 1)
        #expect(findings.first?.description.contains("surprise (speaks)") == true)
    }
}

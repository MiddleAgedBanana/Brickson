import Foundation
import Testing
@testable import Brickson

/// Home's sizes from Family Setup's answer (`ProfileChoice`), the
/// profiles' floors (`HomeLayout.Profile`) and where each holds
/// (`HomeLayout.holdsProfile`): docs/DECISIONS.md, "Sizes that follow how
/// the screen is reached"; docs/work/sizes-that-follow-reach.md.
struct ProfileChoiceTests {
    typealias Profile = HomeLayout.Profile
    typealias Slot = HomeLayout.Slot

    // MARK: The profile an answer asks for

    /// Fails if a question never answered, or cleared, asks for anything
    /// but the largest sizes (docs/ROADMAP.md, Wave 3 item 8).
    @Test func noAnswerAsksForTheLargestSizes() {
        #expect(ProfileChoice.requested(by: nil) == .eyeTracking)
        #expect(ProfileChoice.requested(by: []) == .eyeTracking)
        #expect(Profile.allCases.max() == .eyeTracking)
    }

    /// Fails if one way of reaching the screen asks for other sizes than
    /// the work file's table.
    @Test func eachAnswerAsksForItsOwnSizes() {
        let table: [AccessMethod: Profile] = [
            .touch: .touch, .voiceControl: .touch, .someoneElse: .touch,
            .switchControl: .switchControl, .headTracking: .headTracking, .eyeTracking: .eyeTracking,
        ]
        for method in AccessMethod.allCases {
            #expect(ProfileChoice.requested(by: [method]) == table[method], "\(method)")
        }
    }

    /// Fails if several answers ask for less than any one of them needs,
    /// in every combination of the six.
    @Test func severalAnswersAskForTheLargestAnyOfThemNeeds() {
        let methods = AccessMethod.allCases
        for mask in 1..<(1 << methods.count) {
            let chosen = Set(methods.indices.filter { mask & (1 << $0) != 0 }.map { methods[$0] })
            let asked = ProfileChoice.requested(by: chosen)
            #expect(chosen.allSatisfy { asked >= ProfileChoice.profile(for: $0) }, "\(chosen)")
            #expect(chosen.contains { asked == ProfileChoice.profile(for: $0) }, "\(chosen)")
        }
        #expect(ProfileChoice.requested(by: [.touch, .eyeTracking]) == .eyeTracking)
        #expect(ProfileChoice.requested(by: [.voiceControl, .switchControl]) == .switchControl)
    }

    /// What iOS reports suggests an answer and never changes one: the
    /// profile is asked for by the answer alone (`requested(by:)` reads no
    /// flag), and the suggestion reads no answer, so the first step's words
    /// stay the same as answers are chosen. Fails if a flag suggests
    /// something else.
    @Test func whatIOSReportsOnlySuggestsAnAnswer() {
        #expect(ProfileChoice.suggestion(voiceOver: false, switchControl: false) == nil)
        #expect(ProfileChoice.suggestion(voiceOver: true, switchControl: false)?.answer == .touch)
        #expect(ProfileChoice.suggestion(voiceOver: false, switchControl: true)?.answer == .switchControl)
        #expect(ProfileChoice.suggestion(voiceOver: true, switchControl: true)?.answer == .switchControl)
    }

    // MARK: Held until the owner answers

    /// Home follows the answer only once the owner has said what it does
    /// where a window cannot hold the sizes asked for (docs/DECISIONS.md,
    /// "Sizes that follow how the screen is reached", *Held until the owner
    /// answers*). Fails if the switch is turned on without that answer, if
    /// a held Home asks for anything but touch's sizes, the ones it has
    /// always had, for any answer, or if a Home that follows the answer
    /// asks for other sizes than the answer does.
    @Test func homeKeepsTouchsSizesUntilTheOwnerAnswers() {
        #expect(ProfileChoice.followsTheAnswer == false)
        let answers: [Set<AccessMethod>?] = [nil, []] + AccessMethod.allCases.map { [$0] } + [Set(AccessMethod.allCases)]
        for answer in answers {
            #expect(ProfileChoice.requestedForHome(by: answer, followsAnswer: false) == .touch, "\(String(describing: answer))")
            #expect(ProfileChoice.requestedForHome(by: answer, followsAnswer: true) == ProfileChoice.requested(by: answer),
                    "\(String(describing: answer))")
        }
    }

    // MARK: The floors

    /// Fails if touch's floors and gaps are not the ones Home has had
    /// (invariant 1's 44 points), if a larger profile has a smaller floor
    /// or gap, if the gaze floors are not the reference app's held at the
    /// densest screen, or if Switch Control's differ from head tracking's.
    @Test func theFloorsGrowWithTheProfile() {
        let touch = Profile.touch
        #expect([touch.quickControlFloor, touch.categoryFloor, touch.tileFloor, touch.floor] == [44, 44, 44, 44])
        #expect(touch.controlSpacing == HomeLayout.controlSpacing)
        #expect(touch.regionSpacing == HomeLayout.regionSpacing)
        #expect(touch.minimumRegionSpacing == HomeLayout.minimumRegionSpacing)
        for (smaller, larger) in zip(Profile.allCases, Profile.allCases.dropFirst()) {
            #expect(smaller.quickControlFloor <= larger.quickControlFloor, "\(smaller) \(larger)")
            #expect(smaller.categoryFloor <= larger.categoryFloor, "\(smaller) \(larger)")
            #expect(smaller.tileFloor <= larger.tileFloor, "\(smaller) \(larger)")
            #expect(smaller.controlSpacing <= larger.controlSpacing, "\(smaller) \(larger)")
        }
        // The reference app's 110, 88 and 72 points and 12-point gaps on a
        // 13-inch iPad, about 132 points per inch, held at 163.
        func held(_ points: CGFloat) -> CGFloat { (points * 163 / 132).rounded() }
        let eye = Profile.eyeTracking
        #expect([eye.tileFloor, eye.quickControlFloor, eye.categoryFloor, eye.controlSpacing] == [held(110), held(88), held(72), held(12)])
        let head = Profile.headTracking
        #expect([head.tileFloor, head.quickControlFloor, head.categoryFloor, head.controlSpacing] == [110, 88, 72, 12])
        let switchControl = Profile.switchControl
        #expect([switchControl.tileFloor, switchControl.quickControlFloor, switchControl.categoryFloor, switchControl.controlSpacing]
            == [head.tileFloor, head.quickControlFloor, head.categoryFloor, head.controlSpacing])
        for profile in Profile.allCases {
            #expect(profile.regionSpacing > profile.minimumRegionSpacing && profile.minimumRegionSpacing > profile.controlSpacing + ChainEngine.tie)
        }
    }

    /// Fails if a window too small for a profile falls to one that is not
    /// smaller, skips touch, or tries one twice.
    @Test func aWindowFallsToSmallerSizesAndLastToTouch() {
        #expect(Profile.eyeTracking.withSmallerOnes == [.eyeTracking, .headTracking, .touch])
        #expect(Profile.headTracking.withSmallerOnes == [.headTracking, .touch])
        #expect(Profile.switchControl.withSmallerOnes == [.switchControl, .touch])
        #expect(Profile.touch.withSmallerOnes == [.touch])
        for profile in Profile.allCases {
            let ladder = profile.withSmallerOnes
            #expect(ladder.first == profile && ladder.last == .touch)
            #expect(zip(ladder, ladder.dropFirst()).allSatisfy { $1.isSmaller(than: $0) }, "\(ladder)")
        }
    }

    // MARK: Every window

    /// Every window from 320 to 1432 points wide, every 8, at the engine
    /// tests' heights, with no safe areas, at three text sizes, with Bold
    /// Text off and on, in both modes, at every profile.
    static let everyLayout: [(space: HomeLayout.Space, text: HomeLayout.Text, touch: HomeLayout, larger: [HomeLayout], context: String)] = {
        var layouts: [(HomeLayout.Space, HomeLayout.Text, HomeLayout, [HomeLayout], String)] = []
        for modes in HomeLayoutEngineTests.bothModes {
            for (name, plain) in [("default", HomeLayoutEngineTests.defaultText), ("xxxLarge", HomeLayoutEngineTests.largerText), ("AX5", HomeLayoutEngineTests.largestText)] {
                for boldText in [false, true] {
                    var text = plain
                    text.boldText = boldText
                    for height: CGFloat in [568, 667, 744, 874, 1032, 1376] {
                        for width in stride(from: CGFloat(320), through: 1432, by: 8) {
                            let space = HomeLayout.Space(size: CGSize(width: width, height: height))
                            let touch = HomeLayout(space: space, text: text, modes: modes)
                            let larger = Profile.allCases.filter { $0 != .touch }.map {
                                HomeLayout(space: space, profile: $0, text: text, modes: modes)
                            }
                            layouts.append((space, text, touch, larger, "\(width)×\(height), \(name), Bold Text \(boldText), \(modes)"))
                        }
                    }
                }
            }
        }
        return layouts
    }()

    /// Each slot's region, its row within the region, by the distinct tops
    /// there, and its place in that row, by leading edge; and the grid's
    /// columns and rows. The same in two layouts means every control keeps
    /// its place relative to the others between them. (Rows of a region
    /// need not share columns: on three columns Stop and Settings are
    /// narrower than the categories.)
    static func places(_ layout: HomeLayout) -> [String: [Int]] {
        let regions: [[Slot]] = [[.message, .statusLine, .phrases, .type], Slot.safetyRow, Slot.categoriesRegion]
        func ranks(_ values: [CGFloat]) -> [Int] {
            var distinct: [CGFloat] = []
            for value in values.sorted() where distinct.last.map({ value - $0 > 0.5 }) ?? true { distinct.append(value) }
            return values.map { value in distinct.lastIndex { $0 <= value + 0.5 } ?? 0 }
        }
        var places: [String: [Int]] = ["grid": [layout.grid.columns, layout.grid.rows]]
        for (index, region) in regions.enumerated() {
            let present = region.filter(layout.slots.contains)
            let frames = present.map(layout.frame)
            let rows = ranks(frames.map(\.minY))
            for (offset, slot) in present.enumerated() {
                let row = present.indices.filter { rows[$0] == rows[offset] }
                let column = ranks(row.map { frames[$0].minX })[row.firstIndex(of: offset)!]
                places[slot.description] = [index, rows[offset], column]
            }
        }
        return places
    }

    /// Fails if, in any window, a profile's layout has another arrangement
    /// than touch's, a control in another region, row or column of it, or
    /// regions out of their order, top to bottom (invariant 8): sizes and
    /// spacing change between profiles, places never do.
    @Test func noControlChangesPlaceBetweenProfiles() {
        var faults: [String] = []
        for (_, _, touch, larger, context) in Self.everyLayout {
            let expected = Self.places(touch)
            for layout in larger {
                if layout.isRegular != touch.isRegular || layout.categoryArrangement != touch.categoryArrangement
                    || Self.places(layout) != expected {
                    faults.append("\(layout.profile) (\(context))")
                }
                let regions: [[Slot]] = [[.message, .statusLine, .phrases, .type], Slot.safetyRow, Slot.categoriesRegion, [.phraseGrid]]
                let bounds = regions.map(layout.bounds(of:))
                if zip(bounds, bounds.dropFirst()).contains(where: { $0.maxY > $1.minY + 0.001 }) {
                    faults.append("\(layout.profile) regions out of order (\(context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Fails if a layout said to hold its profile has a control or a
    /// phrase tile under the profile's floor in either
    /// direction, gaps under the profile's, or a starter library that
    /// scrolls: measured from its frames, not from the engine's own check.
    /// Fails too if no window holds a larger profile, so the check cannot
    /// pass by holding nothing.
    @Test func aProfileHoldsOnlyWhereEveryFloorIsMet() {
        var held: [Profile: Int] = [:]
        var faults: [String] = []
        for (_, _, _, larger, context) in Self.everyLayout {
            for layout in larger where layout.holdsProfile {
                held[layout.profile, default: 0] += 1
                let profile = layout.profile
                func short(_ frame: CGRect, _ floor: CGFloat) -> Bool {
                    frame.width < floor - 0.001 || frame.height < floor - 0.001
                }
                for slot in layout.controls {
                    let floor = Slot.categoriesRegion.contains(slot) ? profile.categoryFloor : profile.quickControlFloor
                    if short(layout.frame(slot), floor) { faults.append("\(slot) \(layout.frame(slot)) (\(profile), \(context))") }
                }
                let grid = layout.grid
                for column in 0..<grid.columns where short(grid.tile(row: 0, column: column), profile.tileFloor) {
                    faults.append("tile \(column) \(grid.tile(row: 0, column: column)) (\(profile), \(context))")
                }
                let reference = grid.reflow(in: grid.frame, phraseCount: HomeLayout.referencePhraseCount)
                if reference.scrolls || !layout.startersFit { faults.append("scrolls (\(profile), \(context))") }
                if layout.regionGap < profile.minimumRegionSpacing - 0.001 { faults.append("gap \(layout.regionGap) (\(profile), \(context))") }
                if layout.modes == .phrasesAndTyping && !layout.isRegular
                    && abs(layout.horizontalGap(from: .yes, to: .no) - profile.controlSpacing) > 0.001 {
                    faults.append("Yes to No \(layout.horizontalGap(from: .yes, to: .no)) (\(profile), \(context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect((held[.eyeTracking] ?? 0) > 0 && (held[.headTracking] ?? 0) > 0 && held[.switchControl] == held[.headTracking])
    }

    /// Fails if a profile holds where its larger gap narrows a control or a
    /// phrase tile below the width its words need (`MinimumWidths`, the
    /// tiles' minimums) while touch's sizes in the same window keep it at
    /// least that wide. The arrangement is chosen at touch's gap and the
    /// profile's own gap narrows its columns, so a five-column Home just
    /// wide enough at touch's gap, or a three-column grid, can be too
    /// narrow at a larger one (CodeRabbit's review of PR #69).
    @Test func aProfileHoldsOnlyWhereEveryWordFitsAsAtTouchsSizes() {
        var faults: [String] = []
        for (_, text, touch, larger, context) in Self.everyLayout {
            let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText)
            func words(_ slot: Slot) -> CGFloat {
                switch slot {
                case .yes, .no: minimum.yesNo
                case .again: minimum.again
                case .emergency: minimum.emergency
                case .getAttention: minimum.getAttention
                case .phrases: minimum.phrases
                case .type: minimum.type
                case .stop: minimum.stop
                case .category: minimum.category
                case .settings: minimum.settingsSymbol
                case .message: minimum.message
                case .statusLine, .phraseGrid: 0
                }
            }
            let tile = touch.isRegular ? HomeLayout.regularTile : HomeLayout.compactTile
            let tileWords = text.boldText ? tile.boldMinimumWidth : tile.minimumWidth
            for layout in larger where layout.holdsProfile {
                for slot in layout.slots
                where touch.frame(slot).width >= words(slot) - 0.001 && layout.frame(slot).width < words(slot) - 0.001 {
                    faults.append("\(slot) \(layout.frame(slot).width) wide, touch's \(touch.frame(slot).width) (\(layout.profile), \(context))")
                }
                if touch.grid.tileSize.width >= tileWords - 0.001 && layout.grid.tileSize.width < tileWords - 0.001 {
                    faults.append("tiles \(layout.grid.tileSize.width) wide, touch's \(touch.grid.tileSize.width) (\(layout.profile), \(context))")
                }
            }
        }
        #expect(faults.isEmpty, "\(faults.count), first: \(faults.first ?? "")")
    }

    /// Fails if Home's sizes are not the largest of the profile asked for
    /// and the smaller ones that hold in the window without losing what
    /// touch's sizes have there (`keepsEverything`), or touch's: never a
    /// profile larger than asked for, never one that does not hold, never
    /// a smaller one where a larger would do. Every 24 points of the
    /// windows above, for every profile asked for.
    @Test func theLargestProfileThatHoldsIsTaken() {
        var faults: [String] = []
        for (index, entry) in Self.everyLayout.enumerated() where index % 3 == 0 {
            let byProfile = Dictionary(uniqueKeysWithValues: ([entry.touch] + entry.larger).map { ($0.profile, $0) })
            for requested in Profile.allCases {
                let chosen = ProfileChoice.layout(requested: requested, space: entry.space, text: entry.text, modes: entry.touch.modes)
                let taken = chosen.profile
                if chosen != byProfile[taken] { faults.append("\(taken)'s frames differ (\(entry.context))") }
                if taken > requested { faults.append("\(taken) for \(requested) (\(entry.context))") }
                if taken != .touch && !(chosen.holdsProfile && ProfileChoice.keepsEverything(chosen, of: entry.touch)) {
                    faults.append("\(taken) does not hold (\(entry.context))")
                }
                for skipped in requested.withSmallerOnes where skipped > taken && skipped != .touch {
                    let layout = byProfile[skipped]!
                    if layout.holdsProfile && ProfileChoice.keepsEverything(layout, of: entry.touch) {
                        faults.append("\(taken) where \(skipped) holds (\(entry.context))")
                    }
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    // MARK: The windows people use

    /// The profile Home has in each of `HomeLayoutEngineTests.windows` when
    /// Eye Tracking's sizes are asked for, as they are until anyone
    /// answers, at each text size of `HomeLayoutEngineTests.textSizes`,
    /// smallest first, the same with Bold Text off and on. No phone holds
    /// a larger profile at any text size: head tracking's sizes leave the
    /// starter library 84 to 635 points short there, Eye Tracking's 304 to
    /// 871. Every iPad in portrait holds Eye Tracking's at every size.
    /// docs/DECISIONS.md, "Sizes that follow how the screen is reached",
    /// *Where each profile holds*, has this table.
    static let eyeTable: [String: [Profile]] = [
        "iPhone 17": Array(repeating: .touch, count: 5),
        "iPhone 17 Pro Max": Array(repeating: .touch, count: 5),
        "iPhone 16e": Array(repeating: .touch, count: 5),
        "375×667 phone": Array(repeating: .touch, count: 5),
        "375×667 phone, zoomed": Array(repeating: .touch, count: 5),
        "13-inch iPad": Array(repeating: .eyeTracking, count: 5),
        "13-inch iPad, landscape": Array(repeating: .eyeTracking, count: 5),
        // Head tracking's sizes hold, but leave no room for typing until
        // touch's leave none either, at AX3; at AX5 they scroll.
        "13-inch iPad, landscape, zoomed": [.touch, .touch, .touch, .headTracking, .touch],
        "11-inch iPad": Array(repeating: .eyeTracking, count: 5),
        // Eye Tracking's scroll; at AX5 head tracking's leave no room for
        // typing.
        "11-inch iPad, landscape": [.headTracking, .headTracking, .headTracking, .headTracking, .touch],
        "iPad mini": Array(repeating: .eyeTracking, count: 5),
        // Head tracking's leave the starter library 30 to 58 points short.
        "iPad mini, landscape": Array(repeating: .touch, count: 5),
    ]

    /// Where Bold Text changes what `eyeTable` says: on the iPad mini in
    /// portrait, Eye Tracking's 15-point gap leaves five columns of 130.4
    /// points, narrower than the widest bold word one carries (132), so
    /// head tracking's are taken (`HomeLayout.arrangementHoldsItsWords`).
    static let eyeTableWithBoldText: [String: [Profile]] = [
        "iPad mini": Array(repeating: .headTracking, count: 5),
    ]

    /// Fails if a window people use takes other sizes than `eyeTable`
    /// (`eyeTableWithBoldText` where Bold Text is on and it has the
    /// window) when Eye Tracking's are asked for, or, for head tracking's and
    /// Switch Control's, other than the table's capped at the one asked
    /// for: update the table and the decision then.
    @Test(arguments: HomeLayoutEngineTests.windows.indices)
    func theWindowsPeopleUseTakeTheSizesTheTableSays(window index: Int) {
        let window = HomeLayoutEngineTests.windows[index]
        let space = HomeLayout.Space(size: window.size, safeArea: .init(top: window.top, leading: 0, bottom: window.bottom, trailing: 0))
        #expect(Self.eyeTable[window.name]?.count == HomeLayoutEngineTests.textSizes.count, "\(window.name)")
        for (size, (name, plain)) in HomeLayoutEngineTests.textSizes.enumerated() {
            for boldText in [false, true] {
                let table = (boldText ? Self.eyeTableWithBoldText[window.name] : nil) ?? Self.eyeTable[window.name] ?? []
                var text = plain
                text.boldText = boldText
                let context = "\(window.name), \(name), Bold Text \(boldText)"
                for requested in Profile.allCases {
                    let taken = ProfileChoice.layout(requested: requested, space: space, text: text, modes: .phrasesAndTyping).profile
                    let expected = table.indices.contains(size) ? table[size] : .touch
                    // Where Eye Tracking's or head tracking's sizes are taken,
                    // any smaller profile asked for holds too (Switch Control's
                    // are head tracking's).
                    let capped: Profile = expected == .touch ? .touch : requested == .eyeTracking ? expected : requested
                    #expect(taken == capped, "\(requested): \(context)")
                }
            }
        }
    }

    // MARK: Dwell safety at the larger sizes

    /// Every regular and compact iPad-sized window from 600 to 1432 points
    /// wide, every 32, at an iPad mini's, an 11-inch's and a 13-inch's
    /// heights in both orientations, at three text sizes, Bold Text off,
    /// in which `profile` holds.
    static func heldWindows(_ profile: Profile, every step: CGFloat = 32) -> [(layout: HomeLayout, context: String)] {
        var held: [(HomeLayout, String)] = []
        for (name, text) in [("default", HomeLayoutEngineTests.defaultText), ("xxxLarge", HomeLayoutEngineTests.largerText), ("AX5", HomeLayoutEngineTests.largestText)] {
            for height: CGFloat in [744, 834, 1032, 1133, 1210, 1376] {
                for width in stride(from: CGFloat(600), through: 1432, by: step) {
                    let space = HomeLayout.Space(size: CGSize(width: width, height: height), safeArea: SettingsRowPlaceTests.padSafeArea)
                    let layout = HomeLayout(space: space, profile: profile, text: text, modes: .phrasesAndTyping)
                    guard layout.holdsProfile else { continue }
                    held.append((layout, "\(width)×\(height), \(name), \(profile)"))
                }
            }
        }
        return held
    }

    /// Fails if a chain of held activations on a larger profile's frames
    /// meets anything that speaks, alarms, changes data or moves things
    /// unasked, in any of Home's states, browsing or typing, from any
    /// control a person chooses or place a look rests, beyond the two
    /// findings touch's frames already have and the engine tests pin
    /// (`HomeLayoutEngineTests`): Stop's well's top nearest Again where
    /// Again is above it, and, by centre only, a dimmed phrase nearest
    /// Clear or Put Back while typing. Fails too if the profile holds in
    /// none of the windows.
    @Test(arguments: [Profile.headTracking, .eyeTracking])
    func noChainAtALargerProfileMeetsANewHazard(profile: Profile) {
        let dimmedPhrase = "a dimmed phrase"
        let held = Self.heldWindows(profile)
        var unexpected: [String] = []
        for (index, (layout, context)) in held.enumerated() {
            let typing = index % 2 == 0
            let map = HomeLayoutEngineTests.chainMap(layout, typing: typing)
            var resting: [ChainStart] = []
            if typing {
                let grid = layout.grid
                let categories = (0..<HomeLayout.categoryCapacity).map { "category \($0 + 1)" }
                let topRow = (0..<min(grid.columns, HomeLayout.referencePhraseCount)).map { grid.tile(row: 0, column: $0) }
                let states = HomeChains.states(categoryCount: categories.count, typing: true).filter(\.typing)
                    .map { HomeChains.name(of: $0, categories: categories) }
                let points = topRow.flatMap { ChainEngine.points(across: $0, columns: 2, rows: 2) }
                resting = states.flatMap { state in points.map { ChainStart.resting(at: $0, on: dimmedPhrase, in: state) } }
            }
            for finding in ChainFinding.findings(in: map.hazards(from: map.everyStart() + resting)) {
                let start = finding.example.start
                let fromTheWell = start.chosen?.name == HomeChains.stop || start.restingOn == HomeChains.emptyWell
                let met = finding.example.hazard?.control.name
                let againAboveTheWell = !layout.isRegular
                let byCentreOnly = finding.under.allSatisfy { $0.hasPrefix(NearestRule.centre.rawValue) }
                if againAboveTheWell && fromTheWell && (met == HomeChains.again || met == HomeChains.speak) { continue }
                if start.restingOn == dimmedPhrase && byCentreOnly && (met == HomeChains.clear || met == HomeChains.putBack) { continue }
                unexpected.append("\(finding) (\(context), typing \(typing))")
            }
        }
        let count = unexpected.count
        #expect(count == 0, "first: \(unexpected.first ?? "")")
        #expect(held.count > 20, "\(held.count)")
    }

    /// An answer changed in Family Setup closes Settings onto other sizes
    /// than it opened over. Fails if a look still resting anywhere on
    /// Settings' Back to Talking, in any profile's layout, meets anything
    /// but Phrases, by centre or by edge, on Home at any profile the window
    /// can have: touch's and every larger one it holds. With each
    /// profile's own Back to Talking, closing from Eye Tracking's sizes
    /// onto smaller ones met Type at its foot, and on windows 1352 to 1416
    /// points wide, by centre, Get Attention or Again. Fails too if no
    /// window has more than one profile to close onto.
    @Test func closingSettingsOntoOtherSizesMeetsOnlyPhrases() {
        var windows = 0
        var faults: [String] = []
        for (name, text) in HomeLayoutEngineTests.textSizes {
            for height: CGFloat in [744, 834, 1032, 1133, 1210, 1376] {
                for width in stride(from: CGFloat(600), through: 1432, by: 16) {
                    let space = HomeLayout.Space(size: CGSize(width: width, height: height), safeArea: SettingsRowPlaceTests.padSafeArea)
                    let layouts = Profile.allCases.map {
                        ProfileChoice.layout(requested: $0, space: space, text: text, modes: .phrasesAndTyping)
                    }
                    guard Set(layouts.map(\.profile)).count > 1 else { continue }
                    windows += 1
                    for from in layouts {
                        for to in layouts {
                            let controls = Dictionary(uniqueKeysWithValues: to.controls.filter { $0 != .stop }.map { ($0.description, to.frame($0)) })
                            for point in ChainEngine.points(across: from.backToTalking) {
                                let met = ChainEngine.nearest(to: point, among: controls)
                                if met.byCentre != ["phrases"] || met.byEdge != ["phrases"] {
                                    faults.append("\(met) at \(point), \(from.profile) onto \(to.profile) (\(width)×\(height), \(name))")
                                }
                            }
                        }
                    }
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(windows > 100, "\(windows)")
    }

    /// Back to Talking keeps touch's frame in every profile
    /// (`closingSettingsOntoOtherSizesMeetsOnlyPhrases`), so under a larger
    /// profile it is smaller than that profile's floors: an exception to
    /// invariant 1's larger floors, named, measured and waiting on the
    /// owner with the sizes (docs/DECISIONS.md, "Sizes that follow how the
    /// screen is reached", *Back to Talking keeps touch's frame*). Fails if
    /// it is not touch's wherever a larger profile is taken, if it is ever
    /// below touch's own 44-point floor, or if it is smaller than the
    /// smallest recorded there: 126.4 points wide and 64 tall.
    @Test func backToTalkingUnderALargerProfileIsTouchsAsRecorded() {
        var smallest = CGSize(width: CGFloat.infinity, height: .infinity)
        var held = 0
        var faults: [String] = []
        for (name, text) in HomeLayoutEngineTests.textSizes {
            for height: CGFloat in [744, 834, 1032, 1133, 1210, 1376] {
                for width in stride(from: CGFloat(600), through: 1432, by: 16) {
                    let space = HomeLayout.Space(size: CGSize(width: width, height: height), safeArea: SettingsRowPlaceTests.padSafeArea)
                    let touch = HomeLayout(space: space, text: text, modes: .phrasesAndTyping)
                    for requested in [Profile.headTracking, .eyeTracking] {
                        let layout = ProfileChoice.layout(requested: requested, space: space, text: text, modes: .phrasesAndTyping)
                        guard layout.profile != .touch else { continue }
                        held += 1
                        let back = layout.backToTalking
                        if back != touch.backToTalking { faults.append("\(back), touch's \(touch.backToTalking) (\(layout.profile), \(width)×\(height), \(name))") }
                        if back.width < 44 || back.height < 44 { faults.append("\(back) under 44 (\(layout.profile), \(width)×\(height), \(name))") }
                        smallest = CGSize(width: min(smallest.width, back.width), height: min(smallest.height, back.height))
                    }
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(held > 100, "\(held)")
        #expect(smallest.width >= 126.4 - 0.5 && smallest.height >= 64 - 0.5, "\(smallest)")
    }

    /// The open hazard (docs/DECISIONS.md, "Home's slot plan", *Open
    /// hazard, not accepted: Yes and No border the message*) at the larger
    /// sizes: fails if a look resting on the message meets Yes or No over
    /// more of it than on touch's frames, whose worst shares the engine
    /// tests pin (68% by centre and 62% by edge on regular widths, 97% and
    /// 89% on compact ones).
    @Test(arguments: [Profile.headTracking, .eyeTracking])
    func yesAndNoBorderNoMoreOfTheMessageAtALargerProfile(profile: Profile) {
        var faults: [String] = []
        for (layout, context) in Self.heldWindows(profile, every: 64) {
            let share = Nearest.speakingShare(of: layout)
            let pinned = layout.isRegular ? (centre: 0.68, edge: 0.62) : (centre: 0.97, edge: 0.89)
            if share.centre > pinned.centre || share.edge > pinned.edge { faults.append("\(share) (\(context))") }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Settings over a larger profile's Home: Settings' places come from
    /// Home's frames (`SettingsCover`), so they follow the profile. Fails
    /// if any chain through Settings' first screen, Family Setup, the
    /// first step and the guide's cover closes Settings under the look,
    /// meets anything new or saves an answer, as the swept windows at
    /// touch's sizes do not (`ChainEngineTests`), in every window above
    /// where Eye Tracking's or head tracking's sizes hold.
    @Test func noSettingsChainOverALargerProfileClosesSettingsOrSavesAnAnswer() {
        let categories = (1...HomeLayout.categoryCapacity).map { "category \($0)" }
        let atRest = HomeChains.name(of: HomeChains.State(), categories: categories)
        var scored = 0
        var faults: [String] = []
        for (name, text) in HomeLayoutEngineTests.textSizes where ["default", "AX3", "AX5"].contains(name) {
            for height: CGFloat in [744, 1032, 1133, 1376] {
                for width in stride(from: CGFloat(600), through: 1432, by: 64) {
                    let context = "\(width)×\(height), \(name)"
                    let window = SettingsRowPlaceTests.Window(
                        size: CGSize(width: width, height: height), safeArea: SettingsRowPlaceTests.padSafeArea,
                        text: text, context: context, requested: .eyeTracking
                    )
                    guard window.home.profile != .touch else { continue }
                    scored += 1
                    let place = window.place(text: text)
                    let swept = SettingsChainsTests.SweptFamilySetup(window, text: text, row: place.row)
                    let map = HomeLayoutEngineTests.chainMap(window.home, typing: true)
                        .merging(SettingsChains.map(swept.screens, closingOnto: atRest).map)
                    let found = ChainFinding.findings(in: map.hazards(from: SettingsChains.starts(in: map, home: atRest)))
                    if !found.isEmpty { faults.append("\(found.map(\.path)) (\(context), \(window.home.profile))") }
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(scored > 10, "\(scored)")
    }

    // MARK: Reserved regions

    /// Fails if a window with a fold or a camera across Home takes a
    /// larger profile, which no fold check has measured, or if its touch
    /// layout changes with the profile asked for.
    @Test func aFoldOrACameraAcrossHomeKeepsTouchsSizes() {
        let size = CGSize(width: 1032, height: 1376)
        let fold = HomeLayout.ReservedRegion(kind: .division, frame: CGRect(x: 0, y: 680, width: size.width, height: 16))
        let camera = HomeLayout.ReservedRegion(kind: .occlusion, frame: CGRect(x: 480, y: 0, width: 72, height: 60))
        for regions in [[fold], [camera], [fold, camera]] {
            let space = HomeLayout.Space(size: size, safeArea: SettingsRowPlaceTests.padSafeArea, regions: regions)
            let touch = HomeLayout(space: space, text: HomeLayoutEngineTests.defaultText, modes: .phrasesAndTyping)
            for requested in Profile.allCases {
                let layout = HomeLayout(space: space, profile: requested, text: HomeLayoutEngineTests.defaultText, modes: .phrasesAndTyping)
                #expect(requested == .touch || !layout.holdsProfile, "\(requested) \(regions)")
                #expect(ProfileChoice.layout(requested: requested, space: space, text: HomeLayoutEngineTests.defaultText, modes: .phrasesAndTyping) == touch)
            }
        }
        // The same window without them holds Eye Tracking's.
        let clear = HomeLayout.Space(size: size, safeArea: SettingsRowPlaceTests.padSafeArea)
        #expect(ProfileChoice.layout(requested: .eyeTracking, space: clear, text: HomeLayoutEngineTests.defaultText, modes: .phrasesAndTyping).profile == .eyeTracking)
    }
}

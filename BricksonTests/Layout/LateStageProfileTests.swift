import Foundation
import Testing
@testable import Brickson

/// The late stage's profile and the rest board on Home's layout
/// (`HomeLayout.Profile.lateStage`, `HomeLayout.PhraseArea`):
/// docs/DECISIONS.md, "The late-stage profile";
/// docs/work/late-stage-profile.md.
struct LateStageProfileTests {
    typealias Profile = HomeLayout.Profile
    typealias Slot = HomeLayout.Slot

    /// The board the measurements use: a six-phrase starter category
    /// (Conversation or Feelings) with the starter Emergency, six too.
    static let board = HomeLayout.PhraseArea.restBoard(phrases: 6)

    // MARK: The floors

    /// Fails if a late-stage floor or gap is not the one proposed, if any
    /// is smaller than Eye Tracking's, if Yes, No, Emergency, Again and Get
    /// Attention can be smaller than a tile, if the growth is not 4 degrees
    /// at 46 cm held at 163 points per inch, if another profile's Phrases
    /// and Type differ from its quick controls, or if a window too small
    /// for the late stage's sizes skips Eye Tracking's.
    @Test func theLateStagesFloorsAreTheProposedOnes() {
        let late = Profile.lateStage
        let eye = Profile.eyeTracking
        #expect([late.tileFloor, late.quickControlFloor, late.modeControlFloor, late.categoryFloor, late.controlSpacing]
            == [136, 136, 109, 89, 15])
        #expect(eye.isSmaller(than: late))
        #expect(late.quickControlFloor >= late.tileFloor)
        #expect(late.modeControlFloor == eye.quickControlFloor)
        #expect(late.floor == 89)
        #expect([late.floor(of: .yes), late.floor(of: .getAttention), late.floor(of: .phrases), late.floor(of: .type),
                 late.floor(of: .category(0)), late.floor(of: .stop), late.floor(of: .settings)] == [136, 136, 109, 109, 89, 89, 89])
        for profile in Profile.allCases where profile != .lateStage {
            #expect(profile.modeControlFloor == profile.quickControlFloor, "\(profile)")
            for isRegular in [false, true] {
                #expect(profile.modeControlHeight(isRegular: isRegular) == profile.quickControlHeight(isRegular: isRegular), "\(profile)")
            }
        }
        #expect(late.modeControlHeight(isRegular: true) == 109 && late.quickControlHeight(isRegular: true) == 136)
        let fourDegrees = 2 * 460 * tan(2 * Double.pi / 180) / 25.4 * 163
        #expect(HomeLayout.restBoardQuickControlHeight == CGFloat(fourDegrees.rounded()))
        #expect(late.withSmallerOnes == [.lateStage, .eyeTracking, .headTracking, .touch])
        #expect(HomeLayout.PhraseArea.everyCategory.room == HomeLayout.referencePhraseCount)
        #expect(HomeLayout.PhraseArea.restBoard(phrases: 6).room == 6 && HomeLayout.PhraseArea.restBoard(phrases: 0).room == 1)
    }

    // MARK: Every window

    /// One window's Home at every profile, with every category and with the
    /// board.
    struct Entry {
        let space: HomeLayout.Space
        let text: HomeLayout.Text
        let everyCategory: [Profile: HomeLayout]
        let board: [Profile: HomeLayout]
        let context: String
    }

    /// Every window from 320 to 1432 points wide, every 16, at the engine
    /// tests' heights, with no safe areas, at three text sizes, with Bold
    /// Text off and on, with Phrases and Type.
    static let everyWindow: [Entry] = {
        var entries: [Entry] = []
        for (name, plain) in [("default", HomeLayoutEngineTests.defaultText), ("xxxLarge", HomeLayoutEngineTests.largerText), ("AX5", HomeLayoutEngineTests.largestText)] {
            for boldText in [false, true] {
                var text = plain
                text.boldText = boldText
                for height: CGFloat in [568, 667, 744, 874, 1032, 1376] {
                    for width in stride(from: CGFloat(320), through: 1432, by: 16) {
                        let space = HomeLayout.Space(size: CGSize(width: width, height: height))
                        func layouts(_ area: HomeLayout.PhraseArea) -> [Profile: HomeLayout] {
                            Dictionary(uniqueKeysWithValues: Profile.allCases.map {
                                ($0, HomeLayout(space: space, profile: $0, text: text, modes: .phrasesAndTyping, phraseArea: area))
                            })
                        }
                        entries.append(Entry(space: space, text: text, everyCategory: layouts(.everyCategory), board: layouts(board),
                            context: "\(width)×\(height), \(name), Bold Text \(boldText)"))
                    }
                }
            }
        }
        return entries
    }()

    /// Fails if, in any window, at any profile, the board's layout has
    /// another arrangement than touch's with every category, a control in
    /// another region, row or column, other grid columns, or regions out of
    /// their order (invariant 8): the board changes sizes and the grid's
    /// rows, never a place.
    @Test func noControlChangesPlaceOnTheRestBoard() {
        var faults: [String] = []
        for entry in Self.everyWindow {
            let touch = entry.everyCategory[.touch]!
            var expected = ProfileChoiceTests.places(touch)
            expected["grid"] = nil
            for profile in Profile.allCases {
                let layout = entry.board[profile]!
                var places = ProfileChoiceTests.places(layout)
                places["grid"] = nil
                if layout.isRegular != touch.isRegular || layout.categoryArrangement != touch.categoryArrangement
                    || layout.grid.columns != touch.grid.columns || places != expected {
                    faults.append("\(profile) (\(entry.context))")
                }
                let regions: [[Slot]] = [[.message, .statusLine, .phrases, .type], Slot.safetyRow, Slot.categoriesRegion, [.phraseGrid]]
                let bounds = regions.map(layout.bounds(of:))
                if zip(bounds, bounds.dropFirst()).contains(where: { $0.maxY > $1.minY + 0.001 }) {
                    faults.append("\(profile) regions out of order (\(entry.context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Fails if the board changes anything but the safety row's height and
    /// what follows it down the screen: the message, its status line,
    /// Phrases and Type keep their frames, the categories, Stop and
    /// Settings their sizes, the gaps between regions theirs, and every
    /// control of the safety row its width and leading edge; the safety
    /// row is at least as tall and grows only toward 206 points; and the
    /// board never takes typing away, or carries the safety row into the
    /// keyboard's room, where Home offers typing with every category. The
    /// first fails if the board's growth comes before Phrases and Type's:
    /// the keyboard's give-back then shrinks Phrases under Settings' Back
    /// to Talking.
    @Test func theRestBoardChangesOnlyTheSafetyRowAndTheGrid() {
        var faults: [String] = []
        var grew = 0
        for entry in Self.everyWindow {
            for profile in Profile.allCases {
                let every = entry.everyCategory[profile]!
                let board = entry.board[profile]!
                let context = "\(profile), \(entry.context)"
                for slot in [Slot.message, .statusLine, .phrases, .type] where board.frame(slot) != every.frame(slot) {
                    faults.append("\(slot) \(board.frame(slot)), \(every.frame(slot)) without (\(context))")
                }
                for slot in Slot.categoriesRegion where board.frame(slot).size != every.frame(slot).size {
                    faults.append("\(slot) \(board.frame(slot).size), \(every.frame(slot).size) without (\(context))")
                }
                for slot in Slot.safetyRow where board.frame(slot).minX != every.frame(slot).minX || board.frame(slot).width != every.frame(slot).width {
                    faults.append("\(slot) \(board.frame(slot)), \(every.frame(slot)) without (\(context))")
                }
                if board.regionGap != every.regionGap { faults.append("gap \(board.regionGap), \(every.regionGap) without (\(context))") }
                let ceiling = max(every.quickControlHeight, HomeLayout.restBoardQuickControlHeight)
                if board.quickControlHeight < every.quickControlHeight - 0.001 || board.quickControlHeight > ceiling + 0.001 {
                    faults.append("safety row \(board.quickControlHeight), \(every.quickControlHeight) without (\(context))")
                }
                if board.quickControlHeight > every.quickControlHeight + 0.5 { grew += 1 }
                if every.offersTyping && !board.offersTyping { faults.append("typing lost (\(context))") }
                let safetyBottom = Slot.safetyRow.map(board.frame).map(\.maxY).max() ?? 0
                if every.offersTyping && safetyBottom > board.keyboard.bandLimit + 0.001 {
                    faults.append("safety row ends at \(safetyBottom), the keyboard's limit \(board.keyboard.bandLimit) (\(context))")
                }
                if board.grid.columns != every.grid.columns { faults.append("columns (\(context))") }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(grew > 1000, "\(grew)")
    }

    /// Fails where the board's safety row stops short of 206 points while
    /// there is room for it to grow: it stops only at the keyboard's room,
    /// where the board's tiles are no taller than it, or where the board's
    /// rows leave no more (the tiles at their floor, or the board
    /// scrolling). Fails too where the board grows the safety row taller
    /// than its tiles, beyond the point the grid's whole-point tiles round
    /// away: the tiles never shrink to make Yes and No larger.
    /// And fails if no window grows it all the way.
    @Test func theSafetyRowGrowsTowardFourDegreesWhileTheTilesStayAsTall() {
        var faults: [String] = []
        var reached = 0
        for entry in Self.everyWindow {
            for profile in Profile.allCases {
                let every = entry.everyCategory[profile]!
                let board = entry.board[profile]!
                let grid = board.grid.reflow(in: board.grid.frame, phraseCount: board.phraseArea.room)
                let quick = board.quickControlHeight
                // Tiles are whole points tall (`HomeLayout.Grid`), so up to a
                // point shorter.
                if quick > every.quickControlHeight + 0.5 && grid.tileSize.height < quick - 1 {
                    faults.append("tiles \(grid.tileSize.height) under the safety row \(quick) (\(profile), \(entry.context))")
                }
                guard quick < HomeLayout.restBoardQuickControlHeight - 0.5 else {
                    reached += 1
                    continue
                }
                let safetyBottom = Slot.safetyRow.map(board.frame).map(\.maxY).max() ?? 0
                let atTheKeyboard = safetyBottom >= board.keyboard.bandLimit - 0.5
                // A taller safety row can need less of a drop under Stop's
                // well (`HomeLayout.wellDrop`), and the grid takes what it
                // gives back.
                let givenBack = max(0, every.wellDrop - board.wellDrop) / CGFloat(grid.rows)
                let asTall = grid.tileSize.height <= quick + 0.5 + givenBack
                let gridAtItsFloor = grid.scrolls || grid.tileSize.height <= board.grid.tileFloor + 0.5
                if !atTheKeyboard && !asTall && !gridAtItsFloor {
                    faults.append("\(quick) with tiles \(grid.tileSize.height) tall (\(profile), \(entry.context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(reached > 100, "\(reached)")
    }

    /// Fails if a board layout said to hold its profile has a control under
    /// its floor or a phrase tile under the tile floor, in either
    /// direction, gaps under the profile's, or a board that scrolls:
    /// measured from its frames, not from the engine's own check. Fails too
    /// if the late stage's sizes hold in no window, so the check cannot
    /// pass by holding nothing.
    @Test func theRestBoardHoldsOnlyWhereEveryFloorIsMet() {
        var held: [Profile: Int] = [:]
        var faults: [String] = []
        for entry in Self.everyWindow {
            for (profile, layout) in entry.board where layout.holdsProfile {
                held[profile, default: 0] += 1
                func short(_ frame: CGRect, _ floor: CGFloat) -> Bool {
                    frame.width < floor - 0.001 || frame.height < floor - 0.001
                }
                for slot in layout.controls where short(layout.frame(slot), profile.floor(of: slot)) {
                    faults.append("\(slot) \(layout.frame(slot)) (\(profile), \(entry.context))")
                }
                let grid = layout.grid
                for column in 0..<grid.columns where short(grid.tile(row: 0, column: column), profile.tileFloor) {
                    faults.append("tile \(column) \(grid.tile(row: 0, column: column)) (\(profile), \(entry.context))")
                }
                if grid.reflow(in: grid.frame, phraseCount: layout.phraseArea.room).scrolls || !layout.startersFit {
                    faults.append("scrolls (\(profile), \(entry.context))")
                }
                if layout.regionGap < profile.minimumRegionSpacing - 0.001 { faults.append("gap (\(profile), \(entry.context))") }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect((held[.lateStage] ?? 0) > 0 && (held[.eyeTracking] ?? 0) > 0, "\(held)")
    }

    /// Fails if the board's sizes are not the largest of the late stage's
    /// and the smaller ones that hold in the window without losing what
    /// touch's sizes have there with the board (`keepsEverything`), or
    /// touch's. Every third window above.
    @Test func theLargestProfileThatHoldsIsTakenOnTheRestBoard() {
        var faults: [String] = []
        for (index, entry) in Self.everyWindow.enumerated() where index % 3 == 0 {
            let chosen = ProfileChoice.layout(requested: .lateStage, space: entry.space, text: entry.text, modes: .phrasesAndTyping, phraseArea: Self.board)
            let taken = chosen.profile
            let touch = entry.board[.touch]!
            if chosen != entry.board[taken] { faults.append("\(taken)'s frames differ (\(entry.context))") }
            if taken != .touch && !(chosen.holdsProfile && ProfileChoice.keepsEverything(chosen, of: touch)) {
                faults.append("\(taken) does not hold (\(entry.context))")
            }
            for skipped in Profile.lateStage.withSmallerOnes where skipped > taken && skipped != .touch {
                let layout = entry.board[skipped]!
                if layout.holdsProfile && ProfileChoice.keepsEverything(layout, of: touch) {
                    faults.append("\(taken) where \(skipped) holds (\(entry.context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    // MARK: The windows people use

    /// The profile Home has with the six-phrase board in each of
    /// `HomeLayoutEngineTests.windows`, at each text size of
    /// `HomeLayoutEngineTests.textSizes`, smallest first, the same with
    /// Bold Text off and on but where `boardTableWithBoldText` says.
    /// docs/DECISIONS.md, "The late-stage profile", *Where the board's
    /// sizes hold*, has this table.
    static let boardTable: [String: [Profile]] = [
        "iPhone 17": Array(repeating: .touch, count: 5),
        // The board's two rows leave room for head tracking's sizes.
        "iPhone 17 Pro Max": Array(repeating: .headTracking, count: 5),
        "iPhone 16e": Array(repeating: .touch, count: 5),
        "375×667 phone": Array(repeating: .touch, count: 5),
        "375×667 phone, zoomed": Array(repeating: .touch, count: 5),
        "13-inch iPad": Array(repeating: .lateStage, count: 5),
        "13-inch iPad, landscape": Array(repeating: .lateStage, count: 5),
        // As with every category: head tracking's leave no room for typing
        // until touch's leave none either, at AX3; at AX5 they scroll.
        "13-inch iPad, landscape, zoomed": [.touch, .touch, .touch, .headTracking, .touch],
        "11-inch iPad": Array(repeating: .lateStage, count: 5),
        // The late stage's and Eye Tracking's scroll even with the board's
        // two rows, which every category has on four columns too.
        "11-inch iPad, landscape": [.headTracking, .headTracking, .headTracking, .headTracking, .touch],
        // Five columns 130.4 points wide hold Eye Tracking's 109-point
        // controls but not the late stage's 136.
        "iPad mini": Array(repeating: .eyeTracking, count: 5),
        "iPad mini, landscape": Array(repeating: .touch, count: 5),
    ]

    /// Where Bold Text changes what `boardTable` says: on the iPad mini in
    /// portrait, as with every category, Eye Tracking's 15-point gap
    /// leaves columns narrower than the widest bold word.
    static let boardTableWithBoldText: [String: [Profile]] = [
        "iPad mini": Array(repeating: .headTracking, count: 5),
    ]

    /// Fails if a window people use takes other sizes with the board than
    /// `boardTable` says: update the table and the decision then.
    @Test(arguments: HomeLayoutEngineTests.windows.indices)
    func theRestBoardTakesTheSizesTheTableSays(window index: Int) {
        let window = HomeLayoutEngineTests.windows[index]
        let space = HomeLayout.Space(size: window.size, safeArea: .init(top: window.top, leading: 0, bottom: window.bottom, trailing: 0))
        #expect(Self.boardTable[window.name]?.count == HomeLayoutEngineTests.textSizes.count, "\(window.name)")
        for (size, (name, plain)) in HomeLayoutEngineTests.textSizes.enumerated() {
            for boldText in [false, true] {
                let table = (boldText ? Self.boardTableWithBoldText[window.name] : nil) ?? Self.boardTable[window.name] ?? []
                var text = plain
                text.boldText = boldText
                let layout = ProfileChoice.layout(requested: .lateStage, space: space, text: text, modes: .phrasesAndTyping, phraseArea: Self.board)
                let expected = table.indices.contains(size) ? table[size] : .touch
                #expect(layout.profile == expected, "\(window.name), \(name), Bold Text \(boldText)")
            }
        }
    }

    // MARK: Dwell safety on the board

    /// Windows from 320 to 1432 points wide, every `step`, at a small
    /// phone's, a large phone's and every iPad's height in both
    /// orientations, at three text sizes, Bold Text off, with the board's
    /// layout `ProfileChoice` gives when the late stage's sizes are asked
    /// for, where it is `profile`'s.
    static func boardWindows(_ profile: Profile, every step: CGFloat)
        -> [(layout: HomeLayout, space: HomeLayout.Space, text: HomeLayout.Text, context: String)] {
        var found: [(HomeLayout, HomeLayout.Space, HomeLayout.Text, String)] = []
        for (name, text) in [("default", HomeLayoutEngineTests.defaultText), ("xxxLarge", HomeLayoutEngineTests.largerText), ("AX5", HomeLayoutEngineTests.largestText)] {
            for height: CGFloat in [667, 744, 834, 874, 956, 1032, 1133, 1210, 1376] {
                for width in stride(from: CGFloat(320), through: 1432, by: step) {
                    let phone = width < 600
                    let safeArea = phone ? HomeLayout.Insets(top: 62, leading: 0, bottom: 34, trailing: 0) : SettingsRowPlaceTests.padSafeArea
                    let space = HomeLayout.Space(size: CGSize(width: width, height: height), safeArea: safeArea)
                    let layout = ProfileChoice.layout(requested: .lateStage, space: space, text: text, modes: .phrasesAndTyping, phraseArea: board)
                    guard layout.profile == profile, layout.startersFit else { continue }
                    found.append((layout, space, text, "\(width)×\(height), \(name), \(profile)"))
                }
            }
        }
        return found
    }

    /// Fails if a chain of held activations on the board's frames meets
    /// anything that speaks, alarms, changes data or moves things unasked,
    /// in any of Home's states on the board, browsing or typing, from any
    /// control chosen or place a look rests, beyond the two findings
    /// touch's frames with every category already have and the engine
    /// tests pin (`ProfileChoiceTests.unexpectedChainFindings`). The board
    /// is each of the four category cells in turn. Fails too if the profile
    /// is taken in too few windows to count.
    @Test(arguments: [Profile.touch, .eyeTracking, .lateStage])
    func noChainOnTheRestBoardMeetsANewHazard(profile: Profile) {
        let windows = Self.boardWindows(profile, every: 64)
        var unexpected: [String] = []
        for (index, (layout, _, _, context)) in windows.enumerated() {
            unexpected += ProfileChoiceTests.unexpectedChainFindings(
                in: layout, typing: index % 2 == 0, restBoard: index % HomeLayout.categoryCapacity, context: context
            )
        }
        let count = unexpected.count
        #expect(count == 0, "first: \(unexpected.first ?? "")")
        #expect(windows.count > 10, "\(windows.count)")
    }

    /// The open hazard (docs/DECISIONS.md, "Home's slot plan", *Open
    /// hazard, not accepted: Yes and No border the message*) on the board:
    /// fails if a look resting on the message meets Yes, No or Again over
    /// more of it than in the same window with every category at the same
    /// sizes, or, in windows at least 744 points tall, as the engine and
    /// profile tests measure, more than touch's frames' worst pinned shares
    /// (68% by centre and 62% by edge on regular widths, 97% and 89% on
    /// compact ones). Shorter windows can pass those with every category
    /// too: the engine tests measure them at one height.
    @Test(arguments: [Profile.touch, .eyeTracking, .lateStage])
    func yesAndNoBorderNoMoreOfTheMessageOnTheRestBoard(profile: Profile) {
        var faults: [String] = []
        for (layout, space, text, context) in Self.boardWindows(profile, every: 32) {
            let share = Nearest.speakingShare(of: layout)
            let without = Nearest.speakingShare(of: HomeLayout(space: space, profile: profile, text: text, modes: .phrasesAndTyping))
            if share.centre > without.centre + 0.0001 || share.edge > without.edge + 0.0001 {
                faults.append("\(share), \(without) with every category (\(context))")
            }
            let pinned = layout.isRegular ? (centre: 0.68, edge: 0.62) : (centre: 0.97, edge: 0.89)
            if space.size.height >= 744 && (share.centre > pinned.centre || share.edge > pinned.edge) {
                faults.append("\(share) (\(context))")
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// The board is chosen in Settings and shows when Settings closes, so
    /// Settings opened over Home with every category can close onto the
    /// board, and the other way round, at any profile the window can have.
    /// Fails if Back to Talking is not touch's frame with every category in
    /// every one of them, or if a look still resting anywhere on it meets
    /// anything but Phrases, by centre or by edge, on any of them. Phones
    /// and iPads, at every text size.
    @Test func closingSettingsOntoTheRestBoardMeetsOnlyPhrases() {
        var windows = 0
        var faults: [String] = []
        for (name, text) in HomeLayoutEngineTests.textSizes {
            for height: CGFloat in [667, 744, 874, 956, 1032, 1133, 1376] {
                for width in stride(from: CGFloat(320), through: 1432, by: 32) {
                    let phone = width < 600
                    let safeArea = phone ? HomeLayout.Insets(top: 62, leading: 0, bottom: 34, trailing: 0) : SettingsRowPlaceTests.padSafeArea
                    let space = HomeLayout.Space(size: CGSize(width: width, height: height), safeArea: safeArea)
                    let back = HomeLayout(space: space, text: text, modes: .phrasesAndTyping).backToTalking
                    let layouts = Profile.allCases.flatMap { requested in
                        [HomeLayout.PhraseArea.everyCategory, Self.board].map {
                            ProfileChoice.layout(requested: requested, space: space, text: text, modes: .phrasesAndTyping, phraseArea: $0)
                        }
                    }
                    windows += 1
                    for to in layouts {
                        if to.backToTalking != back { faults.append("\(to.backToTalking), touch's \(back) (\(to.profile), \(to.phraseArea), \(width)×\(height), \(name))") }
                        let controls = Dictionary(uniqueKeysWithValues: to.controls.filter { $0 != .stop }.map { ($0.description, to.frame($0)) })
                        for point in ChainEngine.points(across: back) {
                            let met = ChainEngine.nearest(to: point, among: controls)
                            if met.byCentre != ["phrases"] || met.byEdge != ["phrases"] {
                                faults.append("\(met) at \(point) onto \(to.profile), \(to.phraseArea) (\(width)×\(height), \(name))")
                            }
                        }
                    }
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(windows > 500, "\(windows)")
    }

    /// Settings over the board's Home: Settings' places come from Home's
    /// frames (`SettingsCover`), so they follow the board. Fails if any
    /// chain through Settings' first screen, Family Setup, the first step
    /// and the guide's cover closes Settings under the look, meets anything
    /// new or saves an answer, as the swept windows with every category do
    /// not, in phone and iPad windows at the board's sizes.
    @Test func noSettingsChainOverTheRestBoardClosesSettingsOrSavesAnAnswer() {
        let categories = (1...HomeLayout.categoryCapacity).map { "category \($0)" }
        var scored = 0
        var faults: [String] = []
        let sizes = [CGSize(width: 402, height: 874), CGSize(width: 440, height: 956), CGSize(width: 375, height: 667)]
            + [744, 1032, 1133, 1376].flatMap { height in stride(from: CGFloat(600), through: 1432, by: 64).map { CGSize(width: $0, height: height) } }
        for (name, text) in HomeLayoutEngineTests.textSizes where ["default", "AX3", "AX5"].contains(name) {
            for (index, size) in sizes.enumerated() {
                let phone = size.width < 600
                let safeArea = phone ? HomeLayout.Insets(top: 62, leading: 0, bottom: 34, trailing: 0) : SettingsRowPlaceTests.padSafeArea
                let context = "\(size.width)×\(size.height), \(name)"
                let window = SettingsRowPlaceTests.Window(
                    size: size, safeArea: safeArea, text: text, context: context, requested: .lateStage, phraseArea: Self.board
                )
                guard window.home.startersFit else { continue }
                scored += 1
                let board = index % HomeLayout.categoryCapacity
                let atRest = HomeChains.name(of: HomeChains.atRest(categoryCount: categories.count, restBoard: board), categories: categories)
                let place = window.place(text: text)
                let swept = SettingsChainsTests.SweptFamilySetup(window, text: text, row: place.row)
                let map = HomeLayoutEngineTests.chainMap(window.home, typing: true, restBoard: board)
                    .merging(SettingsChains.map(swept.screens, closingOnto: atRest).map)
                let found = ChainFinding.findings(in: map.hazards(from: SettingsChains.starts(in: map, home: atRest)))
                if !found.isEmpty { faults.append("\(found.map(\.path)) (\(context), \(window.home.profile))") }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(scored > 20, "\(scored)")
    }

    // MARK: Reserved regions

    /// Fails if a window with a fold or a camera across Home lays the board
    /// out in other frames than touch's with every category, which no fold
    /// check has measured, or takes a larger profile.
    @Test func aFoldOrACameraShowsTheBoardInEveryCategorysFrames() {
        let size = CGSize(width: 1032, height: 1376)
        let fold = HomeLayout.ReservedRegion(kind: .division, frame: CGRect(x: 0, y: 680, width: size.width, height: 16))
        let camera = HomeLayout.ReservedRegion(kind: .occlusion, frame: CGRect(x: 480, y: 0, width: 72, height: 60))
        let text = HomeLayoutEngineTests.defaultText
        for regions in [[fold], [camera], [fold, camera]] {
            let space = HomeLayout.Space(size: size, safeArea: SettingsRowPlaceTests.padSafeArea, regions: regions)
            let touch = HomeLayout(space: space, text: text, modes: .phrasesAndTyping)
            let board = HomeLayout(space: space, text: text, largestCategory: 6, modes: .phrasesAndTyping, phraseArea: Self.board)
            #expect(board.phraseArea == .everyCategory, "\(regions)")
            for slot in board.slots where slot != .phraseGrid {
                #expect(board.frame(slot) == touch.frame(slot), "\(slot) \(regions)")
            }
            #expect(ProfileChoice.layout(requested: .lateStage, space: space, text: text, modes: .phrasesAndTyping, phraseArea: Self.board).profile == .touch)
        }
        // The same window without them takes the late stage's.
        let clear = HomeLayout.Space(size: size, safeArea: SettingsRowPlaceTests.padSafeArea)
        #expect(ProfileChoice.layout(requested: .lateStage, space: clear, text: text, modes: .phrasesAndTyping, phraseArea: Self.board).profile == .lateStage)
    }
}

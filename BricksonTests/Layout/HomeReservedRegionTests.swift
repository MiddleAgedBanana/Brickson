import Foundation
import Testing
@testable import Brickson

/// Reproductions from the recorded window geometry, independent of a
/// device model (docs/work/layout-engine.md, "A fold").
nonisolated struct HomeReservedRegionTests {
    private static let defaultText = HomeLayout.Text(
        quickControlLine: 25, categoryLine: 22,
        messageLine: 35, statusLine: 19
    )

    /// Same measured 58×37 camera size, translated within synthetic window
    /// inputs so the optional 8pt clearance leaves exactly the old mode
    /// minimum. These are allocator reproductions, not observed OS poses.
    static func modeWordGapSpace(boldText: Bool) -> HomeLayout.Space {
        HomeLayout.Space(
            size: CGSize(width: boldText ? 858 : 842, height: 669),
            safeArea: .init(top: 0, leading: 0, bottom: 34, trailing: 84),
            regions: [
                .init(kind: .division, frame: CGRect(x: 455.5, y: 0, width: 40, height: 669), isActive: false),
                .init(kind: .occlusion, frame: CGRect(x: boldText ? 598 : 590, y: 21, width: 58, height: 37), isActive: false),
            ]
        )
    }

    /// Fails if the interval fitter accepts the old 86/94pt mode widths.
    /// The independent 89/97 Phrases and 60/65 Type fixtures are from the
    /// dated native font probe with actual 6pt sides and WordFit slack,
    /// not from MinimumWidths. Rejection is allowed; false fit is not.
    @Test func cameraGapsCannotClaimModeWordsFitBelowTheirNativeFloors() {
        for (boldText, phrasesFloor, typeFloor) in [(false, CGFloat(89), CGFloat(60)), (true, CGFloat(97), CGFloat(65))] {
            var text = Self.defaultText
            text.boldText = boldText
            let layout = HomeLayout(space: Self.modeWordGapSpace(boldText: boldText), text: text, modes: .phrasesAndTyping)
            let accepted = layout.controlsFit && layout.reservationIssues.isEmpty
            #expect(!accepted || layout.frame(.phrases).width >= phrasesFloor)
            #expect(!accepted || layout.frame(.type).width >= typeFloor)
        }
    }

    /// Fails if the engine only reports a division or inactive camera
    /// instead of reserving space for it: the original regular allocation
    /// crosses the division with its message and controls, and places the
    /// mode controls across the camera. D's outer bounds contain a scroll
    /// view, so this static-frame reproduction excludes that region.
    @Test func staticHomeFramesAvoidTheDivisionAndInactiveCamera() {
        let reserved = [
            CGRect(x: 455.5, y: 0, width: 40, height: 669),
            CGRect(x: 677.3333333333334, y: 21, width: 58, height: 37),
        ]
        let layout = HomeLayout(
            space: .init(
                size: CGSize(width: 951, height: 669),
                safeArea: .init(top: 0, leading: 0, bottom: 34, trailing: 84),
                reservedRegions: reserved
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        let occupied = layout.slots.filter { $0 != .phraseGrid }
        let crossed = occupied.filter { slot in
            reserved.contains { Self.overlaps(layout.frame(slot), $0) }
        }
        #expect(crossed.isEmpty, "Static slots crossing a reserved region: \(crossed)")
    }

    /// Fails if a division clipped to a pane's outer margin is discarded
    /// when choosing phrase columns. The controls already clear this
    /// rectangle, but the division still requires an even column count;
    /// this width holds two columns at their existing word/target floors.
    @Test func aClippedDivisionKeepsThePanesPhraseColumnsEven() {
        let layout = HomeLayout(
            space: .init(
                size: CGSize(width: 469, height: 669),
                safeArea: .init(top: 0, leading: 0, bottom: 34, trailing: 0),
                reservedRegions: [CGRect(x: 455.5, y: 0, width: 13.5, height: 669)]
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(layout.grid.columns == 2)
    }

    struct Expected: Sendable {
        let viewport: CGRect
        let columns: Int
        let floor: CGFloat
        let tileHeight: CGFloat
        let scroll: CGFloat
        let whole: Int
        let typing: Bool
    }

    struct Scenario: Sendable {
        let name: String
        let size: CGSize
        let safe: HomeLayout.Insets
        let regions: [HomeLayout.ReservedRegion]
        let normal: Expected
        let largest: Expected

        func layout(text: HomeLayout.Text, phrases: Int = HomeLayout.referencePhraseCount) -> HomeLayout {
            HomeLayout(space: .init(size: size, safeArea: safe, regions: regions),
                text: text, largestCategory: phrases, modes: .phrasesAndTyping)
        }
    }

    /// Expected outputs pin the Spec's recorded spaces and outward whole-
    /// point enclosure, after the native fractional-boundary reproduction.
    /// These are fixtures, never a production table of devices.
    private static let scenarios: [Scenario] = [
        Scenario(name: "open-wide-default", size: CGSize(width: 951.0, height: 669.0),
            safe: .init(top: 0.0, leading: 0.0, bottom: 34.0, trailing: 84.0),
            regions: [.init(kind: .division, frame: CGRect(x: 455.5, y: 0.0, width: 40.0, height: 669.0), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 677.3333333333334, y: 21.0, width: 58.0, height: 37.0), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 867.0, y: 0.0, width: 84.0, height: 124.0), isActive: false)],
            normal: Expected(viewport: CGRect(x: 16.0, y: 313.0, width: 835.0, height: 314.0), columns: 4, floor: 100.0, tileHeight: 153.0, scroll: 0.0, whole: 8, typing: true),
            largest: Expected(viewport: CGRect(x: 16.0, y: 485.0, width: 835.0, height: 142.0), columns: 4, floor: 100.0, tileHeight: 100.0, scroll: 66.0, whole: 4, typing: false)),
        Scenario(name: "open-wide-reverse-ax5", size: CGSize(width: 951.0, height: 669.0),
            safe: .init(top: 0.0, leading: 0.0, bottom: 34.0, trailing: 84.0),
            regions: [.init(kind: .division, frame: CGRect(x: 455.5, y: 0.0, width: 40.0, height: 669.0), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 215.66666666666666, y: 611.0, width: 57.99999999999997, height: 37.0), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 867.0, y: 0.0, width: 84.0, height: 124.0), isActive: false)],
            normal: Expected(viewport: CGRect(x: 16.0, y: 313.0, width: 835.0, height: 298.0), columns: 4, floor: 100.0, tileHeight: 145.0, scroll: 0.0, whole: 8, typing: true),
            largest: Expected(viewport: CGRect(x: 16.0, y: 485.0, width: 835.0, height: 126.0), columns: 4, floor: 100.0, tileHeight: 100.0, scroll: 82.0, whole: 4, typing: false)),
        Scenario(name: "open-tall-default", size: CGSize(width: 669.0, height: 951.0),
            safe: .init(top: 82.0, leading: 0.0, bottom: 34.0, trailing: 0.0),
            regions: [.init(kind: .division, frame: CGRect(x: 0.0, y: 455.5, width: 669.0, height: 40.0), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 611.0, y: 677.3333333333334, width: 37.0, height: 58.0), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 525.0, y: 0.0, width: 144.0, height: 82.0), isActive: false)],
            normal: Expected(viewport: CGRect(x: 16.0, y: 556.0, width: 595.0, height: 353.0), columns: 4, floor: 78.0, tileHeight: 172.0, scroll: 0.0, whole: 8, typing: true),
            largest: Expected(viewport: CGRect(x: 16.0, y: 759.0, width: 637.0, height: 150.0), columns: 4, floor: 78.0, tileHeight: 78.0, scroll: 14.0, whole: 4, typing: false)),
        Scenario(name: "open-tall-reverse-default", size: CGSize(width: 669.0, height: 951.0),
            safe: .init(top: 82.0, leading: 0.0, bottom: 34.0, trailing: 0.0),
            regions: [.init(kind: .division, frame: CGRect(x: 0.0, y: 455.5, width: 669.0, height: 40.0), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 21.0, y: 215.66666666666666, width: 37.0, height: 57.99999999999997), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 525.0, y: 0.0, width: 144.0, height: 82.0), isActive: false)],
            normal: Expected(viewport: CGRect(x: 16.0, y: 556.0, width: 637.0, height: 353.0), columns: 4, floor: 78.0, tileHeight: 172.0, scroll: 0.0, whole: 8, typing: true),
            largest: Expected(viewport: CGRect(x: 16.0, y: 759.0, width: 637.0, height: 150.0), columns: 4, floor: 78.0, tileHeight: 78.0, scroll: 14.0, whole: 4, typing: false)),
        Scenario(name: "split-left-wide-default", size: CGSize(width: 469.0, height: 669.0),
            safe: .init(top: 0.0, leading: 0.0, bottom: 34.0, trailing: 0.0),
            regions: [.init(kind: .division, frame: CGRect(x: 455.5, y: 0.0, width: 13.5, height: 669.0), isActive: false)],
            normal: Expected(viewport: CGRect(x: 16.0, y: 377.0, width: 437.0, height: 250.0), columns: 2, floor: 56.0, tileHeight: 56.0, scroll: 0.0, whole: 8, typing: true),
            largest: Expected(viewport: CGRect(x: 16.0, y: 572.0, width: 437.0, height: 55.0), columns: 2, floor: 56.0, tileHeight: 56.0, scroll: 193.0, whole: 0, typing: false)),
        Scenario(name: "split-right-wide-reverse-default", size: CGSize(width: 469.0, height: 669.0),
            safe: .init(top: 0.0, leading: 0.0, bottom: 34.0, trailing: 84.0),
            regions: [.init(kind: .division, frame: CGRect(x: 0.0, y: 0.0, width: 13.5, height: 669.0), isActive: false), .init(kind: .occlusion, frame: CGRect(x: 385.0, y: 0.0, width: 84.0, height: 124.0), isActive: false)],
            normal: Expected(viewport: CGRect(x: 16.0, y: 326.0, width: 353.0, height: 301.0), columns: 2, floor: 56.0, tileHeight: 69.0, scroll: 0.0, whole: 8, typing: true),
            largest: Expected(viewport: CGRect(x: 16.0, y: 572.0, width: 353.0, height: 55.0), columns: 2, floor: 56.0, tileHeight: 56.0, scroll: 193.0, whole: 0, typing: false)),
    ]

    /// Fails if a resolved lane, viewport, floor or keyboard decision
    /// diverges from the recorded Spec, including a hidden below-floor fix.
    @Test(arguments: scenarios)
    func recordedGeometryKeepsItsCapacityAndFloors(scenario: Scenario) {
        for (text, expected) in [(Self.defaultText, scenario.normal), (HomeLayoutEngineTests.largestText, scenario.largest)] {
            let layout = scenario.layout(text: text)
            let grid = layout.grid
            let context = scenario.name + " at line height \(text.quickControlLine)"
            #expect(layout.reservationIssues.isEmpty, "\(context): \(layout.reservationIssues)")
            Self.expectClose(grid.frame, expected.viewport, "\(context)")
            #expect(grid.columns == expected.columns, "\(context)")
            #expect(abs(grid.tileFloor - expected.floor) < 0.001, "\(context)")
            #expect(abs(grid.tileSize.height - expected.tileHeight) < 0.001, "\(context)")
            #expect(abs(grid.shortfall - expected.scroll) < 0.001, "\(context)")
            #expect(layout.offersTyping == expected.typing, "\(context)")
            #expect(layout.startersFit == (expected.scroll == 0), "\(context)")
            let whole = (0..<HomeLayout.referencePhraseCount).filter { index in
                let tile = grid.tile(row: index / grid.columns, column: index % grid.columns)
                return tile.minY >= grid.frame.minY && tile.maxY <= grid.frame.maxY
            }.count
            #expect(whole == expected.whole, "\(context)")
            #expect(grid.columnFrames.count == grid.columns, "\(context)")
            #expect(grid.columnFrames.allSatisfy { $0.width >= 44 }, "\(context)")
        }
    }

    /// Fails if allocation starts considering activity and moves controls
    /// when an inactive camera/division becomes active. Bold Text and all
    /// five validated text metrics exercise both width and height inputs.
    @Test(arguments: scenarios)
    func activatingReportedRegionsDoesNotMoveAnything(scenario: Scenario) {
        for (_, measured) in HomeLayoutEngineTests.textSizes {
            for bold in [false, true] {
                var text = measured
                text.boldText = bold
                let inactive = scenario.layout(text: text)
                let activeRegions = scenario.regions.map { region in
                    var active = region
                    active.isActive = true
                    return active
                }
                let active = HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe, regions: activeRegions),
                    text: text, modes: .phrasesAndTyping)
                #expect(active.frames == inactive.frames, "\(scenario.name)")
                #expect(active.allocationFrames == inactive.allocationFrames, "\(scenario.name)")
                #expect(active.grid == inactive.grid, "\(scenario.name)")
                #expect(active.backToTalking == inactive.backToTalking, "\(scenario.name)")
            }
        }
    }

    /// Fails if two equally invalid activity layouts are mistaken for a
    /// pass. Every recorded space must clear its static targets at all
    /// five validated text metrics, with Bold Text off/on, at its actual
    /// word/target floors. Optional growth is the available sizing budget.
    @Test(arguments: scenarios)
    func everyMeasuredTextSizeAndBoldTextKeepsTargetsClear(scenario: Scenario) {
        for (name, measured) in HomeLayoutEngineTests.textSizes {
            for bold in [false, true] {
                var text = measured
                text.boldText = bold
                let layout = scenario.layout(text: text)
                let context = "\(scenario.name), \(name), Bold Text \(bold)"
                #expect(layout.reservationIssues.isEmpty, "\(context): \(layout.reservationIssues)")
                for slot in layout.slots where slot != .phraseGrid {
                    let frame = layout.frame(slot)
                    #expect(!scenario.regions.contains { Self.overlaps(frame, $0.frame) }, "\(context), \(slot)")
                    #expect(layout.allocation(slot).insetBy(dx: -0.001, dy: -0.001).contains(frame), "\(context), \(slot)")
                    let minimum = HomeLayout.MinimumWidths.forBoldText(bold)
                    let wordWidth: CGFloat
                    switch slot {
                    case .message, .statusLine: wordWidth = minimum.message
                    case .yes, .no: wordWidth = minimum.yesNo
                    case .emergency: wordWidth = minimum.emergency
                    case .again: wordWidth = minimum.again
                    case .getAttention: wordWidth = frame.height < HomeLayout.twoLineQuickControlHeight ? minimum.getAttentionOneLine : minimum.getAttention
                    case .phrases: wordWidth = minimum.phrases
                    case .type: wordWidth = minimum.type
                    case .stop: wordWidth = minimum.stop
                    case .category: wordWidth = minimum.category
                    case .settings: wordWidth = layout.settingsShowsName ? minimum.settings : minimum.settingsSymbol
                    case .phraseGrid: wordWidth = 0
                    }
                    #expect(frame.width >= wordWidth - 0.001, "\(context), \(slot) word floor")
                    if slot == .message {
                        #expect(frame.height >= 2 * text.messageLine - 0.001, "\(context)")
                    } else if slot == .statusLine {
                        #expect(frame.height >= text.statusLine - 0.001, "\(context)")
                    } else {
                        let quick = HomeLayout.Slot.safetyRow.contains(slot) || [.phrases, .type].contains(slot)
                        let line = quick ? text.quickControlLine : text.categoryLine
                        #expect(frame.width >= 44 && frame.height >= max(44, line + 12) - 0.001, "\(context), \(slot)")
                    }
                }
                let grid = layout.grid
                let floors = layout.isRegular ? HomeLayout.regularTile.floors : HomeLayout.compactTile.floors
                let minimum = layout.isRegular ? (bold ? HomeLayout.regularTile.boldMinimumWidth : HomeLayout.regularTile.minimumWidth)
                    : (bold ? HomeLayout.compactTile.boldMinimumWidth : HomeLayout.compactTile.minimumWidth)
                let required = grid.columnFrames.map { HomeLayout.TileFloor.height(for: $0.width, in: floors, boldText: bold, profileFloor: 44) }.max()!
                #expect(grid.columnFrames.allSatisfy { $0.width >= minimum - 0.001 }, "\(context)")
                #expect(grid.columns.isMultiple(of: 2), "\(context)")
                #expect(grid.tileFloor == required && grid.tileSize.height >= required, "\(context)")
            }
        }
    }

    /// Fails if a zero-area or edge-clipped inactive division is lost
    /// before the column decision. Positive overlap controls gaps only.
    @Test func aZeroWidthInactiveDivisionStillRequiresEvenColumns() {
        let space = HomeLayout.Space(size: CGSize(width: 469, height: 669),
            safeArea: .init(top: 0, leading: 0, bottom: 34, trailing: 0),
            regions: [.init(kind: .division, frame: CGRect(x: 455.5, y: 0, width: 0, height: 669), isActive: false)])
        let layout = HomeLayout(space: space, text: Self.defaultText, modes: .phrasesAndTyping)
        #expect(layout.grid.columns == 2)
        #expect(layout.reservationIssues.isEmpty)
        #expect(layout.frames.filter { $0.key != .phraseGrid }
            == HomeLayout(space: .init(size: space.size, safeArea: space.safeArea), text: Self.defaultText, modes: .phrasesAndTyping).frames.filter { $0.key != .phraseGrid })
    }

    /// Fails if a zero-width interior marker is treated as occupied area
    /// and triggers a six-lane allocation or an impossible-space report.
    /// Its presence selects even columns; it consumes no control spacing.
    @Test func anInteriorZeroWidthDivisionDoesNotConsumeControlSpace() {
        let size = CGSize(width: 469, height: 669)
        let safe = HomeLayout.Insets(top: 0, leading: 0, bottom: 34, trailing: 0)
        let clear = HomeLayout(space: .init(size: size, safeArea: safe), text: Self.defaultText, modes: .phrasesAndTyping)
        let marker = HomeLayout(space: .init(size: size, safeArea: safe,
            regions: [.init(kind: .division, frame: CGRect(x: 230, y: 0, width: 0, height: 669), isActive: false)]),
            text: Self.defaultText, modes: .phrasesAndTyping)
        #expect(marker.reservationIssues.isEmpty)
        #expect(marker.slotsInReservedRegions.isEmpty)
        #expect(marker.frames == clear.frames)
        #expect(marker.grid.columns == 2)
    }

    /// Fails if a camera target cut shrinks its allocation, moves a
    /// neighbour, or forgets the explicit 8pt static-control clearance.
    @Test func cameraCutsTargetsInsideUnchangedCells() {
        let scenario = Self.scenarios[0]
        let withCamera = scenario.layout(text: Self.defaultText)
        let divisionOnly = HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe,
            regions: scenario.regions.filter { $0.kind == .division }), text: Self.defaultText, modes: .phrasesAndTyping)
        #expect(withCamera.allocationFrames == divisionOnly.allocationFrames)
        #expect(withCamera.frame(.phrases).width < withCamera.allocation(.phrases).width)
        #expect(abs(withCamera.frame(.phrases).maxX + 8 - 677.3333333333334) < 0.001)
        for slot in HomeLayout.Slot.safetyRow + HomeLayout.Slot.categoriesRegion {
            #expect(withCamera.frame(slot) == divisionOnly.frame(slot))
        }
        #expect(abs(withCamera.horizontalGap(from: .no, to: .again) - 41) < 0.001)
        #expect(abs(withCamera.horizontalGap(from: .emergency, to: .yes) - 8) < 0.001)
    }

    /// Fails if a greedy first camera cut discards the only interval that
    /// clears every occlusion. The two input orders must choose the same
    /// valid 176pt interval, including the preferred 8pt clearance.
    @Test func multipleOcclusionsChooseTheSameValidIntervalInEitherOrder() {
        let scenario = Self.scenarios[0]
        let division = scenario.regions.filter { $0.kind == .division }
        let occlusions: [HomeLayout.ReservedRegion] = [
            .init(kind: .occlusion, frame: CGRect(x: 200, y: 21, width: 20, height: 37)),
            .init(kind: .occlusion, frame: CGRect(x: 350, y: 21, width: 20, height: 37)),
        ]
        let layouts = [occlusions, Array(occlusions.reversed())].map { ordering in
            HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe, regions: division + ordering),
                text: Self.defaultText, modes: .phrasesAndTyping)
        }
        for layout in layouts {
            #expect(layout.reservationIssues.isEmpty)
            #expect(layout.frame(.message).minX == 16 && layout.frame(.message).width == 176)
            for slot in layout.slots where slot != .phraseGrid {
                #expect(!occlusions.contains { Self.overlaps(layout.frame(slot), $0.frame) }, "\(slot)")
            }
        }
        #expect(layouts[0].frames == layouts[1].frames)
        #expect(layouts[0].allocationFrames == layouts[1].allocationFrames)
    }

    /// Fails if the wider legacy column determines Get Attention's height
    /// after an off-centre division gives it a narrower final lane. This
    /// narrow lane holds the words on two lines, requiring the existing 64pt
    /// floor; the final safety band then cannot offer the keyboard.
    @Test func aResizedDivisionRecomputesGetAttentionsTwoLineFloor() {
        let layout = HomeLayout(space: .init(size: CGSize(width: 839, height: 669),
            safeArea: .init(top: 0, leading: 0, bottom: 34, trailing: 84),
            regions: [.init(kind: .division, frame: CGRect(x: 455.5, y: 0, width: 40, height: 669))]),
            text: Self.defaultText, modes: .phrasesAndTyping)
        let attention = layout.frame(.getAttention)
        let minimum = HomeLayout.MinimumWidths.regular
        #expect(attention.width < minimum.getAttentionOneLine && attention.width >= minimum.getAttention)
        #expect(attention.height >= HomeLayout.twoLineQuickControlHeight)
        #expect(layout.reservationIssues.isEmpty)
        #expect(!layout.offersTyping)
    }

    /// Fails if an exterior-only reservation re-reports an existing narrow
    /// message limitation and changes controlsFit, despite requiring no
    /// interior allocation. Compare the complete result, not just frames.
    @Test func exteriorOnlyOcclusionsPreserveTheCompleteLegacyResult() {
        let size = CGSize(width: 320, height: 874)
        let safe = HomeLayout.Insets(top: 20, leading: 0, bottom: 0, trailing: 0)
        var text = Self.defaultText
        text.boldText = true
        let clear = HomeLayout(space: .init(size: size, safeArea: safe), text: text, modes: .phrasesAndTyping)
        let exterior = HomeLayout(space: .init(size: size, safeArea: safe,
            regions: [.init(kind: .occlusion, frame: CGRect(x: 0, y: 0, width: 320, height: 20))]),
            text: text, modes: .phrasesAndTyping)
        #expect(clear.controlsFit)
        #expect(!clear.messageHoldsItsWords)
        #expect(exterior == clear)
    }

    /// Fails if a fractional division boundary is used as an exact target
    /// edge. Standard containers can round that edge into the API region;
    /// enclose positive divisions outward in whole points before sizing,
    /// without consulting display scale or changing the raw input frame.
    @Test func fractionalDivisionEdgesAreEnclosedBeforeAllocatingTargets() {
        for scenario in [Self.scenarios[0], Self.scenarios[2]] {
            let division = scenario.regions.first { $0.kind == .division }!.frame
            let enclosure = division.integral
            for text in [Self.defaultText, HomeLayoutEngineTests.largestText] {
                let layout = scenario.layout(text: text)
                for slot in layout.slots where slot != .phraseGrid {
                    #expect(!Self.overlaps(layout.frame(slot), enclosure), "\(scenario.name), \(slot)")
                }
                for index in 0..<HomeLayout.referencePhraseCount {
                    let grid = layout.grid
                    let tile = grid.tile(row: index / grid.columns, column: index % grid.columns)
                    #expect(!Self.overlaps(tile.intersection(grid.frame), enclosure), "\(scenario.name), tile \(index)")
                }
            }
        }
    }

    /// Fails if a reservation already in the safe-area strip is charged
    /// again as padding, a camera crop or a changed keyboard decision.
    @Test func safeAreaOcclusionAddsNoSecondInset() {
        let scenario = Self.scenarios[0]
        let clearSpace = HomeLayout.Space(size: scenario.size, safeArea: scenario.safe)
        let clear = HomeLayout(space: clearSpace, text: Self.defaultText, modes: .phrasesAndTyping)
        let status = HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe,
            regions: [.init(kind: .occlusion, frame: CGRect(x: 867, y: 0, width: 84, height: 124))]),
            text: Self.defaultText, modes: .phrasesAndTyping)
        #expect(status.frames == clear.frames)
        #expect(status.allocationFrames == clear.allocationFrames)
        #expect(status.grid == clear.grid)
        #expect(status.backToTalking == clear.backToTalking)
        #expect(status.offersTyping == clear.offersTyping)
    }

    /// Fails if coordinates are treated as reader-local a second time.
    /// Equal content size at a translated safe-area origin, with AX5 at
    /// its floors, must translate the occupied and allocated frames once.
    @Test func aNonzeroContentOriginDoesNotOffsetRegionsTwice() {
        let scenario = Self.scenarios[0]
        let original = scenario.layout(text: HomeLayoutEngineTests.largestText)
        let dx: CGFloat = 30, dy: CGFloat = 24
        let regions = scenario.regions.map {
            HomeLayout.ReservedRegion(kind: $0.kind, frame: $0.frame.offsetBy(dx: dx, dy: dy), isActive: $0.isActive)
        }
        let translated = HomeLayout(space: .init(size: scenario.size,
            safeArea: .init(top: dy, leading: dx, bottom: scenario.safe.bottom - dy, trailing: scenario.safe.trailing - dx),
            regions: regions), text: HomeLayoutEngineTests.largestText, modes: .phrasesAndTyping)
        for slot in original.slots {
            Self.expectClose(translated.frame(slot), original.frame(slot).offsetBy(dx: dx, dy: dy), "occupied \(slot)")
            Self.expectClose(translated.allocation(slot), original.allocation(slot).offsetBy(dx: dx, dy: dy), "allocated \(slot)")
        }
    }

    /// Fails if a grown library enters the sizing decision above D and
    /// moves any target, rather than adding only phrase rows at the floor.
    @Test(arguments: scenarios)
    func addingPhrasesNeverMovesTheControls(scenario: Scenario) {
        for text in [Self.defaultText, HomeLayoutEngineTests.largestText] {
            let starter = scenario.layout(text: text)
            let grown = scenario.layout(text: text, phrases: 40)
            #expect(grown.frames == starter.frames, "\(scenario.name)")
            #expect(grown.allocationFrames == starter.allocationFrames, "\(scenario.name)")
            #expect(grown.grid.columnFrames == starter.grid.columnFrames, "\(scenario.name)")
            #expect(grown.grid.rows > starter.grid.rows, "\(scenario.name)")
            #expect(grown.grid.tileSize.height >= grown.grid.tileFloor, "\(scenario.name)")
        }
    }

    /// Fails if warning reflow rebuilds equal columns, recentres lanes,
    /// reclaims a cropped camera strip, or clears only scroll offset zero.
    /// Visible tile intersections are checked; full clipped accessibility
    /// targets still require the deferred physical-device check.
    @Test(arguments: scenarios)
    func warningReflowRetainsExclusionsWhileTheLibraryScrolls(scenario: Scenario) {
        let layout = scenario.layout(text: HomeLayoutEngineTests.largestText, phrases: 40)
        let source = layout.grid
        let local = source.reflow(in: CGRect(x: 0, y: 0, width: source.frame.width, height: max(0, source.frame.height - 30)), phraseCount: 40)
        let oversized = source.reflow(in: CGRect(x: 0, y: 0, width: source.frame.width + 100, height: source.frame.height + 100), phraseCount: 40)
        #expect(local.columns == source.columns, "\(scenario.name)")
        #expect(oversized.frame.width == source.frame.width && oversized.frame.height == source.frame.height, "\(scenario.name)")
        for column in 0..<source.columns {
            #expect(local.columnFrames[column].width == source.columnFrames[column].width, "\(scenario.name)")
            #expect(local.columnFrames[column].minX == source.columnFrames[column].minX - source.frame.minX, "\(scenario.name)")
        }
        for offset in [CGFloat(0), 37, local.shortfall] {
            for index in 0..<40 {
                let tile = local.tile(row: index / local.columns, column: index % local.columns, scrollOffset: offset)
                let visible = tile.intersection(local.frame).offsetBy(dx: source.frame.minX, dy: source.frame.minY)
                #expect(!scenario.regions.contains { Self.overlaps(visible, $0.frame) }, "\(scenario.name)")
            }
        }
    }

    /// Fails if a hypothetical uniform/average width replaces the actual
    /// narrow right lanes and gives every row the wider lanes' 72pt floor.
    @Test func theCommonPhraseFloorUsesEveryActualLane() {
        let grid = Self.scenarios[0].layout(text: Self.defaultText).grid
        #expect(abs(grid.columnFrames[0].width - 215.5) < 0.001)
        #expect(abs(grid.columnFrames[2].width - 173.5) < 0.001)
        #expect(grid.tileFloor == 100)
        #expect(grid.tile(row: 0, column: 2).width == grid.columnFrames[2].width)
    }

    /// Fails if A-to-C is compacted even though the later C row is pinned
    /// by the division. That moves Yes toward the message without gaining
    /// any D height. Only B-to-D returns its 2pt growth here.
    @Test func aPinnedLaterRowKeepsTheUpperGapGrowth() {
        let layout = Self.scenarios[2].layout(text: HomeLayoutEngineTests.largestText)
        #expect(layout.regionGaps.aToC == 12)
        #expect(layout.regionGaps.cToB == 12)
        #expect(layout.regionGaps.bToD == 10)
        #expect(layout.frame(.yes).minY == 308)
        #expect(layout.grid.frame.minY == 759)
    }

    /// Fails if the generic A-growth return stops at 26.5pt, ignoring the
    /// distance tie allowance, or if a fixed default-size case bypasses
    /// the conservative well-envelope sizing constraint.
    @Test func theWellBoundSelectsTheFirstSafeHalfPointReturn() {
        let scenario = Self.scenarios[2]
        let base = HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe), text: Self.defaultText, modes: .phrasesAndTyping)
        let layout = scenario.layout(text: Self.defaultText)
        #expect(layout.frame(.phrases).height == 50.5)
        #expect(HomeWellEnvelope.preserves(base.frames, layout.frames))
        var tooNear = layout.frames
        for slot in [HomeLayout.Slot.again, .getAttention] { tooNear[slot] = tooNear[slot]!.offsetBy(dx: 0, dy: 0.5) }
        #expect(!HomeWellEnvelope.preserves(base.frames, tooNear))
        #expect(layout.frame(.message).height >= 2 * Self.defaultText.messageLine)
    }

    /// Fails if intermediate metrics are declared unsupported after A's
    /// smaller growth budget is exhausted, or if primary/category floors
    /// are consumed rather than their optional growth. These expected
    /// frames follow the same well bound as the default/AX5 fixtures.
    @Test func intermediateTextReturnsOrdinaryPrimaryGrowthAfterAGrowth() {
        let ax1 = HomeLayoutEngineTests.textSizes.first { $0.name == "AX1" }!.text
        let cases: [(HomeLayout.Text, CGFloat, CGFloat, CGFloat)] = [
            (HomeLayoutEngineTests.largerText, 53.5, 60, 21),
            (ax1, 60.75, 50.5, 6.5),
        ]
        for scenario in [Self.scenarios[2], Self.scenarios[3]] {
            for (measured, modeHeight, primaryHeight, returnedA) in cases {
                for bold in [false, true] {
                    var text = measured
                    text.boldText = bold
                    let base = HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe), text: text, modes: .phrasesAndTyping)
                    let layout = scenario.layout(text: text)
                    #expect(layout.reservationIssues.isEmpty)
                    #expect(layout.frame(.phrases).height == modeHeight)
                    #expect(layout.quickControlHeight == primaryHeight)
                    #expect(layout.categoryHeight == 48)
                    #expect(2 * (base.frame(.phrases).height - modeHeight) == returnedA)
                    #expect(layout.frame(.stop).minY == 407)
                    #expect(layout.frame(.category(2)).minY == 496)
                    #expect(layout.grid.frame.minY == 556)
                    #expect(HomeWellEnvelope.preserves(base.frames, layout.frames))
                }
            }
        }
    }

    /// Fails if Type or Back keeps a decision/frame from before the
    /// division/camera geometry was resolved.
    @Test func keyboardAndBackUseTheFinalOccupiedFrames() {
        let tall = Self.scenarios[2].layout(text: HomeLayoutEngineTests.largestText)
        #expect(tall.frame(.getAttention).maxY == 575)
        #expect(!tall.offersTyping)
        for scenario in Self.scenarios {
            let layout = scenario.layout(text: Self.defaultText)
            #expect(layout.frame(.phrases).contains(layout.backToTalking), "\(scenario.name)")
            #expect(layout.backToTalking.width >= 44 && layout.backToTalking.height >= 44, "\(scenario.name)")
        }
    }

    /// Fails if an interior horizontal division in D is silently treated
    /// as a content spacer: such a spacer would scroll through the hole.
    /// No unapproved pane/paging or whole-region displacement is selected.
    @Test func aDivisionThroughScrollingContentReportsTheUnresolvedConstraint() {
        let scenario = Self.scenarios[2]
        let layout = HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe,
            regions: [.init(kind: .division, frame: CGRect(x: 0, y: 700, width: 669, height: 40))]),
            text: HomeLayoutEngineTests.largestText, largestCategory: 40, modes: .phrasesAndTyping)
        #expect(layout.reservationIssues.contains(.divisionCrossesScrollingViewport))
        #expect(!layout.controlsFit)
    }

    /// Fails if the empty-input path starts using division recipes,
    /// changes the former three-column phone grid, or creates camera cells.
    @Test func emptyReservationsKeepTheExistingPhoneAndTabletAllocations() {
        for (size, columns) in [(CGSize(width: 402, height: 874), 3), (CGSize(width: 1032, height: 1376), 4)] {
            for (_, text) in HomeLayoutEngineTests.textSizes {
                let clear = HomeLayout(space: .init(size: size), text: text, modes: .phrasesAndTyping)
                let typedEmpty = HomeLayout(space: .init(size: size, regions: []), text: text, modes: .phrasesAndTyping)
                #expect(clear == typedEmpty)
                #expect(clear.grid.columns == columns)
                #expect(clear.frames == clear.allocationFrames)
                #expect(clear.reservationIssues.isEmpty)
            }
        }
    }

    private static func expectClose(_ actual: CGRect, _ expected: CGRect, _ context: String) {
        #expect(abs(actual.minX - expected.minX) < 0.001 && abs(actual.minY - expected.minY) < 0.001
            && abs(actual.width - expected.width) < 0.001 && abs(actual.height - expected.height) < 0.001, "\(context)")
    }

    private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        !a.isEmpty && !b.isEmpty && a.minX < b.maxX && b.minX < a.maxX
            && a.minY < b.maxY && b.minY < a.maxY
    }
}

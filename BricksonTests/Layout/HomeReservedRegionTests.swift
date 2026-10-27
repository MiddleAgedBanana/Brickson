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

    /// Fails if camera fitting adds starter scroll while optional category
    /// growth remains, or if recovery consumes more growth than needed.
    /// The first input is recorded AX3 geometry; the other camera positions
    /// exercise derived recovery and an explicitly unattainable target.
    @Test func cameraCapacityReturnsOnlyTheOptionalGrowthItNeeds() {
        let scenario = Self.scenarios[1]
        let text = HomeLayout.Text(quickControlLine: 53, categoryLine: 49,
            messageLine: 59, statusLine: 44)
        let withoutCamera = HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe,
            regions: scenario.regions.filter { $0.frame.minY != 611 }),
            text: text, modes: .phrasesAndTyping)
        for (cameraTop, categoryHeight, shortfall) in [
            (CGFloat(611), CGFloat(63), CGFloat(0)),
            (610, 62.5, 0), (609, 62, 0), (599, 61, 8),
        ] {
            let regions = scenario.regions.map { region in
                HomeLayout.ReservedRegion(kind: region.kind,
                    frame: region.frame.minY == 611
                        ? region.frame.offsetBy(dx: 0, dy: cameraTop - 611) : region.frame,
                    isActive: region.isActive)
            }
            let layout = HomeLayout(space: .init(size: scenario.size, safeArea: scenario.safe,
                regions: regions), text: text, modes: .phrasesAndTyping)
            #expect(layout.reservationIssues.isEmpty)
            #expect(abs(layout.shortfall - shortfall) < 0.001)
            #expect(abs(layout.categoryHeight - categoryHeight) < 0.001)
            #expect(layout.categoryHeight >= 61)
            #expect(abs(layout.frame(.category(0)).minY - layout.frame(.stop).maxY - 8) < 0.001)
            #expect(abs(layout.grid.frame.minY - layout.frame(.category(0)).maxY - 10) < 0.001)
            #expect(abs(layout.grid.frame.maxY - cameraTop) < 0.001)
            #expect(layout.grid.tileFloor == 100)
            #expect(HomeWellEnvelope.preserves(withoutCamera.frames, layout.frames))
            for slot in [.message, .statusLine, .phrases, .type] + HomeLayout.Slot.safetyRow {
                #expect(layout.frame(slot) == withoutCamera.frame(slot))
            }
            #expect(layout.backToTalking == withoutCamera.backToTalking)
            if shortfall == 0 {
                #expect(!layout.grid.scrolls)
                for index in 0..<HomeLayout.referencePhraseCount {
                    let tile = layout.grid.tile(row: index / layout.grid.columns,
                        column: index % layout.grid.columns)
                    #expect(layout.grid.frame.contains(tile))
                }
            } else {
                #expect(layout.grid.scrolls)
            }
        }
    }

    /// Fails if a grown library enters the sizing decision above D and
    /// moves any target, rather than adding only phrase rows at the floor.
    @Test(arguments: scenarios)
    func addingPhrasesNeverMovesTheControls(scenario: Scenario) {
        for text in HomeLayoutEngineTests.textSizes.map(\.text) {
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
                #expect(clear.firstRegionTopInset == 0)
            }
        }
    }

    /// Returning zero for the first row's displaced origin fails this.
    /// Relative row gaps cannot encode a translation of every row; Home
    /// must reserve the independently known 22pt before drawing region A.
    @Test func aDivisionThroughTheFirstRowKeepsItsInitialTopInset() {
        let layout = HomeLayout(
            space: .init(
                size: CGSize(width: 951, height: 669),
                safeArea: .init(top: 0, leading: 0, bottom: 34, trailing: 84),
                regions: [.init(kind: .division, frame: CGRect(x: 0, y: 20, width: 951, height: 10))]
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(layout.reservationIssues.isEmpty)
        #expect(layout.content.minY == 8)
        #expect(layout.firstRegionTopInset == 22)
        #expect(layout.allocation(.message).minY == 30)
        #expect(layout.frame(.phrases).minY == 30)
        #expect(layout.backToTalking.minY == 30)
    }

    private static func expectClose(_ actual: CGRect, _ expected: CGRect, _ context: String) {
        #expect(abs(actual.minX - expected.minX) < 0.001 && abs(actual.minY - expected.minY) < 0.001
            && abs(actual.width - expected.width) < 0.001 && abs(actual.height - expected.height) < 0.001, "\(context)")
    }

    private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        !a.isEmpty && !b.isEmpty && a.minX < b.maxX && b.minX < a.maxX
            && a.minY < b.maxY && b.minY < a.maxY
    }

    // MARK: Unsatisfiable reservations, edge occlusions and well-envelope edge cases

    /// Pins the `HomeReservedLayout.Issue` failure paths:
    /// - `.insufficientControlSpace` when a vertical division meets a compact
    ///   window, `.phrasesOnly` mode, or a regular window whose side lane is
    ///   narrower than the minimum control widths;
    /// - `.insufficientPhraseWidth` when vertical divisions leave no usable
    ///   phrase lane;
    /// - `.controlCannotAvoidRegion` when an interior occlusion overlaps a
    ///   control slot;
    /// - `.wellEnvelopeCannotBePreserved` when a horizontal division forces
    ///   the safety row down without enough room above it to preserve the
    ///   Stop well's distance envelope;
    /// - `.backToTalkingCannotFit` when a horizontal division crosses
    ///   `backToTalking`.
    @Test func unsatisfiableReservationsReportTheirSpecificIssues() {
        // 1. Vertical division on a compact window -> .insufficientControlSpace
        let compactVertical = HomeLayout(
            space: .init(
                size: CGSize(width: 402, height: 874),
                regions: [.init(kind: .division, frame: CGRect(x: 196, y: 0, width: 10, height: 874))]
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(compactVertical.reservationIssues.contains(.insufficientControlSpace))
        #expect(!compactVertical.controlsFit)

        // 2. Vertical division in .phrasesOnly mode -> .insufficientControlSpace
        let phrasesOnlyVertical = HomeLayout(
            space: .init(
                size: CGSize(width: 951, height: 669),
                regions: [.init(kind: .division, frame: CGRect(x: 428.5, y: 0, width: 10, height: 669))]
            ),
            text: Self.defaultText, modes: .phrasesOnly
        )
        #expect(phrasesOnlyVertical.reservationIssues.contains(.insufficientControlSpace))

        // 3. Vertical division on a regular window with an off-centre narrow lane -> .insufficientControlSpace
        let narrowLaneVertical = HomeLayout(
            space: .init(
                size: CGSize(width: 951, height: 669),
                regions: [.init(kind: .division, frame: CGRect(x: 120, y: 0, width: 10, height: 669))]
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(narrowLaneVertical.reservationIssues.contains(.insufficientControlSpace))

        // 4. Occlusion trimming the phrase grid's width below two columns -> .insufficientPhraseWidth
        let noPhraseWidth = HomeLayout(
            space: .init(
                size: CGSize(width: 402, height: 874),
                regions: [.init(kind: .occlusion, frame: CGRect(x: 0, y: 400, width: 250, height: 474))]
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(noPhraseWidth.reservationIssues.contains(.insufficientPhraseWidth))

        // 5. Interior occlusion overlapping Yes -> .controlCannotAvoidRegion(.yes)
        let basePhone = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874)),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        let yesFrame = basePhone.frame(.yes)
        let occludedYes = HomeLayout(
            space: .init(
                size: CGSize(width: 402, height: 874),
                regions: [.init(kind: .occlusion, frame: yesFrame.insetBy(dx: 4, dy: 4))]
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(occludedYes.reservationIssues.contains(.controlCannotAvoidRegion(.yes)))
        #expect(occludedYes.slotsInReservedRegions.contains(.yes))

        // 6. Horizontal division between the two category rows at largest text -> .wellEnvelopeCannotBePreserved
        let largestPhone = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874)),
            text: HomeLayoutEngineTests.largestText, modes: .phrasesAndTyping
        )
        let brokenEnvelope = HomeLayout(
            space: .init(
                size: CGSize(width: 402, height: 874),
                regions: [.init(kind: .division, frame: CGRect(x: 0, y: largestPhone.frame(.category(0)).maxY, width: 402, height: 30))]
            ),
            text: HomeLayoutEngineTests.largestText, modes: .phrasesAndTyping
        )
        #expect(brokenEnvelope.reservationIssues.contains(.wellEnvelopeCannotBePreserved))

        // 7. Horizontal division crossing the phrase grid -> .divisionCrossesScrollingViewport,
        // while `backToTalking` remains at least `profile.floor` in both dimensions on `.touch`.
        let crossingGrid = HomeLayout(
            space: .init(
                size: CGSize(width: 402, height: 874),
                regions: [.init(kind: .division, frame: CGRect(x: 0, y: 650, width: 402, height: 24))]
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(crossingGrid.reservationIssues.contains(.divisionCrossesScrollingViewport))
        #expect(crossingGrid.backToTalking.width >= HomeLayout.Profile.touch.floor)
        #expect(crossingGrid.backToTalking.height >= HomeLayout.Profile.touch.floor)
        #expect(HomeReservedLayout.Issue.backToTalkingCannotFit != .wellEnvelopeCannotBePreserved)
    }

    /// In `.threeColumns`, a horizontal division crossing the second category
    /// row (`category(2)`, `category(3)`, `settings`) pushes that row and the
    /// phrase grid down while keeping the first category row (`stop`,
    /// `category(0)`, `category(1)`) above the division.
    @Test func horizontalDivisionBetweenThreeColumnCategoryRowsPushesDownSecondRow() {
        let clear = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874)),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(clear.categoryArrangement == .threeColumns)
        let row2MinY = clear.frame(.category(2)).minY
        let division = CGRect(x: 0, y: row2MinY + 2, width: 402, height: 16)
        let divided = HomeLayout(
            space: .init(
                size: CGSize(width: 402, height: 874),
                regions: [.init(kind: .division, frame: division)]
            ),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(divided.frame(.category(0)).maxY <= division.minY)
        #expect(divided.frame(.category(2)).minY >= division.maxY)
        #expect(divided.frame(.category(3)).minY == divided.frame(.category(2)).minY)
        #expect(divided.frame(.settings).minY == divided.frame(.category(2)).minY)
        #expect(divided.categoryRowGaps.count == 1)
        #expect((divided.categoryRowGaps.first ?? 0) > HomeLayout.controlSpacing)
    }

    /// Region D's vertical division chooses 4 columns (2 per side) when each
    /// side lane can hold two regular tile widths, and 2 columns (1 per side)
    /// when a lane is too narrow for two tiles at `boldMinimumWidth`.
    @Test func verticalDivisionChoosesFourOrTwoPhraseColumnsFromLaneWidth() {
        let wide = Self.scenarios[0].layout(text: Self.defaultText)
        #expect(wide.grid.columns == 4)

        var boldLargest = HomeLayoutEngineTests.largestText
        boldLargest.boldText = true
        let narrowBold = HomeLayout(
            space: .init(
                size: CGSize(width: 740, height: 900),
                regions: [.init(kind: .division, frame: CGRect(x: 455, y: 0, width: 40, height: 900))]
            ),
            text: boldLargest, modes: .phrasesAndTyping
        )
        #expect(narrowBold.isRegular)
        #expect(narrowBold.grid.columns == 2)
        #expect(narrowBold.grid.columnFrames.count == 2)
        #expect(narrowBold.grid.columnFrames[0].maxX <= 455)
        #expect(narrowBold.grid.columnFrames[1].minX >= 495)
    }

    /// Region D trims edge occlusions on the top, leading, bottom, and
    /// trailing edges of the phrase grid, and `fitOcclusions` falls back to a
    /// 0pt edge cut when the 8pt clearance cannot fit a control's minimum
    /// width.
    @Test func phraseGridTrimsOcclusionsOnAllFourEdgesAndControlClearanceFallsBackToZero() {
        let base = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874)),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        let grid = base.grid.frame

        let padBase = HomeLayout(
            space: .init(size: CGSize(width: 1032, height: 1376)),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        let padGrid = padBase.grid.frame
        let topOcclusion = CGRect(x: 460, y: padGrid.minY, width: 100, height: 24)
        let topTrimmed = HomeLayout(
            space: .init(size: CGSize(width: 1032, height: 1376), regions: [.init(kind: .occlusion, frame: topOcclusion)]),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(topTrimmed.grid.frame.minY >= topOcclusion.maxY)

        let bottomOcclusion = CGRect(x: grid.minX, y: grid.maxY - 24, width: 80, height: 24)
        let bottomTrimmed = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874), regions: [.init(kind: .occlusion, frame: bottomOcclusion)]),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(bottomTrimmed.grid.frame.maxY <= bottomOcclusion.minY)

        let leadingOcclusion = CGRect(x: grid.minX, y: grid.midY - 20, width: 20, height: 40)
        let leadingTrimmed = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874), regions: [.init(kind: .occlusion, frame: leadingOcclusion)]),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(leadingTrimmed.grid.frame.minX >= leadingOcclusion.maxX)

        let trailingOcclusion = CGRect(x: grid.maxX - 20, y: grid.midY - 20, width: 20, height: 40)
        let trailingTrimmed = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874), regions: [.init(kind: .occlusion, frame: trailingOcclusion)]),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(trailingTrimmed.grid.frame.maxX <= trailingOcclusion.minX)

        // Control occlusion where 0pt clearance fits `needed` (90pt for [.phrases, .type]) but 8pt clearance does not.
        let typeSlot = base.allocation(.type)
        let tightWidth = typeSlot.width - HomeLayout.MinimumWidths.regular.phrases - 3
        let tightOcclusion = CGRect(x: typeSlot.maxX - tightWidth, y: typeSlot.minY, width: tightWidth, height: typeSlot.height)
        let tightLayout = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874), regions: [.init(kind: .occlusion, frame: tightOcclusion)]),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(!tightLayout.reservationIssues.contains(.controlCannotAvoidRegion(.type)))
        #expect(abs(tightLayout.frame(.type).maxX - tightOcclusion.minX) < 0.001)
    }

    /// Direct unit tests for `HomeWellEnvelope.preserves(_:_:)` covering:
    /// - empty/missing `.stop` well returning `false`;
    /// - downward shift of `.again` toward `.stop` failing `aboveGain`;
    /// - another control moving closer than the well's category + tie failing
    ///   `otherControlsAreFarther`;
    /// - one-row safety row (`!spans`) passing on a valid regular layout and
    ///   failing `excludesAgain` if `.again` comes within tie distance of a
    ///   point in Stop's well.
    @Test func wellEnvelopeDirectEdgeCasesHold() {
        let compact = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874)),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(HomeWellEnvelope.preserves(compact.frames, compact.frames))

        var emptyWell = compact.frames
        emptyWell[.stop] = .zero
        #expect(!HomeWellEnvelope.preserves(compact.frames, emptyWell))

        var shiftedAgain = compact.frames
        shiftedAgain[.again] = compact.frame(.again).offsetBy(dx: 0, dy: 2)
        #expect(!HomeWellEnvelope.preserves(compact.frames, shiftedAgain))

        var encroachingYes = compact.frames
        encroachingYes[.yes] = compact.frame(.stop)
        #expect(!HomeWellEnvelope.preserves(compact.frames, encroachingYes))

        let regular = HomeLayout(
            space: .init(size: CGSize(width: 1032, height: 1376)),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(HomeWellEnvelope.preserves(regular.frames, regular.frames))

        var againNearRegularWell = regular.frames
        againNearRegularWell[.again] = regular.frame(.stop)
        #expect(!HomeWellEnvelope.preserves(regular.frames, againNearRegularWell))
    }
}

import Foundation
import Testing
@testable import Brickson

/// Independent activation checks on supplied geometry, using the unchanged
/// ChainEngine. These fixtures are observations, never a product device table.
struct HomeReservedRegionChainTests {
    private struct Fixture {
        let name: String
        let space: HomeLayout.Space

        func layout(text: HomeLayout.Text, reservations: Bool) -> HomeLayout {
            HomeLayout(
                space: reservations ? space : .init(size: space.size, safeArea: space.safeArea),
                text: text, modes: .phrasesAndTyping
            )
        }
    }

    private static let fixtures: [Fixture] = {
        func region(_ kind: HomeLayout.ReservedRegion.Kind, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> HomeLayout.ReservedRegion {
            .init(kind: kind, frame: CGRect(x: x, y: y, width: width, height: height), isActive: false)
        }
        let wide = CGSize(width: 951, height: 669)
        let tall = CGSize(width: 669, height: 951)
        let wideSafe = HomeLayout.Insets(top: 0, leading: 0, bottom: 34, trailing: 84)
        let tallSafe = HomeLayout.Insets(top: 82, leading: 0, bottom: 34, trailing: 0)
        return [
            Fixture(name: "wide upper camera", space: .init(size: wide, safeArea: wideSafe, regions: [
                region(.division, 455.5, 0, 40, 669), region(.occlusion, 677.3333333333334, 21, 58, 37),
            ])),
            Fixture(name: "wide lower camera", space: .init(size: wide, safeArea: wideSafe, regions: [
                region(.division, 455.5, 0, 40, 669), region(.occlusion, 215.66666666666666, 611, 58, 37),
            ])),
            Fixture(name: "tall right camera", space: .init(size: tall, safeArea: tallSafe, regions: [
                region(.division, 0, 455.5, 669, 40), region(.occlusion, 611, 677.3333333333334, 37, 58),
            ])),
            Fixture(name: "tall left camera", space: .init(size: tall, safeArea: tallSafe, regions: [
                region(.division, 0, 455.5, 669, 40), region(.occlusion, 21, 215.66666666666666, 37, 58),
            ])),
            Fixture(name: "leading pane", space: .init(size: CGSize(width: 469, height: 669), safeArea: .init(top: 0, leading: 0, bottom: 34, trailing: 0), regions: [
                region(.division, 455.5, 0, 13.5, 669),
            ])),
            Fixture(name: "trailing pane", space: .init(size: CGSize(width: 469, height: 669), safeArea: wideSafe, regions: [
                region(.division, 0, 0, 13.5, 669),
            ])),
        ]
    }()

    /// Fails if the resolved layout introduces an activation path or makes
    /// an existing path hazardous under an additional rule/pointer. The
    /// baseline's known findings remain recorded; this accepts no new one.
    /// Typing stays in the map even where Type is unavailable: resizing
    /// can leave Home typing with its software keyboard put away.
    @Test(arguments: [false, true])
    func heldActivationsAddNoHazardPaths(boldText: Bool) {
        var unexpected: [String] = []
        for fixture in Self.fixtures {
            for measured in HomeLayoutEngineTests.textSizes.map(\.text) {
                var text = measured
                text.boldText = boldText
                let before = fixture.layout(text: text, reservations: false)
                let after = fixture.layout(text: text, reservations: true)
                func findings(_ layout: HomeLayout) -> Set<String> {
                    let map = HomeLayoutEngineTests.chainMap(layout, typing: true)
                    return Set(ChainFinding.findings(in: map.hazards(from: map.everyStart())).flatMap { finding in
                        finding.under.map { "\(finding.path) [\($0)]" }
                    })
                }
                let added = findings(after).subtracting(findings(before))
                unexpected += added.sorted().map { "\(fixture.name), quick line \(text.quickControlLine), Bold \(boldText): \($0)" }
            }
        }
        #expect(unexpected.isEmpty, "First new path: \(unexpected.first ?? "none")")
    }

    /// Merely preserving a path's name could widen its resting area. This
    /// independent half-point well sample fails if even one corresponding
    /// point newly selects Again, including ChainEngine's centre/edge ties.
    /// Removing the horizontal-fold growth constraint makes this fail.
    @Test(arguments: [false, true])
    func theExistingAgainEnvelopeDoesNotGrow(boldText: Bool) {
        var added: [String] = []
        for fixture in Self.fixtures {
            for measured in HomeLayoutEngineTests.textSizes.map(\.text) {
                var text = measured
                text.boldText = boldText
                let before = fixture.layout(text: text, reservations: false)
                let after = fixture.layout(text: text, reservations: true)
                let oldWell = before.frame(.stop)
                let newWell = after.frame(.stop)
                let oldControls = before.controls.filter { $0 != .stop }.map { (slot: $0, frame: before.frame($0)) }
                let newControls = after.controls.filter { $0 != .stop }.map { (slot: $0, frame: after.frame($0)) }
                let columns = max(1, Int((newWell.width * 2).rounded(.up)))
                let rows = max(1, Int((newWell.height * 2).rounded(.up)))
                for column in 0...columns {
                    for row in 0...rows {
                        let u = CGFloat(column) / CGFloat(columns)
                        let v = CGFloat(row) / CGFloat(rows)
                        let oldPoint = CGPoint(x: oldWell.minX + u * oldWell.width, y: oldWell.minY + v * oldWell.height)
                        let newPoint = CGPoint(x: newWell.minX + u * newWell.width, y: newWell.minY + v * newWell.height)
                        for rule in NearestRule.allCases {
                            let newAgain = ChainEngine.nearest(to: newPoint, among: newControls, by: rule, frame: \.frame).contains { $0.slot == .again }
                            guard newAgain else { continue }
                            let oldAgain = ChainEngine.nearest(to: oldPoint, among: oldControls, by: rule, frame: \.frame).contains { $0.slot == .again }
                            if !oldAgain, added.count < 5 {
                                added.append("\(fixture.name), quick line \(text.quickControlLine), Bold \(boldText), \(rule), \(newPoint)")
                            }
                        }
                    }
                }
            }
        }
        #expect(added.isEmpty, "New Again point: \(added.first ?? "none")")
    }

    /// Fails if Back is derived before camera fitting and therefore closes
    /// onto a different or speaking target instead of Phrases.
    @Test func backToTalkingUsesTheFinalPhrasesFrame() {
        for fixture in Self.fixtures {
            for text in HomeLayoutEngineTests.textSizes.map(\.text) {
                let layout = fixture.layout(text: text, reservations: true)
                #expect(layout.frame(.phrases).contains(layout.backToTalking), "\(fixture.name)")
                let controls = layout.controls.filter { $0 != .stop }.map { (slot: $0, frame: layout.frame($0)) }
                for point in ChainEngine.points(across: layout.backToTalking) {
                    for rule in NearestRule.allCases {
                        let nearest = ChainEngine.nearest(to: point, among: controls, by: rule, frame: \.frame)
                        #expect(nearest.allSatisfy { $0.slot == .phrases }, "\(fixture.name), \(rule), \(point)")
                    }
                }
            }
        }
    }

    /// Fails if fitting reservations grows the recorded message-reading
    /// hazard beyond the existing engine bounds. A shorter A block must
    /// not trade the well improvement for more unasked speech here.
    @Test(arguments: [false, true])
    func messageReadingKeepsTheExistingSpeakingShareBound(boldText: Bool) {
        for fixture in Self.fixtures {
            for measured in HomeLayoutEngineTests.textSizes.map(\.text) {
                var text = measured
                text.boldText = boldText
                let layout = fixture.layout(text: text, reservations: true)
                let share = Nearest.speakingShare(of: layout)
                let bound = layout.isRegular ? (centre: 0.68, edge: 0.62) : (centre: 0.97, edge: 0.89)
                #expect(share.centre <= bound.centre && share.edge <= bound.edge,
                    "\(fixture.name), quick line \(text.quickControlLine), Bold \(boldText): \(share)")
            }
        }
    }
}

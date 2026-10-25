import Foundation
import Testing
@testable import Brickson

/// Test model shared with SettingsRowPlaceTests and
/// SettingsChainsTests.SweptFamilySetup. Nav64/bar8/gutter16/footer40,
/// row/word metrics and a 44pt Back are model assumptions, not Duo native
/// measurements. The unchanged ChainEngine scores root and Family Setup;
/// first-step answer screens and actual native geometry remain UI gates.
struct SettingsReservedRegionChainTests {
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


    private struct ModelWindow {
        let size: CGSize
        let home: HomeLayout
        let content: CGRect
        let navigationBar: CGRect

        init(_ fixture: Fixture, text: HomeLayout.Text, reservations: Bool) {
            size = fixture.space.size
            home = fixture.layout(text: text, reservations: reservations)
            let safe = fixture.space.safeArea
            let top = home.backToTalking.maxY + 8
            let screen = SettingsScreenFrames(
                stack: CGRect(x: safe.leading, y: top,
                    width: size.width - safe.leading - safe.trailing,
                    height: max(0, size.height - safe.bottom - 40 - top)),
                safeArea: .init(top: 64, leading: 0, bottom: 0, trailing: 0), gutter: 16
            )
            navigationBar = screen.navigationBar
            content = screen.content
        }

        func rowIdealWidth(text: HomeLayout.Text) -> CGFloat {
            185 + (442 - 185) * (text.categoryLine - 22) / (65 - 22)
        }

        func rowHeight(text: HomeLayout.Text, width: CGFloat) -> CGFloat {
            let lines: CGFloat = rowIdealWidth(text: text) <= width ? 1 : 2
            return max(64, lines * text.categoryLine) + 14
        }

        func row(text: HomeLayout.Text) -> CGRect {
            SettingsRowPlace(home: home, rowIdealWidth: rowIdealWidth(text: text),
                rowHeight: { rowHeight(text: text, width: $0) },
                content: content, navigationBar: navigationBar).row
        }
    }
    private struct FamilyModel {
        let guided: CGRect
        let screens: SettingsChains.Screens

        static let guidedWords: [CGFloat] = [1.74, 1.16, 2.32, 1.16, 2.32]

        init(_ window: ModelWindow, text: HomeLayout.Text, row: CGRect) {
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
            screens = SettingsChains.Screens(
                root: [(SettingsChains.backToTalking, backToTalking), (SettingsChains.familySetupRow, row)],
                familySetup: ([(SettingsChains.backToTalking, backToTalking), (SettingsChains.back, back), (SettingsChains.guidedSetupRow, guided)] + rows)
                    .filter { $0.1.intersects(shown) },
                firstStep: nil
            )
        }
    }


    private static func findings(_ window: ModelWindow, text: HomeLayout.Text) -> Set<String> {
        let model = FamilyModel(window, text: text, row: window.row(text: text))
        let categories = (1...HomeLayout.categoryCapacity).map { "category \($0)" }
        let homeMap = HomeLayoutEngineTests.chainMap(window.home, typing: true)
        var signatures = Set<String>()
        // Every browsing closing state, retaining the draft after leaving
        // typing. The Home map still contains its typing transitions.
        for state in HomeChains.states(categoryCount: categories.count, typing: true) where !state.typing {
            let name = HomeChains.name(of: state, categories: categories)
            let map = homeMap.merging(SettingsChains.map(model.screens, closingOnto: name).map)
            let hazards = map.hazards(from: SettingsChains.starts(in: map, home: name), depth: 6)
            for finding in ChainFinding.findings(in: hazards) {
                for under in finding.under { signatures.insert("\(finding.path) [\(under)]") }
            }
        }
        return signatures
    }

    /// Fails if adapting Home creates a new Settings path, or makes an
    /// existing path hazardous under another nearest-rule/pointer pair.
    /// This changes no Settings placement rule or accepted #56 limit.
    @Test(arguments: [false, true])
    func finalHomeFramesAddNoSettingsHazardPaths(boldText: Bool) {
        var added: [String] = []
        for fixture in Self.fixtures {
            for measured in HomeLayoutEngineTests.textSizes.map(\.text) {
                var text = measured
                text.boldText = boldText
                let before = ModelWindow(fixture, text: text, reservations: false)
                let after = ModelWindow(fixture, text: text, reservations: true)
                added += Self.findings(after, text: text).subtracting(Self.findings(before, text: text))
                    .sorted().map { "\(fixture.name), category line \(text.categoryLine), Bold \(boldText): \($0)" }
            }
        }
        #expect(added.isEmpty, "First new Settings chain: \(added.first ?? "none")")
    }

    /// A new root-row/fold intersection fails. Existing R0-13 gaps are
    /// recorded, never pinned to remain broken or accepted as exceptions.
    @Test(arguments: [false, true])
    func theDerivedRowAddsNoFoldIntersection(boldText: Bool) {
        for fixture in Self.fixtures {
            for measured in HomeLayoutEngineTests.textSizes.map(\.text) {
                var text = measured
                text.boldText = boldText
                let before = ModelWindow(fixture, text: text, reservations: false).row(text: text)
                let after = ModelWindow(fixture, text: text, reservations: true).row(text: text)
                for region in fixture.space.regions where region.kind == .division && Self.overlaps(after, region.frame) {
                    #expect(Self.overlaps(before, region.frame), "New Family Setup intersection: \(fixture.name), Bold \(boldText)")
                }
            }
        }
    }

    private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }
}

import Foundation
import Testing
@testable import Brickson

/// Where Set Up Step by Step's second step starts its choices
/// (`SetupChoicesPlace`), from Next's frame at the foot of the step.
/// Windows modelled on CI's: on the iPhone 17 the stack runs from 142 to
/// 800 (`SettingsScreenFramesTests`) and Next takes its last 110 points;
/// on the 13-inch iPad in portrait the stack ends at 1288 and Next takes
/// 158 at the largest text size.
struct SetupChoicesPlaceTests {
    private static let phoneNext = CGRect(x: 0, y: 690, width: 402, height: 110)
    private static let padNext = CGRect(x: 0, y: 1130, width: 1032, height: 158)
    private static let phoneContent = (minX: CGFloat(16), width: CGFloat(370))
    private static let padContent = (minX: CGFloat(16), width: CGFloat(1000))

    /// Every choice's frame from `top`.
    private static func column(
        top: CGFloat, minX: CGFloat, width: CGFloat, heights: [CGFloat], spacing: CGFloat = 16
    ) -> [CGRect] {
        var y = top
        return heights.map { height in
            defer { y += height + spacing }
            return CGRect(x: minX, y: y, width: width, height: height)
        }
    }

    /// The rule the plain way: every point across Next, inside it too, at
    /// most 4 points apart, lies nearer Next than each choice, by centre
    /// and by edge, with the margin to spare.
    private static func everyPointHolds(_ next: CGRect, _ choices: [CGRect]) -> Bool {
        SettingsRowPlace.points(across: next, every: 4).allSatisfy { point in
            choices.allSatisfy { SettingsRowPlace.isNearer(point, toOneOf: [next], thanAny: [$0], margin: SettingsRowPlace.margin) }
        }
    }

    private static func place(
        _ next: CGRect, _ content: (minX: CGFloat, width: CGFloat), heights: [CGFloat], earliest: CGFloat
    ) -> SetupChoicesPlace {
        SetupChoicesPlace(
            next: next, choicesMinX: content.minX, choicesWidth: content.width, heights: heights, spacing: 16, earliest: earliest
        )
    }

    /// On the iPad, with the words above and the bar far below, the choices
    /// follow the words: fails if they are pushed lower than any look on
    /// Next needs.
    @Test func whereTheColumnClearsNextTheChoicesFollowTheWords() {
        let heights = Array(repeating: CGFloat(78), count: 5)
        let place = Self.place(Self.padNext, Self.padContent, heights: heights, earliest: 400)
        #expect(place.top == 400)
        #expect(Self.everyPointHolds(Self.padNext, Self.column(top: 400, minX: 16, width: 1000, heights: heights)))
    }

    /// On the phone, where the words leave the column running down to the
    /// bar, the choices start below it, as high as every point allows:
    /// fails if a choice is left where a look resting on Next meets it, by
    /// centre or by edge, or if the choices start lower than they need to,
    /// by more than a point.
    @Test(arguments: [CGFloat(300), 450, 600, 689, 700])
    func whereTheColumnWouldMeetALookOnNextTheChoicesStartBelowTheBar(earliest: CGFloat) {
        let heights = Array(repeating: CGFloat(78), count: 5)
        #expect(!Self.everyPointHolds(Self.phoneNext, Self.column(top: earliest, minX: 16, width: 370, heights: heights)))
        let place = Self.place(Self.phoneNext, Self.phoneContent, heights: heights, earliest: earliest)
        #expect(place.top >= Self.phoneNext.maxY)
        #expect(Self.everyPointHolds(Self.phoneNext, Self.column(top: place.top, minX: 16, width: 370, heights: heights)))
        #expect(!Self.everyPointHolds(Self.phoneNext, Self.column(top: place.top - 1, minX: 16, width: 370, heights: heights)))
    }

    /// Across the room above the bar and below it, at the default and the
    /// largest sizes' heights, one choice taller than the rest included,
    /// and on both windows: fails if any top the rule gives leaves a choice
    /// a look on Next meets, judged at every point across Next rather than
    /// along its edge alone (the shortcut the rule takes), or if the
    /// choices leave the words where the whole column holds under them.
    @Test func everyTopItGivesHoldsAtEveryPointOfNext() {
        let cases: [(next: CGRect, content: (minX: CGFloat, width: CGFloat), earliest: [CGFloat])] = [
            (Self.phoneNext, Self.phoneContent, [200, 300, 450, 600, 700, 820]),
            (Self.padNext, Self.padContent, [200, 500, 800, 1000, 1100, 1200, 1300]),
        ]
        let columns: [[CGFloat]] = [Array(repeating: 78, count: 5), Array(repeating: 145, count: 5), [78, 145, 78, 78, 78]]
        for (next, content, tops) in cases {
            for heights in columns {
                for earliest in tops {
                    let place = Self.place(next, content, heights: heights, earliest: earliest)
                    let choices = Self.column(top: place.top, minX: content.minX, width: content.width, heights: heights)
                    #expect(Self.everyPointHolds(next, choices), "Next \(next), heights \(heights), earliest \(earliest): top \(place.top)")
                    let underTheWords = Self.column(top: earliest, minX: content.minX, width: content.width, heights: heights)
                    if Self.everyPointHolds(next, underTheWords) {
                        #expect(place.top == earliest, "Next \(next), heights \(heights), earliest \(earliest): top \(place.top)")
                    } else {
                        #expect(place.top >= next.maxY, "Next \(next), heights \(heights), earliest \(earliest): top \(place.top)")
                    }
                }
            }
        }
    }

    /// With no choice to place, or before Next is known, the choices
    /// follow the words: fails if either moves them.
    @Test func withNoChoiceOrNoNextTheChoicesFollowTheWords() {
        #expect(Self.place(Self.phoneNext, Self.phoneContent, heights: [], earliest: 650).top == 650)
        #expect(Self.place(.zero, Self.phoneContent, heights: [78, 78], earliest: 650).top == 650)
    }
}

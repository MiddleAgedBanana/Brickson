import Foundation
import Testing
@testable import Brickson

/// Where Set Up Step by Step's second step places its choices
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

    /// Each choice's top, stacked from `top`.
    private static func stacked(from top: CGFloat, _ heights: [CGFloat], spacing: CGFloat = 16) -> [CGFloat] {
        var y = top
        return heights.map { height in
            defer { y += height + spacing }
            return y
        }
    }

    private static func frame(top: CGFloat, height: CGFloat, _ content: (minX: CGFloat, width: CGFloat)) -> CGRect {
        CGRect(x: content.minX, y: top, width: content.width, height: height)
    }

    /// The rule the plain way: every point across Next, inside it too, at
    /// most 4 points apart, lies nearer Next than the choice, by centre and
    /// by edge, with the margin to spare.
    private static func everyPointHolds(_ next: CGRect, _ choice: CGRect) -> Bool {
        SettingsRowPlace.points(across: next, every: 4).allSatisfy {
            SettingsRowPlace.isNearer($0, toOneOf: [next], thanAny: [choice], margin: SettingsRowPlace.margin)
        }
    }

    private static func place(
        _ next: CGRect, _ content: (minX: CGFloat, width: CGFloat), heights: [CGFloat], earliest: CGFloat
    ) -> SetupChoicesPlace {
        SetupChoicesPlace(
            next: next, choicesMinX: content.minX, choicesWidth: content.width, heights: heights, spacing: 16, earliest: earliest
        )
    }

    /// Checks `tops` against the rule: every choice holds at every point of
    /// Next; the choices that follow the words hold there and keep their
    /// places under them; the first that moved would not hold under them;
    /// the rest start together at or below the bar's foot, in order, 16
    /// points apart, and could not start a point higher. Each failure
    /// names `context`.
    private static func expectTheRule(
        _ tops: [CGFloat], next: CGRect, content: (minX: CGFloat, width: CGFloat), heights: [CGFloat], earliest: CGFloat,
        _ context: String
    ) {
        #expect(tops.count == heights.count, "\(context): \(tops)")
        guard tops.count == heights.count else { return }
        for (top, height) in zip(tops, heights) {
            #expect(everyPointHolds(next, frame(top: top, height: height, content)), "\(context): a choice at \(top) of \(tops)")
        }
        let underTheWords = stacked(from: earliest, heights)
        let kept = zip(tops, underTheWords).prefix { abs($0 - $1) < 0.001 }.count
        guard kept < heights.count else { return }
        #expect(
            !everyPointHolds(next, frame(top: underTheWords[kept], height: heights[kept], content)),
            "\(context): choice \(kept) left the words where it holds under them, \(tops)"
        )
        let rest = Array(heights[kept...])
        #expect(tops[kept] >= next.maxY, "\(context): the rest start above the bar's foot, \(tops)")
        #expect(Array(tops[kept...]) == stacked(from: tops[kept], rest), "\(context): the rest are not stacked, \(tops)")
        let higher = stacked(from: tops[kept] - 1, rest)
        if tops[kept] - 1 >= max(underTheWords[kept], next.maxY) {
            #expect(
                !zip(higher, rest).allSatisfy { everyPointHolds(next, frame(top: $0, height: $1, content)) },
                "\(context): the rest could start a point higher than \(tops[kept])"
            )
        }
    }

    /// On the iPad, with the words above and the bar far below, every
    /// choice follows the words: fails if any is pushed lower than a look
    /// on Next needs.
    @Test func whereTheColumnClearsNextTheChoicesFollowTheWords() {
        let heights = Array(repeating: CGFloat(78), count: 5)
        let place = Self.place(Self.padNext, Self.padContent, heights: heights, earliest: 400)
        #expect(place.tops == Self.stacked(from: 400, heights))
        for (top, height) in zip(place.tops, heights) {
            #expect(Self.everyPointHolds(Self.padNext, Self.frame(top: top, height: height, Self.padContent)))
        }
    }

    /// On the iPhone 17 at the default size, where the words end at 422
    /// (`SettingsChainsTests.SweptFamilySetup`), Every Category and the
    /// first category hold under them and stay, and the third choice's
    /// centre would sit where a look on Next's top corner is nearer it
    /// than Next: fails if the first two leave the words, if any choice is
    /// left where a look resting on Next meets it, by centre or by edge,
    /// or if the rest start lower than they need to, by more than a point.
    @Test func whereOnlyPartOfTheColumnHoldsUnderTheWordsTheRestStartBelowTheBar() {
        let heights = Array(repeating: CGFloat(78), count: 5)
        let place = Self.place(Self.phoneNext, Self.phoneContent, heights: heights, earliest: 422)
        #expect(Array(place.tops.prefix(2)) == [422, 516])
        #expect(place.tops[2] >= Self.phoneNext.maxY)
        Self.expectTheRule(place.tops, next: Self.phoneNext, content: Self.phoneContent, heights: heights, earliest: 422, "phone at 422")
    }

    /// On the phone, from words that leave the whole column above the bar
    /// down to words that end at or under it, as larger text sizes do:
    /// fails wherever the rule does not hold (`expectTheRule`).
    @Test(arguments: [CGFloat(200), 300, 450, 600, 689, 700, 820])
    func onThePhoneEachChoiceHoldsAndStaysAsHighAsItCan(earliest: CGFloat) {
        let heights = Array(repeating: CGFloat(78), count: 5)
        let place = Self.place(Self.phoneNext, Self.phoneContent, heights: heights, earliest: earliest)
        Self.expectTheRule(
            place.tops, next: Self.phoneNext, content: Self.phoneContent, heights: heights, earliest: earliest, "phone at \(earliest)"
        )
    }

    /// Across the room above the bar and below it, at the default and the
    /// largest sizes' heights, one choice taller than the rest included,
    /// and on both windows: fails wherever the rule does not hold, judged
    /// at every point across Next rather than along its edge alone (the
    /// shortcut the rule takes).
    @Test func everyPlaceItGivesHoldsAtEveryPointOfNext() {
        let cases: [(next: CGRect, content: (minX: CGFloat, width: CGFloat), earliest: [CGFloat])] = [
            (Self.phoneNext, Self.phoneContent, [200, 422, 600, 820]),
            (Self.padNext, Self.padContent, [200, 500, 800, 1000, 1100, 1200, 1300]),
        ]
        let columns: [[CGFloat]] = [Array(repeating: 78, count: 5), Array(repeating: 145, count: 5), [78, 145, 78, 78, 78]]
        for (next, content, tops) in cases {
            for heights in columns {
                for earliest in tops {
                    let place = Self.place(next, content, heights: heights, earliest: earliest)
                    Self.expectTheRule(
                        place.tops, next: next, content: content, heights: heights, earliest: earliest,
                        "Next \(next), heights \(heights), earliest \(earliest)"
                    )
                }
            }
        }
    }

    /// With no choice to place, or before Next is known, the choices
    /// follow the words: fails if either moves them.
    @Test func withNoChoiceOrNoNextTheChoicesFollowTheWords() {
        #expect(Self.place(Self.phoneNext, Self.phoneContent, heights: [], earliest: 650).tops == [])
        #expect(Self.place(.zero, Self.phoneContent, heights: [78, 78], earliest: 650).tops == [650, 744])
    }

    // MARK: Where the check-in card's rows were

    /// The second step as CI drew it on run 43214111054 (pull request
    /// #103), with a check-in due: Next's bar, where the check-in card's
    /// three rows were in Family Setup (Go Through Setup Again's top to
    /// Stop Asking's foot), the choices' height and where the words left
    /// the first. On the iPhone 17 at the default size the card's rows run
    /// from 659 to 925, past the sound line and the window's foot at 874;
    /// on the 13-inch iPad at the largest size, from 1119 to 1391.
    private struct CheckInWindow {
        let name: String
        let next: CGRect
        let content: (minX: CGFloat, width: CGFloat)
        let rows: CGRect
        let choiceHeight: CGFloat
        let earliest: CGFloat
        /// Where CI's chains looked as they chose Not Now or Stop Asking,
        /// then Set Up Step by Step, then Next, and met a choice.
        let looks: [CGPoint]
    }

    private static let checkInWindows = [
        CheckInWindow(
            name: "iPhone 17, default size", next: CGRect(x: 0, y: 694.33, width: 402, height: 110), content: phoneContent,
            rows: CGRect(x: 16, y: 659, width: 370, height: 266), choiceHeight: 78, earliest: 410.67,
            looks: [CGPoint(x: 16.5, y: 830.5), CGPoint(x: 201, y: 886)]
        ),
        CheckInWindow(
            name: "13-inch iPad, AX5", next: CGRect(x: 0, y: 1164, width: 1032, height: 112), content: padContent,
            rows: CGRect(x: 16, y: 1119, width: 1000, height: 272), choiceHeight: 80, earliest: 761.5,
            looks: [CGPoint(x: 516, y: 1351)]
        ),
    ]

    /// Whether every point across `arrival`, at most 4 points apart,
    /// lies nearer Next than `choice`, by centre and by edge, with the
    /// margin to spare.
    private static func everyPointHolds(_ next: CGRect, arrival: CGRect, _ choice: CGRect) -> Bool {
        SettingsRowPlace.points(across: arrival, every: 4).allSatisfy {
            SettingsRowPlace.isNearer($0, toOneOf: [next], thanAny: [choice], margin: SettingsRowPlace.margin)
        }
    }

    /// Where a choice is nearer `look` than Next is, by centre or by edge:
    /// a look resting there meets it.
    private static func meetsAChoice(_ look: CGPoint, next: CGRect, choices: [CGRect]) -> Bool {
        !SettingsRowPlace.isNearer(look, toOneOf: [next], thanAny: choices, margin: 0)
    }

    /// Once the check-in card is answered and Set Up Step by Step chosen
    /// in its place, on both of CI's windows where its chains found a held
    /// look saving a choice: fails if any choice lies where a look at a
    /// point of the card's rows, every 4 points across them, or where
    /// CI's chains looked, is nearer it than Next, by centre or by edge,
    /// or if the place breaks the rule for Next itself
    /// (`expectTheRule`).
    @Test func afterTheCheckInEveryChoiceKeepsClearOfTheCardsPlace() {
        for window in Self.checkInWindows {
            let heights = Array(repeating: window.choiceHeight, count: 5)
            let place = SetupChoicesPlace(
                next: window.next, arrivals: [window.rows], choicesMinX: window.content.minX, choicesWidth: window.content.width,
                heights: heights, spacing: 16, earliest: window.earliest
            )
            let choices = place.tops.map { Self.frame(top: $0, height: window.choiceHeight, window.content) }
            for choice in choices {
                #expect(Self.everyPointHolds(window.next, arrival: window.rows, choice), "\(window.name): a choice at \(choice.minY)")
                #expect(Self.everyPointHolds(window.next, choice), "\(window.name): a choice at \(choice.minY) is near Next")
            }
            for look in window.looks {
                #expect(!Self.meetsAChoice(look, next: window.next, choices: choices), "\(window.name): a look at \(look)")
            }
        }
    }

    /// The same windows with the choices placed from Next alone, as the
    /// second step placed them for every way in before: fails unless a
    /// look where CI's chains looked meets a choice, the hazard CI found,
    /// so the finding stays pinned.
    @Test func placedFromNextAloneALookOverTheCardsPlaceMetAChoice() {
        for window in Self.checkInWindows {
            let heights = Array(repeating: window.choiceHeight, count: 5)
            let place = Self.place(window.next, window.content, heights: heights, earliest: window.earliest)
            let choices = place.tops.map { Self.frame(top: $0, height: window.choiceHeight, window.content) }
            #expect(window.looks.allSatisfy { Self.meetsAChoice($0, next: window.next, choices: choices) }, "\(window.name): \(place.tops)")
        }
    }

    /// Across where the card's rows can lie, above the bar, across it and
    /// under it, at the default and the largest sizes' heights, on both
    /// of the modelled windows: fails if any choice lies where a point
    /// across the rows, every 4 points, is nearer it than Next (the plain
    /// way, rather than the corners the place checks), if the place breaks
    /// the rule for Next, or if the rest could start a point higher and
    /// still hold for both.
    @Test func everyPlaceItGivesHoldsAtEveryPointOfTheCardsPlace() {
        let cases: [(next: CGRect, content: (minX: CGFloat, width: CGFloat), rows: [CGRect])] = [
            (Self.phoneNext, Self.phoneContent, [
                CGRect(x: 16, y: 300, width: 370, height: 266), CGRect(x: 16, y: 560, width: 370, height: 266),
                CGRect(x: 16, y: 659, width: 370, height: 266), CGRect(x: 16, y: 760, width: 370, height: 120),
            ]),
            (Self.padNext, Self.padContent, [
                CGRect(x: 16, y: 500, width: 1000, height: 272), CGRect(x: 16, y: 1000, width: 1000, height: 272),
                CGRect(x: 16, y: 1119, width: 1000, height: 272),
            ]),
        ]
        let columns: [[CGFloat]] = [Array(repeating: 78, count: 5), Array(repeating: 145, count: 5)]
        for (next, content, rowsCases) in cases {
            for rows in rowsCases {
                for heights in columns {
                    for earliest in [CGFloat(200), 422, 761.5] {
                        let place = SetupChoicesPlace(
                            next: next, arrivals: [rows], choicesMinX: content.minX, choicesWidth: content.width, heights: heights,
                            spacing: 16, earliest: earliest
                        )
                        let context = "Next \(next), rows \(rows), heights \(heights), earliest \(earliest): \(place.tops)"
                        #expect(place.tops.count == heights.count, "\(context)")
                        guard place.tops.count == heights.count else { continue }
                        let choices = zip(place.tops, heights).map { Self.frame(top: $0, height: $1, content) }
                        for choice in choices {
                            #expect(Self.everyPointHolds(next, arrival: rows, choice), "\(context): at \(choice.minY)")
                            #expect(Self.everyPointHolds(next, choice), "\(context): at \(choice.minY), near Next")
                        }
                        let underTheWords = Self.stacked(from: earliest, heights)
                        let kept = zip(place.tops, underTheWords).prefix { abs($0 - $1) < 0.001 }.count
                        guard kept < heights.count else { continue }
                        let rest = Array(heights[kept...])
                        #expect(Array(place.tops[kept...]) == Self.stacked(from: place.tops[kept], rest), "\(context): not stacked")
                        let higher = Self.stacked(from: place.tops[kept] - 1, rest)
                        if place.tops[kept] - 1 >= max(underTheWords[kept], next.maxY) {
                            #expect(
                                !zip(higher, rest).allSatisfy { top, height in
                                    let choice = Self.frame(top: top, height: height, content)
                                    return Self.everyPointHolds(next, arrival: rows, choice) && Self.everyPointHolds(next, choice)
                                },
                                "\(context): the rest could start a point higher"
                            )
                        }
                    }
                }
            }
        }
    }

    /// Only Set Up Step by Step chosen once the check-in card was answered
    /// in its place brings a look from where the card's rows were: fails
    /// if that way in leaves them out, or another adds them.
    @Test func onlyTheWayInAfterTheCheckInArrivesFromTheCardsPlace() {
        let rows = CGRect(x: 16, y: 659, width: 370, height: 266)
        #expect(SetupChoicesPlace.arrivals(from: .setUpStepByStepAfterTheCheckIn, checkInRows: rows) == [rows])
        #expect(SetupChoicesPlace.arrivals(from: .setUpStepByStep, checkInRows: rows).isEmpty)
        #expect(SetupChoicesPlace.arrivals(from: .checkIn, checkInRows: rows).isEmpty)
    }
}

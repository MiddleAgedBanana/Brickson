import Foundation
import Testing
@testable import Brickson

/// Where Set Up Step by Step's first step starts its answers
/// (`SetupAnswersPlace`), on frames CI measured on main for PR #56's
/// windows: Home's Settings, Settings' Family Setup row and Family Setup's
/// Set Up Step by Step, which Learn About Each Way takes the place of.
struct SetupAnswersPlaceTests {
    nonisolated struct Measured: Sendable {
        let name: String
        let homesSettings: CGRect
        let rootRow: CGRect
        let guided: CGRect
        let content: (minX: CGFloat, width: CGFloat)
    }

    nonisolated static let windows = [
        Measured(
            name: "iPhone 17", homesSettings: CGRect(x: 276, y: 422, width: 110, height: 48),
            rootRow: CGRect(x: 16, y: 312, width: 370, height: 78), guided: CGRect(x: 16, y: 312, width: 370, height: 78),
            content: (16, 370)
        ),
        Measured(
            name: "iPhone 17, AX5", homesSettings: CGRect(x: 276, y: 547, width: 110, height: 77),
            rootRow: CGRect(x: 16, y: 317, width: 370, height: 144.67), guided: CGRect(x: 16, y: 317, width: 370, height: 209.67),
            content: (16, 370)
        ),
        Measured(
            name: "iPad portrait", homesSettings: CGRect(x: 822.5, y: 336, width: 193.5, height: 152),
            rootRow: CGRect(x: 822.5, y: 354, width: 193.5, height: 78), guided: CGRect(x: 822.5, y: 354, width: 193.5, height: 78),
            content: (16, 1000)
        ),
        Measured(
            name: "iPad portrait, AX5", homesSettings: CGRect(x: 822.5, y: 358, width: 193.5, height: 162),
            rootRow: CGRect(x: 578.5, y: 378, width: 437.5, height: 80), guided: CGRect(x: 578.5, y: 378, width: 437.5, height: 145),
            content: (16, 1000)
        ),
        Measured(
            name: "iPad landscape", homesSettings: CGRect(x: 1097.5, y: 336, width: 262.5, height: 152),
            rootRow: CGRect(x: 1097.5, y: 355, width: 262.5, height: 78), guided: CGRect(x: 1097.5, y: 355, width: 262.5, height: 78),
            content: (16, 1344)
        ),
    ]

    static func place(_ window: Measured, earliest: CGFloat? = nil) -> SetupAnswersPlace {
        SetupAnswersPlace(
            arrivals: [window.homesSettings, window.rootRow, window.guided], link: window.guided,
            answersMinX: window.content.minX, answersWidth: window.content.width, answerHeight: 64,
            earliest: earliest ?? window.guided.maxY + 16
        )
    }

    static func everyPointHolds(_ window: Measured, top: CGFloat) -> Bool {
        let answer = CGRect(x: window.content.minX, y: top, width: window.content.width, height: 64)
        return [window.homesSettings, window.rootRow, window.guided]
            .flatMap { SettingsRowPlace.points(across: $0, every: 4) }
            .allSatisfy { SettingsRowPlace.isNearer($0, toOneOf: [window.guided], thanAny: [answer], margin: SettingsRowPlace.margin) }
    }

    /// Fails if the answers start where a point of Home's Settings, the
    /// root's row or Set Up Step by Step lies as near the first answer as
    /// Learn About Each Way, by centre or by edge, within the margin; or
    /// lower than they need to, by more than a point.
    @Test(arguments: windows.map(\.name))
    func theAnswersStartAsHighAsEveryArrivalAllows(name: String) throws {
        let window = try #require(Self.windows.first { $0.name == name })
        let place = Self.place(window)
        #expect(place.top >= window.guided.maxY + 16)
        #expect(Self.everyPointHolds(window, top: place.top), "\(name): answers at \(place.top)")
        if place.top - 1 >= window.guided.maxY + 16 {
            #expect(!Self.everyPointHolds(window, top: place.top - 1), "\(name): answers at \(place.top) could start higher")
        }
    }

    /// Where the room under the link already holds, the answers start right
    /// there: fails if they are pushed lower than any look needs.
    @Test func whereNothingArrivesBelowTheLinkTheAnswersFollowIt() {
        let link = CGRect(x: 16, y: 100, width: 370, height: 78)
        let place = SetupAnswersPlace(
            arrivals: [link], link: link, answersMinX: 16, answersWidth: 370, answerHeight: 64, earliest: 400
        )
        #expect(place.top == 400)
    }

    /// The answers never start above `earliest`, the room the screen's own
    /// words and link take, and on the phone they start below Home's
    /// Settings, which lies under the link there: fails if Home's Settings
    /// is dropped from the arrivals.
    @Test func theAnswersStartBelowHomesSettingsOnThePhone() throws {
        let phone = try #require(Self.windows.first)
        let place = Self.place(phone)
        #expect(place.top > phone.homesSettings.maxY)
        let withoutHome = SetupAnswersPlace(
            arrivals: [phone.rootRow, phone.guided], link: phone.guided,
            answersMinX: 16, answersWidth: 370, answerHeight: 64, earliest: phone.guided.maxY + 16
        )
        #expect(withoutHome.top < place.top)
        let lower = Self.place(phone, earliest: 700)
        #expect(lower.top == 700)
    }

    /// The ways into the first step (`SetupAnswersPlace.arrivals`), on the
    /// phone with a check-in card under Set Up Step by Step, its rows from
    /// 560 down. Fails if, opened from the card's Go Through Setup Again
    /// with Learn About Each Way in its place, the answers start where a
    /// point of that button lies as near the first answer, or start below
    /// the card's other rows as if Home's Settings or the root's row could
    /// lead there; or if, opened with Set Up Step by Step once the card was
    /// answered, a point where the card's rows were lies as near the first
    /// answer as the link.
    @Test func theAnswersStartClearOfTheCheckInCard() throws {
        let phone = try #require(Self.windows.first)
        let goThrough = CGRect(x: 16, y: 560, width: 370, height: 78)
        let rows = CGRect(x: 16, y: 560, width: 370, height: 3 * 78 + 2 * 16)
        func place(_ entry: GuidedSetupEntry, link: CGRect) -> SetupAnswersPlace {
            SetupAnswersPlace(
                arrivals: SetupAnswersPlace.arrivals(
                    from: entry, homesSettings: phone.homesSettings, rootRow: phone.rootRow, opener: link, checkInRows: rows
                ),
                link: link, answersMinX: 16, answersWidth: 370, answerHeight: 64, earliest: link.maxY + 16
            )
        }
        func holds(_ frames: [CGRect], link: CGRect, top: CGFloat) -> Bool {
            let answer = CGRect(x: 16, y: top, width: 370, height: 64)
            return frames.flatMap { SettingsRowPlace.points(across: $0, every: 4) }
                .allSatisfy { SettingsRowPlace.isNearer($0, toOneOf: [link], thanAny: [answer], margin: SettingsRowPlace.margin) }
        }

        let fromCard = place(.checkIn, link: goThrough)
        #expect(fromCard.top >= goThrough.maxY + 16)
        #expect(holds([goThrough], link: goThrough, top: fromCard.top), "answers at \(fromCard.top)")
        #expect(fromCard.top < rows.maxY, "answers at \(fromCard.top) start below Stop Asking")

        let plain = place(.setUpStepByStep, link: phone.guided)
        #expect(plain.top == Self.place(phone).top)
        let afterCard = place(.setUpStepByStepAfterTheCheckIn, link: phone.guided)
        #expect(afterCard.top > rows.maxY, "answers at \(afterCard.top)")
        #expect(holds([phone.homesSettings, phone.rootRow, phone.guided, rows], link: phone.guided, top: afterCard.top))
        #expect(!holds([rows], link: phone.guided, top: plain.top))
    }

    /// Go Through Setup Again's place, for the step it opens, is where it
    /// showed: its frame in Family Setup's content less what Family Setup
    /// had scrolled, and never above the content's top, where it still
    /// showed in the gutter under the bar. Fails if the scroll is left out
    /// (Learn About Each Way then lies lower than the look) or added, or if
    /// a row half under the bar is placed above the content.
    @Test func goThroughSetupAgainIsPlacedWhereItShowed() {
        let row = CGRect(x: 16, y: 678.5, width: 370, height: 78)
        #expect(SetupAnswersPlace.shown(row, scrolledBy: 0) == row)
        #expect(SetupAnswersPlace.shown(row, scrolledBy: 400) == CGRect(x: 16, y: 278.5, width: 370, height: 78))
        #expect(SetupAnswersPlace.shown(row, scrolledBy: 690) == CGRect(x: 16, y: 0, width: 370, height: 78))
        #expect(SetupAnswersPlace.shown(row, scrolledBy: -30) == CGRect(x: 16, y: 708.5, width: 370, height: 78))
    }

    /// The search as it was before it halved and read a frame across the
    /// answers' width by its corners, kept as the plain way to compare
    /// with: every point of every frame, down 8 points at a time, then back
    /// up a point at a time.
    static func plainTop(
        arrivals: [CGRect], link: CGRect, answersMinX: CGFloat, answersWidth: CGFloat, answerHeight: CGFloat, earliest: CGFloat
    ) -> CGFloat {
        let points = arrivals.filter { !$0.isNull }.flatMap { SettingsRowPlace.points(across: $0, every: 4) }
        func holds(_ top: CGFloat) -> Bool {
            let answer = CGRect(x: answersMinX, y: top, width: answersWidth, height: answerHeight)
            return points.allSatisfy { SettingsRowPlace.isNearer($0, toOneOf: [link], thanAny: [answer], margin: SettingsRowPlace.margin) }
        }
        let deepest = points.map { $0.y + SettingsRowPlace.centreDistance(from: $0, to: link) }.max().map { $0 + SettingsRowPlace.margin + 1 }
            ?? earliest
        var coarse = earliest
        while coarse < deepest, !holds(coarse) {
            coarse += 8
        }
        var found = coarse
        while found - 1 >= earliest, found - 1 > coarse - 8, holds(found - 1) {
            found -= 1
        }
        return found
    }

    /// Fails if the search finds any top but the plain way's: on the
    /// measured windows, and swept over links high and low, wide and
    /// narrow, frames of words short and tall under them, a frame beyond
    /// the answers' width (read point by point), a frame reaching below
    /// where the answers may start, and a fractional start.
    @Test func theSearchFindsWhatThePlainWayFinds() {
        for window in Self.windows {
            let arrivals = [window.homesSettings, window.rootRow, window.guided]
            let plain = Self.plainTop(
                arrivals: arrivals, link: window.guided, answersMinX: window.content.minX,
                answersWidth: window.content.width, answerHeight: 64, earliest: window.guided.maxY + 16
            )
            #expect(Self.place(window).top == plain, "\(window.name)")
        }
        let links = [
            CGRect(x: 16, y: 0, width: 370, height: 64), CGRect(x: 16, y: 240, width: 200, height: 96),
            CGRect(x: 150, y: 120, width: 120, height: 48), CGRect(x: 236, y: 30.5, width: 150, height: 130),
        ]
        for link in links {
            for wordsHeight in [0, 24, 101.5] as [CGFloat] {
                let words = CGRect(x: 16, y: link.maxY + 16, width: 370, height: wordsHeight)
                let sets: [(arrivals: [CGRect], earliest: CGFloat)] = [
                    ([link.insetBy(dx: 0, dy: -8), words], words.maxY + 64),
                    ([link, words, CGRect(x: 380, y: link.minY - 30, width: 60, height: 50)], words.maxY + 64),
                    ([link, CGRect(x: 276, y: link.maxY + 4, width: 110, height: 48)], link.maxY + 16.25),
                    ([link, words], words.maxY + 0.5),
                ]
                for set in sets {
                    let place = SetupAnswersPlace(
                        arrivals: set.arrivals, link: link, answersMinX: 16, answersWidth: 370, answerHeight: 64, earliest: set.earliest
                    )
                    let plain = Self.plainTop(
                        arrivals: set.arrivals, link: link, answersMinX: 16, answersWidth: 370, answerHeight: 64, earliest: set.earliest
                    )
                    #expect(place.top == plain, "link \(link), words \(wordsHeight), arrivals \(set.arrivals)")
                }
            }
        }
    }

    /// A phone at 3x lays frames out on thirds of a point, which no binary
    /// fraction holds exactly, so the plain way's top, built by adding 8
    /// and taking away 1 again and again, can round differently from the
    /// halving's single sum by a hair: an independent check of 2026-11-05
    /// found differences of about 1e-13 points. Fails if the search finds
    /// a top that differs by more than a hair from the plain way's on the
    /// measured windows moved down by a third and by two thirds of a
    /// point, or one where a look could still be nearer the answers.
    @Test(arguments: [1.0 / 3, 2.0 / 3] as [CGFloat])
    func onThirdsOfAPointTheSearchFindsWhatThePlainWayFinds(shift: CGFloat) {
        for window in Self.windows {
            let moved = Measured(
                name: window.name, homesSettings: window.homesSettings.offsetBy(dx: 0, dy: shift),
                rootRow: window.rootRow.offsetBy(dx: 0, dy: shift), guided: window.guided.offsetBy(dx: 0, dy: shift),
                content: window.content
            )
            let plain = Self.plainTop(
                arrivals: [moved.homesSettings, moved.rootRow, moved.guided], link: moved.guided, answersMinX: moved.content.minX,
                answersWidth: moved.content.width, answerHeight: 64, earliest: moved.guided.maxY + 16
            )
            let top = Self.place(moved).top
            #expect(abs(top - plain) < 0.001, "\(window.name) moved \(shift): \(top) against \(plain)")
            #expect(Self.everyPointHolds(moved, top: top), "\(window.name) moved \(shift): answers at \(top)")
        }
    }

    /// A frame of words far taller than any screen, such as a long phrase
    /// at the largest text size, is placed at once. Fails if the search
    /// goes back to a try for every 8 points over a point every 4: on this
    /// frame that is hours, and the screen's layout waits for it.
    @Test(.timeLimit(.minutes(1)))
    func aFrameFarTallerThanAScreenIsPlacedAtOnce() {
        let link = CGRect(x: 16, y: 100, width: 370, height: 64)
        let words = CGRect(x: 16, y: link.maxY + 16, width: 370, height: 100_000)
        let place = SetupAnswersPlace(
            arrivals: [link, words], link: link, answersMinX: 16, answersWidth: 370, answerHeight: 64, earliest: words.maxY + 64
        )
        let answer = CGRect(x: 16, y: place.top, width: 370, height: 64)
        let lowest = [CGPoint(x: 16, y: words.maxY), CGPoint(x: 386, y: words.maxY)]
        #expect(lowest.allSatisfy { SettingsRowPlace.isNearer($0, toOneOf: [link], thanAny: [answer], margin: SettingsRowPlace.margin) })
        let higher = CGRect(x: 16, y: place.top - 1, width: 370, height: 64)
        #expect(!lowest.allSatisfy { SettingsRowPlace.isNearer($0, toOneOf: [link], thanAny: [higher], margin: SettingsRowPlace.margin) })
    }
}

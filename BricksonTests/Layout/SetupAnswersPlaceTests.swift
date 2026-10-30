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
}

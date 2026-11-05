import Foundation
import Testing
@testable import Brickson

/// Where the Library's question screens put the way back, the words and
/// the choices (`LibraryQuestionPlace`). Each test names the change that
/// would make it fail.
struct LibraryQuestionPlaceTests {
    private static let rowHeight = SettingsMetrics.rowHeight
    private static let spacing = SettingsMetrics.rowSpacing

    private static func place(
        row: CGRect?, rowIsLast: Bool = false, width: CGFloat = 358, visibleHeight: CGFloat = 600,
        backHeight: CGFloat = 64, wordsHeight: CGFloat = 80, choicesHeight: CGFloat = 64
    ) -> LibraryQuestionPlace {
        LibraryQuestionPlace(
            row: row, rowIsLast: rowIsLast, width: width, visibleHeight: visibleHeight,
            backHeight: { _ in backHeight }, wordsHeight: { _ in wordsHeight }, choicesHeight: { _ in choicesHeight },
            spacing: spacing, rowHeight: rowHeight
        )
    }

    /// Keep takes the asking control's place (invariant 3). Fails if the
    /// way back is placed anywhere but the opening row's frame.
    @Test func theWayBackTakesTheRowsPlace() {
        let row = CGRect(x: 0, y: 300, width: 358, height: 64)
        #expect(Self.place(row: row).back == row)
    }

    /// Fails if a way back taller than the row grows upward, away from
    /// where the row was, or a shorter one shrinks the row's place.
    @Test func aTallerWayBackGrowsDown() {
        let row = CGRect(x: 0, y: 300, width: 358, height: 64)
        #expect(Self.place(row: row, backHeight: 100).back == CGRect(x: 0, y: 300, width: 358, height: 100))
        #expect(Self.place(row: row, backHeight: 40).back == row)
    }

    /// Fails if the words are put anywhere but just above the way back
    /// where they fit, and just under it where they do not.
    @Test func theWordsGoJustAboveWhereTheyFit() {
        let low = Self.place(row: CGRect(x: 0, y: 300, width: 358, height: 64))
        #expect(low.words == CGRect(x: 0, y: 300 - Self.spacing - 80, width: 358, height: 80))
        let high = Self.place(row: CGRect(x: 0, y: 40, width: 358, height: 64))
        #expect(high.words == CGRect(x: 0, y: 40 + 64 + Self.spacing, width: 358, height: 80))
    }

    /// Fails if a row measured below what shows, or above the content,
    /// puts the way back where a look cannot be.
    @Test func theWayBackStaysWithinWhatShows() {
        let below = Self.place(row: CGRect(x: 0, y: 900, width: 358, height: 64))
        #expect(below.back.maxY == 600)
        let above = Self.place(row: CGRect(x: 0, y: -30, width: 358, height: 64))
        #expect(above.back.minY == 0)
    }

    /// Fails if a screen opened with no measured row does not start at the
    /// top with its words under the way back.
    @Test func withNoRowTheWayBackIsAtTheTop() {
        let place = Self.place(row: nil)
        #expect(place.back == CGRect(x: 0, y: 0, width: 358, height: 64))
        #expect(place.words.minY == 64 + Self.spacing)
    }

    /// A held look on the spot just activated, or resting on the words
    /// while reading, must meet the way back, never a choice that deletes,
    /// moves or replaces (invariant 10). Fails if the choices start less
    /// than a row below both, or where any point of the way back or the
    /// words is nearer the first choice, by centre or by edge, with the
    /// margin. Swept over rows from the top to the foot, phone and iPad
    /// widths, and short to tall words and ways back.
    @Test(arguments: [288, 704] as [CGFloat])
    func noPointOfTheWayBackOrTheWordsIsNearerAChoice(width: CGFloat) {
        for top in stride(from: CGFloat(0), through: 640, by: 59) {
            for wordsHeight in [24, 200] as [CGFloat] {
                for backHeight in [64, 130] as [CGFloat] {
                    let place = Self.place(
                        row: CGRect(x: 0, y: top, width: width, height: 64), width: width,
                        backHeight: backHeight, wordsHeight: wordsHeight
                    )
                    #expect(place.choicesTop >= max(place.back.maxY, place.words.maxY) + Self.rowHeight)
                    let choice = CGRect(x: 0, y: place.choicesTop, width: width, height: Self.rowHeight)
                    let points = [place.back, place.words].flatMap { SettingsRowPlace.points(across: $0, every: 4) }
                    let nearer = points.allSatisfy {
                        SettingsRowPlace.isNearer($0, toOneOf: [place.back], thanAny: [choice], margin: SettingsRowPlace.margin)
                    }
                    #expect(nearer, "row at \(top), \(width) wide, words \(wordsHeight), way back \(backHeight)")
                }
            }
        }
    }

    /// A look in the gap under a row met the row too. Fails if the first
    /// choice is nearer any point of that gap than the way back is.
    @Test func theGapUnderTheRowIsNearerTheWayBack() {
        let place = Self.place(row: CGRect(x: 0, y: 300, width: 358, height: 64))
        let gap = CGRect(x: 0, y: 364, width: 358, height: Self.spacing / 2)
        let choice = CGRect(x: 0, y: place.choicesTop, width: 358, height: Self.rowHeight)
        let nearer = SettingsRowPlace.points(across: gap, every: 2).allSatisfy {
            SettingsRowPlace.isNearer($0, toOneOf: [place.back], thanAny: [choice], margin: SettingsRowPlace.margin)
        }
        #expect(nearer)
    }

    /// A screen's last row is nearest every point under it. Fails if its
    /// question puts a choice under the way back, if the choices are not a
    /// row and a gap clear above it, or if the words are not under it.
    @Test func aLastRowsChoicesGoAbove() {
        let row = CGRect(x: 0, y: 400, width: 358, height: 64)
        let place = Self.place(row: row, rowIsLast: true, choicesHeight: 144)
        #expect(place.back == row)
        #expect(place.choicesTop + 144 == row.minY - Self.rowHeight - Self.spacing)
        #expect(place.words.minY == row.maxY + Self.spacing)
    }

    /// Where a last row's choices do not fit above it, they go below every
    /// point down to the foot of what shows. Fails if a point there, under
    /// the way back, is nearer the first choice.
    @Test func aLastRowsChoicesThatDoNotFitAboveGoBelowTheFoot() {
        let row = CGRect(x: 0, y: 100, width: 358, height: 64)
        let place = Self.place(row: row, rowIsLast: true, choicesHeight: 400)
        let choice = CGRect(x: 0, y: place.choicesTop, width: 358, height: Self.rowHeight)
        let under = CGRect(x: 0, y: row.maxY, width: 358, height: 600 - row.maxY)
        let nearer = SettingsRowPlace.points(across: under, every: 8).allSatisfy {
            SettingsRowPlace.isNearer($0, toOneOf: [place.back], thanAny: [choice], margin: SettingsRowPlace.margin)
        }
        #expect(place.choicesTop > 600)
        #expect(nearer)
    }
}

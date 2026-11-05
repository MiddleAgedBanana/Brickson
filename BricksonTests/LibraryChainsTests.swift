import Foundation
import Testing
@testable import Brickson

/// The Library's screens as the chain engine scores them (`LibraryChains`),
/// on modelled frames: a phone's content, rows 64 points tall and 16 apart,
/// and the question screens placed by `LibraryQuestionPlace` from the row
/// that asked. The UI tests score the frames the running app draws.
struct LibraryChainsTests {
    /// The content's top leading corner, in the window, under the safety
    /// bar and the navigation bar.
    private static let content = CGPoint(x: 16, y: 180)
    private static let width: CGFloat = 358
    private static let visibleHeight: CGFloat = 640
    private static let backToTalking = CGRect(x: 16, y: 50, width: 358, height: 60)
    private static let back = CGRect(x: 16, y: 120, width: 44, height: 44)

    /// A row of a screen, in the window, after the line kept for results.
    private static func row(_ index: Int) -> CGRect {
        CGRect(x: content.x, y: content.y + 38 + 80 * CGFloat(index), width: width, height: 64)
    }

    private static let bar: [(name: String, frame: CGRect)] = [
        (LibraryChains.backToTalking, backToTalking), (LibraryChains.back, back),
    ]

    private static let library: [(name: String, frame: CGRect)] = bar + [
        (LibraryChains.emergencyRow, row(0)),
        ("libraryCategory0", row(1)), ("libraryCategory1", row(2)), ("libraryCategory2", row(3)), ("libraryCategory3", row(4)),
        (LibraryChains.addCategory, row(5)),
    ]

    /// A category whose lower phrase rows lie under Edit Phrase's last
    /// row, Delete Phrase.
    private static let category: [(name: String, frame: CGRect)] = bar + [(LibraryChains.addPhrase, row(0))]
        + (0..<5).map { ("libraryPhrase\($0)", row($0 + 1)) }
        + [(LibraryChains.changePicture, row(6)), (LibraryChains.rename, row(7))]

    /// Edit Phrase: the field (not a button) keeps four lines at the top,
    /// and Delete Phrase is the last control.
    private static let save = CGRect(x: 16, y: 336, width: 358, height: 64)
    private static let movePhraseRow = CGRect(x: 16, y: 454, width: 358, height: 64)
    private static let deletePhraseRow = CGRect(x: 16, y: 534, width: 358, height: 64)
    private static let editor: [(name: String, frame: CGRect)] = bar + [
        (LibraryChains.save, save), (LibraryChains.movePhraseRow, movePhraseRow), (LibraryChains.deletePhraseRow, deletePhraseRow),
    ]

    /// A question opened from `row`, in the window: the way back and the
    /// choices where `LibraryQuestionPlace` puts them, full rows unless
    /// `columns` makes them a grid of 64-point squares, and the words.
    private static func question(
        from row: CGRect, isLast: Bool = false, choices: [String], columns: Int = 1
    ) -> (controls: [(name: String, frame: CGRect)], words: CGRect) {
        let inContent = row.offsetBy(dx: -content.x, dy: -content.y)
        let lines = CGFloat((choices.count + columns - 1) / columns)
        let place = LibraryQuestionPlace(
            row: inContent, rowIsLast: isLast, width: width, visibleHeight: visibleHeight,
            backHeight: { _ in 64 }, wordsHeight: { _ in 66 }, choicesHeight: { _ in 80 * lines - 16 },
            spacing: 16, rowHeight: 64
        )
        let toWindow = { (frame: CGRect) in frame.offsetBy(dx: content.x, dy: content.y) }
        let choices = choices.enumerated().map { index, name in
            let frame = columns == 1
                ? CGRect(x: 0, y: place.choicesTop + 80 * CGFloat(index), width: width, height: 64)
                : CGRect(x: 80 * CGFloat(index % columns), y: place.choicesTop + 80 * CGFloat(index / columns), width: 64, height: 64)
            return (name, toWindow(frame))
        }
        return (bar + [(LibraryChains.wayBack, toWindow(place.back))] + choices, toWindow(place.words))
    }

    private static let pictures = ["libraryPicture-heart.fill", "libraryPicture-star.fill", "libraryPicture-house.fill", "libraryPicture-bed.double.fill"]

    private static func map(
        deletePhrase: [(name: String, frame: CGRect)], pictureColumns: Int = 1
    ) -> (map: ChainMap, unknown: [String]) {
        let delete = question(from: deletePhraseRow, isLast: true, choices: [LibraryChains.deleteForGood])
        let move = question(from: movePhraseRow, choices: (0..<7).map { "libraryMovePlace\($0)" })
        let picture = question(from: row(6), choices: pictures, columns: pictureColumns)
        return LibraryChains.map(
            LibraryChains.Screens(
                library: library, categoryRow: "libraryCategory0", category: category,
                editor: editor,
                deletePhrase: deletePhrase,
                movePhrase: move.controls,
                picture: picture.controls,
                words: [LibraryChains.deletePhrase: delete.words, LibraryChains.movePhrase: move.words, LibraryChains.picture: picture.words]
            ),
            closingOnto: "Home"
        )
    }

    /// Fails if a held look, after any choice on the Library's screens or
    /// resting on a question's words, deletes, moves or changes something
    /// it did not choose: the way back takes the asking row's place, the
    /// words sit beside it, the choices start well below both, and Delete
    /// for Good dims in place once it has deleted.
    @Test func noHeldLookChangesTheLibrary() {
        let modelled = Self.map(
            deletePhrase: Self.question(from: Self.deletePhraseRow, isLast: true, choices: [LibraryChains.deleteForGood]).controls
        )
        #expect(modelled.unknown == [])
        let hazards = modelled.map.hazards(from: LibraryChains.starts(in: modelled.map))
        #expect(ChainFinding.findings(in: hazards).map(\.description) == [])
        #expect(LibraryChains.starts(in: modelled.map).contains { $0.chosen == nil }, "no start rests on a question's words")
    }

    /// The same screens with Delete for Good where Delete Phrase was, and
    /// the way back at the top. Fails if the surface could not see the
    /// hazard the placement prevents: a look still resting where Delete
    /// Phrase was deletes the phrase.
    @Test func deleteForGoodUnderTheAskingRowIsFound() {
        let top = CGRect(x: Self.content.x, y: Self.content.y, width: Self.width, height: 64)
        let modelled = Self.map(deletePhrase: Self.bar + [
            (LibraryChains.wayBack, top), (LibraryChains.deleteForGood, Self.deletePhraseRow),
        ])
        let hazards = modelled.map.hazards(from: LibraryChains.starts(in: modelled.map))
        #expect(hazards.contains { LibraryChains.kind(of: $0) == .changesTheLibrary && $0.hazard?.control.name == LibraryChains.deleteForGood })
    }

    /// Delete for Good under the way back, though Delete Phrase is Edit
    /// Phrase's last control. Fails if the surface could not see why its
    /// choice goes above: a phrase row lower than Delete Phrase opens the
    /// editor, the look under Delete Phrase meets it, and then meets Delete
    /// for Good, deleting a phrase nobody chose.
    @Test func deleteForGoodUnderALastRowIsFound() {
        let modelled = Self.map(deletePhrase: Self.question(from: Self.deletePhraseRow, choices: [LibraryChains.deleteForGood]).controls)
        let hazards = modelled.map.hazards(from: LibraryChains.starts(in: modelled.map))
        #expect(hazards.contains { LibraryChains.kind(of: $0) == .changesTheLibrary && $0.hazard?.control.name == LibraryChains.deleteForGood })
    }

    /// Change Picture's pictures as a grid of 64-point squares under the way
    /// back. Fails if the surface could not see why they are rows as wide
    /// as it: by the nearest centre, a look at the asking row's lower
    /// corner meets the first picture, not the way back.
    @Test func picturesNarrowerThanTheWayBackAreFound() {
        let modelled = Self.map(
            deletePhrase: Self.question(from: Self.deletePhraseRow, isLast: true, choices: [LibraryChains.deleteForGood]).controls,
            pictureColumns: 4
        )
        let hazards = modelled.map.hazards(from: LibraryChains.starts(in: modelled.map))
        #expect(hazards.contains { LibraryChains.kind(of: $0) == .changesTheLibrary && $0.hazard?.state == LibraryChains.picture })
    }

    /// Fails if a control the surface does not know is scored as harmless
    /// instead of reported.
    @Test func anUnknownControlIsReported() {
        let screens = LibraryChains.Screens(
            library: Self.library + [("somethingNew", Self.row(6))], categoryRow: "libraryCategory0", category: nil
        )
        #expect(LibraryChains.map(screens, closingOnto: "Home").unknown == ["somethingNew on \(LibraryChains.library)"])
    }
}

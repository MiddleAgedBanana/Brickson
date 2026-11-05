import SwiftUI
import Testing
@testable import Brickson

/// Which words the Library's editors find too wide for Home
/// (`HomeWordRoom`), measured with the real fonts. Each test names the
/// change that would make it fail.
struct HomeWordRoomTests {
    private let library: LibrarySnapshot

    init() throws {
        library = try StarterLibrary.bundled()
    }

    /// Everyday words longer than most, for the measured table the owner's
    /// decision on long words rests on (docs/DECISIONS.md, "Words wider
    /// than Home's narrowest buttons"). Neutral and practical, like the
    /// starter library's.
    static let longWords = [
        "understand.", "uncomfortable.", "uncomfortable", "comfortable.", "comfortable",
        "appointment", "temperature", "medication", "repositioned", "wheelchair",
        "television", "headphones", "grandchildren", "conversation", "everything",
        "breakfast", "something", "important", "tomorrow", "physiotherapist",
    ]

    /// Fails if a room is narrower than the width the starter library's
    /// words set, so the editors would flag the starter's own words.
    @Test func everyStarterWordFits() {
        for phrase in library.categories.flatMap(\.phrases).map(\.text) {
            #expect(HomeWordRoom.wordsTooWide(inPhrase: phrase).isEmpty, "\"\(phrase)\"")
        }
        for name in library.categories.filter({ !$0.isEmergency }).map(\.name) {
            #expect(HomeWordRoom.wordsTooWide(inCategoryName: name).isEmpty, "\"\(name)\"")
        }
    }

    /// Fails if a word wider than the narrowest tile or category button is
    /// let through: "uncomfortable." needs about 132 points of the compact
    /// tile's 99, "Entertainment" about 124 of the category button's 110.
    @Test func aWordWiderThanTheNarrowestButtonIsFound() {
        #expect(HomeWordRoom.wordsTooWide(inPhrase: "I'm uncomfortable.") == ["uncomfortable."])
        #expect(HomeWordRoom.wordsTooWide(inCategoryName: "Entertainment") == ["Entertainment"])
        #expect(HomeWordRoom.wordsTooWide(inCategoryName: "Fun") == [])
    }

    /// Fails if a word is reported twice, out of order, or with the
    /// spaces and line breaks around it.
    @Test func eachWordIsReportedOnceInOrder() {
        let long = String(repeating: "W", count: 30)
        let longer = String(repeating: "M", count: 40)
        #expect(HomeWordRoom.wordsTooWide(inPhrase: "  \(long) and \(long)\n\(longer) yes ") == [long, longer])
        #expect(HomeWordRoom.wordsTooWide(inPhrase: "").isEmpty)
    }

    /// Fails if `HomeWordRoom` lets through a word that SwiftUI draws wider
    /// than its room, so what the editors check is what Home draws. The
    /// table of every long word's measure in every room is attached to the
    /// result.
    @Test(arguments: [false, true])
    func theLongWordsAreMeasuredAsSwiftUIDrawsThem(boldText: Bool) {
        var table = ["word\tfont\tBold Text\troom\tmeasured\tfits"]
        let rooms = HomeWordRoom.phraseRooms(boldText: boldText) + HomeWordRoom.categoryRooms(boldText: boldText)
        for room in rooms {
            for word in Self.longWords {
                let measured = room.font.widestWord(word, at: .large)
                let fits = HomeWordRoom.fits(word, in: room)
                table.append("\(word)\t\(room.font.textStyle)\t\(boldText)\t\(room.width)\t\(measured)\t\(fits)")
                guard fits else { continue }
                let drawn = StarterLabelFitTests.drawnSize(word, room.font, boldText: boldText).width
                #expect(drawn <= room.width, "\"\(word)\" in \(room.font.textStyle): drawn \(drawn), room \(room.width)")
            }
        }
        Attachment.record(table.joined(separator: "\n"), named: "long-words-\(boldText ? "bold" : "regular").tsv")
    }
}

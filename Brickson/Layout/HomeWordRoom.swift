import SwiftUI

/// Whether each word of a phrase or a category's name is drawn whole on
/// Home in every window the layout engine plans for.
///
/// A label never draws below the default text size (AGENTS.md, "Words
/// never break"), so a word wider than its control at that size has
/// nowhere to go: alone it is cut short, and in a phrase of several words
/// it wraps mid-word (docs/HANDOFF.md, *Known gaps*). The narrowest each
/// control may be is set by the starter library's widest words
/// (`HomeLayout.compactTile`, `.regularTile` and `.MinimumWidths`), and
/// `HomeLayoutEngineTests` checks that no window makes one narrower. So a
/// word that fits those widths, measured as the engine measures, with
/// Bold Text off and on, is whole in every window.
///
/// The Library's editors use it: a category name with a word that does
/// not fit is refused, since a shorter name always does the job, and a
/// phrase is saved with a note naming the word (docs/DECISIONS.md, "Words
/// wider than Home's narrowest buttons").
enum HomeWordRoom {
    /// The width a word may take in a font, slack included.
    struct Room: Equatable {
        let font: LabelFont
        let width: CGFloat
    }

    /// Where a phrase's words are drawn: the narrowest compact and regular
    /// tiles inside their label inset, and the message.
    static func phraseRooms(boldText: Bool) -> [Room] {
        let legibility: LegibilityWeight = boldText ? .bold : .regular
        let inset = 2 * HomeLayout.labelInset.horizontal
        let compact = boldText ? HomeLayout.compactTile.boldMinimumWidth : HomeLayout.compactTile.minimumWidth
        let regular = boldText ? HomeLayout.regularTile.boldMinimumWidth : HomeLayout.regularTile.minimumWidth
        return [
            Room(font: LabelFont.compactTile.legible(legibility), width: compact - inset),
            Room(font: LabelFont.regularTile.legible(legibility), width: regular - inset),
            Room(font: LabelFont.message.legible(legibility), width: HomeLayout.MinimumWidths.forBoldText(boldText).message),
        ]
    }

    /// Where an everyday category's name is drawn: the narrowest category
    /// button, inside the wider side inset of a control that shows
    /// selected (`HomeLayout.selectableSideInset`).
    static func categoryRooms(boldText: Bool) -> [Room] {
        let legibility: LegibilityWeight = boldText ? .bold : .regular
        let minimum = HomeLayout.MinimumWidths.forBoldText(boldText).category
        return [
            Room(font: LabelFont.category.legible(legibility), width: minimum - 2 * HomeLayout.selectableSideInset),
        ]
    }

    /// The words of a phrase too wide for one of its rooms, each once, in
    /// the order they come.
    static func wordsTooWide(inPhrase text: String) -> [String] {
        wordsTooWide(in: text, rooms: phraseRooms(boldText: false) + phraseRooms(boldText: true))
    }

    /// The words of a category's name too wide for the narrowest category
    /// button, each once, in the order they come.
    static func wordsTooWide(inCategoryName name: String) -> [String] {
        wordsTooWide(in: name, rooms: categoryRooms(boldText: false) + categoryRooms(boldText: true))
    }

    /// Whether `word` fits `room` at the default text size, with
    /// `WordFit.widthSlack`, as `StarterLabelFitTests` checks the starter
    /// library's words.
    static func fits(_ word: String, in room: Room) -> Bool {
        room.font.widestWord(word, at: .large) + WordFit.widthSlack <= room.width
    }

    private static func wordsTooWide(in text: String, rooms: [Room]) -> [String] {
        var reported: Set<String> = []
        return WordFit.words(in: text).map(String.init).filter { word in
            !rooms.allSatisfy { fits(word, in: $0) } && reported.insert(word).inserted
        }
    }
}

import Foundation
import SwiftData
import Testing
@testable import Brickson

struct CategorySelectionTests {
    // Models live in a container for the whole test: SwiftData expects one
    // to exist before any model is created.
    private let container: ModelContainer
    private let everyday: PhraseCategory
    private let emergency: PhraseCategory
    private let feelings: PhraseCategory

    init() throws {
        container = try PhraseLibraryStore.makeInMemoryContainer()
        everyday = PhraseCategory(name: "Basics", symbolName: "star.fill", sortOrder: 1)
        emergency = PhraseCategory(
            name: "Emergency",
            symbolName: "exclamationmark.triangle.fill",
            sortOrder: 0,
            isEmergency: true
        )
        feelings = PhraseCategory(name: "Feelings", symbolName: "heart.fill", sortOrder: 2)
        for category in [everyday, emergency, feelings] {
            container.mainContext.insert(category)
        }
    }

    private var ordered: [PhraseCategory] { [emergency, everyday, feelings] }

    /// Every category with as many phrases as Home needs to offer it.
    private var full: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: ordered.map { ($0.uuid, LibraryRules.fewestPhrases) })
    }

    @Test func startsOnTheFirstEverydayCategoryEvenWhenEmergencyComesFirst() {
        #expect(CategorySelection.resolve(ordered, selectedID: nil) === everyday)
    }

    @Test func keepsTheChosenCategory() {
        #expect(CategorySelection.resolve(ordered, selectedID: feelings.uuid) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: emergency.uuid) === emergency)
    }

    @Test func aChosenCategoryThatNoLongerExistsFallsBackToTheFirstEverydayOne() {
        #expect(CategorySelection.resolve(ordered, selectedID: UUID()) === everyday)
    }

    @Test func aLibraryWithOnlyEmergencyPhrasesStillShowsThem() {
        #expect(CategorySelection.resolve([emergency], selectedID: nil) === emergency)
    }

    @Test func anEmptyLibraryShowsNothing() {
        #expect(CategorySelection.resolve([], selectedID: nil) == nil)
    }

    @Test func emergencyFindsTheEmergencyCategory() {
        #expect(CategorySelection.emergency(in: ordered) === emergency)
        #expect(CategorySelection.emergency(in: [everyday, feelings]) == nil)
    }

    /// The Emergency quick control is the emergency category's only button,
    /// so "Emergency" names exactly one control on Home.
    @Test func theCategoryRowLeavesOutTheEmergencyCategory() {
        let shown = CategorySelection.shownInCategoryRow(ordered)
        #expect(shown.count == 2)
        #expect(shown.first === everyday)
        #expect(shown.last === feelings)
    }

    /// Fails if a category past Home's last cell is dropped (it must stay
    /// reachable in the last cell, which scrolls), or a cell shows another
    /// cell's category.
    @Test func theLastCellHoldsEveryCategoryFromThereOn() {
        let four = Array(0..<4)
        #expect((0..<4).map { Array(CategorySelection.inCell($0, of: four, cells: 4)) } == [[0], [1], [2], [3]])
        let six = Array(0..<6)
        #expect(Array(CategorySelection.inCell(3, of: six, cells: 4)) == [3, 4, 5])
        #expect(Array(CategorySelection.inCell(1, of: six, cells: 4)) == [1])
        let two = Array(0..<2)
        #expect(CategorySelection.inCell(2, of: two, cells: 4).isEmpty)
        #expect(CategorySelection.inCell(3, of: two, cells: 4).isEmpty)
        #expect(CategorySelection.inCell(-1, of: four, cells: 4).isEmpty)
        #expect(CategorySelection.inCell(4, of: four, cells: 4).isEmpty)
        #expect(CategorySelection.inCell(0, of: four, cells: 0).isEmpty)
    }

    // MARK: The rest board (docs/DECISIONS.md, "The late-stage profile")

    /// Fails if the board shows anything but its own category or
    /// Emergency's: every other category is dimmed there, so a remembered
    /// choice of one would show phrases no button on the screen leads to.
    @Test func theRestBoardShowsItsCategoryOrEmergency() {
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: feelings.uuid, phraseCounts: full) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: everyday.uuid, restBoard: feelings.uuid, phraseCounts: full) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: UUID(), restBoard: feelings.uuid, phraseCounts: full) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: emergency.uuid, restBoard: feelings.uuid, phraseCounts: full) === emergency)
    }

    /// Fails if a board the library no longer holds, or Emergency named as
    /// one, changes what Home shows: Home then shows every category as it
    /// would with no board.
    @Test func aBoardNotInTheLibraryShowsAsEveryCategoryDoes() {
        #expect(CategorySelection.resolve(ordered, selectedID: feelings.uuid, restBoard: UUID(), phraseCounts: full) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: UUID(), phraseCounts: full) === everyday)
        #expect(CategorySelection.resolve(ordered, selectedID: feelings.uuid, restBoard: emergency.uuid, phraseCounts: full) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: nil, phraseCounts: full) === everyday)
    }

    /// The rest board's category shows whatever it holds: Set Up offers no
    /// board with too few phrases, and one chosen before stays the
    /// person's. Fails if it is skipped for being short.
    @Test func theRestBoardShowsEvenWithTooFewPhrases() {
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: feelings.uuid, phraseCounts: [:]) === feelings)
    }

    // MARK: Four phrases in every category (docs/DECISIONS.md)

    /// Fails if Home shows an everyday category with fewer phrases than the
    /// widest grid has columns, chosen or not: its empty cells would border
    /// the controls above the grid.
    @Test func aCategoryWithTooFewPhrasesIsNeverShown() {
        var counts = full
        counts[feelings.uuid] = LibraryRules.fewestPhrases - 1
        #expect(CategorySelection.resolve(ordered, selectedID: feelings.uuid, restBoard: nil, phraseCounts: counts) === everyday)
        counts[everyday.uuid] = 0
        counts[feelings.uuid] = LibraryRules.fewestPhrases
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: nil, phraseCounts: counts) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: everyday.uuid, restBoard: nil, phraseCounts: counts) === feelings)
    }

    /// Fails if Home, offering no everyday category, shows a dimmed one
    /// instead of Emergency's phrases, or stops showing Emergency's when
    /// they are fewer than four (Emergency is never dimmed, invariant 2).
    @Test func offeringNoEverydayCategoryHomeShowsEmergency() {
        let counts = [emergency.uuid: 1, everyday.uuid: 3]
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: nil, phraseCounts: counts) === emergency)
        #expect(CategorySelection.resolve(ordered, selectedID: everyday.uuid, restBoard: nil, phraseCounts: counts) === emergency)
        #expect(CategorySelection.resolve(ordered, selectedID: emergency.uuid, restBoard: nil, phraseCounts: counts) === emergency)
        #expect(CategorySelection.isOffered(emergency, phraseCounts: [:]))
    }

    /// A damaged library with no Emergency and no category Home offers
    /// still shows a category, as before the rule. Fails if it shows
    /// nothing.
    @Test func aLibraryOfferingNothingFallsBackToEveryCategory() {
        #expect(CategorySelection.resolve([everyday, feelings], selectedID: nil, restBoard: nil, phraseCounts: [:]) === everyday)
    }

    /// Fails if a category's button is dimmed with enough phrases, or not
    /// dimmed with too few; or if, on the rest board, the board's rule
    /// stops deciding: every other category dimmed, the board never.
    @Test func aCategoryIsDimmedWithTooFewPhrasesOrOffTheRestBoard() {
        var counts = full
        #expect(!CategorySelection.isDimmed(feelings, restBoard: nil, phraseCounts: counts))
        counts[feelings.uuid] = LibraryRules.fewestPhrases - 1
        #expect(CategorySelection.isDimmed(feelings, restBoard: nil, phraseCounts: counts))
        #expect(!CategorySelection.isDimmed(feelings, restBoard: feelings.uuid, phraseCounts: counts))
        #expect(CategorySelection.isDimmed(everyday, restBoard: feelings.uuid, phraseCounts: full))
    }

    /// Fails if the board's view of the library loses a category, its order,
    /// which one is Emergency, or a phrase count, from which the grid's
    /// rows are sized.
    @Test func theBoardsLibraryKeepsEachCategoryInOrder() throws {
        for (order, text) in ["Yes please", "Not now", "Later"].enumerated() {
            container.mainContext.insert(Phrase(text: text, sortOrder: order, category: feelings))
        }
        try container.mainContext.save()
        let library = CategorySelection.restBoardLibrary(ordered)
        #expect(library == [
            RestBoard.Category(id: emergency.uuid, isEmergency: true, phrases: 0),
            RestBoard.Category(id: everyday.uuid, isEmergency: false, phrases: 0),
            RestBoard.Category(id: feelings.uuid, isEmergency: false, phrases: 3),
        ])
    }

    // MARK: The grid's phrases

    /// Fails if Home's grid shows another category's phrase or one in no
    /// category, loses the fixed order (place, then words, then identity),
    /// or carries anything but each phrase's identity and words.
    @Test func theGridShowsOneCategorysPhrasesInTheirOrder() {
        let tied = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let phrases = [
            Phrase(text: "Later", sortOrder: 2, category: feelings),
            Phrase(text: "Water", sortOrder: 0, category: everyday),
            Phrase(text: "Yes please", sortOrder: 0, category: feelings),
            Phrase(text: "Not now", sortOrder: 1, category: feelings, uuid: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!),
            Phrase(text: "Not now", sortOrder: 1, category: feelings, uuid: tied),
            Phrase(text: "Alone", sortOrder: 0),
        ]
        for phrase in phrases { container.mainContext.insert(phrase) }

        let shown = CategorySelection.phrases(of: feelings.uuid, in: phrases)
        #expect(shown?.map(\.text) == ["Yes please", "Not now", "Not now", "Later"])
        #expect(shown?[1].id == tied)
        #expect(shown?.map(\.id) == Phrase.orderedForDisplay(phrases.filter { $0.category === feelings }).map(\.uuid))
        #expect(CategorySelection.phrases(of: emergency.uuid, in: phrases) == [])
        #expect(CategorySelection.phrases(of: nil, in: phrases) == nil)
    }

    /// Fails if a category's count, from which the grid's rows are sized,
    /// misses a phrase, counts another category's, or counts a phrase in
    /// no category.
    @Test func eachCategoryCountsItsOwnPhrases() {
        let phrases = [
            Phrase(text: "Water", sortOrder: 0, category: everyday),
            Phrase(text: "Tea", sortOrder: 1, category: everyday),
            Phrase(text: "Yes please", sortOrder: 0, category: feelings),
            Phrase(text: "Alone", sortOrder: 0),
        ]
        for phrase in phrases { container.mainContext.insert(phrase) }

        #expect(CategorySelection.phraseCounts(phrases) == [everyday.uuid: 2, feelings.uuid: 1])
    }
}

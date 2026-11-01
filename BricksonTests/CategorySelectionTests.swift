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
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: feelings.uuid) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: everyday.uuid, restBoard: feelings.uuid) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: UUID(), restBoard: feelings.uuid) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: emergency.uuid, restBoard: feelings.uuid) === emergency)
    }

    /// Fails if a board the library no longer holds, or Emergency named as
    /// one, changes what Home shows: Home then shows every category as it
    /// would with no board.
    @Test func aBoardNotInTheLibraryShowsAsEveryCategoryDoes() {
        #expect(CategorySelection.resolve(ordered, selectedID: feelings.uuid, restBoard: UUID()) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: UUID()) === everyday)
        #expect(CategorySelection.resolve(ordered, selectedID: feelings.uuid, restBoard: emergency.uuid) === feelings)
        #expect(CategorySelection.resolve(ordered, selectedID: nil, restBoard: nil) === everyday)
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
}

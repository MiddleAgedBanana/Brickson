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
}

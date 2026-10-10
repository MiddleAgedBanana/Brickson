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
}

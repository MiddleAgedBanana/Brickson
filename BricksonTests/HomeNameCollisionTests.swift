import SwiftData
import Testing
@testable import Brickson

/// Voice Control on Home with the starter library: no two controls on the
/// screen answer to the same name, whichever category shows
/// (docs/ACCESSIBILITY.md, section 3). When two do, Voice Control stops to
/// ask which one is meant, which costs the person another command every
/// time. A library a family has grown is checked when editing arrives
/// (ROADMAP R0, item 6).
struct HomeNameCollisionTests {
    /// Fails if a starter phrase, a category name or a fixed control's name,
    /// its other names included, sounds the same as another control on the
    /// same screen: a tile "Again." or "Repeat.", or a category named "Yes".
    /// The categories and phrases come from the starter library as the app
    /// stores it, and the category row from the same rule Home uses.
    @Test func noTwoControlsOnHomeShareANameWhicheverCategoryShows() throws {
        let container = try PhraseLibraryStore.makeInMemoryContainer()
        try PhraseLibrarySeeder.seedIfEmpty(container, with: StarterLibrary.bundled())
        let ordered = PhraseCategory.orderedForDisplay(
            try container.mainContext.fetch(FetchDescriptor<PhraseCategory>())
        )
        let categoryRow = CategorySelection.shownInCategoryRow(ordered).map(\.name)
        #expect(!ordered.isEmpty)

        for category in ordered {
            let phrases = category.phrasesInOrder.map(\.text)
            #expect(!phrases.isEmpty, "\(category.name) has no phrases")
            let controls = HomeControlNames.onHome(categoryRow: categoryRow, phrases: phrases)
            #expect(
                HomeControlNames.collisions(among: controls) == [],
                "two controls share a name while \(category.name) shows"
            )
        }
    }
}

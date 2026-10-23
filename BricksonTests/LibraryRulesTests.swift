import Testing
import UIKit
@testable import Brickson

/// The lists the editor offers. Edits themselves are in `LibraryEditTests`.
struct LibraryRulesTests {
    /// A misspelled SF Symbol name draws nothing at all, with no error, so
    /// a family could choose a blank picture.
    @Test func everySymbolChoiceExists() {
        for symbol in LibraryRules.symbolChoices {
            #expect(UIImage(systemName: symbol) != nil, "\(symbol) is not an SF Symbol")
        }
    }

    @Test func everySymbolChoiceIsListedOnce() {
        #expect(Set(LibraryRules.symbolChoices).count == LibraryRules.symbolChoices.count)
    }

    /// Fails if a new category would start with a picture the editor then
    /// refuses to keep.
    @Test func aNewCategoryStartsWithAListedSymbol() {
        #expect(LibraryRules.symbolChoices.contains(LibraryRules.newCategorySymbol))
    }
}

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

    /// Every picture is a button named in words for VoiceOver and Voice
    /// Control (`LibrarySymbolNames`). Fails if a picture is added without
    /// a name, or two share one, which Voice Control could not tell apart.
    @Test func everySymbolChoiceHasAName() {
        let names = LibraryRules.symbolChoices.map(LibrarySymbolNames.name(of:))
        let fallback = LibrarySymbolNames.name(of: "not.a.listed.symbol")
        for (symbol, name) in zip(LibraryRules.symbolChoices, names) {
            #expect(!name.isEmpty && name != fallback, "\(symbol) has no name of its own")
        }
        #expect(Set(names).count == names.count)
    }

    @Test func everySymbolChoiceIsListedOnce() {
        #expect(Set(LibraryRules.symbolChoices).count == LibraryRules.symbolChoices.count)
    }

    /// Fails if a new category would start with a picture the editor then
    /// refuses to keep.
    @Test func aNewCategoryStartsWithAListedSymbol() {
        #expect(LibraryRules.symbolChoices.contains(LibraryRules.newCategorySymbol))
    }

    @Test func everyLibraryEditRejectionCaseHasANonEmptyUserFacingMessage() {
        let cases: [LibraryEditRejection] = [
            .emptyName,
            .emptyText,
            .duplicateCategoryName,
            .duplicatePhrase,
            .reservedCategoryName,
            .unknownSymbol,
            .emergencyCategoryCannotBeDeleted,
            .emergencyCategoryNeedsAPhrase,
            .libraryNeedsACategory,
            .homeHasRoomForFour,
            .homeNeedsThree,
            .notFound,
            .libraryNeedsRepair,
        ]
        for rejection in cases {
            #expect(!rejection.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        #expect(Set(cases.map(\.message)).count == cases.count)
    }
}

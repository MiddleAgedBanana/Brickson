import Foundation
import Testing
import UIKit
@testable import Brickson

/// The bundled starter phrases: the first thing every new person sees.
struct StarterPhrasesTests {
    private let library: StarterLibrary

    init() throws {
        library = try StarterLibrary.bundled()
    }

    @Test func thereIsExactlyOneEmergencyCategory() {
        #expect(library.categories.filter(\.isEmergency).count == 1)
    }

    @Test func everyCategoryHasANameAndPhrases() {
        for category in library.categories {
            #expect(!category.name.trimmingCharacters(in: .whitespaces).isEmpty)
            #expect(!category.phrases.isEmpty, "\(category.name) has no phrases")
        }
    }

    @Test func categoryNamesAreUnique() {
        let names = library.categories.map { $0.name.lowercased() }
        #expect(Set(names).count == names.count)
    }

    /// A phrase listed twice in one category is two tiles that say the same
    /// thing, taking a place a different phrase could have.
    @Test func noPhraseAppearsTwiceInACategory() {
        for category in library.categories {
            let phrases = category.phrases.map { $0.lowercased() }
            #expect(Set(phrases).count == phrases.count, "\(category.name) repeats a phrase")
        }
    }

    @Test func noPhraseIsBlankOrHasStraySpaces() {
        for phrase in library.categories.flatMap(\.phrases) {
            #expect(!phrase.isEmpty)
            #expect(phrase == phrase.trimmingCharacters(in: .whitespacesAndNewlines), "\"\(phrase)\"")
        }
    }

    /// Yes and No are quick controls, one activation away in every state.
    /// Tiles that say the same would only take a place in the grid.
    @Test func yesAndNoAreNotTiles() {
        let answers: Set<String> = ["yes", "no"]
        for phrase in library.categories.flatMap(\.phrases) {
            let bare = phrase.lowercased().trimmingCharacters(in: .punctuationCharacters)
            #expect(!answers.contains(bare), "\"\(phrase)\" duplicates a quick control")
        }
    }

    /// A misspelled SF Symbol name draws nothing at all, with no error.
    @Test func everyCategorySymbolExists() {
        for category in library.categories {
            #expect(UIImage(systemName: category.symbolName) != nil, "\(category.symbolName) is not an SF Symbol")
        }
    }
}

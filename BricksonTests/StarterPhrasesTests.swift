import Foundation
import Testing
import UIKit
@testable import Brickson

/// The bundled starter phrases: the first thing every new person sees.
struct StarterPhrasesTests {
    private let library: LibrarySnapshot

    init() throws {
        library = try StarterLibrary.bundled()
    }

    private var phrases: [LibrarySnapshot.Phrase] {
        library.categories.flatMap(\.phrases)
    }

    /// Every identity a starter category or phrase has ever had, with its
    /// words. This list only grows. A starter phrase whose wording changes
    /// gets a new identity and a new line here; an existing line is never
    /// edited, because a backup or a later "restore the starter phrases"
    /// tells an untouched starter phrase from the person's own words by its
    /// identity (docs/DECISIONS.md, "Starter phrases"). A retired phrase's
    /// line stays, so its identity is never handed out again.
    private static let shippedIdentities: [String: String] = [
        "236173E3-0A84-4305-830C-DDD05AF16472": "Basics",
        "BEF474BF-A9D3-4CA0-A2B3-DF800C70E07D": "Emergency",
        "E8FB50A4-AE55-46D4-A054-AA3AA1A2E87A": "Needs",
        "81F8F5BD-F2CE-4186-BC1B-D1FA27F628CA": "Conversation",
        "FF99D433-4ED8-41D1-A661-D48EB30F1945": "Feelings",

        "4BABD144-5232-45FC-B8B0-2C9055536293": "Maybe.",
        "79E779D5-C7D1-4651-8C36-C88DA3CE285C": "I don't know.",
        "9D7428D9-D4FC-4ECC-973B-A51AB5BCF14D": "Please.",
        "06D63EC4-9335-4994-9D67-473BD3C5BC65": "Thank you.",
        "37824337-4B63-4345-807E-20DDFB0B7180": "Wait a moment, please.",
        "66A971A4-FE09-4B34-A810-70EBAA7169C4": "I'm not finished.",
        "4ED63E64-DA30-49CC-A22A-168E7D191E4E": "Hello.",
        "F4436804-9150-4ECF-BDFC-A3A3826DDDD5": "Goodbye.",
        "0AE47FBC-30FA-4D99-8017-520CC0E9D88B": "I need help now.",
        "98B62E4B-81FD-4DC0-85C7-E5D3AAF711C5": "Please come here.",
        "B24267D9-4FA4-4465-AFB7-96F62225CB51": "I can't breathe.",
        "38F8DF65-9E9B-47A4-AD01-42A203871C08": "I'm choking.",
        "1EB3641E-AF1F-45B7-93D2-5A3E2E53A97D": "I'm in pain.",
        "A9EFC9B8-E51F-4C39-AC83-25D831EEC852": "Something is wrong.",
        "D27DBAE7-214F-4696-AB5D-5D76042343E3": "I'm thirsty.",
        "D075CCE3-ACC6-4FD1-90A0-E9B18747C8BA": "I'm hungry.",
        "24C810AE-089E-4A1C-AE13-8D1A48558502": "I need the bathroom.",
        "8B36C1F7-04DF-407E-A587-853DEFF5E8F6": "I'm too hot.",
        "EAC9C328-5620-4C56-8061-1B086FDA4026": "I'm too cold.",
        "F8BC81F4-322D-425A-80F4-6B4D30AC19CB": "Please move me.",
        "7229A0AF-99F0-45FC-9032-90E163C557BD": "I need my medication.",
        "47A182EE-35A7-4F82-B7B1-6E70BA0655E0": "I'm tired.",
        "CD400D16-FDE1-4934-A5C8-9F1F5D1E34E8": "Give me a moment to answer.",
        "E3249B78-27CC-490F-8504-5F899729345E": "Can you repeat that?",
        "FC7BA19B-9487-4588-A1EA-EDF51513E428": "I understand.",
        "F99B70FA-D4F7-44F4-8B10-771AD9AE11FD": "I don't understand.",
        "E0722EBD-C407-4220-822D-CF59804E12B2": "That's not what I meant.",
        "74DC1F38-F90F-40A7-A50B-AAA03CF156F8": "Please ask me yes or no questions.",
        "5391D75E-188E-40D9-8A5D-AC52C5AF1A5E": "I love you.",
        "05AF131D-EF90-4AB0-9508-3376D23793B2": "I'm happy.",
        "63740035-5A30-48B5-A7E9-56D17C527EC2": "I'm okay.",
        "5EAB3650-ABEA-4674-8F7E-B9B699E72519": "I'm worried.",
        "B3B44D64-604C-4BAF-850D-FF854D81B78C": "I'm frustrated.",
        "1B8B7230-167A-444C-A0EE-292ACDCE9AB4": "That's funny.",
    ]

    /// Fails if a starter item's words change without a new identity, or if
    /// a new starter item is added without its line above.
    @Test func everyStarterIdentityKeepsItsWords() throws {
        let shipped = Dictionary(uniqueKeysWithValues: Self.shippedIdentities.map { (UUID(uuidString: $0.key)!, $0.value) })
        for category in library.categories {
            #expect(shipped[category.id].map { LibraryText.sameBytes($0, category.name) } == true, "\(category.id)")
        }
        for phrase in phrases {
            #expect(shipped[phrase.id].map { LibraryText.sameBytes($0, phrase.text) } == true, "\(phrase.id)")
        }
    }

    @Test func everyIdentityIsUsedOnce() {
        #expect(library.hasUniqueIDs)
    }

    /// Emergency must open to phrases from the very first launch (decision
    /// E1, invariant 2).
    @Test func emergencyWorksFromTheStart() {
        #expect(library.categories.filter(\.isEmergency).count == 1)
        #expect(library.keepsEmergencyWorking)
    }

    @Test func everyCategoryHasPhrases() {
        for category in library.categories {
            #expect(!category.phrases.isEmpty, "\(category.name) has no phrases")
        }
    }

    /// The starter library follows the rules a family's own edits follow:
    /// names that differ and are not a Home control's, words in every
    /// phrase, no phrase twice in a category, no stray spaces, and pictures
    /// from the editor's list. Fails if a starter item could not have been
    /// made in the editor.
    @Test func theStarterLibraryFollowsTheEditorsRules() throws {
        for category in library.categories {
            let name = try LibraryRules.categoryName(
                category.name,
                isEmergency: category.isEmergency,
                in: library,
                excluding: category.id
            )
            #expect(LibraryText.sameBytes(name, category.name), "\"\(category.name)\" has stray spaces")
            #expect(try LibraryRules.symbol(category.symbolName) == category.symbolName)
            for phrase in category.phrases {
                let text = try LibraryRules.phraseText(phrase.text, in: category, excluding: phrase.id)
                #expect(LibraryText.sameBytes(text, phrase.text), "\"\(phrase.text)\" has stray spaces")
            }
        }
    }

    /// Yes and No are quick controls, one activation away in every state.
    /// Tiles that say the same would only take a place in the grid.
    @Test func yesAndNoAreNotTiles() {
        let answers: Set<String> = ["yes", "no"]
        for phrase in phrases {
            let bare = phrase.text.lowercased().trimmingCharacters(in: .punctuationCharacters)
            #expect(!answers.contains(bare), "\"\(phrase.text)\" duplicates a quick control")
        }
    }

    /// A misspelled SF Symbol name draws nothing at all, with no error.
    @Test func everyCategorySymbolExists() {
        for category in library.categories {
            #expect(UIImage(systemName: category.symbolName) != nil, "\(category.symbolName) is not an SF Symbol")
        }
    }
}

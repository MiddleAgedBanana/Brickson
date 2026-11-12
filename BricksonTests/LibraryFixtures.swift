import Foundation
@testable import Brickson

/// Small libraries with readable, fixed identities, shared by the library
/// tests. Category ids are 100, 200, 300; each phrase's id follows its
/// category's.
enum LibraryFixtures {
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
    }

    static let basicsID = id(100)
    static let emergencyID = id(200)
    static let needsID = id(300)

    static let basics = LibrarySnapshot.Category(
        id: basicsID,
        name: "Basics",
        symbolName: "bubble.left.and.bubble.right.fill",
        isEmergency: false,
        phrases: [
            .init(id: id(101), text: "Hello."),
            .init(id: id(102), text: "Thank you."),
            .init(id: id(103), text: "Goodbye."),
        ]
    )

    static let emergency = LibrarySnapshot.Category(
        id: emergencyID,
        name: "Emergency",
        symbolName: "exclamationmark.triangle.fill",
        isEmergency: true,
        phrases: [
            .init(id: id(201), text: "I need help now."),
            .init(id: id(202), text: "Please come here."),
        ]
    )

    static let needs = LibrarySnapshot.Category(
        id: needsID,
        name: "Needs",
        symbolName: "hand.raised.fill",
        isEmergency: false,
        phrases: [
            .init(id: id(301), text: "I'm thirsty."),
        ]
    )

    /// Small, and outside the bounds Home asks for, as only a damaged or
    /// hand-made store can be: two everyday categories where Home needs
    /// three, and Emergency with two phrases where it keeps four
    /// (docs/DECISIONS.md, "Three or four everyday categories" and "Four
    /// phrases in every category"). An edit may bring it back or leave it
    /// as it is, but never take it farther out, so no edit deletes one of
    /// its categories or one of Emergency's phrases: `libraryOfFour` is
    /// the library for those.
    static let library = LibrarySnapshot(categories: [basics, emergency, needs])

    static let friendsID = id(600)
    static let tripsID = id(700)

    static let friends = LibrarySnapshot.Category(
        id: friendsID,
        name: "Friends",
        symbolName: "person.fill",
        isEmergency: false,
        phrases: [
            .init(id: id(601), text: "Call my friend."),
        ]
    )

    static let trips = LibrarySnapshot.Category(
        id: tripsID,
        name: "Trips",
        symbolName: "car.fill",
        isEmergency: false,
        phrases: [
            .init(id: id(701), text: "Let's go out."),
        ]
    )

    /// `library` with four everyday categories, so deleting one leaves the
    /// three Home needs.
    static let libraryOfFour = LibrarySnapshot(categories: [basics, emergency, needs, friends, trips])

    /// The library each kind's sample edit is made in: `library`, except
    /// for deleting a category, which needs `libraryOfFour`.
    static func sampleLibrary(_ kind: LibraryEdit.Kind) -> LibrarySnapshot {
        kind == .deleteCategory ? libraryOfFour : library
    }

    /// One edit of each kind that changes `sampleLibrary(kind)`. The switch
    /// has no default, so adding a kind of edit without a sample here fails
    /// to compile, and every per-kind test covers it.
    static func sampleEdit(_ kind: LibraryEdit.Kind) -> LibraryEdit {
        switch kind {
        case .addCategory:
            .addCategory(name: "Family", symbolName: "person.2.fill")
        case .renameCategory:
            .renameCategory(needsID, name: "Wants")
        case .changeCategorySymbol:
            .changeCategorySymbol(needsID, symbolName: "drop.fill")
        case .moveCategory:
            .moveCategory(needsID, before: basicsID)
        case .deleteCategory:
            .deleteCategory(basicsID)
        case .addPhrase:
            .addPhrase(text: "Please.", category: basicsID)
        case .editPhrase:
            .editPhrase(id(101), text: "Hi.")
        case .movePhrase:
            .movePhrase(id(103), category: needsID, before: nil)
        case .deletePhrase:
            .deletePhrase(id(102))
        case .merge:
            .merge(LibrarySnapshot(categories: [
                .init(id: id(400), name: "Family", symbolName: "person.2.fill", isEmergency: false, phrases: [
                    .init(id: id(401), text: "Where is everyone?"),
                ]),
            ]))
        case .replace:
            // Three everyday categories, so it brings `library` back toward
            // the bounds and keeps `libraryOfFour`, less one, inside them.
            .replace(LibrarySnapshot(categories: [
                emergency,
                needs,
                .init(id: id(400), name: "Family", symbolName: "person.2.fill", isEmergency: false, phrases: [
                    .init(id: id(401), text: "Where is everyone?"),
                ]),
                trips,
            ]))
        }
    }
}

/// Predictable identities for new items: 900, 901, 902…
final class SequentialIDs {
    private var next: Int

    init(startingAt first: Int = 900) {
        next = first
    }

    func make() -> UUID {
        defer { next += 1 }
        return LibraryFixtures.id(next)
    }
}

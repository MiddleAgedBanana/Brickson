import Foundation
import Testing
@testable import Brickson

/// The rules for changing a library, checked without a store. Each test
/// names the change that would make it fail.
struct LibraryEditTests {
    private typealias F = LibraryFixtures
    private let library = LibraryFixtures.library

    private func makePlan(_ edit: LibraryEdit, in library: LibrarySnapshot? = nil) throws -> LibraryPlan {
        let ids = SequentialIDs()
        return try edit.plan(in: library ?? self.library, makeID: ids.make)
    }

    private func names(_ library: LibrarySnapshot) -> [String] {
        library.categories.map(\.name)
    }

    private func texts(_ library: LibrarySnapshot, _ categoryID: UUID) -> [String] {
        library.categories.first { $0.id == categoryID }?.phrases.map(\.text) ?? []
    }

    // MARK: Every kind

    /// Fails if a kind of edit is added whose sample changes nothing, or
    /// that the planner refuses on an ordinary library.
    @Test(arguments: LibraryEdit.Kind.allCases)
    func everyKindPlansAChange(kind: LibraryEdit.Kind) throws {
        let edit = F.sampleEdit(kind)
        #expect(edit.kind == kind)
        let plan = try makePlan(edit)
        #expect(plan.kind == kind)
        #expect(plan.before == library)
        #expect(!plan.changes.isEmpty)
        #expect(plan.after.keepsEmergencyWorking)
        #expect(plan.after.hasUniqueIDs)
    }

    /// Invariant 3: every delete, merge and replace asks first. Fails if a
    /// kind is moved to the wrong side.
    @Test func deletesMergesAndReplacesAskFirst() {
        let asking = Set(LibraryEdit.Kind.allCases.filter(\.asksFirst))
        #expect(asking == [.deleteCategory, .deletePhrase, .merge, .replace])
    }

    /// Fails if the planner stops checking identities before matching by
    /// them.
    @Test func aLibraryWithRepeatedIdentitiesCannotBeEdited() {
        var broken = library
        broken.categories[2].phrases.append(.init(id: F.id(101), text: "Copy."))
        #expect(throws: LibraryEditRejection.libraryNeedsRepair) {
            try makePlan(.addPhrase(text: "New.", category: F.needsID), in: broken)
        }
    }

    // MARK: Categories

    @Test func aNewCategoryGoesAtTheEndAndIsNeverAnEmergencyOne() throws {
        let plan = try makePlan(.addCategory(name: "  Family  ", symbolName: "person.2.fill"))

        #expect(names(plan.after) == ["Basics", "Emergency", "Needs", "Family"])
        let added = try #require(plan.after.categories.last)
        #expect(added.id == F.id(900))
        #expect(!added.isEmergency)
        #expect(added.phrases.isEmpty)
        #expect(plan.changes.categoriesAdded == 1)
        #expect(plan.changes.categoriesMoved == 0)
    }

    @Test func aCategoryNeedsAName() {
        #expect(throws: LibraryEditRejection.emptyName) {
            try makePlan(.addCategory(name: " \n ", symbolName: "star.fill"))
        }
    }

    /// Names that read and sound the same are one name. Fails if the
    /// comparison stops ignoring case, accents, spacing or punctuation.
    @Test(arguments: ["basics", "BASICS!", " Básics ", "Ba-sics"])
    func categoryNamesMustDiffer(name: String) {
        #expect(throws: LibraryEditRejection.duplicateCategoryName) {
            try makePlan(.addCategory(name: name, symbolName: "star.fill"))
        }
    }

    /// A category named like a Home control would be a second button with
    /// that name. Fails if validation omits an alternate input label,
    /// such as Again's Repeat alias, from either add or rename.
    @Test(arguments: ["Yes", "no.", "EMERGENCY", "Get attention", "Again!", "Repeat", "repeat!"])
    func homeControlNamesAreReserved(name: String) {
        #expect(throws: LibraryEditRejection.reservedCategoryName) {
            try makePlan(.addCategory(name: name, symbolName: "star.fill"))
        }
        #expect(throws: LibraryEditRejection.reservedCategoryName) {
            try makePlan(.renameCategory(F.needsID, name: name))
        }
    }

    /// The emergency category has no button of its own, so it keeps a name
    /// like "Emergency". Fails if the reserved names apply to it.
    @Test func theEmergencyCategoryMayBeNamedEmergency() throws {
        let plan = try makePlan(.renameCategory(F.emergencyID, name: "EMERGENCY"))
        #expect(plan.after.categories[1].name == "EMERGENCY")
    }

    @Test func aCategoryMayChangeItsOwnNamesCase() throws {
        let plan = try makePlan(.renameCategory(F.needsID, name: "NEEDS"))
        #expect(names(plan.after) == ["Basics", "Emergency", "NEEDS"])
        #expect(plan.changes.categoriesChanged == 1)
    }

    @Test func symbolsComeFromTheList() throws {
        #expect(throws: LibraryEditRejection.unknownSymbol) {
            try makePlan(.changeCategorySymbol(F.needsID, symbolName: "not.a.symbol"))
        }
        #expect(throws: LibraryEditRejection.unknownSymbol) {
            try makePlan(.addCategory(name: "Family", symbolName: "person.3.sequence.fill.badge.plus"))
        }
        let plan = try makePlan(.changeCategorySymbol(F.needsID, symbolName: "drop.fill"))
        #expect(plan.after.categories[2].symbolName == "drop.fill")
    }

    @Test func editsOfMissingItemsAreRefused() {
        let missing = F.id(999)
        let edits: [LibraryEdit] = [
            .renameCategory(missing, name: "X"),
            .changeCategorySymbol(missing, symbolName: "star.fill"),
            .moveCategory(missing, before: nil),
            .moveCategory(F.needsID, before: missing),
            .deleteCategory(missing),
            .addPhrase(text: "X.", category: missing),
            .editPhrase(missing, text: "X."),
            .movePhrase(missing, category: F.needsID, before: nil),
            .movePhrase(F.id(101), category: missing, before: nil),
            .movePhrase(F.id(101), category: F.needsID, before: F.id(102)),
            .deletePhrase(missing),
        ]
        for edit in edits {
            #expect(throws: LibraryEditRejection.notFound, "\(edit)") { try makePlan(edit) }
        }
    }

    // MARK: Moving

    @Test func aCategoryMovesBeforeAnotherOrToTheEnd() throws {
        let earlier = try makePlan(.moveCategory(F.needsID, before: F.basicsID))
        #expect(names(earlier.after) == ["Needs", "Basics", "Emergency"])

        let last = try makePlan(.moveCategory(F.basicsID, before: nil))
        #expect(names(last.after) == ["Emergency", "Needs", "Basics"])
    }

    /// A held look can repeat a move. Placing an item where it already is
    /// must change nothing, so the repeat is harmless (invariant 10). Fails
    /// if moves become relative ("one place earlier").
    @Test func repeatingAMoveChangesNothing() throws {
        let first = try makePlan(.moveCategory(F.needsID, before: F.basicsID))
        let again = try LibraryEdit.moveCategory(F.needsID, before: F.basicsID).plan(in: first.after)
        #expect(again.changes.isEmpty)
        #expect(again.after == first.after)

        let phrase = try makePlan(.movePhrase(F.id(103), category: F.basicsID, before: F.id(101)))
        let phraseAgain = try LibraryEdit.movePhrase(F.id(103), category: F.basicsID, before: F.id(101))
            .plan(in: phrase.after)
        #expect(phraseAgain.changes.isEmpty)
    }

    @Test func placingAnItemBeforeItselfChangesNothing() throws {
        #expect(try makePlan(.moveCategory(F.needsID, before: F.needsID)).changes.isEmpty)
        #expect(try makePlan(.movePhrase(F.id(102), category: F.basicsID, before: F.id(102))).changes.isEmpty)
    }

    @Test func aPhraseMovesWithinAndBetweenCategories() throws {
        let within = try makePlan(.movePhrase(F.id(103), category: F.basicsID, before: F.id(101)))
        #expect(texts(within.after, F.basicsID) == ["Goodbye.", "Hello.", "Thank you."])

        let between = try makePlan(.movePhrase(F.id(101), category: F.needsID, before: nil))
        #expect(texts(between.after, F.basicsID) == ["Thank you.", "Goodbye."])
        #expect(texts(between.after, F.needsID) == ["I'm thirsty.", "Hello."])
        #expect(between.after.location(ofPhrase: F.id(101))?.category == 2)
    }

    @Test func aPhraseCannotMoveIntoACategoryThatAlreadySaysIt() {
        var library = library
        library.categories[2].phrases.append(.init(id: F.id(302), text: "hello."))
        #expect(throws: LibraryEditRejection.duplicatePhrase) {
            try makePlan(.movePhrase(F.id(101), category: F.needsID, before: nil), in: library)
        }
    }

    // MARK: Phrases

    @Test func aNewPhraseIsTrimmedAndGoesAtTheEnd() throws {
        let plan = try makePlan(.addPhrase(text: "\tPlease. \n", category: F.basicsID))
        #expect(texts(plan.after, F.basicsID) == ["Hello.", "Thank you.", "Goodbye.", "Please."])
        #expect(plan.after.categories[0].phrases.last?.id == F.id(900))
        #expect(plan.changes.phrasesMoved == 0)
    }

    @Test func aPhraseNeedsWords() {
        #expect(throws: LibraryEditRejection.emptyText) {
            try makePlan(.addPhrase(text: "   ", category: F.basicsID))
        }
        #expect(throws: LibraryEditRejection.emptyText) {
            try makePlan(.editPhrase(F.id(101), text: "\n"))
        }
    }

    /// Case does not make a different phrase; punctuation does, because it
    /// changes how the words are said.
    @Test func phrasesInACategoryMustDiffer() throws {
        #expect(throws: LibraryEditRejection.duplicatePhrase) {
            try makePlan(.addPhrase(text: "hello.", category: F.basicsID))
        }
        #expect(throws: LibraryEditRejection.duplicatePhrase) {
            try makePlan(.editPhrase(F.id(102), text: "HELLO."))
        }
        _ = try makePlan(.addPhrase(text: "Hello!", category: F.basicsID))
        _ = try makePlan(.addPhrase(text: "Hello.", category: F.needsID))
        _ = try makePlan(.editPhrase(F.id(101), text: "HELLO."))
    }

    @Test func editingAPhraseKeepsItsIdentityAndPlace() throws {
        let plan = try makePlan(.editPhrase(F.id(102), text: "Thanks."))
        #expect(plan.after.categories[0].phrases[1] == .init(id: F.id(102), text: "Thanks."))
        #expect(plan.changes.phrasesChanged == 1)
        #expect(plan.changes.phrasesMoved == 0)
    }

    /// Deleting closes the gap, which moves every later phrase. The plan
    /// says so, for the screens that ask first.
    @Test func deletingAPhraseReportsThePhrasesThatShift() throws {
        let plan = try makePlan(.deletePhrase(F.id(101)))
        #expect(texts(plan.after, F.basicsID) == ["Thank you.", "Goodbye."])
        #expect(plan.changes.phrasesRemoved == 1)
        #expect(plan.changes.phrasesMoved == 2)
    }

    @Test func deletingACategoryDeletesItsPhrases() throws {
        let plan = try makePlan(.deleteCategory(F.basicsID))
        #expect(names(plan.after) == ["Emergency", "Needs"])
        #expect(plan.changes.categoriesRemoved == 1)
        #expect(plan.changes.phrasesRemoved == 3)
        #expect(plan.after.phraseCount == 3)
    }

    // MARK: Emergency (decision E1)

    /// Fails if the emergency category can be deleted: Home's Emergency
    /// control would have nothing to open.
    @Test func theEmergencyCategoryCannotBeDeleted() {
        #expect(throws: LibraryEditRejection.emergencyCategoryCannotBeDeleted) {
            try makePlan(.deleteCategory(F.emergencyID))
        }
    }

    @Test func theEmergencyCategoryKeepsItsLastPhrase() throws {
        let one = try makePlan(.deletePhrase(F.id(202))).after
        #expect(throws: LibraryEditRejection.emergencyCategoryNeedsAPhrase) {
            try LibraryEdit.deletePhrase(F.id(201)).plan(in: one)
        }
        #expect(throws: LibraryEditRejection.emergencyCategoryNeedsAPhrase) {
            try LibraryEdit.movePhrase(F.id(201), category: F.basicsID, before: nil).plan(in: one)
        }
        // Its words can still change, and it can still move within itself.
        _ = try LibraryEdit.editPhrase(F.id(201), text: "Help.").plan(in: one)
        _ = try LibraryEdit.movePhrase(F.id(201), category: F.emergencyID, before: nil).plan(in: one)
    }

    /// Fails if a whitespace-only imported phrase counts as something
    /// Emergency can say, even though its tile produces no speech.
    @Test(arguments: [" \n\t", "\u{00A0}"])
    func emergencyNeedsWordsNotOnlyAStoredPhrase(blank: String) {
        var onlyBlank = library
        onlyBlank.categories[1].phrases = [.init(id: F.id(201), text: blank)]
        #expect(!onlyBlank.keepsEmergencyWorking)
    }

    /// Fails if an imported blank lets a delete or move remove Emergency's
    /// last phrase with words. Imports must still keep the blank's bytes.
    @Test(arguments: [" \n\t", "\u{00A0}"])
    func importedWhitespaceCannotReplaceTheLastEmergencyWords(blank: String) throws {
        var backup = library
        backup.categories[1].phrases[1].text = blank
        let imported = try makePlan(.replace(backup)).after
        #expect(imported.keepsEmergencyWorking)
        #expect(Array(imported.categories[1].phrases[1].text.utf8) == Array(blank.utf8))

        #expect(throws: LibraryEditRejection.emergencyCategoryNeedsAPhrase) {
            try makePlan(.deletePhrase(F.id(201)), in: imported)
        }
        #expect(throws: LibraryEditRejection.emergencyCategoryNeedsAPhrase) {
            try makePlan(.movePhrase(F.id(201), category: F.basicsID, before: nil), in: imported)
        }

        // Removing the blank, editing the words, and reordering within
        // Emergency all keep a reachable phrase with words.
        let removedBlank = try makePlan(.deletePhrase(F.id(202)), in: imported)
        #expect(texts(removedBlank.after, F.emergencyID) == ["I need help now."])
        let edited = try makePlan(.editPhrase(F.id(201), text: "Help."), in: imported)
        #expect(edited.after.keepsEmergencyWorking)
        let reordered = try makePlan(.movePhrase(F.id(201), category: F.emergencyID, before: nil), in: imported)
        #expect(reordered.after.keepsEmergencyWorking)
        #expect(Array(reordered.after.categories[1].phrases[0].text.utf8) == Array(blank.utf8))
    }

    /// A library that already broke the rule (from a damaged store) can
    /// still be edited, as long as the edit does not make it worse.
    /// An empty store is refilled with the starter phrases at the next
    /// launch. Fails if an edit can empty a library (one damaged so it has
    /// no emergency category), which would put starter words in place of
    /// the person's.
    @Test func noEditEmptiesTheLibrary() throws {
        let onlyBasics = LibrarySnapshot(categories: [F.basics])
        #expect(throws: LibraryEditRejection.libraryNeedsACategory) {
            try LibraryEdit.deleteCategory(F.basicsID).plan(in: onlyBasics)
        }
        #expect(throws: LibraryEditRejection.libraryNeedsACategory) {
            try LibraryEdit.replace(.empty).plan(in: onlyBasics)
        }
    }

    @Test func aLibraryWithoutEmergencyCanStillBeEdited() throws {
        let noEmergency = LibrarySnapshot(categories: [F.basics, F.needs])
        let plan = try makePlan(.addPhrase(text: "Please.", category: F.basicsID), in: noEmergency)
        #expect(plan.after.phraseCount == 5)
    }
}

/// Bringing a backup into a library: `LibraryImport` through
/// `LibraryEdit.merge` and `.replace`.
struct LibraryImportTests {
    private typealias F = LibraryFixtures
    private let library = LibraryFixtures.library

    private func merge(_ incoming: LibrarySnapshot, into library: LibrarySnapshot? = nil) throws -> LibraryPlan {
        let ids = SequentialIDs()
        return try LibraryEdit.merge(incoming).plan(in: library ?? self.library, makeID: ids.make)
    }

    private func replace(
        _ library: LibrarySnapshot? = nil,
        with incoming: LibrarySnapshot,
        starter: LibrarySnapshot? = nil
    ) throws -> LibraryPlan {
        let ids = SequentialIDs()
        return try LibraryEdit.replace(incoming).plan(in: library ?? self.library, starter: starter, makeID: ids.make)
    }

    private func texts(_ library: LibrarySnapshot, _ categoryID: UUID) -> [String] {
        library.categories.first { $0.id == categoryID }?.phrases.map(\.text) ?? []
    }

    // MARK: Merge

    /// Fails if merge stops skipping what is already there.
    @Test func mergingALibraryIntoItselfAddsNothing() throws {
        let plan = try merge(library)
        #expect(plan.changes.isEmpty)
        #expect(plan.importReport?.phrasesAlreadyThere == library.phraseCount)
    }

    /// Merge only ever adds. Fails if it sorts, inserts in the middle,
    /// renames or deletes.
    @Test func mergeMovesAndChangesNothingAlreadyThere() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.id(400), name: "Family", symbolName: "person.2.fill", isEmergency: false, phrases: [
                .init(id: F.id(401), text: "Where is everyone?"),
            ]),
            .init(id: F.basicsID, name: "Basics", symbolName: "star.fill", isEmergency: false, phrases: [
                .init(id: F.id(104), text: "See you soon."),
                .init(id: F.id(101), text: "Hello."),
            ]),
        ])
        let plan = try merge(incoming)

        #expect(plan.after.categories.map(\.name) == ["Basics", "Emergency", "Needs", "Family"])
        #expect(texts(plan.after, F.basicsID) == ["Hello.", "Thank you.", "Goodbye.", "See you soon."])
        #expect(plan.changes.categoriesMoved == 0)
        #expect(plan.changes.categoriesChanged == 0)
        #expect(plan.changes.categoriesRemoved == 0)
        #expect(plan.changes.phrasesMoved == 0)
        #expect(plan.changes.phrasesChanged == 0)
        #expect(plan.changes.phrasesRemoved == 0)
        #expect(plan.changes.categoriesAdded == 1)
        #expect(plan.changes.phrasesAdded == 2)
    }

    /// A backup's category name is the person's words too. Fails if merge
    /// joins categories whose names differ, by identity or by a loose
    /// match, which would drop the backup's name.
    @Test func aCategoryWhoseNameDiffersIsAddedWithItsName() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.basicsID, name: "Renamed elsewhere", symbolName: "star.fill", isEmergency: false, phrases: [
                .init(id: F.id(104), text: "See you soon."),
                .init(id: F.id(101), text: "Hello."),
            ]),
            .init(id: F.id(500), name: "needs!", symbolName: "drop.fill", isEmergency: false, phrases: [
                .init(id: F.id(501), text: "I'm hungry."),
            ]),
        ])
        let plan = try merge(incoming)

        #expect(plan.after.categories.map(\.name) == ["Basics", "Emergency", "Needs", "Renamed elsewhere", "needs!"])
        #expect(texts(plan.after, F.basicsID) == ["Hello.", "Thank you.", "Goodbye."])
        // The identity was taken, so the renamed category gets a new one;
        // "Hello." is already in the library and is not copied.
        #expect(plan.after.categories[3].id == F.id(900))
        #expect(plan.after.categories[3].phrases.map(\.text) == ["See you soon."])
        #expect(texts(plan.after, F.id(500)) == ["I'm hungry."])

        let twice = try LibraryEdit.merge(incoming).plan(in: plan.after, makeID: SequentialIDs(startingAt: 950).make)
        #expect(twice.changes.isEmpty)
    }

    /// A backup that says the same thing twice in one category keeps both
    /// tiles, the first time and every time. Fails if merge checks against
    /// what it has just added.
    @Test func aRepeatedPhraseInOneBackupCategoryIsKept() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.id(400), name: "Family", symbolName: "person.2.fill", isEmergency: false, phrases: [
                .init(id: F.id(401), text: "Where is everyone?"),
                .init(id: F.id(402), text: "Where is everyone?"),
            ]),
        ])
        let plan = try merge(incoming)
        #expect(texts(plan.after, F.id(400)) == ["Where is everyone?", "Where is everyone?"])
        #expect(plan.after.categories.last?.phrases.map(\.id) == [F.id(401), F.id(402)])

        let replaced = try replace(with: LibrarySnapshot(categories: [F.emergency] + incoming.categories))
        #expect(texts(replaced.after, F.id(400)) == ["Where is everyone?", "Where is everyone?"])

        let twice = try LibraryEdit.merge(incoming).plan(in: plan.after, makeID: SequentialIDs(startingAt: 950).make)
        #expect(twice.changes.isEmpty)
    }

    /// Fails if merge remembers phrases it has just added and skips a
    /// repeat that shares their identity (a hand-edited backup), instead
    /// of giving the repeat a new identity as replace does.
    @Test func aRepeatedIdentityInOneBackupIsKeptWithANewOne() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.id(400), name: "Family", symbolName: "person.2.fill", isEmergency: false, phrases: [
                .init(id: F.id(401), text: "Where is everyone?"),
                .init(id: F.id(401), text: "Where is everyone?"),
            ]),
        ])
        let plan = try merge(incoming)
        #expect(texts(plan.after, F.id(400)) == ["Where is everyone?", "Where is everyone?"])
        #expect(plan.after.hasUniqueIDs)
        #expect(plan.importReport?.phrasesGivenNewIdentity == 1)

        let twice = try LibraryEdit.merge(incoming).plan(in: plan.after, makeID: SequentialIDs(startingAt: 950).make)
        #expect(twice.changes.isEmpty)
    }

    /// Fails if merging twice adds anything the first merge did not.
    @Test func mergingTwiceIsTheSameAsMergingOnce() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.id(400), name: "Family", symbolName: "person.2.fill", isEmergency: false, phrases: [
                .init(id: F.id(401), text: "Where is everyone?"),
            ]),
            .init(id: F.basicsID, name: "Basics", symbolName: "star.fill", isEmergency: false, phrases: [
                // Same identity as "Hello.", different words.
                .init(id: F.id(101), text: "Hi there."),
            ]),
        ])
        let once = try merge(incoming)
        let twice = try LibraryEdit.merge(incoming).plan(in: once.after, makeID: SequentialIDs(startingAt: 950).make)

        #expect(twice.changes.isEmpty)
        #expect(twice.after == once.after)
    }

    /// The local phrase keeps its words and identity; the backup's words are
    /// added under a new identity. Fails if merge overwrites by identity.
    @Test func theSameIdentityWithDifferentWordsKeepsBoth() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.basicsID, name: "Basics", symbolName: "star.fill", isEmergency: false, phrases: [
                .init(id: F.id(101), text: "Hi there."),
            ]),
        ])
        let plan = try merge(incoming)

        #expect(plan.after.categories[0].phrases.first == .init(id: F.id(101), text: "Hello."))
        #expect(plan.after.categories[0].phrases.last == .init(id: F.id(900), text: "Hi there."))
        #expect(plan.importReport?.phrasesGivenNewIdentity == 1)
    }

    /// Two devices each made a "Needs" category. Fails if merge matches by
    /// identity only.
    @Test func categoriesWithTheSameNameBecomeOne() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.id(500), name: "Needs", symbolName: "drop.fill", isEmergency: false, phrases: [
                .init(id: F.id(501), text: "I'm hungry."),
            ]),
        ])
        let plan = try merge(incoming)

        #expect(plan.after.categories.count == 3)
        #expect(texts(plan.after, F.needsID) == ["I'm thirsty.", "I'm hungry."])
        #expect(plan.after.categories[2].name == "Needs")
    }

    /// Fails if a backup can bring a second emergency category, whose
    /// phrases Emergency could not reach.
    @Test func everyIncomingEmergencyCategoryFeedsTheOneEmergencyCategory() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.id(600), name: "Urgent", symbolName: "star.fill", isEmergency: true, phrases: [
                .init(id: F.id(601), text: "Call the nurse."),
            ]),
            .init(id: F.id(700), name: "Emergency", symbolName: "star.fill", isEmergency: true, phrases: [
                .init(id: F.id(701), text: "I need help now."),
                .init(id: F.id(702), text: "Come quickly."),
            ]),
        ])
        let plan = try merge(incoming)

        #expect(plan.after.categories.filter(\.isEmergency).count == 1)
        #expect(texts(plan.after, F.emergencyID) == [
            "I need help now.", "Please come here.", "Call the nurse.", "Come quickly.",
        ])

        let intoNone = try merge(incoming, into: LibrarySnapshot(categories: [F.basics]))
        #expect(intoNone.after.categories.filter(\.isEmergency).count == 1)
        #expect(intoNone.after.keepsEmergencyWorking)
    }

    /// Import keeps a backup's words exactly. Fails if the editor's rules
    /// (trimming, reserved names, near-duplicates, the symbol list) leak
    /// into import.
    @Test(arguments: ["Yes", "Repeat"])
    func importKeepsWhatTheEditorWouldRefuse(categoryName: String) throws {
        let long = String(repeating: "Very long words. ", count: 400)
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.id(800), name: categoryName, symbolName: "no.such.symbol", isEmergency: false, phrases: [
                .init(id: F.id(801), text: "  spaced  "),
                .init(id: F.id(802), text: "hello."),
                .init(id: F.id(803), text: "Hello."),
                .init(id: F.id(804), text: long),
            ]),
        ])
        let plan = try merge(incoming)
        let added = try #require(plan.after.categories.last)

        #expect(added.name == categoryName)
        #expect(added.symbolName == "no.such.symbol")
        #expect(added.phrases.map(\.text) == ["  spaced  ", "hello.", "Hello.", long])
    }

    /// Only a phrase with no characters at all is skipped. Fails if import
    /// trims, so that spaces or line breaks someone kept are lost.
    @Test func onlyEmptyPhrasesAreSkipped() throws {
        let incoming = LibrarySnapshot(categories: [
            .init(id: F.basicsID, name: "Basics", symbolName: "star.fill", isEmergency: false, phrases: [
                .init(id: F.id(110), text: ""),
                .init(id: F.id(111), text: " \n\t"),
                .init(id: F.id(112), text: "Please."),
            ]),
        ])
        let plan = try merge(incoming)

        #expect(Array(texts(plan.after, F.basicsID).suffix(2)) == [" \n\t", "Please."])
        #expect(plan.changes.phrasesAdded == 2)
        #expect(plan.importReport?.emptyPhrasesSkipped == 1)
    }

    /// A phrase moved to another category here is the same phrase as in an
    /// older backup. Fails if merge copies it back.
    @Test func aPhraseMovedHereIsNotCopiedBack() throws {
        let moved = try LibraryEdit.movePhrase(F.id(101), category: F.needsID, before: nil).plan(in: library).after
        let plan = try merge(library, into: moved)
        #expect(plan.changes.isEmpty)
    }

    // MARK: Replace

    @Test func replaceMakesTheLibraryMatchTheBackup() throws {
        let incoming = LibrarySnapshot(categories: [F.needs, F.emergency])
        let plan = try replace(with: incoming)

        #expect(plan.after == incoming)
        #expect(plan.changes.categoriesRemoved == 1)
        #expect(plan.asksFirst)
    }

    /// Replace keeps the backup's structure. Fails if it joins categories
    /// by name, as merge does, which would lose one of them.
    @Test func replaceKeepsCategoriesThatShareAName() throws {
        let twin = LibrarySnapshot.Category(id: F.id(400), name: "Needs", symbolName: "drop.fill", isEmergency: false, phrases: [
            .init(id: F.id(401), text: "I'm hungry."),
        ])
        let incoming = LibrarySnapshot(categories: [F.needs, twin, F.emergency])
        let plan = try replace(with: incoming)

        #expect(plan.after == incoming)
    }

    /// A repeated identity in a backup gets a new one, so nothing is lost
    /// and the store never holds two items with one identity.
    @Test func replaceRenumbersRepeatedIdentities() throws {
        let clash = LibrarySnapshot.Category(id: F.needsID, name: "More needs", symbolName: "drop.fill", isEmergency: false, phrases: [
            .init(id: F.id(301), text: "I'm hungry."),
        ])
        let plan = try replace(with: LibrarySnapshot(categories: [F.needs, clash, F.emergency]))

        #expect(plan.after.hasUniqueIDs)
        #expect(plan.after.categories.map(\.name) == ["Needs", "More needs", "Emergency"])
        #expect(plan.after.categories[1].phrases.map(\.text) == ["I'm hungry."])
        #expect(plan.importReport?.phrasesGivenNewIdentity == 1)
    }

    /// Invariant 7: a replace that would lose the person's words needs a
    /// safety copy first. Fails if the check is dropped or inverted.
    @Test func replacingThePersonsWordsNeedsASafetyCopy() throws {
        let incoming = LibrarySnapshot(categories: [F.emergency])
        #expect(try replace(with: incoming).needsSafetyCopy)
        // Compared with the starter library, untouched starter items are not
        // the person's words, but an edited one is.
        #expect(try !replace(with: incoming, starter: library).needsSafetyCopy)
        let edited = try LibraryEdit.editPhrase(F.id(101), text: "Hi.").plan(in: library).after
        #expect(try replace(edited, with: incoming, starter: library).needsSafetyCopy)
    }

    @Test func replacingNothingOrLosingNothingNeedsNoSafetyCopy() throws {
        let emptyLibrary = LibrarySnapshot(categories: [])
        #expect(try !replace(emptyLibrary, with: library).needsSafetyCopy)
        // A backup that holds every word in the library loses nothing.
        let bigger = LibrarySnapshot(categories: library.categories + [
            .init(id: F.id(400), name: "Family", symbolName: "person.2.fill", isEmergency: false, phrases: []),
        ])
        #expect(try !replace(with: bigger).needsSafetyCopy)
    }

    /// Fails if a replace can leave Emergency with nothing to open.
    @Test func replaceKeepsTheCurrentEmergencyPhrasesWhenTheBackupHasNone() throws {
        let noEmergency = LibrarySnapshot(categories: [F.needs])
        let plan = try replace(with: noEmergency)
        #expect(plan.after.keepsEmergencyWorking)
        #expect(texts(plan.after, F.emergencyID) == ["I need help now.", "Please come here."])
        #expect(plan.importReport?.keptCurrentEmergencyPhrases == true)

        let blankEmergency = LibrarySnapshot(categories: [
            .init(id: F.id(600), name: "Emergency", symbolName: "star.fill", isEmergency: true, phrases: [
                .init(id: F.id(601), text: " "),
            ]),
        ])
        let blank = try replace(with: blankEmergency)
        #expect(blank.after.keepsEmergencyWorking)
        #expect(blank.after.categories.filter(\.isEmergency).first?.phrases.map(\.text)
            == [" ", "I need help now.", "Please come here."])

        // The backup has the current emergency phrases, with the same
        // identities, in an ordinary category. They are still kept in
        // Emergency, under new identities.
        let elsewhere = LibrarySnapshot(categories: [
            .init(id: F.id(400), name: "Saved", symbolName: "star.fill", isEmergency: false, phrases: F.emergency.phrases),
        ])
        let moved = try replace(with: elsewhere)
        #expect(moved.after.hasUniqueIDs)
        #expect(moved.after.categories.filter(\.isEmergency).first?.phrases.map(\.text)
            == ["I need help now.", "Please come here."])
        #expect(texts(moved.after, F.id(400)) == ["I need help now.", "Please come here."])
    }
}

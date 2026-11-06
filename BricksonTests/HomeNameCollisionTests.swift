import Foundation
import SwiftData
import Testing
@testable import Brickson

/// Voice Control on Home with the starter library: no two controls on the
/// screen answer to the same name, whichever category shows
/// (docs/ACCESSIBILITY.md, section 3). When two do, Voice Control stops to
/// ask which one is meant, which costs the person another command every
/// time. A library a family has grown is checked as its words are saved:
/// `LibraryNameCollisionTests`, below.
struct HomeNameCollisionTests {
    /// Fails if a starter phrase, a category name or a fixed control's name,
    /// its other names included, sounds the same as another control on the
    /// same screen, with the alarm sounding and Stop showing: a tile
    /// "Again.", "Help." or "Stop.", or a category named "Yes".
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

/// Voice Control on Home with a library a family has grown: a phrase or
/// category saved with words another control answers to is kept as written,
/// and the Library says so, unless they are the name of a control one
/// activation away, which the editor refuses (docs/DECISIONS.md, "Phrases
/// named like Home's controls").
struct LibraryNameCollisionTests {
    private typealias F = LibraryFixtures

    /// `F.library` with `texts` added to the category `id`.
    private func library(adding texts: [String], to id: UUID = F.basicsID) -> LibrarySnapshot {
        var library = F.library
        let index = library.categories.firstIndex { $0.id == id }!
        for (offset, text) in texts.enumerated() {
            library.categories[index].phrases.append(.init(id: F.id(900 + offset), text: text))
        }
        return library
    }

    /// Fails if a control's name, or one of the other names it answers to,
    /// is left out of the check, or if case or punctuation hides one.
    @Test(arguments: [
        "Yes", "no.", "EMERGENCY", "Get attention", "help!", "Again!", "Repeat", "Stop.", "Stop Alert",
        "Settings", "Phrases", "Type", "Speak", "Clear", "put back",
    ])
    func aPhraseNamedLikeAHomeControlSharesAName(text: String) {
        #expect(library(adding: [text]).sharesAName(phrase: text, inCategory: F.basicsID))
        // In Emergency's phrases too, which show under the same controls.
        #expect(library(adding: [text], to: F.emergencyID).sharesAName(phrase: text, inCategory: F.emergencyID))
    }

    /// Fails if the check matches part of a phrase: Voice Control's "Tap
    /// Help" means a control named Help, not one whose name has the word
    /// in it. A phrase with nothing to say has no name to share.
    @Test(arguments: ["Help me.", "Yes, please.", "Stop that.", "Don't stop.", "👍", "..."])
    func aPhraseWithOtherWordsSharesNoName(text: String) {
        #expect(!library(adding: [text]).sharesAName(phrase: text, inCategory: F.basicsID))
    }

    /// Fails if the category buttons are left out: they stay on screen
    /// whichever category's phrases show.
    @Test func aPhraseNamedLikeACategoryButtonSharesAName() {
        #expect(library(adding: ["Needs."]).sharesAName(phrase: "Needs.", inCategory: F.basicsID))
        #expect(library(adding: ["Needs."], to: F.emergencyID).sharesAName(phrase: "Needs.", inCategory: F.emergencyID))
    }

    /// "Okay." and "Okay?" are two phrases to the library, which keeps
    /// punctuation, and one name to Voice Control. Only one category's
    /// phrases show at a time, so the same words in two categories never
    /// share a screen. Fails if the check compares phrases as the duplicate
    /// rule does, or across categories.
    @Test func phrasesSaidAlikeShareANameOnlyWhereTheyShowTogether() {
        let together = library(adding: ["Okay.", "Okay?"])
        #expect(together.sharesAName(phrase: "Okay?", inCategory: F.basicsID))

        var apart = library(adding: ["Okay."])
        apart.categories[2].phrases.append(.init(id: F.id(950), text: "Okay?"))
        #expect(!apart.sharesAName(phrase: "Okay.", inCategory: F.basicsID))
        #expect(!apart.sharesAName(phrase: "Okay?", inCategory: F.needsID))
    }

    /// Fails if a name shared elsewhere on the screen is reported for words
    /// that share nothing: the note would then show on every phrase saved
    /// in a category with one such phrase.
    @Test func anotherPhrasesNameIsNotThisOnes() {
        let library = library(adding: ["Stop.", "Water, please."])
        #expect(library.sharesAName(phrase: "Stop.", inCategory: F.basicsID))
        #expect(!library.sharesAName(phrase: "Water, please.", inCategory: F.basicsID))
    }

    /// A category's button answers to its name while any category's
    /// phrases show, so a phrase in any category can share it. Emergency's
    /// category has no button of its own: Home's Emergency opens it. Fails
    /// if only one category's phrases are compared, or if Emergency's name
    /// counts as a button.
    @Test func aCategoryNamedLikeAPhraseSharesAName() {
        #expect(!F.library.sharesAName(category: F.needsID))
        #expect(library(adding: ["Needs!"]).sharesAName(category: F.needsID))
        #expect(library(adding: ["Needs!"], to: F.emergencyID).sharesAName(category: F.needsID))
        #expect(!library(adding: ["Basics!"]).sharesAName(category: F.needsID))

        var renamed = library(adding: ["Help"])
        renamed.categories[1].name = "Help"
        #expect(!renamed.sharesAName(category: F.emergencyID))
    }

    /// Fails if a starter phrase or name collides, or if the snapshot's
    /// check and the one over the stored library disagree.
    @Test func theStarterLibrarySharesNoNames() throws {
        #expect(try StarterLibrary.bundled().sharedNames == [])
    }

    /// The family's words come first, for every control but the four that
    /// are one activation away (docs/DECISIONS.md, "Phrases named like
    /// Home's controls"). Fails if the editor starts refusing such a phrase,
    /// or changes its words.
    @Test(arguments: ["Stop.", "Again", "Repeat!", "Settings", "Type", "Put back", "Help me.", "Yes, please.", "Y E S", "H e l p."])
    func theWordsAreKeptAsWritten(text: String) throws {
        let ids = SequentialIDs()
        let added = try LibraryEdit.addPhrase(text: text, category: F.basicsID).plan(in: F.library, makeID: ids.make)
        #expect(added.after.categories[0].phrases.last?.text == text)
        let changed = try LibraryEdit.editPhrase(F.id(101), text: text).plan(in: F.library, makeID: ids.make)
        #expect(changed.after.categories[0].phrases.first?.text == text)
    }

    /// Invariant 10: Yes, No, Emergency and Get Attention are one activation
    /// away, so with Voice Control their names stay theirs. Fails if a name
    /// is left out, Get Attention's Help among them, if case, punctuation
    /// or a symbol gets one past, or if only adding or only editing refuses.
    @Test(arguments: ["Yes", "no.", "EMERGENCY", "Get attention", "GetAttention", "help!", "Help", "😀Yes😀"])
    func theFourControlsKeepTheirNames(text: String) {
        let ids = SequentialIDs()
        #expect(throws: LibraryEditRejection.phraseNamedLikeASafetyControl) {
            try LibraryEdit.addPhrase(text: text, category: F.basicsID).plan(in: F.library, makeID: ids.make)
        }
        #expect(throws: LibraryEditRejection.phraseNamedLikeASafetyControl) {
            try LibraryEdit.editPhrase(F.id(101), text: text).plan(in: F.library, makeID: ids.make)
        }
    }

    /// A backup's words are never changed or refused on the way in
    /// (invariant 7), so a library can hold such a phrase. Only an edit that
    /// gives a phrase such a name is refused: it can still be moved,
    /// deleted, changed to other words, or edited and stay what it was.
    /// Fails if the rule stops a family fixing one, or if a second phrase
    /// can take the name because one already has it.
    @Test func aPhraseThatAlreadyHasSuchANameCanStillBeChanged() throws {
        let ids = SequentialIDs()
        let held = library(adding: ["Help", "Water, please."])
        let phrase = F.id(900)
        #expect(try LibraryEdit.editPhrase(phrase, text: "Help!").plan(in: held, makeID: ids.make).after.categories[0].phrases.map(\.text).contains("Help!"))
        #expect(try LibraryEdit.editPhrase(phrase, text: "Help me.").plan(in: held, makeID: ids.make).after.categories[0].phrases.map(\.text).contains("Help me."))
        _ = try LibraryEdit.movePhrase(phrase, category: F.basicsID, before: F.id(101)).plan(in: held, makeID: ids.make)
        _ = try LibraryEdit.deletePhrase(phrase).plan(in: held, makeID: ids.make)
        #expect(throws: LibraryEditRejection.phraseNamedLikeASafetyControl) {
            try LibraryEdit.editPhrase(F.id(101), text: "Help!").plan(in: held, makeID: ids.make)
        }
        #expect(throws: LibraryEditRejection.phraseNamedLikeASafetyControl) {
            try LibraryEdit.editPhrase(phrase, text: "Yes").plan(in: held, makeID: ids.make)
        }
    }

    /// A restore says so only where it brings a shared name the library
    /// did not have. Fails if every restore's line says it, or none does,
    /// or if a backup's words are refused or changed.
    @Test func aPlanSaysWhetherItBringsASharedName() throws {
        let ids = SequentialIDs()
        func merging(_ text: String, into library: LibrarySnapshot) throws -> LibraryPlan {
            var category = F.basics
            category.phrases = [.init(id: F.id(960), text: text)]
            return try LibraryEdit.merge(LibrarySnapshot(categories: [category])).plan(in: library, makeID: ids.make)
        }
        let bringsOne = try merging("Help", into: F.library)
        #expect(bringsOne.after.categories[0].phrases.last?.text == "Help")
        #expect(bringsOne.bringsASharedName)
        #expect(LibraryRestoreWords.line("Added.", after: bringsOne) == "Added. \(LibraryRules.restoredSharedNameNote)")
        let bringsNone = try merging("Water, please.", into: F.library)
        #expect(!bringsNone.bringsASharedName)
        #expect(LibraryRestoreWords.line("Added.", after: bringsNone) == "Added.")
        #expect(try !merging("Water, please.", into: library(adding: ["Help"])).bringsASharedName)
    }

    /// Edit Phrase's line keeps the height of the tallest thing it can say,
    /// or the rows under it move as a note appears. Fails if a version Save
    /// can leave is left out.
    @Test func editPhrasesLineKeepsRoomForBothNotes() {
        let both = LibraryRules.savedLine("Saved.", isWide: true, sharesAName: true)
        #expect(LibraryRules.savedPhraseLines.contains(both))
        #expect(LibraryRules.savedPhraseLines.count == 4)
        #expect(Set(LibraryRules.savedPhraseLines).count == 4)
    }

    /// Fails if a line drops what Save did, drops a note or runs two
    /// sentences together.
    @Test func aSavedLineSaysWhatSaveDidThenEachNote() {
        let note = LibraryRules.sharedNameNote
        let wide = LibraryRules.wideWordNote
        #expect(LibraryRules.savedLine("Saved.", isWide: false, sharesAName: false) == "Saved.")
        #expect(LibraryRules.savedLine("Saved.", isWide: false, sharesAName: true) == "Saved. \(note)")
        #expect(LibraryRules.savedLine("Saved.", isWide: true, sharesAName: false) == "Saved. \(wide)")
        #expect(LibraryRules.savedLine("Saved.", isWide: true, sharesAName: true) == "Saved. \(wide) \(note)")
    }
}

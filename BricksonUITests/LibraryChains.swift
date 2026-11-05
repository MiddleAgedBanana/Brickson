import Foundation

/// The Library's screens in Settings for the chain engine (`ChainEngine`):
/// Phrases and Categories, one category, one phrase's editor, and the
/// question screens they open (docs/DECISIONS.md, "The Library's question
/// screens"), each with what its controls do. Settings covers Home, and
/// Back to Talking, in the same place on every screen, closes it onto Home.
///
/// - Phrases and Categories: Back returns to Family Setup; each category's
///   row opens its screen; Add a Category opens New Category; Export a
///   Backup and Restore from a Backup open the system's share sheet and
///   file picker, which are not followed (what lies past them is the
///   system's, and each needs deliberate choices).
/// - A category: Back returns to the Library; Add a Phrase opens New
///   Phrase; each phrase's row opens its editor; Rename opens the name's
///   editor; Change Picture, Move Category and Delete Category open their
///   questions.
/// - A phrase's editor: Back returns to the category; the field puts the
///   cursor in its words, and Save does nothing until they are changed,
///   which a held look cannot do; Move Phrase and Delete Phrase open their
///   questions. The field is not a button, so the UI test reads it on its
///   own: left out, a look over it met Back to Talking.
/// - A question: Back and the way back (Keep, Leave It Here, Keep This
///   Picture) return to the screen that asked; Delete for Good deletes and
///   the screen stays, with Delete for Good dimmed and the way back, now
///   Done, returning to the screen above what was deleted; a place in a
///   move moves things and the screen stays; a picture changes the category
///   and the screen stays. A look can also rest on a question's words.
///
/// Every phrase's editor is built the same way, so every phrase row opens
/// the one editor a UI test read. Only the category a UI test opened is
/// followed: another category's screen has its own number of phrases, so
/// the chain ends at its row. A control this does not know is returned as
/// unknown rather than guessed at.
///
/// Test infrastructure only, compiled into both test targets like
/// `ChainEngine`.
nonisolated enum LibraryChains {
    /// The states, by the titles the screens show, except the category,
    /// whose title is the category's own name.
    static let library = "Phrases and Categories"
    static let category = "a category"
    static let editor = "Edit Phrase"
    static let deletePhrase = "Delete Phrase"
    static let movePhrase = "Move Phrase"
    static let picture = "Change Picture"
    static let moveCategory = "Move Category"
    static let deleteCategory = "Delete Category"
    /// The delete questions once Delete for Good has deleted.
    static let deletedPhrase = "Delete Phrase, deleted"
    static let deletedCategory = "Delete Category, deleted"
    /// A question's words, where a look can rest.
    static let words = "libraryQuestionWords"

    /// Controls, by the names the UI tests read them by.
    static let backToTalking = SettingsChains.backToTalking
    static let back = SettingsChains.back
    static let wayBack = "libraryWayBack"
    static let deleteForGood = "libraryDeleteForGood"
    static let save = "librarySave"
    static let phraseField = "libraryPhraseField"
    static let addCategory = "libraryAddCategory"
    static let export = "libraryExport"
    static let restore = "libraryRestore"
    static let addPhrase = "libraryAddPhrase"
    static let rename = "libraryRename"
    static let changePicture = "libraryChangePicture"
    static let moveCategoryRow = "libraryMoveCategory"
    static let deleteCategoryRow = "libraryDeleteCategory"
    static let movePhraseRow = "libraryMovePhrase"
    static let deletePhraseRow = "libraryDeletePhrase"
    static let emergencyRow = "libraryEmergency"
    static let categoryRowPrefix = "libraryCategory"
    static let phraseRowPrefix = "libraryPhrase"
    static let movePlacePrefix = "libraryMovePlace"
    static let picturePrefix = "libraryPicture-"

    /// The controls of each screen, as it first appears. A screen not read
    /// (nil) is left out of the map, and chains reaching it end there.
    struct Screens {
        var library: [(name: String, frame: CGRect)]
        /// The row on the Library that opened `category`.
        var categoryRow: String
        var category: [(name: String, frame: CGRect)]?
        var editor: [(name: String, frame: CGRect)]? = nil
        var deletePhrase: [(name: String, frame: CGRect)]? = nil
        var movePhrase: [(name: String, frame: CGRect)]? = nil
        var picture: [(name: String, frame: CGRect)]? = nil
        var moveCategory: [(name: String, frame: CGRect)]? = nil
        var deleteCategory: [(name: String, frame: CGRect)]? = nil
        /// Each question's words, by the question's state.
        var words: [String: CGRect] = [:]
    }

    /// The map of the Library's screens, with Back to Talking leading to
    /// `home`, the Home state Settings was opened from, and the Library's
    /// Back to Family Setup (`SettingsChains.familySetup`); and the
    /// controls it does not know, each with its screen.
    static func map(_ screens: Screens, closingOnto home: String) -> (map: ChainMap, unknown: [String]) {
        var unknown: [String] = []
        func controls(
            _ list: [(name: String, frame: CGRect)]?, on screen: String, backTo parent: String,
            _ known: (String, CGRect) -> ChainControl?
        ) -> [ChainControl]? {
            list.map { list in
                list.compactMap { name, frame in
                    switch name {
                    case backToTalking: return ChainControl(name, frame, .navigates, leadsTo: home)
                    case back: return ChainControl(name, frame, .navigates, leadsTo: parent)
                    default:
                        guard let control = known(name, frame) else {
                            unknown.append("\(name) on \(screen)")
                            return nil
                        }
                        return control
                    }
                }
            }
        }
        var states: [String: [ChainControl]] = [:]
        states[library] = controls(screens.library, on: library, backTo: SettingsChains.familySetup) { name, frame in
            switch name {
            case screens.categoryRow: ChainControl(name, frame, .navigates, leadsTo: category)
            case _ where name == emergencyRow || name.hasPrefix(categoryRowPrefix): ChainControl(name, frame, .navigates, leadsTo: "category \(name)")
            case addCategory: ChainControl(name, frame, .navigates, leadsTo: "New Category")
            case export: ChainControl(name, frame, .navigates, leadsTo: "the share sheet")
            case restore: ChainControl(name, frame, .navigates, leadsTo: "the file picker")
            default: nil
            }
        }
        states[category] = controls(screens.category, on: category, backTo: library) { name, frame in
            switch name {
            case _ where name.hasPrefix(phraseRowPrefix): ChainControl(name, frame, .navigates, leadsTo: editor)
            case addPhrase: ChainControl(name, frame, .navigates, leadsTo: "New Phrase")
            case rename: ChainControl(name, frame, .navigates, leadsTo: "Rename Category")
            case changePicture: ChainControl(name, frame, .navigates, leadsTo: picture)
            case moveCategoryRow: ChainControl(name, frame, .navigates, leadsTo: moveCategory)
            case deleteCategoryRow: ChainControl(name, frame, .navigates, leadsTo: deleteCategory)
            default: nil
            }
        }
        states[editor] = controls(screens.editor, on: editor, backTo: category) { name, frame in
            switch name {
            case save, phraseField: ChainControl(name, frame, .nothing)
            case movePhraseRow: ChainControl(name, frame, .navigates, leadsTo: movePhrase)
            case deletePhraseRow: ChainControl(name, frame, .navigates, leadsTo: deletePhrase)
            default: nil
            }
        }
        states[deletePhrase] = controls(screens.deletePhrase, on: deletePhrase, backTo: editor) { name, frame in
            switch name {
            case wayBack: ChainControl(name, frame, .navigates, leadsTo: editor)
            case deleteForGood: ChainControl(name, frame, .changesData, leadsTo: deletedPhrase)
            default: nil
            }
        }
        states[deletedPhrase] = controls(screens.deletePhrase, on: deletedPhrase, backTo: editor) { name, frame in
            switch name {
            case wayBack: ChainControl(name, frame, .navigates, leadsTo: category)
            case deleteForGood: ChainControl(name, frame, .nothing)
            default: nil
            }
        }
        states[movePhrase] = controls(screens.movePhrase, on: movePhrase, backTo: editor) { name, frame in
            switch name {
            case wayBack: ChainControl(name, frame, .navigates, leadsTo: editor)
            case _ where name.hasPrefix(movePlacePrefix): ChainControl(name, frame, .movesThings)
            default: nil
            }
        }
        states[picture] = controls(screens.picture, on: picture, backTo: category) { name, frame in
            switch name {
            case wayBack: ChainControl(name, frame, .navigates, leadsTo: category)
            case _ where name.hasPrefix(picturePrefix): ChainControl(name, frame, .changesData)
            default: nil
            }
        }
        states[moveCategory] = controls(screens.moveCategory, on: moveCategory, backTo: category) { name, frame in
            switch name {
            case wayBack: ChainControl(name, frame, .navigates, leadsTo: category)
            case _ where name.hasPrefix(movePlacePrefix): ChainControl(name, frame, .movesThings)
            default: nil
            }
        }
        states[deleteCategory] = controls(screens.deleteCategory, on: deleteCategory, backTo: category) { name, frame in
            switch name {
            case wayBack: ChainControl(name, frame, .navigates, leadsTo: category)
            case deleteForGood: ChainControl(name, frame, .changesData, leadsTo: deletedCategory)
            default: nil
            }
        }
        states[deletedCategory] = controls(screens.deleteCategory, on: deletedCategory, backTo: category) { name, frame in
            switch name {
            case wayBack: ChainControl(name, frame, .navigates, leadsTo: library)
            case deleteForGood: ChainControl(name, frame, .nothing)
            default: nil
            }
        }
        // The deleted states keep their question's words in place.
        var resting: [String: [(name: String, frame: CGRect)]] = [:]
        for (state, frame) in screens.words where states[state] != nil {
            resting[state] = [(words, frame)]
        }
        for (asked, deleted) in [(deletePhrase, deletedPhrase), (deleteCategory, deletedCategory)] {
            if let frame = screens.words[asked], states[deleted] != nil {
                resting[deleted] = [(words, frame)]
            }
        }
        return (ChainMap(states: states, resting: resting), unknown)
    }

    /// The Library's screens in the map, as against Home's and Settings'.
    static let screens: Set = [
        library, category, editor, deletePhrase, deletedPhrase, movePhrase, picture, moveCategory, deleteCategory, deletedCategory,
    ]

    /// Where chains through the Library start in `map`: every control of
    /// its screens chosen, with the look at its centre and across it, and
    /// the look resting across each question's words, in state-name order.
    static func starts(in map: ChainMap) -> [ChainStart] {
        map.states.keys.sorted().filter { screens.contains($0) }.flatMap { map.starts(in: $0) }
    }

    /// The kinds of hazard a chain through the Library can end in.
    enum Kind: String, CaseIterable, Sendable {
        /// A held look deletes, moves or changes something in the
        /// Library that the person did not choose.
        case changesTheLibrary
        /// Settings closes under the look and a pointer gone back to where
        /// the person looks meets Home's Yes, No or Get Attention.
        case closesUnderTheLook
        /// Anything else: a new hazard.
        case unexpected
    }

    /// The kind of hazard `chain` ended in; nil when it ended in none.
    static func kind(of chain: Chain) -> Kind? {
        guard let hazard = chain.hazard else { return nil }
        if screens.contains(hazard.state) { return .changesTheLibrary }
        let onHome = !screens.contains(hazard.state) && !SettingsChains.screens.contains(hazard.state)
        return onHome && chain.pointer == .returnsToLook ? .closesUnderTheLook : .unexpected
    }
}

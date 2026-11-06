import SwiftData
import SwiftUI

/// Edit Phrase, or New Phrase from a category's Add a Phrase: the field,
/// Save, a line kept for what Save did, then Move Phrase and Delete Phrase
/// (Edit Phrase only).
///
/// Save is dimmed until the words differ from what the field first showed
/// (`LibraryEditorWords`), so a look resting on it meets nothing to do, and
/// Return saves, as it speaks on Home: the field's words go through
/// `MessageComposer`, so a typed line break never reaches the phrase. New Phrase empties its field after a
/// save, ready for the next. Words not yet saved hold Settings' idle
/// reset, and typing counts as activity.
///
/// A phrase with a word wider than Home's narrowest phrase buttons is saved
/// with a note that it may wrap there (`HomeWordRoom`; docs/DECISIONS.md,
/// "Words wider than Home's narrowest buttons"), and one with a name another
/// control on Home answers to with a note saying so (docs/DECISIONS.md,
/// "Phrases named like Home's controls").
struct LibraryPhraseEditor: View {
    let phraseID: UUID?
    /// The category a new phrase goes in; unused when editing.
    let categoryID: UUID?
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsScreen(title: title) {
            LibraryPhraseEditorContent(phraseID: phraseID, categoryID: categoryID, path: $path)
        }
    }

    private var title: LocalizedStringKey {
        if phraseID == nil {
            return "New Phrase"
        }
        return "Edit Phrase"
    }
}

private struct LibraryPhraseEditorContent: View {
    let phraseID: UUID?
    let categoryID: UUID?
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.modelContext) private var modelContext
    @State private var words = LibraryEditorWords()
    @State private var text = ""
    @State private var result: String?
    @State private var hasLoaded = false
    @FocusState private var isFocused: Bool

    var body: some View {
        LibraryTextField(label: "Phrase", lines: 4, text: $text, isFocused: $isFocused)
            .accessibilityIdentifier("libraryPhraseField")
            .onAppear(perform: load)
            .task {
                // A new phrase is typed straight away.
                if phraseID == nil {
                    isFocused = true
                }
            }
            .onChange(of: text) { _, proposed in
                edit(proposed)
            }

        Button(action: save) {
            SettingsRowLabel(title: "Save", systemImage: "checkmark")
        }
        .settingsRowStyle(fill: Palette.phraseFill)
        .disabled(!canSave)
        .holdsSettingsIdleReset(canSave)
        .accessibilityIdentifier("librarySave")

        LibraryResultLine(text: result, alternatives: resultLines, identifier: "libraryEditorResult")

        if let phraseID {
            LibraryAskingRow(title: "Move Phrase", systemImage: "arrow.up.arrow.down", route: .movePhrase(phraseID), path: $path)
                .accessibilityIdentifier("libraryMovePhrase")
            LibraryAskingRow(title: "Delete Phrase", systemImage: "trash.fill", route: .deletePhrase(phraseID), isLast: true, path: $path)
                .disabled(deleteRefusal != nil)
                .accessibilityIdentifier("libraryDeletePhrase")
            LibraryResultLine(text: deleteRefusal, alternatives: [deleteRefusal].compactMap { $0 }, identifier: "libraryDeleteReason")
        }
    }

    private var canSave: Bool { words.canSave }

    /// Why Delete Phrase is dimmed (Emergency's last phrase with words,
    /// or a category's fourth phrase), or nil.
    private var deleteRefusal: String? {
        phraseID.flatMap { library.refusal(of: .deletePhrase($0)) }
    }

    private var resultLines: [String] {
        LibraryRules.savedPhraseLines + [String(localized: "That's as long as a phrase can be.")]
            + [LibraryEditRejection.emptyText, .duplicatePhrase].map(\.message)
            + (result.map { [$0] } ?? []) + LibraryMessages.anyChange
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let phraseID, let found = library.phrase(phraseID) else { return }
        words = LibraryEditorWords(restoring: found.phrase.text)
        text = words.composer.text
    }

    private func edit(_ proposed: String) {
        activity?.recordActivity()
        let outcome = words.composer.apply(.propose(proposed))
        if outcome.draftChanged {
            result = nil
        }
        if outcome.reachedLimit {
            result = String(localized: "That's as long as a phrase can be.")
        }
        if outcome.fieldNeedsUpdate {
            text = words.composer.text
        }
        if outcome.textToSpeak != nil {
            // Return saves.
            save()
        }
    }

    private func save() {
        activity?.recordActivity()
        guard canSave else { return }
        let typed = words.composer.text
        let change: LibraryEdit
        if let phraseID {
            change = .editPhrase(phraseID, text: typed)
        } else if let categoryID {
            change = .addPhrase(text: typed, category: categoryID)
        } else {
            return
        }
        switch library.perform(change, in: modelContext.container) {
        case .saved(let plan):
            let stored = LibraryText.trimmed(typed)
            let isWide = !HomeWordRoom.wordsTooWide(inPhrase: stored).isEmpty
            let shownIn = categoryID ?? phraseID.flatMap { library.phrase($0)?.category.id }
            let sharesAName = shownIn.map { plan.after.sharesAName(phrase: stored, inCategory: $0) } ?? false
            // At the largest text sizes on a phone the keyboard covers the
            // line, and a note is there to be read. Nothing moves with it.
            if isWide || sharesAName {
                isFocused = false
            }
            if phraseID == nil {
                let name = categoryID.flatMap { library.category($0)?.name } ?? ""
                result = LibraryRules.savedLine(String(localized: "Added “\(stored)” to \(name)."), isWide: isWide, sharesAName: sharesAName)
                words = LibraryEditorWords()
                text = ""
            } else {
                result = LibraryRules.savedLine(String(localized: "Saved."), isWide: isWide, sharesAName: sharesAName)
                words = LibraryEditorWords(restoring: stored)
                text = words.composer.text
            }
        case .refused(let reason):
            result = reason
        }
    }
}

/// Rename, or New Category from the Library's Add a Category: the field,
/// Save and a line kept for what Save did, as on the phrase editor.
///
/// A name with a word too wide for Home's narrowest category button is
/// refused, naming the word, because a category's name has no second line
/// to wrap onto (`HomeWordRoom`). A name a phrase also has is saved with a
/// note saying so (docs/DECISIONS.md, "Phrases named like Home's controls").
/// New Category opens the new category's screen in place of itself once
/// saved, so Add a Phrase is one activation away.
struct LibraryNameEditor: View {
    /// The category being renamed; nil for a new one.
    let categoryID: UUID?
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsScreen(title: title) {
            LibraryNameEditorContent(categoryID: categoryID, path: $path)
        }
    }

    private var title: LocalizedStringKey {
        if categoryID == nil {
            return "New Category"
        }
        return "Rename Category"
    }
}

private struct LibraryNameEditorContent: View {
    let categoryID: UUID?
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.modelContext) private var modelContext
    @State private var words = LibraryEditorWords()
    @State private var text = ""
    @State private var result: String?
    @State private var hasLoaded = false
    @FocusState private var isFocused: Bool

    var body: some View {
        LibraryTextField(label: "Category Name", lines: 2, text: $text, isFocused: $isFocused)
            .accessibilityIdentifier("libraryNameField")
            .onAppear(perform: load)
            .task {
                if categoryID == nil {
                    isFocused = true
                }
            }
            .onChange(of: text) { _, proposed in
                edit(proposed)
            }

        Button(action: save) {
            SettingsRowLabel(title: "Save", systemImage: "checkmark")
        }
        .settingsRowStyle(fill: Palette.phraseFill)
        .disabled(!canSave)
        .holdsSettingsIdleReset(canSave)
        .accessibilityIdentifier("librarySave")

        LibraryResultLine(text: result, alternatives: resultLines, identifier: "libraryEditorResult")
    }

    private var canSave: Bool { words.canSave }

    private var resultLines: [String] {
        [
            String(localized: "Saved."),
            LibraryRules.savedLine(String(localized: "Saved."), sharesAName: true),
            String(localized: "That's as long as a name can be."),
        ]
            + [LibraryEditRejection.emptyName, .duplicateCategoryName, .reservedCategoryName, .homeHasRoomForFour].map(\.message)
            + (result.map { [$0] } ?? []) + LibraryMessages.anyChange
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let categoryID, let category = library.category(categoryID) else { return }
        words = LibraryEditorWords(restoring: category.name)
        text = words.composer.text
    }

    private func edit(_ proposed: String) {
        activity?.recordActivity()
        let outcome = words.composer.apply(.propose(proposed))
        if outcome.draftChanged {
            result = nil
        }
        if outcome.reachedLimit {
            result = String(localized: "That's as long as a name can be.")
        }
        if outcome.fieldNeedsUpdate {
            text = words.composer.text
        }
        if outcome.textToSpeak != nil {
            save()
        }
    }

    private func save() {
        activity?.recordActivity()
        guard canSave else { return }
        let name = LibraryText.trimmed(words.composer.text)
        if let word = HomeWordRoom.wordsTooWide(inCategoryName: name).first {
            result = String(localized: "“\(word)” is too wide for Home's category buttons. Choose a shorter word.")
            return
        }
        let change: LibraryEdit = categoryID.map { LibraryEdit.renameCategory($0, name: name) }
            ?? LibraryEdit.addCategory(name: name, symbolName: LibraryRules.newCategorySymbol)
        switch library.perform(change, in: modelContext.container) {
        case .saved(let plan):
            if categoryID == nil {
                let before = Set(plan.before.categories.map(\.id))
                guard let added = plan.after.categories.first(where: { !before.contains($0.id) }) else { return }
                library.categoryResults[added.id] = LibraryRules.savedLine(
                    String(localized: "Added “\(name)”. Add its phrases here."),
                    sharesAName: plan.after.sharesAName(category: added.id)
                )
                if let last = path.indices.last, path[last] == .newCategory {
                    path[last] = .libraryCategory(added.id)
                }
            } else if let categoryID {
                let sharesAName = plan.after.sharesAName(category: categoryID)
                if sharesAName {
                    isFocused = false
                }
                result = LibraryRules.savedLine(String(localized: "Saved."), sharesAName: sharesAName)
                words = LibraryEditorWords(restoring: name)
                text = words.composer.text
            }
        case .refused(let reason):
            result = reason
        }
    }
}

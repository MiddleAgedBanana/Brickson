import SwiftData
import SwiftUI

/// Edit Phrase, or New Phrase from a category's Add a Phrase: the field,
/// Save, a line kept for what Save did, then Move Phrase and Delete Phrase
/// (Edit Phrase only).
///
/// Save is dimmed until the words differ from what is saved, so a look
/// resting on it meets nothing to do, and Return saves, as it speaks on
/// Home: the field's words go through `MessageComposer`, so a typed line
/// break never reaches the phrase. New Phrase empties its field after a
/// save, ready for the next. Words not yet saved hold Settings' idle
/// reset, and typing counts as activity.
///
/// A phrase with a word wider than Home's narrowest phrase buttons is saved
/// with a note that it may wrap there (`HomeWordRoom`; docs/DECISIONS.md,
/// "Words wider than Home's narrowest buttons").
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
    @State private var composer = MessageComposer()
    @State private var text = ""
    /// The words as saved, trimmed as the library keeps them; empty for a
    /// new phrase.
    @State private var saved = ""
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

    /// Words that differ from what is saved, and are not blank.
    private var canSave: Bool {
        !LibraryText.isBlank(composer.text) && LibraryText.trimmed(composer.text) != saved
    }

    /// Why Delete Phrase is dimmed (Emergency's last phrase), or nil.
    private var deleteRefusal: String? {
        phraseID.flatMap { library.refusal(of: .deletePhrase($0)) }
    }

    private var resultLines: [String] {
        [
            String(localized: "Saved."),
            String(localized: "Saved. A word in it is wider than Home's narrowest phrase buttons, so on the narrowest screens it can wrap onto a second line."),
            String(localized: "That's as long as a phrase can be."),
        ] + [LibraryEditRejection.emptyText, .duplicatePhrase].map(\.message)
            + (result.map { [$0] } ?? []) + LibraryMessages.anyChange
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let phraseID, let found = library.phrase(phraseID) else { return }
        composer = MessageComposer(restoring: found.phrase.text)
        text = composer.text
        saved = LibraryText.trimmed(found.phrase.text)
    }

    private func edit(_ proposed: String) {
        activity?.recordActivity()
        let outcome = composer.apply(.propose(proposed))
        if outcome.draftChanged {
            result = nil
        }
        if outcome.reachedLimit {
            result = String(localized: "That's as long as a phrase can be.")
        }
        if outcome.fieldNeedsUpdate {
            text = composer.text
        }
        if outcome.textToSpeak != nil {
            // Return saves.
            save()
        }
    }

    private func save() {
        activity?.recordActivity()
        guard canSave else { return }
        let words = composer.text
        let change: LibraryEdit
        if let phraseID {
            change = .editPhrase(phraseID, text: words)
        } else if let categoryID {
            change = .addPhrase(text: words, category: categoryID)
        } else {
            return
        }
        switch library.perform(change, in: modelContext.container) {
        case .saved:
            let stored = LibraryText.trimmed(words)
            let isWide = !HomeWordRoom.wordsTooWide(inPhrase: stored).isEmpty
            if phraseID == nil {
                let name = categoryID.flatMap { library.category($0)?.name } ?? ""
                result = isWide
                    ? String(localized: "Added “\(stored)” to \(name). A word in it is wider than Home's narrowest phrase buttons, so on the narrowest screens it can wrap onto a second line.")
                    : String(localized: "Added “\(stored)” to \(name).")
                composer = MessageComposer()
                text = ""
                saved = ""
            } else {
                result = isWide
                    ? String(localized: "Saved. A word in it is wider than Home's narrowest phrase buttons, so on the narrowest screens it can wrap onto a second line.")
                    : String(localized: "Saved.")
                composer = MessageComposer(restoring: stored)
                text = composer.text
                saved = stored
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
/// to wrap onto (`HomeWordRoom`). New Category opens the new category's
/// screen in place of itself once saved, so Add a Phrase is one activation
/// away.
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
    @State private var composer = MessageComposer()
    @State private var text = ""
    @State private var saved = ""
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

    private var canSave: Bool {
        !LibraryText.isBlank(composer.text) && LibraryText.trimmed(composer.text) != saved
    }

    private var resultLines: [String] {
        [String(localized: "Saved."), String(localized: "That's as long as a name can be.")]
            + [LibraryEditRejection.emptyName, .duplicateCategoryName, .reservedCategoryName, .homeHasRoomForFour].map(\.message)
            + (result.map { [$0] } ?? []) + LibraryMessages.anyChange
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let categoryID, let category = library.category(categoryID) else { return }
        composer = MessageComposer(restoring: category.name)
        text = composer.text
        saved = LibraryText.trimmed(category.name)
    }

    private func edit(_ proposed: String) {
        activity?.recordActivity()
        let outcome = composer.apply(.propose(proposed))
        if outcome.draftChanged {
            result = nil
        }
        if outcome.reachedLimit {
            result = String(localized: "That's as long as a name can be.")
        }
        if outcome.fieldNeedsUpdate {
            text = composer.text
        }
        if outcome.textToSpeak != nil {
            save()
        }
    }

    private func save() {
        activity?.recordActivity()
        guard canSave else { return }
        let name = LibraryText.trimmed(composer.text)
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
                library.categoryResults[added.id] = String(localized: "Added “\(name)”. Add its phrases here.")
                if let last = path.indices.last, path[last] == .newCategory {
                    path[last] = .libraryCategory(added.id)
                }
            } else {
                result = String(localized: "Saved.")
                composer = MessageComposer(restoring: name)
                text = composer.text
                saved = name
            }
        case .refused(let reason):
            result = reason
        }
    }
}

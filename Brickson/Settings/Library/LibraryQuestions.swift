import SwiftData
import SwiftUI

// The Library's question screens: Delete, Move, Change Picture and a
// chosen backup. Each puts its way back in the place of the row that
// asked, its words beside it and its choices well below both
// (`LibraryQuestion`; docs/DECISIONS.md, "The Library's question
// screens"). Nothing changes until a choice is made, and each choice
// changes the library in one save, or not at all.

/// Words for what a delete did, shown on the screen above it.
enum LibraryDeleteWords {
    static func deleted(phrase text: String) -> String {
        String(localized: "Deleted “\(text)”.")
    }

    static func deleted(category name: String) -> String {
        String(localized: "Deleted “\(name)” and every phrase in it.")
    }
}

// MARK: - Delete

/// Delete Phrase or Delete Category: what goes and what keeps a copy, Keep
/// in the place of the row that asked, and Delete for Good well below.
/// Delete for Good returns to the screen above what was deleted, whose
/// controls only open screens, and says there what it did.
struct LibraryDeleteQuestion: View {
    let item: LibraryItem
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsScreen(title: title) {
            LibraryDeleteContent(item: item, path: $path)
        }
    }

    private var title: LocalizedStringKey {
        switch item {
        case .phrase: "Delete Phrase"
        case .category: "Delete Category"
        }
    }
}

private struct LibraryDeleteContent: View {
    let item: LibraryItem
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library
    @Environment(SetupStore.self) private var setup
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.modelContext) private var modelContext
    @State private var result: String?

    var body: some View {
        LibraryQuestion {
            SettingsParagraph(verbatim: question)
        } back: {
            LibraryWayBack(title: keep, path: $path)
        } choices: {
            Button(action: deleteForGood) {
                SettingsRowLabel(title: "Delete for Good", systemImage: "trash.fill")
            }
            .settingsRowStyle()
            .disabled(refusal != nil)
            .accessibilityIdentifier("libraryDeleteForGood")
            LibraryResultLine(
                text: result ?? refusal,
                alternatives: [refusal].compactMap { $0 } + LibraryMessages.anyChange,
                identifier: "libraryQuestionResult"
            )
        }
    }

    private var keep: LocalizedStringKey {
        switch item {
        case .phrase: "Keep Phrase"
        case .category: "Keep Category"
        }
    }

    private var change: LibraryEdit {
        switch item {
        case .phrase(let id): .deletePhrase(id)
        case .category(let id): .deleteCategory(id)
        }
    }

    private var refusal: String? {
        library.refusal(of: change)
    }

    private var question: String {
        switch item {
        case .phrase(let id):
            guard let text = library.phrase(id)?.phrase.text else { return Self.gone }
            return String(localized: "Delete “\(text)”? It will be gone from \(AppName.display). A backup you exported still has it.")
        case .category(let id):
            guard let name = library.category(id)?.name else { return Self.gone }
            let words = String(localized: "Delete “\(name)” and every phrase in it? They will be gone from \(AppName.display). A backup you exported still has them.")
            guard setup.record.restBoardCategory == id else { return words }
            return words + " " + String(localized: "Home's rest board shows this category, so Home will show every category instead.")
        }
    }

    private static var gone: String {
        String(localized: "This isn't in your phrases any more.")
    }

    private func deleteForGood() {
        activity?.recordActivity()
        // The words for the screen above, read before they are gone.
        let line: String?
        let categoryID: UUID?
        switch item {
        case .phrase(let id):
            let found = library.phrase(id)
            line = found.map { LibraryDeleteWords.deleted(phrase: $0.phrase.text) }
            categoryID = found?.category.id
        case .category(let id):
            line = library.category(id).map { LibraryDeleteWords.deleted(category: $0.name) }
            categoryID = nil
        }
        switch library.perform(change, in: modelContext.container) {
        case .saved:
            if let categoryID {
                library.categoryResults[categoryID] = line
            } else {
                library.libraryResult = line
            }
            while let last = path.last, last.isAbout(item.id) {
                path.removeLast()
            }
        case .refused(let reason):
            result = reason
        }
    }
}

// MARK: - Move

/// Move Phrase or Move Category: each other item as a place before it,
/// the item itself as Leave Here, and At the End. Places are absolute
/// (`LibraryEdit.movePhrase`, `.moveCategory`), so choosing one again
/// changes nothing. The screen stays after a move, the list redrawn in the
/// new order in the same frames, and Leave It Here, in the place of the
/// row that asked, goes back.
struct LibraryMoveQuestion: View {
    let item: LibraryItem
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsScreen(title: title) {
            LibraryMoveContent(item: item, path: $path)
        }
    }

    private var title: LocalizedStringKey {
        switch item {
        case .phrase: "Move Phrase"
        case .category: "Move Category"
        }
    }
}

private struct LibraryMoveContent: View {
    let item: LibraryItem
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.modelContext) private var modelContext
    @State private var result: String?

    /// One place the item can go.
    private struct Place {
        let label: String
        let systemImage: String
        /// The item it goes before; nil goes to the end.
        let before: UUID?
        /// The item's own place: choosing it changes nothing.
        let isItself: Bool
    }

    var body: some View {
        LibraryQuestion {
            SettingsParagraph(verbatim: words)
        } back: {
            LibraryWayBack(title: "Leave It Here", path: $path)
        } choices: {
            // By place, not by item, so each row keeps its frame and only
            // its words change after a move.
            ForEach(Array(places.enumerated()), id: \.offset) { index, place in
                Button {
                    move(to: place)
                } label: {
                    SettingsRowLabel(text: Text(verbatim: place.label), systemImage: place.systemImage)
                }
                .settingsRowStyle()
                .accessibilityIdentifier("libraryMovePlace\(index)")
            }
            LibraryResultLine(text: result, alternatives: results, identifier: "libraryQuestionResult")
        }
    }

    private var results: [String] {
        [String(localized: "Moved."), String(localized: "It's already there.")] + LibraryMessages.anyChange
    }

    /// The items in the list the item moves in, in Home's order: the
    /// phrases of its category, or the everyday categories.
    private var siblings: [(id: UUID, name: String)] {
        switch item {
        case .phrase(let id):
            return (library.phrase(id)?.category.phrases ?? []).map { ($0.id, $0.text) }
        case .category:
            return (library.snapshot?.categories ?? []).filter { !$0.isEmergency }.map { ($0.id, $0.name) }
        }
    }

    private var places: [Place] {
        guard siblings.contains(where: { $0.id == item.id }) else { return [] }
        var places: [Place] = []
        for sibling in siblings {
            if sibling.id == item.id {
                places.append(Place(label: String(localized: "Leave “\(sibling.name)” Here"), systemImage: "pin.fill", before: nil, isItself: true))
            } else {
                places.append(Place(label: String(localized: "Before “\(sibling.name)”"), systemImage: "arrow.up.to.line", before: sibling.id, isItself: false))
            }
        }
        places.append(Place(label: String(localized: "At the End"), systemImage: "arrow.down.to.line", before: nil, isItself: false))
        return places
    }

    private var words: String {
        switch item {
        case .phrase(let id):
            guard let found = library.phrase(id) else { return String(localized: "This isn't in your phrases any more.") }
            return String(localized: "Choose where “\(found.phrase.text)” goes in \(found.category.name). Home shows the phrases in this order.")
        case .category(let id):
            guard let category = library.category(id) else { return String(localized: "This isn't in your phrases any more.") }
            return String(localized: "Choose where “\(category.name)” goes. Home shows the categories in this order.")
        }
    }

    private func move(to place: Place) {
        activity?.recordActivity()
        guard !place.isItself else {
            result = String(localized: "It's already there.")
            return
        }
        let change: LibraryEdit
        switch item {
        case .phrase(let id):
            guard let category = library.phrase(id)?.category.id else { return }
            change = .movePhrase(id, category: category, before: place.before)
        case .category(let id):
            change = .moveCategory(id, before: place.before)
        }
        switch library.perform(change, in: modelContext.container) {
        case .saved(let plan):
            result = plan.changes.isEmpty ? String(localized: "It's already there.") : String(localized: "Moved.")
        case .refused(let reason):
            result = reason
        }
    }
}

// MARK: - Change Picture

/// Change Picture: the pictures a category can have, each named in words,
/// the one it has marked with a check. Choosing one saves it and the
/// screen stays; choosing the one it has changes nothing.
struct LibraryPictureQuestion: View {
    let categoryID: UUID
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsScreen(title: "Change Picture") {
            LibraryPictureContent(categoryID: categoryID, path: $path)
        }
    }
}

private struct LibraryPictureContent: View {
    let categoryID: UUID
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.modelContext) private var modelContext
    @State private var result: String?

    var body: some View {
        let category = library.category(categoryID)
        LibraryQuestion {
            if let category {
                SettingsParagraph(verbatim: String(localized: "Choose a picture for “\(category.name)”. It shows on the category's button on Home."))
                SettingsReservedParagraph(
                    text: Text(verbatim: Self.now(category.symbolName)),
                    alternatives: LibraryRules.symbolChoices.map { Text(verbatim: Self.now($0)) }
                )
            } else {
                SettingsParagraph(verbatim: String(localized: "This isn't in your phrases any more."))
            }
        } back: {
            LibraryWayBack(title: "Keep This Picture", path: $path)
        } choices: {
            if let category {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: SettingsMetrics.rowHeight), spacing: SettingsMetrics.rowSpacing)],
                    spacing: SettingsMetrics.rowSpacing
                ) {
                    ForEach(LibraryRules.symbolChoices, id: \.self) { symbol in
                        picture(symbol, isChosen: symbol == category.symbolName)
                    }
                }
                LibraryResultLine(
                    text: result,
                    alternatives: [String(localized: "Saved.")] + [LibraryEditRejection.unknownSymbol.message] + LibraryMessages.anyChange,
                    identifier: "libraryQuestionResult"
                )
            }
        }
    }

    private static func now(_ symbolName: String) -> String {
        String(localized: "Now: \(LibrarySymbolNames.name(of: symbolName)).")
    }

    private func picture(_ symbol: String, isChosen: Bool) -> some View {
        Button {
            choose(symbol)
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight)
                .overlay(alignment: .topTrailing) {
                    if isChosen {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .settingsRowStyle()
        .accessibilityLabel(Text(verbatim: LibrarySymbolNames.name(of: symbol)))
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityIdentifier("libraryPicture-\(symbol)")
    }

    private func choose(_ symbol: String) {
        activity?.recordActivity()
        switch library.perform(.changeCategorySymbol(categoryID, symbolName: symbol), in: modelContext.container) {
        case .saved:
            result = String(localized: "Saved.")
        case .refused(let reason):
            result = reason
        }
    }
}

// MARK: - Restore

/// What a restore did, in words.
enum LibraryRestoreWords {
    static func added(_ changes: LibraryChanges) -> String {
        String(localized: "Added. New categories: \(changes.categoriesAdded). New phrases: \(changes.phrasesAdded). Nothing was removed or moved.")
    }

    static var replaced: String {
        String(localized: "Replaced. Your phrases now match this backup.")
    }

    /// The lines a restore can leave that don't depend on numbers.
    static var results: [String] {
        [replaced]
    }
}

/// The Restore question for a backup the family chose: what it holds,
/// Cancel in the place of Restore from a Backup, and Add to My Phrases and
/// Replace My Phrases well below, each dimmed with its reason where it
/// can't run (`RestoreChoices`). After either, both dim in place and
/// Cancel reads Done.
struct LibraryRestoreQuestion: View {
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsScreen(title: "Restore from a Backup") {
            LibraryRestoreContent(path: $path)
        }
    }
}

private struct LibraryRestoreContent: View {
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.modelContext) private var modelContext
    @State private var result: String?
    /// A choice was made: both choices dim, and Cancel reads Done.
    @State private var isDone = false

    var body: some View {
        LibraryQuestion {
            if let choices = library.restore {
                SettingsParagraph(verbatim: Self.summary(of: choices.backup))
                SettingsParagraph("Add to My Phrases adds what this backup has that your phrases don't. It removes and moves nothing.")
                SettingsParagraph("Replace My Phrases makes your phrases match this backup, in its order.")
            } else {
                SettingsParagraph("There's no backup to restore. Go back and choose one.")
            }
        } back: {
            LibraryWayBack(title: backTitle, path: $path)
        } choices: {
            if let choices = library.restore {
                Button {
                    restore(choices.add, words: { LibraryRestoreWords.added($0.changes) })
                } label: {
                    SettingsRowLabel(title: "Add to My Phrases", systemImage: "plus.square.on.square")
                }
                .settingsRowStyle()
                .disabled(isDone || refusal(choices.add) != nil)
                .accessibilityIdentifier("libraryRestoreAdd")
                LibraryResultLine(
                    text: refusal(choices.add),
                    alternatives: [refusal(choices.add)].compactMap { $0 },
                    identifier: "libraryRestoreAddReason"
                )

                Button {
                    restore(choices.replace, words: { _ in LibraryRestoreWords.replaced })
                } label: {
                    SettingsRowLabel(title: "Replace My Phrases", systemImage: "arrow.triangle.2.circlepath")
                }
                .settingsRowStyle()
                .disabled(isDone || refusal(choices.replace) != nil)
                .accessibilityIdentifier("libraryRestoreReplace")
                LibraryResultLine(
                    text: refusal(choices.replace),
                    alternatives: [refusal(choices.replace)].compactMap { $0 },
                    identifier: "libraryRestoreReplaceReason"
                )

                LibraryResultLine(
                    text: result,
                    alternatives: LibraryRestoreWords.results + (result.map { [$0] } ?? []) + LibraryMessages.anyChange,
                    identifier: "libraryQuestionResult"
                )
            }
        }
    }

    private var backTitle: LocalizedStringKey {
        if isDone {
            return "Done"
        }
        return "Cancel"
    }

    private static func summary(of backup: LibrarySnapshot) -> String {
        let phrases = backup.categories.reduce(0) { $0 + $1.phrases.count }
        return String(localized: "Categories in this backup: \(backup.categories.count). Phrases in it: \(phrases).")
    }

    private func refusal(_ choice: Result<LibraryPlan, RestoreChoices.Refusal>) -> String? {
        switch choice {
        case .success: nil
        case .failure(let refusal): refusal.message
        }
    }

    private func restore(_ choice: Result<LibraryPlan, RestoreChoices.Refusal>, words: (LibraryPlan) -> String) {
        activity?.recordActivity()
        guard !isDone, case .success(let plan) = choice else { return }
        // Either way, the other choice was planned against the library as
        // it was, so both dim now.
        isDone = true
        switch library.apply(plan, in: modelContext.container) {
        case .saved(let saved):
            let line = words(saved)
            result = line
            library.backupResult = line
        case .refused(let reason):
            result = reason
            library.backupResult = reason
        }
    }
}

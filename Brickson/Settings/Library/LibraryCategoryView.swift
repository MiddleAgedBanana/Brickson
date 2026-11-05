import SwiftUI

/// One category, titled with its name: Add a Phrase, a row for each
/// phrase in Home's order, then Change Picture, Move Category, Delete
/// Category and Rename. Emergency keeps passive words in those four rows'
/// place, because it is always one step away on Home. Every control here
/// only opens something, and what a delete did shows in a line kept for it
/// at the top.
struct LibraryCategoryView: View {
    let categoryID: UUID
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library

    var body: some View {
        SettingsScreen(verbatimTitle: library.category(categoryID)?.name ?? "") {
            LibraryCategoryContent(categoryID: categoryID, path: $path)
        }
    }
}

private struct LibraryCategoryContent: View {
    let categoryID: UUID
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library

    var body: some View {
        let category = library.category(categoryID)
        LibraryResultLine(text: library.categoryResults[categoryID], alternatives: resultLines(category))

        if let category {
            NavigationLink(value: SettingsRoute.newPhrase(category: categoryID)) {
                SettingsRowLabel(title: "Add a Phrase", systemImage: "plus.bubble.fill")
            }
            .settingsRowStyle()
            .accessibilityIdentifier("libraryAddPhrase")

            ForEach(Array(category.phrases.enumerated()), id: \.element.id) { index, phrase in
                NavigationLink(value: SettingsRoute.phrase(phrase.id)) {
                    SettingsRowLabel(text: Text(verbatim: phrase.text), systemImage: "text.bubble.fill")
                }
                .settingsRowStyle()
                .accessibilityIdentifier("libraryPhrase\(index)")
            }

            if category.isEmergency {
                SettingsParagraph("Emergency is always one step away on Home, so it can't be renamed, moved or deleted. You can change its phrases.")
            } else {
                LibraryAskingRow(title: "Change Picture", systemImage: "photo.fill", route: .categoryPicture(categoryID), path: $path)
                    .accessibilityIdentifier("libraryChangePicture")
                LibraryAskingRow(title: "Move Category", systemImage: "arrow.up.arrow.down", route: .moveCategory(categoryID), path: $path)
                    .accessibilityIdentifier("libraryMoveCategory")
                LibraryAskingRow(title: "Delete Category", systemImage: "trash.fill", route: .deleteCategory(categoryID), path: $path)
                    .disabled(deleteRefusal != nil)
                    .accessibilityIdentifier("libraryDeleteCategory")
                // Last, so a look resting under the rows meets a screen
                // where nothing changes until words are typed
                // (docs/DECISIONS.md, "The Library's question screens").
                NavigationLink(value: SettingsRoute.categoryName(categoryID)) {
                    SettingsRowLabel(title: "Rename", systemImage: "pencil")
                }
                .settingsRowStyle()
                .accessibilityIdentifier("libraryRename")
                LibraryResultLine(text: deleteRefusal, alternatives: [deleteRefusal].compactMap { $0 }, identifier: "libraryDeleteReason")
            }
        } else {
            SettingsParagraph("This category isn't in your phrases any more.")
        }
    }

    /// Why Delete Category is dimmed (Home needs three everyday
    /// categories), or nil where it can ask.
    private var deleteRefusal: String? {
        library.refusal(of: .deleteCategory(categoryID))
    }

    /// What the line at the top can say: a phrase deleted, or the category
    /// just added.
    private func resultLines(_ category: LibrarySnapshot.Category?) -> [String] {
        let deleted = (category?.phrases ?? []).map { LibraryDeleteWords.deleted(phrase: $0.text) }
        let current = library.categoryResults[categoryID].map { [$0] } ?? []
        return deleted + current + LibraryMessages.anyChange
    }
}

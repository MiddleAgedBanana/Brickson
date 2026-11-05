import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Phrases and Categories: every category, Emergency first, a way to add
/// one, and the backups (docs/DECISIONS.md, "The Library in Settings").
///
/// Every control here only opens something: a category, the new
/// category's name, the system's share sheet or its file picker. What a
/// delete or a restore did shows in a line kept for it, so nothing moves
/// when it appears.
struct LibraryView: View {
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsScreen(title: "Phrases and Categories") {
            LibraryContent(path: $path)
        }
    }
}

private struct LibraryContent: View {
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isVolatileStore) private var isVolatileStore
    @Environment(\.phraseLibraryIssue) private var phraseLibraryIssue
    @Environment(\.restoresSampleBackup) private var restoresSampleBackup
    @Environment(\.settingsScrollPosition) private var scroll
    /// The file picker is open.
    @State private var isPicking = false
    /// A chosen file is being read, which can take a while for one in
    /// iCloud Drive that is not on the device yet.
    @State private var isReading = false
    /// Restore from a Backup as drawn, in this screen's content.
    @State private var restoreRow: CGRect?
    /// Where Restore from a Backup was on screen when it was chosen.
    @State private var askedFrom: CGRect?

    var body: some View {
        LibraryResultLine(text: library.libraryResult, alternatives: deletedLines)
            .onAppear {
                library.refresh(modelContext.container)
            }
        warnings

        ForEach(categoryRows, id: \.category.id) { row in
            NavigationLink(value: SettingsRoute.libraryCategory(row.category.id)) {
                SettingsRowLabel(text: Text(verbatim: row.category.name), systemImage: row.category.symbolName)
            }
            .settingsRowStyle()
            .accessibilityIdentifier(row.identifier)
        }

        NavigationLink(value: SettingsRoute.newCategory) {
            SettingsRowLabel(title: "Add a Category", systemImage: "plus.circle.fill")
        }
        .settingsRowStyle()
        .disabled(!canAddCategory)
        .accessibilityIdentifier("libraryAddCategory")
        SettingsReservedParagraph(
            text: Text(canAddCategory ? Self.room : Self.full),
            alternatives: [Text(Self.room), Text(Self.full)]
        )

        SettingsHeading("Backups")
        SettingsParagraph("A backup is a file with your categories and phrases. It isn't encrypted, so anyone who has it can read your phrases. Keep it somewhere private.")

        ShareLink(item: backupFile, preview: SharePreview(backupFile.fileName)) {
            SettingsRowLabel(title: "Export a Backup", systemImage: "square.and.arrow.up")
        }
        .settingsRowStyle()
        .disabled(exportRefusal != nil)
        .accessibilityIdentifier("libraryExport")
        LibraryResultLine(text: exportRefusal, alternatives: [exportRefusal].compactMap { $0 }, identifier: "libraryExportReason")

        Button {
            activity?.recordActivity()
            askedFrom = restoreRow.map { $0.offsetBy(dx: 0, dy: -(scroll?.offset ?? 0)) }
            if restoresSampleBackup, let starter = library.starter {
                open(.success(LaunchOptions.sampleBackup(from: starter)))
            } else {
                isPicking = true
            }
        } label: {
            SettingsRowLabel(title: "Restore from a Backup", systemImage: "arrow.down.doc.fill")
        }
        .settingsRowStyle()
        .disabled(isReading || library.snapshot == nil)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(SettingsMetrics.contentSpace)) } action: { restoreRow = $0 }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.json]) { picked in
            choose(picked)
        }
        .holdsSettingsIdleReset(isPicking || isReading)
        .accessibilityIdentifier("libraryRestore")
        LibraryResultLine(text: library.backupResult, alternatives: backupLines, identifier: "libraryBackupResult")
    }

    // MARK: The categories

    private struct CategoryRow {
        let category: LibrarySnapshot.Category
        let identifier: String
    }

    /// Emergency first, as Home sets it apart, then the everyday categories
    /// in Home's order.
    private var categoryRows: [CategoryRow] {
        let categories = library.snapshot?.categories ?? []
        let emergency = categories.filter(\.isEmergency).map { CategoryRow(category: $0, identifier: "libraryEmergency") }
        let everyday = categories.filter { !$0.isEmergency }.enumerated().map { index, category in
            CategoryRow(category: category, identifier: "libraryCategory\(index)")
        }
        return emergency + everyday
    }

    private var canAddCategory: Bool {
        guard let snapshot = library.snapshot else { return false }
        return snapshot.everydayCategoryCount < LibraryRules.mostEverydayCategories
    }

    private static let room: LocalizedStringKey = "Home has room for four categories besides Emergency."
    private static let full: LocalizedStringKey = "Home has room for four categories besides Emergency, so another can't be added. Rename one, or delete one first."

    /// What the line at the top can say after a category is deleted here.
    private var deletedLines: [String] {
        (library.snapshot?.categories ?? []).map { LibraryDeleteWords.deleted(category: $0.name) } + LibraryMessages.anyChange
    }

    /// The store's own warnings, in Home's words.
    @ViewBuilder
    private var warnings: some View {
        if isVolatileStore {
            SettingsParagraph(verbatim: String(localized: "Phrases can't be saved right now. Changes will be lost when the app closes."))
        }
        if let phraseLibraryIssue {
            SettingsParagraph(verbatim: phraseLibraryIssue.message)
        }
        if let failure = library.readFailure {
            SettingsParagraph(verbatim: failure)
        }
    }

    // MARK: Export

    /// The backup the share sheet offers, made only when the family
    /// chooses where it goes (`BackupFile`).
    private var backupFile: BackupFile {
        BackupFile(library: library.snapshot ?? LibrarySnapshot(categories: []), madeOn: .now)
    }

    /// Why Export is dimmed, or nil where it can run.
    private var exportRefusal: String? {
        guard let snapshot = library.snapshot else {
            return library.readFailure ?? LibraryEditError.libraryUnreadable.message
        }
        if phraseLibraryIssue == .libraryUnreadable {
            // The phrases showing are the starter ones, in memory: a backup
            // of them would not be the person's.
            return String(localized: "Your saved phrases couldn't be opened, so they can't be backed up now.")
        }
        do {
            _ = try BackupCodec.encode(snapshot)
            return nil
        } catch let error as BackupEncodeError {
            return error.message
        } catch {
            return String(localized: "A backup couldn't be made. Nothing was saved.")
        }
    }

    // MARK: Restore

    /// Every line Restore from a Backup can show while this screen is open.
    private var backupLines: [String] {
        [BackupDecodeError.tooLarge, .unreadable, .notABackup, .newerVersion, .damaged].map(\.message) + [
            String(localized: "Reading the backup…"),
            String(localized: "The file couldn't be opened. Nothing was changed."),
        ] + LibraryRestoreWords.results + LibraryMessages.anyChange
    }

    private func choose(_ picked: Result<URL, any Error>) {
        activity?.recordActivity()
        switch picked {
        case .success(let url):
            isReading = true
            library.backupResult = String(localized: "Reading the backup…")
            Task {
                let read = await BackupReading.read(url)
                isReading = false
                open(read)
            }
        case .failure:
            library.backupResult = String(localized: "The file couldn't be opened. Nothing was changed.")
        }
    }

    /// Opens the Restore question for a backup that was read, or says why
    /// it can't be restored. Nothing is changed here.
    private func open(_ read: Result<LibrarySnapshot, BackupDecodeError>) {
        activity?.recordActivity()
        // The family went elsewhere while the file was read.
        guard path.last == .library else {
            library.backupResult = nil
            return
        }
        switch read {
        case .success(let backup):
            library.refresh(modelContext.container)
            guard let current = library.snapshot else {
                library.backupResult = library.readFailure
                return
            }
            library.backupResult = nil
            library.restore = RestoreChoices(backup: backup, library: current, starter: library.starter)
            library.askedFrom = askedFrom
            path.append(.restoreBackup)
        case .failure(let error):
            library.backupResult = error.message
        }
    }
}

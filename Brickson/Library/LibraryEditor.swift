import Foundation
import OSLog
import SwiftData

/// Reads the stored library as a `LibrarySnapshot`, and writes a checked
/// `LibraryPlan` back in one save.
///
/// Every edit happens in a context of its own, made for that edit, with
/// autosave off (docs/DECISIONS.md, "Every save is explicit"). If the save
/// fails, that context is simply dropped: nothing reached the store, the
/// main context never held the change, and no `rollback()` is needed. A
/// rollback after a delete crashed SwiftData in the reference app
/// (docs/LESSONS.md, "Never roll back a cascade delete").
enum LibraryEditor {
    /// The library as stored now, read in a fresh context.
    static func read(_ container: ModelContainer) throws(LibraryEditError) -> LibrarySnapshot {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            return try StoredLibrary(context).snapshot
        } catch {
            logger.error("The phrase library could not be read: \(error)")
            throw .libraryUnreadable
        }
    }

    /// Writes `plan` to the store, or nothing at all.
    ///
    /// The plan is refused if the store no longer matches the library it
    /// was made from (another edit landed in between), and a replace that
    /// would remove the person's own words is refused. A safety-copy
    /// exception still requires the owner's decision before implementation.
    ///
    /// `save` exists so tests can make the save fail; the app never passes
    /// it.
    @discardableResult
    static func apply(
        _ plan: LibraryPlan,
        to container: ModelContainer,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws(LibraryEditError) -> LibrarySnapshot {
        guard !plan.needsSafetyCopy else { throw .safetyCopyRequired }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let stored: StoredLibrary
        do {
            stored = try StoredLibrary(context)
        } catch {
            logger.error("The phrase library could not be read for an edit: \(error)")
            throw .libraryUnreadable
        }
        guard stored.snapshot == plan.before else { throw .libraryChanged }
        guard !plan.changes.isEmpty else { return plan.after }
        stored.write(plan.after, in: context)
        do {
            try save(context)
        } catch {
            // The edit context goes out of scope here, taking the unsaved
            // change with it.
            logger.error("An edit to the phrase library could not be saved: \(error)")
            throw .saveFailed
        }
        return plan.after
    }

    private static let logger = Logger(subsystem: AppLog.subsystem, category: "library")
}

/// Why an edit that passed its checks was not written. Nothing was changed.
nonisolated enum LibraryEditError: Error, Equatable, Sendable {
    case libraryUnreadable
    /// The library changed after the plan was made.
    case libraryChanged
    /// A replace would remove the person's words. The proposed safety-copy
    /// exception is not adopted (docs/DECISIONS.md, "Replacing the library").
    case safetyCopyRequired
    case saveFailed

    var message: String {
        switch self {
        case .libraryUnreadable:
            String(localized: "Your phrases couldn't be read, so nothing was changed.")
        case .libraryChanged:
            String(localized: "Your phrases changed while this was open, so nothing was changed. Try again.")
        case .safetyCopyRequired:
            String(localized: "Replacing would remove phrases that aren't in the backup, so nothing was changed. Add the backup to your phrases instead.")
        case .saveFailed:
            String(localized: "Couldn't save, so nothing was changed. Try again.")
        }
    }
}

/// The stored categories and phrases in one context, by identity, with the
/// snapshot they make.
///
/// Phrases that belong to no category (a category deleted without its
/// phrases, which nothing in Brickson does) are not part of the library:
/// they are never shown, and never touched here, so no edit can delete
/// them.
struct StoredLibrary {
    let snapshot: LibrarySnapshot
    private let categories: [UUID: PhraseCategory]
    private let phrases: [UUID: Phrase]

    init(_ context: ModelContext) throws {
        // Fetching every phrase first means a phrase table that cannot be
        // read throws here, instead of failing later while Home draws.
        _ = try context.fetch(FetchDescriptor<Phrase>())
        let stored = PhraseCategory.orderedForDisplay(try context.fetch(FetchDescriptor<PhraseCategory>()))
        var categories: [UUID: PhraseCategory] = [:]
        var phrases: [UUID: Phrase] = [:]
        var snapshotCategories: [LibrarySnapshot.Category] = []
        for category in stored {
            let inOrder = category.phrasesInOrder
            categories[category.uuid] = categories[category.uuid] ?? category
            for phrase in inOrder {
                phrases[phrase.uuid] = phrases[phrase.uuid] ?? phrase
            }
            snapshotCategories.append(LibrarySnapshot.Category(
                id: category.uuid,
                name: category.name,
                symbolName: category.symbolName,
                isEmergency: category.isEmergency,
                phrases: inOrder.map { LibrarySnapshot.Phrase(id: $0.uuid, text: $0.text) }
            ))
        }
        snapshot = LibrarySnapshot(categories: snapshotCategories)
        self.categories = categories
        self.phrases = phrases
    }

    /// Changes the stored library into `target` inside `context`, without
    /// saving. Only values that differ are written. Sort orders become
    /// each item's place in `target`, so ties or gaps from an older store
    /// are settled by the first edit. A deleted category's phrases are
    /// deleted explicitly, because the relationship does not cascade
    /// (docs/DECISIONS.md, "Versioned storage").
    ///
    /// Callers check `snapshot.hasUniqueIDs` first, through the plan.
    func write(_ target: LibrarySnapshot, in context: ModelContext) {
        var categoryModels = categories
        for (categoryIndex, category) in target.categories.enumerated() {
            let model: PhraseCategory
            if let existing = categoryModels[category.id] {
                model = existing
                if !LibraryText.sameBytes(model.name, category.name) { model.name = category.name }
                if !LibraryText.sameBytes(model.symbolName, category.symbolName) { model.symbolName = category.symbolName }
                if model.isEmergency != category.isEmergency { model.isEmergency = category.isEmergency }
                if model.sortOrder != categoryIndex { model.sortOrder = categoryIndex }
            } else {
                model = PhraseCategory(
                    name: category.name,
                    symbolName: category.symbolName,
                    sortOrder: categoryIndex,
                    isEmergency: category.isEmergency,
                    uuid: category.id
                )
                context.insert(model)
                categoryModels[category.id] = model
            }
            for (phraseIndex, phrase) in category.phrases.enumerated() {
                if let existing = phrases[phrase.id] {
                    if !LibraryText.sameBytes(existing.text, phrase.text) { existing.text = phrase.text }
                    if existing.sortOrder != phraseIndex { existing.sortOrder = phraseIndex }
                    if existing.category?.uuid != category.id { existing.category = model }
                } else {
                    context.insert(Phrase(text: phrase.text, sortOrder: phraseIndex, category: model, uuid: phrase.id))
                }
            }
        }
        let keptPhrases = Set(target.categories.flatMap { $0.phrases.map(\.id) })
        for (id, phrase) in phrases where !keptPhrases.contains(id) {
            context.delete(phrase)
        }
        let keptCategories = Set(target.categories.map(\.id))
        for (id, category) in categories where !keptCategories.contains(id) {
            context.delete(category)
        }
    }
}

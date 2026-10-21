import Foundation

/// One change a family makes to the phrase library, as plain data.
///
/// `plan(in:starter:makeID:)` checks the change against the library and the
/// rules, and either refuses it with a reason or returns a `LibraryPlan`:
/// the library as it will be, what changes, and whether the family must be
/// asked first. Planning never touches the store; `LibraryEditor.apply`
/// writes a plan in one save, or nothing at all.
///
/// There is deliberately no case that sets or clears the emergency flag, so
/// no edit can create a second emergency category or remove the only one
/// (docs/DECISIONS.md, "The emergency category is always there").
nonisolated enum LibraryEdit: Equatable, Sendable {
    /// A new, empty category at the end of the list. Never an emergency one.
    case addCategory(name: String, symbolName: String)
    case renameCategory(UUID, name: String)
    case changeCategorySymbol(UUID, symbolName: String)
    /// Places the category just before another one, or at the end when
    /// `before` is nil. Placing it before itself, or where it already is,
    /// changes nothing, so a repeated activation is harmless.
    case moveCategory(UUID, before: UUID?)
    /// Deletes the category and every phrase in it, in one save.
    case deleteCategory(UUID)
    /// A new phrase at the end of a category.
    case addPhrase(text: String, category: UUID)
    case editPhrase(UUID, text: String)
    /// Places the phrase in `category`, just before another phrase there,
    /// or at the end when `before` is nil. As with categories, a repeat
    /// changes nothing.
    case movePhrase(UUID, category: UUID, before: UUID?)
    case deletePhrase(UUID)
    /// Adds what a backup has that the library lacks. Moves, renames and
    /// deletes nothing (`LibraryImport.merge`).
    case merge(LibrarySnapshot)
    /// Makes the library match a backup (`LibraryImport.replace`).
    case replace(LibrarySnapshot)

    nonisolated enum Kind: CaseIterable, Sendable {
        case addCategory, renameCategory, changeCategorySymbol, moveCategory, deleteCategory
        case addPhrase, editPhrase, movePhrase, deletePhrase
        case merge, replace
    }

    var kind: Kind {
        switch self {
        case .addCategory: .addCategory
        case .renameCategory: .renameCategory
        case .changeCategorySymbol: .changeCategorySymbol
        case .moveCategory: .moveCategory
        case .deleteCategory: .deleteCategory
        case .addPhrase: .addPhrase
        case .editPhrase: .editPhrase
        case .movePhrase: .movePhrase
        case .deletePhrase: .deletePhrase
        case .merge: .merge
        case .replace: .replace
        }
    }
}

nonisolated extension LibraryEdit.Kind {
    /// Deletes, merges and replaces ask the family first, with a question
    /// built in the app (invariant 3). Adding, renaming and moving do not:
    /// they lose no words.
    var asksFirst: Bool {
        switch self {
        case .deleteCategory, .deletePhrase, .merge, .replace: true
        case .addCategory, .renameCategory, .changeCategorySymbol, .moveCategory,
             .addPhrase, .editPhrase, .movePhrase: false
        }
    }
}

/// A checked edit, ready for `LibraryEditor.apply`.
nonisolated struct LibraryPlan: Equatable, Sendable {
    let kind: LibraryEdit.Kind
    /// The library the plan was made from. `LibraryEditor.apply` refuses
    /// the plan if the store no longer matches it.
    let before: LibrarySnapshot
    /// The library as it will be after the edit.
    let after: LibrarySnapshot
    let changes: LibraryChanges
    /// True when a replace would remove words the person wrote that the
    /// backup does not have. Such a replace is refused: letting it run
    /// after a safety copy would be an exception to invariant 7, which is
    /// the owner's to decide (docs/DECISIONS.md, "Replacing the library").
    let needsSafetyCopy: Bool
    /// What a merge or replace kept, skipped or renumbered; nil for other
    /// edits.
    let importReport: LibraryImportReport?

    var asksFirst: Bool { kind.asksFirst }
}

nonisolated extension LibraryEdit {
    /// Checks this edit against `library` and returns the plan, or throws
    /// the reason it cannot be made. Nothing is written.
    ///
    /// - Parameters:
    ///   - starter: the bundled starter library. A replace compares against
    ///     it to tell the person's own words from untouched starter phrases;
    ///     without it, every word counts as the person's.
    ///   - makeID: makes identities for new categories and phrases. Tests
    ///     pass a predictable one; the app uses random ones.
    func plan(
        in library: LibrarySnapshot,
        starter: LibrarySnapshot? = nil,
        makeID: () -> UUID = { UUID() }
    ) throws(LibraryEditRejection) -> LibraryPlan {
        guard library.hasUniqueIDs else { throw .libraryNeedsRepair }
        var after = library
        var importReport: LibraryImportReport?
        var needsSafetyCopy = false

        switch self {
        case let .addCategory(name, symbolName):
            let name = try LibraryRules.categoryName(name, isEmergency: false, in: library, excluding: nil)
            let symbolName = try LibraryRules.symbol(symbolName)
            var ids = LibraryIDs(library)
            after.categories.append(LibrarySnapshot.Category(
                id: ids.newCategoryID(makeID),
                name: name,
                symbolName: symbolName,
                isEmergency: false,
                phrases: []
            ))

        case let .renameCategory(id, name):
            guard let index = library.categoryIndex(of: id) else { throw .notFound }
            after.categories[index].name = try LibraryRules.categoryName(
                name,
                isEmergency: library.categories[index].isEmergency,
                in: library,
                excluding: id
            )

        case let .changeCategorySymbol(id, symbolName):
            guard let index = library.categoryIndex(of: id) else { throw .notFound }
            after.categories[index].symbolName = try LibraryRules.symbol(symbolName)

        case let .moveCategory(id, before: target):
            guard let index = library.categoryIndex(of: id) else { throw .notFound }
            if let target, library.categoryIndex(of: target) == nil { throw .notFound }
            guard target != id else { break }
            let category = after.categories.remove(at: index)
            let destination = target.flatMap(after.categoryIndex(of:)) ?? after.categories.endIndex
            after.categories.insert(category, at: destination)

        case let .deleteCategory(id):
            guard let index = library.categoryIndex(of: id) else { throw .notFound }
            guard !library.categories[index].isEmergency else { throw .emergencyCategoryCannotBeDeleted }
            after.categories.remove(at: index)

        case let .addPhrase(text, categoryID):
            guard let index = library.categoryIndex(of: categoryID) else { throw .notFound }
            let text = try LibraryRules.phraseText(text, in: library.categories[index], excluding: nil)
            var ids = LibraryIDs(library)
            after.categories[index].phrases.append(LibrarySnapshot.Phrase(id: ids.newPhraseID(makeID), text: text))

        case let .editPhrase(id, text):
            guard let location = library.location(ofPhrase: id) else { throw .notFound }
            after.categories[location.category].phrases[location.phrase].text = try LibraryRules.phraseText(
                text,
                in: library.categories[location.category],
                excluding: id
            )

        case let .movePhrase(id, categoryID, before: target):
            guard let source = library.location(ofPhrase: id),
                  let destinationCategory = library.categoryIndex(of: categoryID) else { throw .notFound }
            if let target {
                guard library.categories[destinationCategory].phrases.contains(where: { $0.id == target }) else {
                    throw .notFound
                }
            }
            guard target != id else { break }
            let phrase = library.categories[source.category].phrases[source.phrase]
            if destinationCategory != source.category {
                // Moving must not leave Emergency empty, nor put a second
                // copy of the same words in one category.
                if library.categories[source.category].isEmergency,
                   library.categories[source.category].phrases.count == 1 {
                    throw .emergencyCategoryNeedsAPhrase
                }
                _ = try LibraryRules.phraseText(phrase.text, in: library.categories[destinationCategory], excluding: id)
            }
            after.categories[source.category].phrases.remove(at: source.phrase)
            let phrases = after.categories[destinationCategory].phrases
            let destination = target.flatMap { target in phrases.firstIndex { $0.id == target } } ?? phrases.endIndex
            after.categories[destinationCategory].phrases.insert(phrase, at: destination)

        case let .deletePhrase(id):
            guard let location = library.location(ofPhrase: id) else { throw .notFound }
            let category = library.categories[location.category]
            if category.isEmergency, category.phrases.count == 1 {
                throw .emergencyCategoryNeedsAPhrase
            }
            after.categories[location.category].phrases.remove(at: location.phrase)

        case let .merge(incoming):
            let merged = LibraryImport.merge(incoming, into: library, makeID: makeID)
            after = merged.library
            importReport = merged.report

        case let .replace(incoming):
            let replaced = LibraryImport.replace(library, with: incoming, makeID: makeID)
            after = replaced.library
            importReport = replaced.report
            let ownWords = library.ownWords(comparedWith: starter)
            needsSafetyCopy = !ownWords.isEmpty && !after.contains(ownWords)
        }

        // Backstops for every kind of edit, including any added later: no
        // edit may stop Emergency from working or empty the library, and
        // identities stay unique. An empty store is refilled with the
        // starter phrases at the next launch, so emptying a library (one
        // damaged so it has no emergency category, say) would put words
        // the person never chose in place of theirs.
        if library.keepsEmergencyWorking && !after.keepsEmergencyWorking {
            throw .emergencyCategoryNeedsAPhrase
        }
        if !library.categories.isEmpty && after.categories.isEmpty {
            throw .libraryNeedsACategory
        }
        guard after.hasUniqueIDs else { throw .libraryNeedsRepair }

        return LibraryPlan(
            kind: kind,
            before: library,
            after: after,
            changes: LibraryChanges(from: library, to: after),
            needsSafetyCopy: needsSafetyCopy,
            importReport: importReport
        )
    }
}

/// The identities already in use, so new ones never collide.
nonisolated struct LibraryIDs {
    private(set) var categoryIDs: Set<UUID>
    private(set) var phraseIDs: Set<UUID>

    init(_ library: LibrarySnapshot) {
        categoryIDs = Set(library.categories.map(\.id))
        phraseIDs = Set(library.categories.flatMap { $0.phrases.map(\.id) })
    }

    /// `preferred` if no category uses it yet, otherwise a new one.
    mutating func categoryID(preferring preferred: UUID, _ makeID: () -> UUID) -> UUID {
        if categoryIDs.insert(preferred).inserted { return preferred }
        return newCategoryID(makeID)
    }

    mutating func newCategoryID(_ makeID: () -> UUID) -> UUID {
        var id = makeID()
        while !categoryIDs.insert(id).inserted { id = makeID() }
        return id
    }

    /// `preferred` if no phrase uses it yet, otherwise a new one.
    mutating func phraseID(preferring preferred: UUID, _ makeID: () -> UUID) -> UUID {
        if phraseIDs.insert(preferred).inserted { return preferred }
        return newPhraseID(makeID)
    }

    mutating func newPhraseID(_ makeID: () -> UUID) -> UUID {
        var id = makeID()
        while !phraseIDs.insert(id).inserted { id = makeID() }
        return id
    }
}

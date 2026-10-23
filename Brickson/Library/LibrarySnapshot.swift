import Foundation

/// The phrase library as plain values: categories in their on-screen order,
/// each holding its phrases in order. Array order is the order; there are no
/// sort-order numbers to tie or skip.
///
/// It knows nothing about SwiftData, so the rules for changing a library
/// (`LibraryEdit`) and the backup format (`BackupCodec`) are tested without
/// a store. `LibraryEditor` reads one from the store and writes one back.
///
/// Equality compares text byte for byte. Swift's `==` on `String` treats
/// canonically equivalent text as equal ("é" as one character, and "e" plus
/// a combining accent), which would let a change to the bytes of someone's
/// words go unnoticed (docs/DECISIONS.md, "Backup file format").
nonisolated struct LibrarySnapshot: Equatable, Sendable {
    nonisolated struct Category: Equatable, Sendable {
        /// The stored `uuid`: stable across edits, backups and restores.
        var id: UUID
        var name: String
        /// An SF Symbol name. Kept as written, even when it is not one the
        /// editor offers (a backup from a newer version, say).
        var symbolName: String
        var isEmergency: Bool
        var phrases: [Phrase]

        static func == (lhs: Category, rhs: Category) -> Bool {
            lhs.id == rhs.id
                && LibraryText.sameBytes(lhs.name, rhs.name)
                && LibraryText.sameBytes(lhs.symbolName, rhs.symbolName)
                && lhs.isEmergency == rhs.isEmergency
                && lhs.phrases == rhs.phrases
        }
    }

    nonisolated struct Phrase: Equatable, Sendable {
        var id: UUID
        var text: String

        static func == (lhs: Phrase, rhs: Phrase) -> Bool {
            lhs.id == rhs.id && LibraryText.sameBytes(lhs.text, rhs.text)
        }
    }

    var categories: [Category]

    static let empty = LibrarySnapshot(categories: [])
}

nonisolated extension LibrarySnapshot {
    var phraseCount: Int {
        categories.reduce(0) { $0 + $1.phrases.count }
    }

    func categoryIndex(of id: UUID) -> Int? {
        categories.firstIndex { $0.id == id }
    }

    /// Where a phrase sits: its category's index and its own index there.
    func location(ofPhrase id: UUID) -> (category: Int, phrase: Int)? {
        for (categoryIndex, category) in categories.enumerated() {
            if let phraseIndex = category.phrases.firstIndex(where: { $0.id == id }) {
                return (categoryIndex, phraseIndex)
            }
        }
        return nil
    }

    /// True when no two categories share an id and no two phrases do.
    /// Every edit is matched to the store by id, so a library that breaks
    /// this cannot be changed safely. Nothing Brickson writes breaks it.
    var hasUniqueIDs: Bool {
        let categoryIDs = categories.map(\.id)
        let phraseIDs = categories.flatMap { $0.phrases.map(\.id) }
        return Set(categoryIDs).count == categoryIDs.count
            && Set(phraseIDs).count == phraseIDs.count
    }

    /// The emergency rule (docs/DECISIONS.md, "The emergency category is
    /// always there"): exactly one emergency category, holding at least one
    /// phrase with words. Home's Emergency control opens the first emergency
    /// category it finds and hides the rest, so a second one is unreachable
    /// and one holding only imported blank text has nothing to say.
    var keepsEmergencyWorking: Bool {
        let emergencies = categories.filter(\.isEmergency)
        return emergencies.count == 1
            && emergencies[0].phrases.contains { !LibraryText.isBlank($0.text) }
    }

    /// The words in this library that the person wrote or changed: every
    /// category name and phrase text that is not a starter item with its
    /// starter text unchanged (matched by id and exact bytes). Without a
    /// starter library to compare against, everything counts as theirs.
    func ownWords(comparedWith starter: LibrarySnapshot?) -> LibraryWords {
        var starterNames: [UUID: [UInt8]] = [:]
        var starterTexts: [UUID: [UInt8]] = [:]
        for category in starter?.categories ?? [] {
            starterNames[category.id] = Array(category.name.utf8)
            for phrase in category.phrases {
                starterTexts[phrase.id] = Array(phrase.text.utf8)
            }
        }
        var words = LibraryWords()
        for category in categories {
            let name = Array(category.name.utf8)
            if starterNames[category.id] != name {
                words.names.insert(name)
            }
            for phrase in category.phrases {
                let text = Array(phrase.text.utf8)
                if starterTexts[phrase.id] != text {
                    words.texts.insert(text)
                }
            }
        }
        return words
    }

    /// True when every name and text in `words` is somewhere in this
    /// library, byte for byte.
    func contains(_ words: LibraryWords) -> Bool {
        let names = Set(categories.map { Array($0.name.utf8) })
        let texts = Set(categories.flatMap { $0.phrases.map { Array($0.text.utf8) } })
        return words.names.isSubset(of: names) && words.texts.isSubset(of: texts)
    }
}

/// Category names and phrase texts, as UTF-8 bytes.
nonisolated struct LibraryWords: Equatable, Sendable {
    var names: Set<[UInt8]> = []
    var texts: Set<[UInt8]> = []

    var isEmpty: Bool { names.isEmpty && texts.isEmpty }
}

/// What changing one library into another does, counted by id. Used for the
/// question a family is asked, and by tests ("a merge moves nothing that
/// was already there").
nonisolated struct LibraryChanges: Equatable, Sendable {
    var categoriesAdded = 0
    var categoriesRemoved = 0
    /// Categories whose name, symbol or emergency flag changed.
    var categoriesChanged = 0
    /// Categories that are in both and whose place in the list changed,
    /// including those that shift when an earlier one is removed.
    var categoriesMoved = 0
    var phrasesAdded = 0
    var phrasesRemoved = 0
    var phrasesChanged = 0
    /// Phrases that are in both and whose category or place changed,
    /// including those that shift up when an earlier one is removed (a
    /// position change someone who finds words by place will notice).
    var phrasesMoved = 0

    init(from before: LibrarySnapshot, to after: LibrarySnapshot) {
        let oldCategories = Dictionary(
            before.categories.enumerated().map { ($1.id, (index: $0, category: $1)) },
            uniquingKeysWith: { first, _ in first }
        )
        let newCategoryIDs = Set(after.categories.map(\.id))
        for (index, category) in after.categories.enumerated() {
            guard let old = oldCategories[category.id] else {
                categoriesAdded += 1
                continue
            }
            if !LibraryText.sameBytes(old.category.name, category.name)
                || !LibraryText.sameBytes(old.category.symbolName, category.symbolName)
                || old.category.isEmergency != category.isEmergency {
                categoriesChanged += 1
            }
            if old.index != index {
                categoriesMoved += 1
            }
        }
        categoriesRemoved = before.categories.count { !newCategoryIDs.contains($0.id) }

        var oldPhrases: [UUID: (category: UUID, index: Int, text: String)] = [:]
        for category in before.categories {
            for (index, phrase) in category.phrases.enumerated() where oldPhrases[phrase.id] == nil {
                oldPhrases[phrase.id] = (category.id, index, phrase.text)
            }
        }
        var newPhraseIDs: Set<UUID> = []
        for category in after.categories {
            for (index, phrase) in category.phrases.enumerated() {
                newPhraseIDs.insert(phrase.id)
                guard let old = oldPhrases[phrase.id] else {
                    phrasesAdded += 1
                    continue
                }
                if !LibraryText.sameBytes(old.text, phrase.text) {
                    phrasesChanged += 1
                }
                if old.category != category.id || old.index != index {
                    phrasesMoved += 1
                }
            }
        }
        phrasesRemoved = oldPhrases.keys.count { !newPhraseIDs.contains($0) }
    }

    var isEmpty: Bool {
        self == LibraryChanges(from: .empty, to: .empty)
    }
}

/// How the library's rules compare and clean text. Plain functions, so the
/// editor, the import and the tests agree.
nonisolated enum LibraryText {
    /// Byte-for-byte equality of the UTF-8 encoding.
    static func sameBytes(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.elementsEqual(rhs.utf8)
    }

    /// The text with whitespace and line breaks removed from both ends, and
    /// nothing else changed. Only the editor trims; import never does.
    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when every scalar is whitespace, a control code, or a
    /// default-ignorable scalar with no glyph of its own. This only checks
    /// the text: joiners and variation selectors in meaningful text stay
    /// intact, and import never removes or rewrites any scalar.
    static func isBlank(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar)
                || scalar.properties.generalCategory == .control
                || scalar.properties.isDefaultIgnorableCodePoint
        }
    }

    /// What two category names are compared by. Names that differ only in
    /// case, accents, width, spacing or punctuation read and sound the same,
    /// so Voice Control ("Tap Needs") could not tell their buttons apart.
    /// Symbols remain significant: different emoji are different names.
    /// Fixed Home control names have a separate, stricter reservation.
    static func nameKey(_ name: String) -> String {
        let folded = name.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: nil
        )
        var scalars = String.UnicodeScalarView()
        // Ignore standalone blank Characters, not every invisible scalar:
        // joiners and emoji tags inside a meaningful grapheme affect its
        // appearance and must still distinguish that name. Storage is intact.
        for character in folded where !isBlank(String(character)) {
            for scalar in character.unicodeScalars
            where !CharacterSet.punctuationCharacters.contains(scalar)
                && !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// What two phrases in one category are compared by: trimmed, and
    /// ignoring case and width. Punctuation counts, because "Okay." and
    /// "Okay?" are said differently.
    static func phraseKey(_ text: String) -> String {
        trimmed(text).folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
    }
}

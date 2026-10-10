import Foundation
import SwiftData

/// Version 1 of the stored phrase library: categories, each holding phrases.
///
/// The library is versioned from the very first release because every later
/// version has to migrate from whatever 1.0 ships. A change to a stored
/// property is never made in place: add `PhraseLibrarySchemaV2` with copies of
/// the models, add a stage to `PhraseLibraryMigrationPlan`, and keep this
/// version exactly as it is (docs/DECISIONS.md, "Versioned storage").
///
/// The shapes also follow SwiftData's iCloud rules (every stored property has
/// a default, relationships are optional, nothing is `.unique`), so turning on
/// sync later would not need a migration. Sync itself is not built
/// (docs/DECISIONS.md, "No iCloud sync in 1.0").
///
/// `nonisolated` keeps the schema's conformances usable from SwiftData's own
/// threads under the project's default main-actor isolation.
nonisolated enum PhraseLibrarySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [PhraseCategory.self, Phrase.self]
    }

    @Model
    final class PhraseCategory {
        /// Stable identity that survives backups, restores, and (later)
        /// Siri and Shortcuts, unlike the store's own identifier.
        var uuid: UUID = UUID()
        var name: String = ""
        /// An SF Symbol name shown beside the category's name.
        var symbolName: String = ""
        var sortOrder: Int = 0
        /// Emergency phrases always speak, even in edit mode (invariant 2).
        var isEmergency: Bool = false

        /// `.nullify`, not `.cascade`: in the reference app, rolling back a
        /// failed cascade delete crashed SwiftData (FamilyVoice D28). Code
        /// that deletes a category deletes its phrases explicitly in the
        /// same save (docs/LESSONS.md, "Never roll back a cascade delete").
        @Relationship(deleteRule: .nullify, inverse: \Phrase.category)
        var phrases: [Phrase]? = []

        init(
            name: String,
            symbolName: String,
            sortOrder: Int,
            isEmergency: Bool = false,
            uuid: UUID = UUID()
        ) {
            self.uuid = uuid
            self.name = name
            self.symbolName = symbolName
            self.sortOrder = sortOrder
            self.isEmergency = isEmergency
        }
    }

    @Model
    final class Phrase {
        var uuid: UUID = UUID()
        var text: String = ""
        var sortOrder: Int = 0
        var category: PhraseCategory?

        // A field is added only together with the feature that uses it (a
        // recording for message banking, for example), in a new schema
        // version (docs/LESSONS.md, "Add stored fields with their feature").

        init(
            text: String,
            sortOrder: Int,
            category: PhraseCategory? = nil,
            uuid: UUID = UUID()
        ) {
            self.uuid = uuid
            self.text = text
            self.sortOrder = sortOrder
            self.category = category
        }
    }
}

/// The current model versions. Code outside this folder uses these names, so
/// a new schema version only has to move the aliases.
typealias PhraseCategory = PhraseLibrarySchemaV1.PhraseCategory
typealias Phrase = PhraseLibrarySchemaV1.Phrase

/// How stores written by older versions move forward. Version 1 is the first,
/// so there is nothing to migrate yet.
nonisolated enum PhraseLibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PhraseLibrarySchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}

extension PhraseCategory {
    /// Total ordering for category buttons. A restored or hand-edited backup
    /// can contain tied sort orders, and Swift's sort is not stable, so ties
    /// fall back to the name and then the stable `uuid`. A control that moves
    /// between launches is a control someone reaches for and misses
    /// (invariant 8).
    static func orderedForDisplay(_ categories: [PhraseCategory]) -> [PhraseCategory] {
        categories.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.uuid.uuidString < rhs.uuid.uuidString
        }
    }

    /// This category's phrases in their fixed on-screen order, with the same
    /// tie-breaking as `orderedForDisplay`.
    var phrasesInOrder: [Phrase] {
        (phrases ?? []).sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            if lhs.text != rhs.text { return lhs.text < rhs.text }
            return lhs.uuid.uuidString < rhs.uuid.uuidString
        }
    }
}

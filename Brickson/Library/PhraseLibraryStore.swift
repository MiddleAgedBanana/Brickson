import Foundation
import OSLog
import SwiftData

/// Opens the on-device phrase library.
nonisolated enum PhraseLibraryStore {
    /// The library's schema, always the newest version.
    static var schema: Schema { Schema(versionedSchema: PhraseLibrarySchemaV1.self) }

    /// A container for the given configuration, with the migration plan that
    /// carries older stores forward.
    static func makeContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: PhraseLibraryMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// A throwaway in-memory library, for tests and as the fallback below.
    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        ))
    }

    /// The persistent library, or — if the store cannot be opened (a corrupt
    /// file, a full disk) — an in-memory one, so the app still launches and
    /// speaks. `isVolatile` tells Home to say plainly that changes will not
    /// be kept (invariant 5: no silent failures).
    static func openForApp() -> (container: ModelContainer, isVolatile: Bool) {
        let logger = Logger(subsystem: AppLog.subsystem, category: "library")
        // On a new install the Application Support folder does not exist
        // yet. SwiftData recovers by creating it, but only after logging a
        // page of alarming errors; creating it first avoids that.
        do {
            try FileManager.default.createDirectory(
                at: URL.applicationSupportDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Could not create Application Support: \(error)")
        }
        do {
            // `.none`: never sync, even if an iCloud capability is added for
            // something else later (docs/DECISIONS.md, "No iCloud sync in 1.0").
            let persistent = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return (try makeContainer(persistent), false)
        } catch {
            logger.error("Persistent phrase library failed to open, using memory: \(error)")
            do {
                return (try makeInMemoryContainer(), true)
            } catch {
                // Nothing can be shown without a container. This has never
                // been observed; it would mean SwiftData itself is unusable.
                fatalError("Unable to create any phrase library: \(error)")
            }
        }
    }
}

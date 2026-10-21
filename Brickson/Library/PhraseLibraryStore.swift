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

    /// Where the app keeps its library. `.none`: never sync, even if an
    /// iCloud capability is added for something else later
    /// (docs/DECISIONS.md, "No iCloud sync in 1.0").
    static var persistentConfiguration: ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
    }

    /// What `openForApp` found.
    struct Opened {
        let container: ModelContainer
        /// True when the library is in memory: nothing changed now is kept.
        let isVolatile: Bool
        /// Set when saved phrases exist but could not be opened.
        let issue: PhraseLibraryIssue?
    }

    /// The persistent library, or, if the store cannot be opened (a damaged
    /// file, a store from a newer version, a full disk on first launch), an
    /// in-memory one, so the app still launches and speaks. `isVolatile`
    /// tells Home to say plainly that changes will not be kept (invariant 5:
    /// no silent failures).
    ///
    /// When a store file exists but will not open, someone's phrases may be
    /// in it. The file is left exactly as it is, to be tried again at the
    /// next launch, and `issue` says so (docs/DECISIONS.md, "An unreadable
    /// library is reported, never replaced").
    ///
    /// `makeContainer`, `makeInMemory` and `storeExists` exist so tests can
    /// make each step fail; the app passes none of them.
    static func openForApp(
        makeContainer: (ModelConfiguration) throws -> ModelContainer = { try PhraseLibraryStore.makeContainer($0) },
        makeInMemory: () throws -> ModelContainer = { try PhraseLibraryStore.makeInMemoryContainer() },
        storeExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    ) -> Opened {
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
        let configuration = persistentConfiguration
        // Asked before opening: a failed open might leave a file behind.
        let hadSavedPhrases = storeExists(configuration.url)
        do {
            return Opened(container: try makeContainer(configuration), isVolatile: false, issue: nil)
        } catch {
            logger.error("Persistent phrase library failed to open, using memory: \(error)")
            do {
                return Opened(
                    container: try makeInMemory(),
                    isVolatile: true,
                    issue: hadSavedPhrases ? .libraryUnreadable : nil
                )
            } catch {
                // Nothing can be shown without a container. This has never
                // been observed; it would mean SwiftData itself is unusable.
                fatalError("Unable to create any phrase library: \(error)")
            }
        }
    }
}

import Foundation

/// The backup file: a phrase library as JSON (docs/DECISIONS.md, "Backup
/// file format").
///
/// ```json
/// {
///   "categories" : [
///     {
///       "isEmergency" : false,
///       "name" : "Basics",
///       "phrases" : [
///         { "text" : "Hello.", "uuid" : "…" }
///       ],
///       "symbolName" : "bubble.left.and.bubble.right.fill",
///       "uuid" : "…"
///     }
///   ],
///   "format" : "brickson.library",
///   "formatVersion" : 1
/// }
/// ```
///
/// - `format` and the meaning of each `formatVersion` are permanent once a
///   backup exists anywhere. `format` is an internal name, never shown, so
///   it stays the same if the app is renamed.
/// - Array order is the order. There are no sort-order numbers.
/// - Categories and phrases only: no settings, no draft message, no device
///   name, no date (the privacy policy says a backup holds "your categories
///   and phrases"). The date belongs in the file name.
/// - Encoding is deterministic: the same library always gives the same
///   bytes. Words are never trimmed, normalized or reordered, so a library
///   exported, imported and exported again gives identical bytes.
///
/// The bundled starter phrases are a file in this format, read by the
/// same decoder.
nonisolated enum BackupCodec {
    static let format = "brickson.library"
    static let formatVersion = 1
    /// Far more than any phrase library needs, and small enough that
    /// choosing the wrong file cannot exhaust memory.
    static let maximumByteCount = 8 * 1024 * 1024

    static func encode(_ library: LibrarySnapshot) throws -> Data {
        let document = Document(
            format: format,
            formatVersion: formatVersion,
            categories: library.categories.map { category in
                Document.Category(
                    uuid: category.id,
                    name: category.name,
                    symbolName: category.symbolName,
                    isEmergency: category.isEmergency,
                    phrases: category.phrases.map { Document.Phrase(uuid: $0.id, text: $0.text) }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        // A file `decode` would refuse is never written: it would look like
        // a backup and fail only when it was needed.
        guard data.count <= maximumByteCount else { throw BackupEncodeError.tooLarge }
        return data
    }

    /// Reads a backup, or says why it cannot. Reading never touches the
    /// store; only a confirmed import does.
    static func decode(_ data: Data) throws(BackupDecodeError) -> LibrarySnapshot {
        guard data.count <= maximumByteCount else { throw .tooLarge }
        let decoder = JSONDecoder()
        // The format and version are read first, so a newer backup is
        // recognised as newer rather than reported as damaged.
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch DecodingError.dataCorrupted {
            throw .unreadable
        } catch {
            throw .notABackup
        }
        guard header.format == format else { throw .notABackup }
        guard let version = header.formatVersion else { throw .damaged }
        guard version <= formatVersion else { throw .newerVersion }
        guard version >= 1 else { throw .damaged }

        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch {
            throw .damaged
        }
        return LibrarySnapshot(categories: document.categories.map { category in
            LibrarySnapshot.Category(
                id: category.uuid,
                name: category.name,
                symbolName: category.symbolName,
                isEmergency: category.isEmergency,
                phrases: category.phrases.map { LibrarySnapshot.Phrase(id: $0.uuid, text: $0.text) }
            )
        })
    }

    /// Just enough to tell what kind of file this is. Only a file that is
    /// not a JSON object fails here; a missing or mistyped field reads as
    /// nil, so the checks above can say which it was.
    private struct Header: Decodable {
        let format: String?
        let formatVersion: Int?

        private enum CodingKeys: String, CodingKey {
            case format, formatVersion
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            format = try? container.decode(String.self, forKey: .format)
            formatVersion = try? container.decode(Int.self, forKey: .formatVersion)
        }
    }

    /// The file's shape. Field names are permanent: never rename them.
    private struct Document: Codable {
        let format: String
        let formatVersion: Int
        let categories: [Category]

        struct Category: Codable {
            let uuid: UUID
            let name: String
            let symbolName: String
            let isEmergency: Bool
            let phrases: [Phrase]
        }

        struct Phrase: Codable {
            let uuid: UUID
            let text: String
        }
    }
}

/// Why a file could not be read as a backup. Nothing was changed.
nonisolated enum BackupDecodeError: Error, Equatable, Sendable {
    case tooLarge
    /// Not JSON at all, or cut short.
    case unreadable
    /// JSON, but not a phrase backup.
    case notABackup
    /// A backup from a newer version of the app, which this one cannot
    /// read without guessing.
    case newerVersion
    /// A phrase backup with something missing or of the wrong kind.
    case damaged

    var message: String {
        switch self {
        case .tooLarge:
            String(localized: "This file is too large to be a phrase backup. Nothing was changed.")
        case .unreadable:
            String(localized: "This file couldn't be read. It may be damaged or not a phrase backup. Nothing was changed.")
        case .notABackup:
            String(localized: "This file isn't a phrase backup. Nothing was changed.")
        case .newerVersion:
            String(localized: "This backup was made by a newer version of the app. Update the app, then try again. Nothing was changed.")
        case .damaged:
            String(localized: "This backup is damaged and couldn't be read. Nothing was changed.")
        }
    }
}

/// Why a backup could not be written. Nothing was written.
nonisolated enum BackupEncodeError: Error, Equatable, Sendable {
    /// The library is larger than a backup may be (`maximumByteCount`).
    case tooLarge

    var message: String {
        switch self {
        case .tooLarge:
            String(localized: "This library is too large to fit in one backup. Nothing was saved.")
        }
    }
}

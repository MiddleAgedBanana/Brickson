import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// One backup of the library, as the system share sheet offers it: the
/// bytes `BackupCodec` writes, as a JSON file named with the day it was
/// made (docs/DECISIONS.md, "Backup file format": a date belongs in the
/// file name, never in the file).
///
/// The bytes are made only when the family chooses where the file goes,
/// and handed straight to the system. Nothing is written to Brickson's own
/// storage, so no copy is left behind (docs/DECISIONS.md, "Exporting and
/// restoring a backup").
nonisolated struct BackupFile: Transferable, Equatable, Sendable {
    let library: LibrarySnapshot
    /// "Brickson Phrases 2026-11-05.json", with the app's name as people
    /// see it (`AppName`).
    let fileName: String

    /// - Parameters:
    ///   - date: the day the backup is made, in `calendar`'s time zone.
    init(library: LibrarySnapshot, madeOn date: Date, calendar: Calendar = .current) {
        self.library = library
        fileName = Self.fileName(madeOn: date, calendar: calendar)
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            try bytes(of: file)
        }
        .suggestedFileName { $0.fileName }
    }

    /// The file's bytes. The share sheet may ask for them from any thread,
    /// so this and the closure that calls it are nonisolated
    /// (`OffMainThreadCallbackTests`).
    static func bytes(of file: BackupFile) throws -> Data {
        try BackupCodec.encode(file.library)
    }

    /// The day as year, month and day, which sorts by date in any
    /// language, in the Gregorian calendar whatever the person's own.
    static func fileName(madeOn date: Date, calendar: Calendar) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let day = gregorian.dateComponents([.year, .month, .day], from: date)
        let stamp = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        return String(localized: "\(AppName.display) Phrases \(stamp)") + ".json"
    }
}

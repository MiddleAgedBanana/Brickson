import Foundation

/// A backup the family chose in the system's file picker, read and decoded
/// without touching the library (docs/DECISIONS.md, "Exporting and
/// restoring a backup").
///
/// The file picker hands over an address the app may read only while it
/// says so (a security-scoped address), and a file in iCloud Drive may not
/// be on the device yet, so the read goes through a file coordinator,
/// which waits for it. That can take a while, so it runs away from the
/// main thread (`read(_:)`). Nothing is copied into Brickson's storage.
nonisolated enum BackupReading {
    /// Reads and decodes the file at `url` on the concurrent pool, so the
    /// screen stays live while a file downloads. `@concurrent`, because the
    /// project's approachable concurrency would otherwise run this on its
    /// caller's actor, the main one.
    @concurrent
    static func read(_ url: URL) async -> Result<LibrarySnapshot, BackupDecodeError> {
        readNow(url)
    }

    /// The same read, on the calling thread.
    static func readNow(_ url: URL) -> Result<LibrarySnapshot, BackupDecodeError> {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }
        var coordinationError: NSError?
        var bytes: Data?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordinationError) { readable in
            // Mapped where it is safe, so a very large file is refused by
            // its size without being read into memory.
            bytes = try? Data(contentsOf: readable, options: [.mappedIfSafe])
        }
        guard coordinationError == nil, let bytes else { return .failure(.unreadable) }
        do {
            return .success(try BackupCodec.decode(bytes))
        } catch {
            return .failure(error)
        }
    }
}

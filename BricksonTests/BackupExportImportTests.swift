import CoreTransferable
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Brickson

/// Exporting a backup through the share sheet (`BackupFile`). Each test
/// names the change that would make it fail.
struct BackupFileTests {
    private typealias F = LibraryFixtures

    /// Fails if the date leaves the name, follows the person's calendar
    /// rather than the Gregorian one, ignores the time zone, or loses the
    /// extension. 2026-11-05 at 03:30 UTC is still 4 November in New York.
    @Test func theFileIsNamedWithTheDayItWasMade() throws {
        var calendar = Calendar(identifier: .buddhist)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let date = Date(timeIntervalSince1970: 1_793_849_400)
        let name = BackupFile(library: F.library, madeOn: date, calendar: calendar).fileName
        #expect(name.hasPrefix(AppName.display))
        #expect(name.hasSuffix(" 2026-11-04.json"))
    }

    /// The share sheet may ask for the file from any thread. Fails if the
    /// representation's closure becomes main-actor isolated, which traps
    /// there, or if the file holds anything but the codec's bytes.
    @Test func theFileCanBeMadeOnABackgroundThread() async throws {
        let file = BackupFile(library: F.library, madeOn: .now)
        let bytes = try await Task.detached { try await file.exported(as: .json) }.value
        #expect(bytes == (try BackupCodec.encode(F.library)))
    }
}

/// Reading a backup the family chose (`BackupReading`), with nothing
/// changed in the library.
struct BackupReadingTests {
    private typealias F = LibraryFixtures

    private func file(_ bytes: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "backup-\(UUID().uuidString).json")
        try bytes.write(to: url)
        return url
    }

    /// Fails if a readable backup is not read whole, or reading it waits
    /// on the main thread's caller.
    @Test func aBackupIsReadAsItWasWritten() async throws {
        let url = try file(BackupCodec.encode(F.library))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(BackupReading.readNow(url) == .success(F.library))
        #expect(await BackupReading.read(url) == .success(F.library))
    }

    /// Fails if a file that is not a backup, a missing file or one too
    /// large is not refused with the codec's own reason.
    @Test func whatIsNotABackupIsRefused() throws {
        let notJSON = try file(Data("Hello.".utf8))
        let tooLarge = try file(Data(count: BackupCodec.maximumByteCount + 1))
        let missing = FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: notJSON)
            try? FileManager.default.removeItem(at: tooLarge)
        }
        #expect(BackupReading.readNow(notJSON) == .failure(.unreadable))
        #expect(BackupReading.readNow(tooLarge) == .failure(.tooLarge))
        #expect(BackupReading.readNow(missing) == .failure(.unreadable))
    }
}

/// What the Restore question offers for a backup (`RestoreChoices`).
struct RestoreChoicesTests {
    private typealias F = LibraryFixtures

    private func choices(_ backup: LibrarySnapshot, starter: LibrarySnapshot? = nil) -> RestoreChoices {
        RestoreChoices(backup: backup, library: F.library, starter: starter, makeID: SequentialIDs().make)
    }

    private static let family = LibrarySnapshot.Category(
        id: F.id(400), name: "Family", symbolName: "person.2.fill", isEmergency: false,
        phrases: [.init(id: F.id(401), text: "Where is everyone?")]
    )

    /// Fails if Add stops adding what the backup brings, or Replace may
    /// remove words the person wrote (here every word counts as theirs).
    @Test func addAddsAndReplaceKeepsThePersonsWords() throws {
        let backup = LibrarySnapshot(categories: [F.emergency, Self.family])
        let choices = choices(backup)
        let add = try choices.add.get()
        #expect(add.changes.categoriesAdded == 1)
        #expect(add.after.categories.count == 4)
        #expect(choices.replace == .failure(.wouldRemoveOwnWords))
    }

    /// Fails if Replace is refused where it removes only untouched
    /// starter words.
    @Test func replaceRunsWhenItRemovesOnlyStarterWords() throws {
        let backup = LibrarySnapshot(categories: [F.emergency, F.needs, Self.family])
        let replace = try choices(backup, starter: F.library).replace.get()
        #expect(replace.after.categories.map(\.name) == ["Emergency", "Needs", "Family"])
    }

    /// Fails if a choice that would change nothing is offered as if it did.
    @Test func aBackupOfThisLibraryOffersNothing() {
        let choices = choices(F.library)
        #expect(choices.add == .failure(.nothingToAdd))
        #expect(choices.replace == .failure(.alreadyTheSame))
    }

    /// Fails if a backup can bring a category whose name Home's narrowest
    /// category button cannot hold, or one Home has no room for.
    @Test func aBackupHomeCannotShowIsRefusedWhole() {
        var wide = Self.family
        wide.name = "Entertainment"
        let tooWide = choices(LibrarySnapshot(categories: [F.emergency, wide]), starter: F.library)
        #expect(tooWide.add == .failure(.nameTooWide("Entertainment")))
        #expect(tooWide.replace == .failure(.nameTooWide("Entertainment")))

        let extra = (5...7).map { number in
            LibrarySnapshot.Category(
                id: F.id(number * 100), name: "Extra \(number)", symbolName: "star.fill", isEmergency: false,
                phrases: [.init(id: F.id(number * 100 + 1), text: "Phrase \(number).")]
            )
        }
        let fifth = choices(LibrarySnapshot(categories: [F.emergency] + extra))
        #expect(fifth.add == .failure(.rejected(.homeHasRoomForFour)))
    }

    /// Every refusal has words of its own. Fails if one is empty or two
    /// read the same.
    @Test func everyRefusalHasItsOwnWords() {
        let refusals: [RestoreChoices.Refusal] = [
            .rejected(.homeNeedsThree), .wouldRemoveOwnWords, .nameTooWide("Entertainment"), .nothingToAdd, .alreadyTheSame,
        ]
        for refusal in refusals {
            #expect(!refusal.message.isEmpty)
        }
        #expect(Set(refusals.map(\.message)).count == refusals.count)
    }
}

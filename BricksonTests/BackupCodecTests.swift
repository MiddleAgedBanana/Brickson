import Foundation
import Testing
@testable import Brickson

/// The backup file format. Words must come back byte for byte, and a file
/// that is not a readable backup is refused with a reason, never guessed at.
struct BackupCodecTests {
    private typealias F = LibraryFixtures

    /// Text that a careless codec or store would change. Each entry names
    /// what it guards.
    static let hardWords: [String] = [
        "Caf\u{E9}",                    // é as one scalar (NFC)
        "Cafe\u{301}",                  // e plus a combining accent (NFD)
        "👋🏽 👨‍👩‍👧",                         // skin tone and a joined family
        "שלום, מה שלומך?",              // right to left
        "line one\nline two\ttab",
        "before\u{2028}after",           // line separator
        "It’s “quoted” and it's \"quoted\"",
        "  leading and trailing spaces  ",
        "slash / backslash \\ and <html>",
        String(repeating: "A long phrase that keeps going. ", count: 300),
    ]

    static var hardLibrary: LibrarySnapshot {
        LibrarySnapshot(categories: [
            .init(id: F.id(100), name: "Caf\u{E9}", symbolName: "cup.and.saucer.fill", isEmergency: false, phrases:
                hardWords.enumerated().map { .init(id: F.id(101 + $0.offset), text: $0.element) }),
            // A name the editor's symbol list does not have, kept as written.
            .init(id: F.id(300), name: "Cafe\u{301} menu", symbolName: "no.such.symbol", isEmergency: false, phrases: []),
            F.emergency,
        ])
    }

    private func bytes(_ library: LibrarySnapshot) -> [[UInt8]] {
        library.categories.flatMap { category in
            [Array(category.name.utf8), Array(category.symbolName.utf8)] + category.phrases.map { Array($0.text.utf8) }
        }
    }

    // MARK: Round trips

    /// Fails if encoding depends on anything but the library (unsorted
    /// keys, a timestamp).
    @Test func theSameLibraryAlwaysGivesTheSameBytes() throws {
        #expect(try BackupCodec.encode(Self.hardLibrary) == BackupCodec.encode(Self.hardLibrary))
    }

    /// Fails if the codec trims, normalizes or reorders anything.
    @Test func wordsSurviveByteForByte() throws {
        let encoded = try BackupCodec.encode(Self.hardLibrary)
        let decoded = try BackupCodec.decode(encoded)

        #expect(decoded == Self.hardLibrary)
        #expect(bytes(decoded) == bytes(Self.hardLibrary))
        #expect(try BackupCodec.encode(decoded) == encoded)
    }

    /// Swift's `==` calls these equal; the person's file must not.
    @Test func composedAndDecomposedAccentsStayDistinct() throws {
        let decoded = try BackupCodec.decode(BackupCodec.encode(Self.hardLibrary))
        let phrases = decoded.categories[0].phrases
        #expect(Array(phrases[0].text.utf8) == [0x43, 0x61, 0x66, 0xC3, 0xA9])
        #expect(Array(phrases[1].text.utf8) == [0x43, 0x61, 0x66, 0x65, 0xCC, 0x81])
        #expect(phrases[0].text == phrases[1].text, "Swift's == treats them as equal")
        #expect(LibrarySnapshot.Phrase(id: F.id(101), text: phrases[1].text) != phrases[0])
    }

    @Test func anEmptyLibraryRoundTrips() throws {
        #expect(try BackupCodec.decode(BackupCodec.encode(.empty)) == .empty)
    }

    // MARK: The format

    /// The field names and the header are permanent. Fails if one is
    /// renamed or a field is added, which old backups and old versions of
    /// the app would not understand.
    @Test func theFileHasExactlyTheDocumentedFields() throws {
        let data = try BackupCodec.encode(F.library)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["format", "formatVersion", "categories"])
        #expect(object["format"] as? String == "brickson.library")
        #expect(object["formatVersion"] as? Int == 1)
        let categories = try #require(object["categories"] as? [[String: Any]])
        #expect(Set(categories[0].keys) == ["uuid", "name", "symbolName", "isEmergency", "phrases"])
        let phrases = try #require(categories[0]["phrases"] as? [[String: Any]])
        #expect(Set(phrases[0].keys) == ["uuid", "text"])
        #expect(phrases.map { $0["text"] as? String } == ["Hello.", "Thank you.", "Goodbye."])
    }

    /// A file written by hand, with its own spacing and key order, reads
    /// the same.
    @Test func aHandWrittenFileReads() throws {
        let json = """
        {"formatVersion": 1, "format": "brickson.library", "categories": [
          {"name": "Emergency", "uuid": "00000000-0000-4000-8000-000000000200",
           "isEmergency": true, "symbolName": "exclamationmark.triangle.fill",
           "phrases": [{"text": "I need help now.", "uuid": "00000000-0000-4000-8000-000000000201"},
                       {"uuid": "00000000-0000-4000-8000-000000000202", "text": "Please come here."}]}
        ]}
        """
        let library = try BackupCodec.decode(Data(json.utf8))
        #expect(library == LibrarySnapshot(categories: [F.emergency]))
    }

    // MARK: Files that are refused

    private func refusal(_ json: String) -> BackupDecodeError? {
        refusal(Data(json.utf8))
    }

    private func refusal(_ data: Data) -> BackupDecodeError? {
        do throws(BackupDecodeError) {
            _ = try BackupCodec.decode(data)
            return nil
        } catch {
            return error
        }
    }

    private static let validCategory = """
    {"uuid": "00000000-0000-4000-8000-000000000100", "name": "Basics", "symbolName": "star.fill", "isEmergency": false, "phrases": []}
    """

    @Test func aFileTooLargeIsRefusedBeforeReading() {
        let data = Data(repeating: UInt8(ascii: " "), count: BackupCodec.maximumByteCount + 1)
        #expect(refusal(data) == .tooLarge)
    }

    /// Fails if export can write a file that import would refuse as too
    /// large.
    @Test func aLibraryTooLargeToReadBackIsNotWritten() {
        let library = LibrarySnapshot(categories: [
            .init(id: F.id(100), name: "Long", symbolName: "star.fill", isEmergency: false, phrases: [
                .init(id: F.id(101), text: String(repeating: "a", count: BackupCodec.maximumByteCount)),
            ]),
        ])
        #expect(throws: BackupEncodeError.tooLarge) { try BackupCodec.encode(library) }
    }

    @Test func somethingThatIsNotJSONIsUnreadable() throws {
        let valid = try BackupCodec.encode(F.library)
        #expect(refusal(Data()) == .unreadable)
        #expect(refusal("Hello.") == .unreadable)
        // Cut short, as an interrupted copy would be.
        #expect(refusal(valid.prefix(valid.count / 2)) == .unreadable)
    }

    @Test func jsonThatIsNotABackupIsSaidToBeSo() {
        #expect(refusal("[]") == .notABackup)
        #expect(refusal("42") == .notABackup)
        #expect(refusal("{}") == .notABackup)
        #expect(refusal(#"{"format": "something.else", "formatVersion": 1, "categories": []}"#) == .notABackup)
        #expect(refusal(#"{"format": 7, "formatVersion": 1, "categories": []}"#) == .notABackup)
    }

    /// Fails if a newer file is read on a best guess.
    @Test func aBackupFromANewerVersionIsNotGuessedAt() {
        #expect(refusal(#"{"format": "brickson.library", "formatVersion": 2, "categories": []}"#) == .newerVersion)
        #expect(refusal(#"{"format": "brickson.library", "formatVersion": 2, "pages": {}}"#) == .newerVersion)
    }

    @Test(arguments: [
        #"{"format": "brickson.library", "categories": []}"#,
        #"{"format": "brickson.library", "formatVersion": 0, "categories": []}"#,
        #"{"format": "brickson.library", "formatVersion": "1", "categories": []}"#,
        #"{"format": "brickson.library", "formatVersion": 1.5, "categories": []}"#,
        #"{"format": "brickson.library", "formatVersion": 1}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": {}}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": [{"name": "No identity", "symbolName": "star.fill", "isEmergency": false, "phrases": []}]}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": [{"uuid": "not-a-uuid", "name": "Basics", "symbolName": "star.fill", "isEmergency": false, "phrases": []}]}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": [{"uuid": "00000000-0000-4000-8000-000000000100", "name": "Basics", "symbolName": "star.fill", "phrases": []}]}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": [{"uuid": "00000000-0000-4000-8000-000000000100", "name": "Basics", "symbolName": "star.fill", "isEmergency": 0, "phrases": []}]}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": [{"uuid": "00000000-0000-4000-8000-000000000100", "name": 5, "symbolName": "star.fill", "isEmergency": false, "phrases": []}]}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": [{"uuid": "00000000-0000-4000-8000-000000000100", "name": "Basics", "symbolName": "star.fill", "isEmergency": false, "phrases": [{"text": "No identity."}]}]}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": [{"uuid": "00000000-0000-4000-8000-000000000100", "name": "Basics", "symbolName": "star.fill", "isEmergency": false, "phrases": [{"uuid": "00000000-0000-4000-8000-000000000101"}]}]}"#,
        #"{"format": "brickson.library", "formatVersion": 1, "categories": [{"uuid": "00000000-0000-4000-8000-000000000100", "name": "Basics", "symbolName": "star.fill", "isEmergency": false, "phrases": [{"uuid": "00000000-0000-4000-8000-000000000101", "text": null}]}]}"#,
    ])
    func aDamagedBackupIsSaidToBeDamaged(json: String) {
        #expect(refusal(json) == .damaged)
    }

    /// Every refusal has a sentence for the family, and none of them claims
    /// something was changed.
    @Test func everyRefusalExplainsItself() {
        let all: [BackupDecodeError] = [.tooLarge, .unreadable, .notABackup, .newerVersion, .damaged]
        for error in all {
            #expect(error.message.hasSuffix("Nothing was changed."), "\(error)")
        }
    }
}

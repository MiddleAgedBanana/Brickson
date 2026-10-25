import Foundation
import Testing
@testable import Brickson

/// Keeping the typed message across launches (`DraftStore`, `DraftFile`).
/// Every save path has a test that makes the save fail (invariant 5). Each
/// test's comment names the change that would make it fail.
struct DraftStoreTests {
    private struct SaveFailed: Error {}
    private struct LoadFailed: Error {}

    /// Records what was saved, and fails while `failing` is set.
    private final class FakeStorage {
        var saved: [String] = []
        var failing = false

        func save(_ text: String) throws {
            if failing { throw SaveFailed() }
            saved.append(text)
        }
    }

    private func store(restoring draft: String = "", storage: FakeStorage) -> DraftStore {
        DraftStore(load: { draft }, save: storage.save)
    }

    /// A folder of its own under the temporary directory, removed afterwards
    /// by the caller.
    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "DraftStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    // MARK: Restoring

    /// Fails if the draft saved before the app closed isn't on screen after
    /// relaunch (the privacy policy's promise).
    @Test func theSavedDraftComesBackAtLaunch() {
        let storage = FakeStorage()
        let draft = store(restoring: "Please bring my glasses", storage: storage)

        #expect(draft.text == "Please bring my glasses")
        #expect(draft.issue == nil)
        #expect(storage.saved.isEmpty, "restoring must not write")
    }

    /// Fails if restoring a draft can speak: a line break restored from an
    /// old file must not become Return.
    @Test func restoringNeverSpeaks() {
        let draft = store(restoring: "Hello\n", storage: FakeStorage())

        #expect(draft.text == "Hello ")
        #expect(draft.perform(.propose("Hello ")) == .unchanged)
    }

    /// Fails if a draft that can't be read stops the app, shows nothing, or
    /// leaves anything but an empty draft to type in.
    @Test func anUnreadableDraftStartsEmptyAndSaysSo() {
        let draft = DraftStore(load: { throw LoadFailed() }, save: FakeStorage().save)

        #expect(draft.text == "")
        #expect(draft.issue == .notRestored)
    }

    /// Fails if the "not restored" notice stays after the person's new
    /// message is saved, or goes before anything is saved.
    @Test func theNotRestoredNoticeLastsUntilTheNextSave() {
        let storage = FakeStorage()
        let draft = DraftStore(load: { throw LoadFailed() }, save: storage.save)

        draft.perform(.speak)
        #expect(draft.issue == .notRestored, "nothing was saved yet")
        draft.perform(.propose("New"))
        #expect(draft.issue == nil)
        #expect(storage.saved == ["New"])
    }

    // MARK: Saving

    /// Fails if a change is not saved at once: the draft must survive the
    /// app being closed at any moment.
    @Test func everyChangeIsSaved() {
        let storage = FakeStorage()
        let draft = store(storage: storage)

        draft.perform(.propose("I"))
        draft.perform(.propose("I need"))
        draft.perform(.insert(" help"))
        draft.perform(.deleteBackward)

        #expect(storage.saved == ["I", "I need", "I need help", "I need hel"])
    }

    /// Fails if an edit that changes nothing writes to disk.
    @Test func editsThatChangeNothingAreNotSaved() {
        let storage = FakeStorage()
        let draft = store(restoring: "Yes", storage: storage)

        draft.perform(.speak)
        draft.perform(.propose("Yes"))
        draft.perform(.restoreCleared)

        #expect(storage.saved.isEmpty)
    }

    /// Fails if Return saves a line break or skips the speech request.
    @Test func returnSpeaksAndSavesNoLineBreak() {
        let storage = FakeStorage()
        let draft = store(restoring: "I'm thirsty", storage: storage)

        let outcome = draft.perform(.propose("I'm thirsty\n"))

        #expect(outcome.textToSpeak == "I'm thirsty")
        #expect(draft.text == "I'm thirsty")
        #expect(storage.saved.isEmpty, "the draft did not change")
    }

    /// Fails if Clear leaves the old words in storage (the privacy policy:
    /// the message stays "until you clear it").
    @Test func clearEmptiesTheStoredCopy() {
        let storage = FakeStorage()
        let draft = store(restoring: "Private words", storage: storage)

        let outcome = draft.perform(.clear)

        #expect(outcome.clearedText == "Private words")
        #expect(storage.saved == [""])
    }

    /// Fails if Speak with clear-after-speaking doesn't empty the stored
    /// copy too.
    @Test func speakingThatClearsEmptiesTheStoredCopy() {
        let storage = FakeStorage()
        let draft = DraftStore(load: { "Goodbye" }, save: storage.save, afterSpeaking: .clearsDraft)

        let outcome = draft.perform(.speak)

        #expect(outcome.textToSpeak == "Goodbye")
        #expect(storage.saved == [""])
    }

    // MARK: A failed save never loses what is on screen

    /// Fails if a failed save takes the words off the screen, rolls them
    /// back, or shows nothing (invariant 5).
    @Test func aFailedSaveKeepsTheWordsAndSaysSo() {
        let storage = FakeStorage()
        storage.failing = true
        let draft = store(storage: storage)

        let outcome = draft.perform(.propose("Call my daughter"))

        #expect(draft.text == "Call my daughter")
        #expect(draft.issue == .notSaved)
        #expect(outcome.draftChanged)
    }

    /// Fails if typing stops working while saves fail, or if speaking is
    /// blocked by a failed save.
    @Test func typingAndSpeakingGoOnWhileSavesFail() {
        let storage = FakeStorage()
        storage.failing = true
        let draft = store(storage: storage)

        draft.perform(.propose("Call"))
        draft.perform(.propose("Call my son"))
        let spoken = draft.perform(.speak)

        #expect(draft.text == "Call my son")
        #expect(spoken.textToSpeak == "Call my son")
        #expect(draft.issue == .notSaved)
    }

    /// Fails if the store gives up after a failure: the next edit, even one
    /// that changes nothing, saves the latest words and clears the notice.
    @Test func theNextEditRetriesAndSavesTheLatestWords() {
        let storage = FakeStorage()
        storage.failing = true
        let draft = store(storage: storage)
        draft.perform(.propose("Turn on the light"))

        storage.failing = false
        draft.perform(.speak)

        #expect(storage.saved == ["Turn on the light"])
        #expect(draft.issue == nil)
    }

    /// Fails if `retrySave()` doesn't save after a failure, or writes when
    /// nothing failed.
    @Test func retrySaveSavesOnlyAfterAFailure() {
        let storage = FakeStorage()
        let draft = store(restoring: "Saved already", storage: storage)

        draft.retrySave()
        #expect(storage.saved.isEmpty)

        storage.failing = true
        draft.perform(.insert("!"))
        storage.failing = false
        draft.retrySave()

        #expect(storage.saved == ["Saved already!"])
        #expect(draft.issue == nil)
    }

    /// Fails if a failed Clear brings the words back or loses the chance to
    /// clear the stored copy later.
    @Test func aFailedClearStillClearsTheScreenAndRetries() {
        let storage = FakeStorage()
        storage.failing = true
        let draft = store(restoring: "Secret", storage: storage)

        draft.perform(.clear)
        #expect(draft.text == "")
        #expect(draft.issue == .notSaved)

        storage.failing = false
        draft.retrySave()
        #expect(storage.saved == [""])
    }

    // MARK: The file on disk

    /// Fails if the file loses or changes words between writing and reading.
    @Test func theFileKeepsTheWordsExactly() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = DraftFile(directory: folder)
        let words = "Café, 👍 and “quotes” — 12:30"

        try file.write(words)

        #expect(try file.read() == words)
    }

    /// Fails if a missing file is an error instead of an empty draft (it is
    /// the normal state on a new install and after Clear).
    @Test func noFileMeansAnEmptyDraft() throws {
        let file = DraftFile(directory: temporaryFolder())

        #expect(try file.read() == "")
    }

    /// Fails if writing an empty draft leaves the old words on disk.
    @Test func anEmptyDraftRemovesTheFile() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = DraftFile(directory: folder)
        try file.write("Delete me")

        try file.write("")
        try file.write("")

        #expect(!FileManager.default.fileExists(atPath: file.url.path(percentEncoded: false)))
        #expect(try file.read() == "")
    }

    /// Fails if a newer draft doesn't replace the older one completely, or
    /// if the replacement leaves temporary files behind.
    @Test func aNewDraftReplacesTheOldOne() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = DraftFile(directory: folder)

        try file.write("A long first draft of several words")
        try file.write("Short")

        #expect(try file.read() == "Short")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) == [DraftFile.fileName])
    }

    /// Fails if a damaged file costs the whole message instead of the
    /// damaged bytes.
    @Test func damagedBytesDoNotCostTheRestOfTheMessage() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = DraftFile(directory: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data([0x48, 0x69, 0xFF, 0x21]).write(to: file.url)

        #expect(try file.read() == "Hi\u{FFFD}!")
    }

    /// Fails if a real write failure doesn't reach the store as an error.
    /// A file sitting where the folder should be makes the write fail.
    @Test func aBlockedFolderMakesTheWriteFail() throws {
        let blocked = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: blocked) }
        try Data("not a folder".utf8).write(to: blocked)
        let file = DraftFile(directory: blocked)

        #expect(throws: (any Error).self) { try file.write("Words") }
    }

    /// Fails if the store shows nothing when the real file can't be written,
    /// or loses the words on screen.
    @Test func theStoreSurvivesARealWriteFailure() throws {
        let blocked = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: blocked) }
        try Data("not a folder".utf8).write(to: blocked)
        let draft = DraftStore(directory: blocked)

        draft.perform(.propose("Still here"))

        #expect(draft.text == "Still here")
        #expect(draft.issue == .notSaved)
    }

    /// Fails if a draft written by one store isn't read by the next, the
    /// path a relaunch takes.
    @Test func aDraftSurvivesARelaunch() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        DraftStore(directory: folder).perform(.propose("Bring the blanket"))
        let relaunched = DraftStore(directory: folder)

        #expect(relaunched.text == "Bring the blanket")
        #expect(relaunched.issue == nil)
    }

    /// Fails if the app's draft folder moves: every draft already saved
    /// would be left behind.
    @Test func theAppKeepsTheDraftInApplicationSupport() {
        let file = DraftFile.applicationSupport

        let expected = URL.applicationSupportDirectory.appending(path: "Typing/draft.txt")
        #expect(file.url.path(percentEncoded: false) == expected.path(percentEncoded: false))
    }

    // MARK: The length limit

    /// Fails if an edit refused at the length limit passes silently: the
    /// field puts the words back as they were, so Home must say why
    /// (`DraftIssue.reachedLimit`), until the next change is saved.
    @Test func aRefusedEditSaysTheMessageIsFull() {
        let storage = FakeStorage()
        let draft = store(storage: storage)
        let full = String(repeating: "a", count: MessageComposer.maximumLength)
        draft.perform(.propose(full))
        #expect(draft.issue == nil)

        let refused = draft.perform(.propose(full + "b"))

        #expect(refused.reachedLimit && refused.fieldNeedsUpdate)
        #expect(draft.text == full)
        #expect(draft.issue == .reachedLimit)
        draft.perform(.deleteBackward)
        #expect(draft.issue == nil)
    }

    /// Fails if the limit's notice takes the place of a failed save's,
    /// which matters more: those words may be lost; or if a refusal under
    /// it goes uncounted, so Home would not tell VoiceOver of it.
    @Test func aFailedSaveOutranksTheLimit() {
        let storage = FakeStorage()
        let draft = store(storage: storage)
        let full = String(repeating: "a", count: MessageComposer.maximumLength)
        storage.failing = true
        draft.perform(.propose(full))
        #expect(draft.issue == .notSaved)

        draft.perform(.propose(full + "b"))

        #expect(draft.issue == .notSaved)
        // Still counted, so Home tells VoiceOver the keystroke did nothing.
        #expect(draft.refusals == 1)
    }

    /// Fails if a refusal straight after another is not counted, so Home
    /// would tell VoiceOver only of the first: `issue` does not change
    /// between them.
    @Test func everyRefusalIsCounted() {
        let draft = store(storage: FakeStorage())
        let full = String(repeating: "a", count: MessageComposer.maximumLength)
        draft.perform(.propose(full))
        #expect(draft.refusals == 0)

        draft.perform(.propose(full + "b"))
        draft.perform(.propose(full + "c"))

        #expect(draft.issue == .reachedLimit)
        #expect(draft.refusals == 2)
        draft.perform(.deleteBackward)
        #expect(draft.refusals == 2)
    }

    /// Fails if a failed save or restore stops being told when it shows, or
    /// the limit is told when it shows as well as on every refusal, which
    /// would tell the first refusal twice.
    @Test func onlyTheLimitIsToldOnEveryRefusalInstead() {
        #expect(DraftIssue.notSaved.isAnnouncedWhenItShows)
        #expect(DraftIssue.notRestored.isAnnouncedWhenItShows)
        #expect(!DraftIssue.reachedLimit.isAnnouncedWhenItShows)
    }

    // MARK: Messages

    /// Fails if a notice is missing words, or its short form grows too long
    /// for the warning space.
    @Test func everyNoticeHasShortAndFullWords() {
        for issue in DraftIssue.allCases {
            #expect(!issue.compactMessage.isEmpty)
            #expect(issue.compactMessage.count <= 20, "\(issue) is too long for the warning space")
            #expect(issue.message.count > issue.compactMessage.count)
            #expect(!issue.systemImage.isEmpty)
        }
    }
}

import Foundation
import Observation
import OSLog

/// The message being typed, kept across launches. The privacy policy
/// promises it ("What stays on your device"): the draft is saved after every
/// change, survives the app closing, and stays until it is cleared.
///
/// The draft on screen is the one in `composer`, and a failed save never
/// takes it away. The words stay on screen and in memory, `issue` becomes
/// `.notSaved` so Home can say so in its reserved warning space (invariant
/// 5), and the next edit or `retrySave()` tries again. An edit refused at
/// the length limit is told the same way (`.reachedLimit`), so words that
/// do not go in never vanish without a reason.
///
/// Restoring at launch only reads: it never speaks and never opens typing.
@MainActor
@Observable
final class DraftStore {
    private(set) var composer: MessageComposer
    /// Set while the draft cannot be kept, or after an edit was refused
    /// at the length limit; Home shows it as passive text.
    private(set) var issue: DraftIssue?
    /// How many edits have been refused at the length limit. `issue` stays
    /// `.reachedLimit` through refusals in a row, so Home tells VoiceOver
    /// of each one by this count: every keystroke refused is a new event.
    private(set) var refusals = 0
    @ObservationIgnored private let save: (String) throws -> Void
    @ObservationIgnored private let logger = Logger(subsystem: AppLog.subsystem, category: "typing")

    /// The draft kept in `directory`, normally Application Support/Typing.
    /// Test storage passes a folder of its own.
    convenience init(directory: URL) {
        let file = DraftFile(directory: directory)
        self.init(load: { try file.read() }, save: { try file.write($0) })
    }

    /// `load` and `save` exist so tests can make each one fail; the app uses
    /// `init(directory:)`.
    init(
        load: () throws -> String,
        save: @escaping (String) throws -> Void,
        afterSpeaking: MessageComposer.AfterSpeaking = .keepsDraft
    ) {
        self.save = save
        var restored = ""
        var loadError: (any Error)?
        do {
            restored = try load()
        } catch {
            loadError = error
        }
        composer = MessageComposer(restoring: restored, afterSpeaking: afterSpeaking)
        if let loadError {
            // The unreadable file is left where it is: the first save after
            // the person types replaces it, and nothing else touches it.
            issue = .notRestored
            logger.error("The typed message could not be restored: \(Self.describe(loadError), privacy: .public)")
        }
    }

    /// The draft as it is on screen.
    var text: String { composer.text }

    /// Applies one edit, saves the draft if it changed (or if the last save
    /// failed), and returns what the edit did. The caller passes
    /// `textToSpeak` to the speech engine; this type never speaks. An edit
    /// refused at the length limit sets `.reachedLimit` until the next
    /// change is saved, unless a failed save, which matters more, is being
    /// shown.
    @discardableResult
    func perform(_ edit: MessageComposer.Edit) -> MessageComposer.Outcome {
        let outcome = composer.apply(edit)
        if outcome.draftChanged || issue == .notSaved {
            persist()
        }
        if outcome.reachedLimit {
            if issue != .notSaved {
                issue = .reachedLimit
            }
            refusals += 1
        }
        return outcome
    }

    /// Tries a failed save again, for example when the app goes to the
    /// background. Does nothing when the draft is already saved.
    func retrySave() {
        guard issue == .notSaved else { return }
        persist()
    }

    private func persist() {
        do {
            try save(composer.text)
            // Saved: whatever was wrong before is behind the person now.
            issue = nil
        } catch {
            issue = .notSaved
            logger.error("The typed message could not be saved: \(Self.describe(error), privacy: .public)")
        }
    }

    /// An error's domain and code only. A file error's description names the
    /// file, never the words, but the words must never reach a log, so only
    /// these two parts are kept (AGENTS.md, "The privacy policy is a
    /// promise").
    private static func describe(_ error: any Error) -> String {
        let failure = error as NSError
        return "\(failure.domain) \(failure.code)"
    }
}

/// Why the typed message cannot be kept, or why a change did not go in.
/// Shown as passive text in Home's reserved warning space, never as a
/// dialog: it adds no control and moves nothing (invariant 4's rule for
/// warnings, applied to typing).
nonisolated enum DraftIssue: CaseIterable, Equatable, Sendable {
    /// The last change could not be saved. The message is still on screen.
    case notSaved
    /// The message typed before the app last closed could not be read back.
    case notRestored
    /// The last change would have taken the message past
    /// `MessageComposer.maximumLength`, so it was refused whole
    /// (docs/DECISIONS.md, "The typed message").
    case reachedLimit

    /// Short enough for the warning space, like "Volume low".
    var compactMessage: String {
        switch self {
        case .notSaved:
            String(localized: "Message not saved")
        case .notRestored:
            String(localized: "Message not restored")
        case .reachedLimit:
            String(localized: "Message full")
        }
    }

    /// The full sentence, for VoiceOver.
    var message: String {
        switch self {
        case .notSaved:
            String(localized: "This message is not being saved. It stays on screen, but it may be lost if the app closes.")
        case .notRestored:
            String(localized: "The message you were typing before the app closed could not be restored.")
        case .reachedLimit:
            String(localized: "This message is as long as it can be, so the last change was not added.")
        }
    }

    /// Whether VoiceOver is told of it when it shows. A failed save or
    /// restore is told once, when it shows: the words are still on screen
    /// and go in as they are typed. An edit refused at the length limit is
    /// told on every refusal instead (`DraftStore.refusals`), since each
    /// one is a keystroke that did nothing.
    var isAnnouncedWhenItShows: Bool {
        self != .reachedLimit
    }

    var systemImage: String {
        switch self {
        case .notSaved:
            "externaldrive.badge.exclamationmark"
        case .notRestored:
            "exclamationmark.bubble"
        case .reachedLimit:
            "text.badge.xmark"
        }
    }
}

/// The draft on disk: one small UTF-8 text file, `draft.txt`, in a folder of
/// its own. In the app that folder is Application Support/Typing, inside
/// Brickson's own container: other apps cannot open it, iOS encrypts it
/// while the device is locked, device backups include it, and deleting the
/// app removes it (the privacy policy's promises).
nonisolated struct DraftFile: Equatable, Sendable {
    static let fileName = "draft.txt"

    let directory: URL

    var url: URL { directory.appending(path: Self.fileName, directoryHint: .notDirectory) }

    /// The app's draft folder. Moving it would leave every existing draft
    /// behind, so `DraftStoreTests` pins it.
    static var applicationSupport: DraftFile {
        DraftFile(directory: directory(in: .applicationSupportDirectory))
    }

    /// The draft's folder among the app's own files: Application Support in
    /// the app, the test storage under UI tests (`LaunchOptions.filesDirectory`).
    static func directory(in files: URL) -> URL {
        files.appending(path: "Typing", directoryHint: .isDirectory)
    }

    /// The saved draft, or "" when there is none. Bytes that are not valid
    /// UTF-8 become "\u{FFFD}" rather than costing the rest of the message.
    func read() throws -> String {
        do {
            return String(decoding: try Data(contentsOf: url), as: UTF8.self)
        } catch let error as CocoaError where Self.isMissingFile(error) {
            return ""
        }
    }

    /// Replaces the saved draft in one step: the words go to a temporary
    /// file that then takes the old one's place, so a crash or a full disk
    /// leaves the old draft or the new one, never part of either. An empty
    /// draft removes the file.
    func write(_ text: String) throws {
        guard !text.isEmpty else {
            do {
                try FileManager.default.removeItem(at: url)
            } catch let error as CocoaError where Self.isMissingFile(error) {
                // Already gone: nothing to clear.
            }
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Readable after the device is first unlocked, so a save while the
        // screen is locked (speech keeps playing then) cannot fail for that.
        try Data(text.utf8).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static func isMissingFile(_ error: CocoaError) -> Bool {
        error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
    }
}

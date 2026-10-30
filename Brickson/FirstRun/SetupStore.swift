import Foundation
import Observation
import os

/// Something the person or family should know about the setup record. Shown
/// as passive text in Family Setup; never a dialog, never a crash.
nonisolated enum SetupStoreIssue: Equatable, Sendable {
    /// The saved record could not be read (for example, it was written by a
    /// newer version of Brickson). It was set aside, not deleted, and setup
    /// starts again from the beginning.
    case unreadableRecordSetAside
    /// The last change could not be saved; nothing was changed.
    case couldNotSave
}

/// Keeps the `SetupRecord` in UserDefaults as JSON.
///
/// A change is all or nothing (AGENTS.md, invariant 5): `update` encodes
/// the changed record first and only then replaces both the stored copy and
/// the one on screen. If encoding fails, both keep their old value and
/// `issue` says so, and the caller keeps any answers it was holding so the
/// family can try again.
@Observable
final class SetupStore {
    static let recordKey = "setupRecord"
    /// Where an unreadable record is moved, so it can still be inspected.
    static let setAsideKey = "setupRecord.unreadable"

    private(set) var record: SetupRecord
    private(set) var issue: SetupStoreIssue? = nil

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let encode: (SetupRecord) throws -> Data
    @ObservationIgnored private let logger = Logger(subsystem: AppLog.subsystem, category: "Setup")

    init(
        defaults: UserDefaults,
        now: Date = .now,
        encode: @escaping (SetupRecord) throws -> Data = { try JSONEncoder().encode($0) },
        decode: (Data) throws -> SetupRecord = { try JSONDecoder().decode(SetupRecord.self, from: $0) }
    ) {
        self.defaults = defaults
        self.encode = encode

        guard let data = defaults.data(forKey: Self.recordKey) else {
            record = SetupRecord(createdAt: now)
            save(record)
            return
        }
        do {
            let stored = try decode(data)
            guard stored.version <= SetupRecord.currentVersion else {
                throw CocoaError(.coderReadCorrupt)
            }
            record = stored
        } catch {
            // Never discard it: a newer Brickson may be able to read it again.
            logger.error("Setup record unreadable; set aside: \(error.localizedDescription, privacy: .public)")
            defaults.set(data, forKey: Self.setAsideKey)
            record = SetupRecord(createdAt: now)
            issue = .unreadableRecordSetAside
            save(record)
        }
    }

    /// Applies `change` and saves it. Returns false, and changes nothing,
    /// when the save fails.
    @discardableResult
    func update(_ change: (inout SetupRecord) -> Void) -> Bool {
        var changed = record
        change(&changed)
        guard changed != record else { return true }
        guard save(changed) else { return false }
        record = changed
        if issue == .couldNotSave {
            issue = nil
        }
        return true
    }

    /// Go Through Setup Again, on Family Setup's check-in card: answers the
    /// check-in with the answers as they are (`CheckInPolicy.wentThroughAgain`),
    /// then opens the first step of Set Up Step by Step. A failed save opens
    /// nothing, so the card stays and Family Setup shows `issue`
    /// (docs/DECISIONS.md, "The first step's own rows").
    func goThroughSetupAgain(path: inout [SettingsRoute], now: Date) {
        guard update({ CheckInPolicy.wentThroughAgain(&$0, now: now) }) else { return }
        path.append(.guidedSetup(.access))
    }

    @discardableResult
    private func save(_ candidate: SetupRecord) -> Bool {
        do {
            defaults.set(try encode(candidate), forKey: Self.recordKey)
            return true
        } catch {
            logger.error("Setup record not saved: \(error.localizedDescription, privacy: .public)")
            issue = .couldNotSave
            return false
        }
    }
}

import Foundation
import Testing
@testable import Brickson

/// Invariant 5: a failed save never crashes and never leaves data
/// half-changed, and every save path has a test that makes it fail.
@MainActor
struct SetupStoreTests {
    private struct EncodingFailed: Error {}

    private let launch = Date(timeIntervalSince1970: 1_800_000_000)

    /// A fresh, private defaults suite per test, so tests never share state
    /// or touch the app's own settings.
    private func makeDefaults() -> UserDefaults {
        let name = "SetupStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func aFirstLaunchStartsAFreshRecordAndSavesIt() throws {
        let defaults = makeDefaults()
        let store = SetupStore(defaults: defaults, now: launch)

        #expect(store.record == SetupRecord(createdAt: launch))
        #expect(store.issue == nil)
        #expect(defaults.data(forKey: SetupStore.recordKey) != nil)
    }

    @Test func changesSurviveARelaunch() {
        let defaults = makeDefaults()
        let store = SetupStore(defaults: defaults, now: launch)
        store.update { $0.answerAccessMethods([.switchControl], at: launch) }

        let relaunched = SetupStore(defaults: defaults, now: launch.addingTimeInterval(60))
        #expect(relaunched.record.accessMethods == [.switchControl])
        #expect(relaunched.record.createdAt == launch)
    }

    @Test func aFailedSaveChangesNothingAndSaysSo() {
        let defaults = makeDefaults()
        _ = SetupStore(defaults: defaults, now: launch)
        let store = SetupStore(defaults: defaults, now: launch, encode: { _ in throw EncodingFailed() })

        let saved = store.update { $0.familySetupOpened = true }

        #expect(!saved)
        #expect(store.record.familySetupOpened == false, "the screen must not show a change that was not kept")
        #expect(store.issue == .couldNotSave)
        let relaunched = SetupStore(defaults: defaults, now: launch)
        #expect(relaunched.record.familySetupOpened == false)
    }

    @Test func theNextSuccessfulSaveClearsTheWarning() {
        let defaults = makeDefaults()
        var failing = true
        let store = SetupStore(defaults: defaults, now: launch, encode: { record in
            if failing { throw EncodingFailed() }
            return try JSONEncoder().encode(record)
        })
        let failedSave = store.update { $0.familySetupOpened = true }
        #expect(!failedSave)

        failing = false
        let retried = store.update { $0.familySetupOpened = true }
        #expect(retried)
        #expect(store.issue == nil)
        #expect(store.record.familySetupOpened)
    }

    /// Never delete what cannot be read: set it aside and start again.
    @Test func anUnreadableRecordIsSetAsideNotDeleted() {
        let defaults = makeDefaults()
        let garbage = Data("not a setup record".utf8)
        defaults.set(garbage, forKey: SetupStore.recordKey)

        let store = SetupStore(defaults: defaults, now: launch)

        #expect(store.issue == .unreadableRecordSetAside)
        #expect(store.record == SetupRecord(createdAt: launch))
        #expect(defaults.data(forKey: SetupStore.setAsideKey) == garbage)
    }

    /// A record from a newer Brickson (after a downgrade) is not guessed at.
    @Test func aRecordFromANewerVersionIsSetAside() throws {
        let defaults = makeDefaults()
        var newer = SetupRecord(createdAt: launch)
        newer.version = SetupRecord.currentVersion + 1
        let data = try JSONEncoder().encode(newer)
        defaults.set(data, forKey: SetupStore.recordKey)

        let store = SetupStore(defaults: defaults, now: launch)

        #expect(store.issue == .unreadableRecordSetAside)
        #expect(defaults.data(forKey: SetupStore.setAsideKey) == data)
    }

    // MARK: Go Through Setup Again

    /// The check-in card's Go Through Setup Again answers the check-in,
    /// with the answers as they are, and only then opens the first step.
    /// Fails if it opens anything else, or if the answer is not kept.
    @Test func goingThroughSetupAgainAnswersTheCheckInThenOpensTheFirstStep() {
        let defaults = makeDefaults()
        let store = SetupStore(defaults: defaults, now: launch)
        store.update { CheckInPolicy.answered(&$0, methods: [.eyeTracking], now: launch) }
        let due = launch.addingTimeInterval(100 * 24 * 60 * 60)
        var path: [SettingsRoute] = [.familySetup]

        store.goThroughSetupAgain(path: &path, now: due)

        #expect(path == [.familySetup, .guidedSetup(.access)])
        #expect(store.record.accessMethods == [.eyeTracking])
        #expect(store.record.answeredAt == due)
        #expect(store.issue == nil)
        #expect(SetupStore(defaults: defaults, now: due).record == store.record)
    }

    /// A failed save opens nothing and changes nothing, so the card stays
    /// due and Family Setup shows the warning (invariant 5). Fails if the
    /// first step opens anyway, or if the screen shows a check-in answer
    /// that was not kept.
    @Test func goingThroughSetupAgainOpensNothingWhenTheCheckInCannotBeSaved() {
        let defaults = makeDefaults()
        _ = SetupStore(defaults: defaults, now: launch)
        let store = SetupStore(defaults: defaults, now: launch, encode: { _ in throw EncodingFailed() })
        let before = store.record
        let due = launch.addingTimeInterval(100 * 24 * 60 * 60)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        #expect(CheckInPolicy.isDue(before, now: due, calendar: calendar))
        var path: [SettingsRoute] = [.familySetup]

        store.goThroughSetupAgain(path: &path, now: due)

        #expect(path == [.familySetup], "the first step must not open after a failed save")
        #expect(store.record == before, "the screen must not show a change that was not kept")
        #expect(store.issue == .couldNotSave)
        #expect(CheckInPolicy.isDue(store.record, now: due, calendar: calendar), "the card must stay")
        #expect(SetupStore(defaults: defaults, now: launch).record == before)
    }
}

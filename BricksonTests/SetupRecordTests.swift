import Foundation
import Testing
@testable import Brickson

/// Family Setup records what it was told, never "setup completed": a family
/// can stop part-way, and the layout and check-ins must still behave.
struct SetupRecordTests {
    private let launch = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    private func days(_ count: Int, after date: Date) -> Date {
        calendar.date(byAdding: .day, value: count, to: date)!
    }

    // MARK: Answers

    @Test func nobodyAnsweringMeansPlanForTheLargestSizes() {
        let record = SetupRecord(createdAt: launch)
        #expect(record.plannedAccessMethods == nil)
    }

    @Test func clearingEveryChoiceIsTreatedAsNoAnswer() {
        var record = SetupRecord(createdAt: launch)
        record.answerAccessMethods([], at: launch)

        #expect(record.accessMethods == [])
        #expect(record.plannedAccessMethods == nil)
    }

    @Test func answersAreKeptAsGiven() {
        var record = SetupRecord(createdAt: launch)
        record.answerAccessMethods([.eyeTracking, .switchControl], at: launch)

        #expect(record.plannedAccessMethods == [.eyeTracking, .switchControl])
        #expect(record.answeredAt == launch)
    }

    @Test func theRecordSurvivesARoundTrip() throws {
        var record = SetupRecord(createdAt: launch)
        record.familySetupOpened = true
        record.answerAccessMethods([.headTracking], at: launch)

        let data = try JSONEncoder().encode(record)
        #expect(try JSONDecoder().decode(SetupRecord.self, from: data) == record)
    }

    // MARK: First-run hint

    @Test func theHintShowsUntilFamilySetupIsOpened() {
        var record = SetupRecord(createdAt: launch)
        #expect(FirstRunHint.isShown(for: record))

        record.familySetupOpened = true
        #expect(!FirstRunHint.isShown(for: record))
    }

    // MARK: Check-ins

    @Test func aCheckInIsDueThreeMonthsAfterFirstLaunch() {
        let record = SetupRecord(createdAt: launch)
        let threeMonths = calendar.date(byAdding: .month, value: 3, to: launch)!

        #expect(!CheckInPolicy.isDue(record, now: threeMonths.addingTimeInterval(-1), calendar: calendar))
        #expect(CheckInPolicy.isDue(record, now: threeMonths, calendar: calendar))
    }

    @Test func answeringStartsThreeMonthsAgain() {
        var record = SetupRecord(createdAt: launch)
        let answered = days(60, after: launch)
        CheckInPolicy.answered(&record, methods: [.touch], now: answered)

        let threeMonthsAfterLaunch = calendar.date(byAdding: .month, value: 3, to: launch)!
        let threeMonthsAfterAnswer = calendar.date(byAdding: .month, value: 3, to: answered)!
        #expect(!CheckInPolicy.isDue(record, now: threeMonthsAfterLaunch, calendar: calendar))
        #expect(CheckInPolicy.isDue(record, now: threeMonthsAfterAnswer, calendar: calendar))
    }

    @Test func notNowWaitsThirtyDays() {
        var record = SetupRecord(createdAt: launch)
        let due = calendar.date(byAdding: .month, value: 3, to: launch)!
        CheckInPolicy.notNow(&record, now: due, calendar: calendar)

        #expect(!CheckInPolicy.isDue(record, now: days(29, after: due), calendar: calendar))
        #expect(CheckInPolicy.isDue(record, now: days(30, after: due), calendar: calendar))
    }

    @Test func stopAskingEndsCheckInsUntilTheFamilyAnswersAgain() {
        var record = SetupRecord(createdAt: launch)
        CheckInPolicy.stopAsking(&record)
        #expect(!CheckInPolicy.isDue(record, now: days(1000, after: launch), calendar: calendar))

        let answered = days(400, after: launch)
        CheckInPolicy.answered(&record, methods: [.eyeTracking], now: answered)
        let later = calendar.date(byAdding: .month, value: 3, to: answered)!
        #expect(CheckInPolicy.isDue(record, now: later, calendar: calendar))
    }

    /// A clock set backwards must not make a check-in appear early.
    @Test func aClockSetBackwardsShowsNothing() {
        let record = SetupRecord(createdAt: launch)
        #expect(!CheckInPolicy.isDue(record, now: days(-400, after: launch), calendar: calendar))
    }
}

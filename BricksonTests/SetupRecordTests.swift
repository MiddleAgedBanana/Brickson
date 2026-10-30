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

    /// Going through setup again from the card answers the check-in with
    /// the answers as they are, since the first step's Next only moves on
    /// (docs/DECISIONS.md, "The first step's own rows"). Fails if the
    /// answers change, if the next check-in is not three months away, or
    /// if a family that had stopped check-ins would not be asked again.
    @Test func goingThroughSetupAgainAnswersTheCheckInWithTheAnswersAsTheyAre() {
        let due = calendar.date(byAdding: .month, value: 3, to: launch)!
        var record = SetupRecord(createdAt: launch)
        CheckInPolicy.answered(&record, methods: [.eyeTracking, .someoneElse], now: launch)
        #expect(CheckInPolicy.isDue(record, now: due, calendar: calendar))

        CheckInPolicy.wentThroughAgain(&record, now: due)
        #expect(record.accessMethods == [.eyeTracking, .someoneElse])
        #expect(!CheckInPolicy.isDue(record, now: days(80, after: due), calendar: calendar))
        #expect(CheckInPolicy.isDue(record, now: calendar.date(byAdding: .month, value: 3, to: due)!, calendar: calendar))
        #expect(CheckInPolicy.afterword(for: record) == .answered)

        var neverAnswered = SetupRecord(createdAt: launch)
        CheckInPolicy.wentThroughAgain(&neverAnswered, now: due)
        #expect(neverAnswered.plannedAccessMethods == nil)
        #expect(!CheckInPolicy.isDue(neverAnswered, now: days(80, after: due), calendar: calendar))
    }

    /// Once the card is answered on screen, passive words take its place,
    /// so the rows below never move up under the spot just activated
    /// (AGENTS.md, invariant 10). Each answer gets its own words.
    @Test func eachAnswerLeavesItsOwnWordsInTheCardsPlace() {
        let due = calendar.date(byAdding: .month, value: 3, to: launch)!

        var snoozed = SetupRecord(createdAt: launch)
        CheckInPolicy.notNow(&snoozed, now: due, calendar: calendar)
        #expect(CheckInPolicy.afterword(for: snoozed) == .askAgainLater)

        var stopped = SetupRecord(createdAt: launch)
        CheckInPolicy.stopAsking(&stopped)
        #expect(CheckInPolicy.afterword(for: stopped) == .stopped)

        var answered = SetupRecord(createdAt: launch)
        CheckInPolicy.answered(&answered, methods: [.switchControl], now: due)
        #expect(CheckInPolicy.afterword(for: answered) == .answered)
    }

    /// A clock set backwards must not make a check-in appear early.
    @Test func aClockSetBackwardsShowsNothing() {
        let record = SetupRecord(createdAt: launch)
        #expect(!CheckInPolicy.isDue(record, now: days(-400, after: launch), calendar: calendar))
    }
}

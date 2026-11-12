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

    // MARK: The rest board

    /// Fails if a record starts with a rest board chosen, if choosing one
    /// is not kept through a round trip, if Every Category does not clear
    /// it, or if choosing one answers the access question or a check-in
    /// (docs/DECISIONS.md, "The late-stage profile").
    @Test func aRestBoardIsChosenKeptAndCleared() throws {
        var record = SetupRecord(createdAt: launch)
        #expect(record.restBoardCategory == nil)
        let category = UUID()
        record.chooseRestBoard(category)
        #expect(record.restBoardCategory == category)
        #expect(record.accessMethods == nil && record.answeredAt == nil)
        let data = try JSONEncoder().encode(record)
        #expect(try JSONDecoder().decode(SetupRecord.self, from: data).restBoardCategory == category)
        record.chooseRestBoard(nil)
        #expect(record.restBoardCategory == nil)
    }

    /// A record saved before the board has no `restBoardCategory` key.
    /// Fails if it no longer reads (the store would set it aside and the
    /// family's answers would be lost), or reads with a board chosen.
    @Test func aRecordSavedBeforeTheRestBoardReadsWithNone() throws {
        var record = SetupRecord(createdAt: launch)
        record.answerAccessMethods([.eyeTracking], at: launch)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        object.removeValue(forKey: "restBoardCategory")
        let old = try JSONSerialization.data(withJSONObject: object)
        let read = try JSONDecoder().decode(SetupRecord.self, from: old)
        #expect(read.restBoardCategory == nil)
        #expect(read.accessMethods == [.eyeTracking])
        #expect(read.version == SetupRecord.currentVersion)
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

    /// The UI tests' `--check-in-due` makes a record due on any day and at
    /// any hour, month ends and daylight-saving changes included (at 2 a.m.
    /// three months after the day daylight saving starts, the hour that
    /// day skips put it an hour short), whether it was
    /// just made, just answered, put off with Not Now or stopped, and
    /// keeps the answers. Fails if one of those records is left not due,
    /// or if an answer, the rest board or Family Setup's having been opened
    /// is changed.
    @Test func makingACheckInDueWorksOnEveryDayAndKeepsTheAnswers() {
        let board = UUID()
        for day in 0..<(2 * 366) {
            for hour in [0, 2, 7, 12, 23] {
                let now = calendar.date(byAdding: .hour, value: hour, to: calendar.startOfDay(for: days(day, after: launch)))!
                var fresh = SetupRecord(createdAt: now)
                var answered = SetupRecord(createdAt: launch)
                answered.familySetupOpened = true
                answered.chooseRestBoard(board)
                CheckInPolicy.answered(&answered, methods: [.eyeTracking, .someoneElse], now: now)
                var snoozed = answered
                CheckInPolicy.notNow(&snoozed, now: now, calendar: calendar)
                var stopped = answered
                CheckInPolicy.stopAsking(&stopped)
                for var record in [fresh, answered, snoozed, stopped] {
                    CheckInPolicy.makeDue(&record, now: now, calendar: calendar)
                    #expect(CheckInPolicy.isDue(record, now: now, calendar: calendar), "\(now)")
                    #expect(CheckInPolicy.afterword(for: record) == .answered)
                }
                CheckInPolicy.makeDue(&fresh, now: now, calendar: calendar)
                #expect(fresh.accessMethods == nil && fresh.answeredAt == nil && !fresh.familySetupOpened)
                CheckInPolicy.makeDue(&answered, now: now, calendar: calendar)
                #expect(answered.accessMethods == [.eyeTracking, .someoneElse])
                #expect(answered.restBoardCategory == board && answered.familySetupOpened)
            }
        }
    }

    /// Made due, a record that was already due keeps its dates: a check-in
    /// made due for a test is never pushed later.
    @Test func makingACheckInDueNeverMovesItLater() {
        var record = SetupRecord(createdAt: launch)
        let longAfter = calendar.date(byAdding: .month, value: 9, to: launch)!
        CheckInPolicy.makeDue(&record, now: longAfter, calendar: calendar)
        #expect(record.createdAt == launch)
    }
}

import CoreGraphics
import Foundation
import Testing

// The probe app's plain logic (BricksonProbe/Logic), compiled into this
// target by project.yml. The probe is a separate test app for the
// experiments in docs/EXPERIMENTS.md, never part of Brickson.

struct ProbeStationTests {
    /// A-1 comes first on devices (docs/EXPERIMENTS.md). Fails if the
    /// station order or the Snap station's first question changes.
    @Test func theSnapStationComesFirstWithA1() {
        #expect(ProbeStation.allCases.first == .snap)
        #expect(ProbeStation.snap.questions.first == "A-1")
    }

    /// Every station serves at least one question, under an ID the run
    /// sheet uses. Fails if a station loses its questions or an ID is
    /// mistyped (A1 for A-1, D-1 for D-01).
    @Test(arguments: ProbeStation.allCases)
    func everyStationNamesWellFormedQuestions(station: ProbeStation) throws {
        #expect(!station.questions.isEmpty)
        let form = try Regex(#"^(A-[1-9][0-9]?a?|B-[1-4]|D-[0-9]{2}|G-[0-9]{2})$"#)
        for question in station.questions {
            #expect(question.wholeMatch(of: form) != nil, "\(question)")
        }
        #expect(Set(station.questions).count == station.questions.count)
    }

    /// Fails if two stations share a title, which the log tells apart by.
    @Test func stationTitlesAreUnique() {
        let titles = ProbeStation.allCases.map(\.title)
        #expect(Set(titles).count == titles.count)
    }
}

struct ProbeLogTests {
    /// Fails if a line's time stops counting from the probe's start.
    @Test func linesCountTheirTimeFromTheStart() {
        let start = ContinuousClock.now
        let log = ProbeLog(start: start)
        log.record("Counter activated (#1)", station: "Snap", at: start.advanced(by: .milliseconds(1_500)))
        log.record("Picker: Type chosen", station: "Snap", at: start.advanced(by: .seconds(2)))
        log.record("Centre activated (#1)", station: "Rings", at: start.advanced(by: .seconds(3)))

        #expect(log.entries.map(\.elapsed) == [.milliseconds(1_500), .seconds(2), .seconds(3)])
        #expect(log.latest(on: "Snap")?.event == "Picker: Type chosen")
        #expect(log.latest(on: "Busy") == nil)
    }

    /// A long session keeps its newest lines and says how many it dropped.
    /// Fails if the log grows without bound or drops lines silently.
    @Test func aFullLogDropsItsOldestLinesAndSaysSo() {
        let log = ProbeLog()
        for number in 0..<(ProbeLog.capacity + 3) {
            log.record("Line \(number)", station: "Snap")
        }

        #expect(log.entries.count == ProbeLog.capacity)
        #expect(log.dropped == 3)
        #expect(log.entries.first?.event == "Line 3")
        #expect(log.exportText.contains("3 older lines were dropped"))
    }

    /// Fails if the shared text loses its header, its order or a column.
    @Test func theExportIsTabSeparatedOldestFirst() {
        let start = ContinuousClock.now
        let log = ProbeLog(start: start)
        log.record("First", station: "Snap", at: start.advanced(by: .milliseconds(250)))
        log.record("Second", station: "Busy", at: start.advanced(by: .seconds(4)))
        let lines = log.exportText.split(separator: "\n").map(String.init)

        #expect(lines.count == 3)
        #expect(lines[0] == "seconds\ttime\tstation\tevent")
        #expect(lines[1].hasPrefix("0.25\t") && lines[1].hasSuffix("\tSnap\tFirst"))
        #expect(lines[2].hasPrefix("4.00\t") && lines[2].hasSuffix("\tBusy\tSecond"))
        #expect(lines.dropFirst().allSatisfy { $0.split(separator: "\t").count == 4 })
    }

    /// A report that arrives late (a speech report held up while Busy held
    /// the main thread) goes in at the time it happened, after lines at
    /// the same time. Fails if the log appends in arrival order.
    @Test func aLateReportGoesInAtItsOwnTime() {
        let start = ContinuousClock.now
        let log = ProbeLog(start: start)
        log.record("Busy until now", station: "Busy", at: start.advanced(by: .milliseconds(3_500)))
        log.record("Word at 5", station: "Speech", at: start.advanced(by: .seconds(1)))
        log.record("Same time, recorded first", station: "Snap", at: start.advanced(by: .seconds(2)))
        log.record("Same time, recorded second", station: "Snap", at: start.advanced(by: .seconds(2)))

        #expect(log.entries.map(\.event) == [
            "Word at 5", "Same time, recorded first", "Same time, recorded second", "Busy until now",
        ])
        #expect(log.latest(on: "Busy")?.event == "Busy until now")
    }

    /// A full log drops the line that happened first, even when it arrived
    /// last. Fails if it drops by arrival order.
    @Test func aFullLogDropsTheEarliestLine() {
        let start = ContinuousClock.now
        let log = ProbeLog(start: start)
        for number in 1...ProbeLog.capacity {
            log.record("Line \(number)", station: "Snap", at: start.advanced(by: .seconds(number)))
        }
        log.record("Late report", station: "Speech", at: start.advanced(by: .milliseconds(500)))

        #expect(log.entries.count == ProbeLog.capacity)
        #expect(log.entries.first?.event == "Line 1")
        #expect(!log.entries.contains { $0.event == "Late report" })
        #expect(log.dropped == 1)
    }

    @Test func clearingEmptiesTheLog() {
        let log = ProbeLog()
        log.record("Line", station: "Snap")
        log.clear()
        #expect(log.entries.isEmpty)
        #expect(log.dropped == 0)
    }

    @Test func secondsHaveTwoDecimals() {
        #expect(ProbeLogFormat.seconds(.milliseconds(1_234)) == "1.23")
        #expect(ProbeLogFormat.seconds(.zero) == "0.00")
        #expect(ProbeLogFormat.seconds(.seconds(65)) == "65.00")
    }
}

struct ProbeCountdownTests {
    /// The readout says 5 until a whole second has passed and 0 only at the
    /// end. Fails if it rounds down, goes negative or finishes early.
    @Test func secondsLeftRoundUpAndStopAtZero() {
        let start = ContinuousClock.now
        let countdown = ProbeCountdown(startedAt: start, length: .seconds(5))

        #expect(countdown.secondsLeft(now: start) == 5)
        #expect(countdown.secondsLeft(now: start.advanced(by: .milliseconds(100))) == 5)
        #expect(countdown.secondsLeft(now: start.advanced(by: .seconds(4))) == 1)
        #expect(countdown.secondsLeft(now: start.advanced(by: .milliseconds(4_900))) == 1)
        #expect(!countdown.isFinished(now: start.advanced(by: .milliseconds(4_999))))
        #expect(countdown.secondsLeft(now: start.advanced(by: .seconds(5))) == 0)
        #expect(countdown.isFinished(now: start.advanced(by: .seconds(5))))
        #expect(countdown.secondsLeft(now: start.advanced(by: .seconds(6))) == 0)
    }
}

struct ProbeStatusTests {
    private func reading(_ name: String, _ value: String) -> ProbeStatusReading {
        ProbeStatusReading(name: name, value: value)
    }

    /// The first read logs every value, then only what moved. Fails if a
    /// change goes unlogged or an unchanged value is logged again.
    @Test func onlyChangesAreLoggedAfterTheFirstRead() {
        let first = [reading("isAssistiveTouchRunning", "false"), reading("isSwitchControlRunning", "false")]
        let second = [reading("isAssistiveTouchRunning", "true"), reading("isSwitchControlRunning", "false"),
                      reading("isApplicationAccessibilityEnabled", "true")]

        #expect(ProbeStatusChanges.lines(from: [], to: first)
            == ["isAssistiveTouchRunning = false", "isSwitchControlRunning = false"])
        #expect(ProbeStatusChanges.lines(from: first, to: first).isEmpty)
        #expect(ProbeStatusChanges.lines(from: first, to: second)
            == ["isAssistiveTouchRunning: false → true", "isApplicationAccessibilityEnabled = true"])
    }

    /// Power and heat log under Screen, everything else under Status.
    /// Fails if a group logs under the wrong station or logs twice.
    @Test func theMonitorLogsEachGroupUnderItsStation() {
        let log = ProbeLog()
        let monitor = ProbeStatusMonitor(log: log)
        let power = [reading("ProcessInfo.isLowPowerModeEnabled", "false")]
        let uikit = [reading("UIAccessibility.isAssistiveTouchRunning", "false")]

        monitor.update(ProbeStatusMonitor.power, with: power)
        monitor.update(ProbeStatusMonitor.uikit, with: uikit)
        monitor.update(ProbeStatusMonitor.uikit, with: uikit)

        #expect(log.entries.map(\.station) == ["Screen", "Status"])
        #expect(monitor.readings(for: ProbeStatusMonitor.uikit) == uikit)
        #expect(ProbeStatusMonitor.groups.count == 4)
    }

    @Test func thermalStatesHaveWords() {
        #expect(ProbeStatusChanges.words(for: .nominal) == "nominal")
        #expect(ProbeStatusChanges.words(for: .critical) == "critical")
    }
}

struct ProbeSpeechScriptsTests {
    /// The spoken command names the button Voice Control would press
    /// (A-16). Fails if the button's name and the command drift apart.
    @Test func theVoiceControlCommandNamesTheCounter() {
        #expect(ProbeSpeechScripts.voiceControlCommand == "Tap \(ProbeSpeechScripts.counterLabel)")
    }

    /// G-30 compares one utterance with the same words in parts. Fails if
    /// the parts stop adding up to the sentence.
    @Test func thePartsMakeTheSentence() {
        #expect(ProbeSpeechScripts.parts.joined(separator: " ") == ProbeSpeechScripts.sentence)
    }

    /// Fails if the SSML loses its pauses, its root element, or lets a
    /// part's text break the markup.
    @Test func theSSMLPausesBetweenPartsAndEscapesText() {
        let ssml = ProbeSpeechScripts.ssml(parts: ["One", "Two & <three>"], pauseMilliseconds: 600)
        #expect(ssml == "<speak>One<break time=\"600ms\"/>Two &amp; &lt;three&gt;</speak>")
        #expect(ProbeSpeechScripts.escapedForXML("\"it's\"") == "&quot;it&apos;s&quot;")
    }
}

struct ProbeVisibleTextTests {
    /// A-34 reads what the keyboard delivered. Fails if a space, Return,
    /// tab or no-break space stops showing.
    @Test func invisibleCharactersShow() {
        #expect(ProbeVisibleText.marked("a b\nc\td\u{00A0}e") == "a·b⏎c⇥d⍽e")
        #expect(ProbeVisibleText.marked("x\r\ny") == "x⏎y")
        #expect(ProbeVisibleText.marked("") == "")
    }
}

struct ProbeUtteranceTallyTests {
    /// D-25 compares voices by their word reports. Fails if a report goes
    /// uncounted or the longest gap is measured from the wrong report.
    @Test func reportsAndTheLongestGapAreCounted() {
        let start = ContinuousClock.now
        var tally = ProbeUtteranceTally(startedAt: start)
        tally.word(at: start.advanced(by: .milliseconds(200)))
        tally.word(at: start.advanced(by: .milliseconds(500)))
        tally.word(at: start.advanced(by: .milliseconds(1_500)))

        #expect(tally.wordReports == 3)
        #expect(tally.longestGap == .seconds(1))
        #expect(tally.summary(endedAt: start.advanced(by: .seconds(2)), how: "finished")
            == "finished after 2.00 s: 3 word reports, longest gap 1.00 s")
    }

    @Test func anUtteranceWithNoReportsSaysSo() {
        let start = ContinuousClock.now
        let tally = ProbeUtteranceTally(startedAt: start)
        #expect(tally.summary(endedAt: start.advanced(by: .seconds(1)), how: "cancelled")
            == "cancelled after 1.00 s: 0 word reports, longest gap 0.00 s")
    }
}

struct ProbeGeometryTests {
    /// The run sheet quotes these distances. Fails if a ring is dropped or
    /// they fall out of order.
    @Test func theRingsRunFrom25To300Points() {
        #expect(ProbeGeometry.ringRadii == [25, 50, 100, 150, 200, 300])
        #expect(zip(ProbeGeometry.ringRadii, ProbeGeometry.ringRadii.dropFirst()).allSatisfy { pair in pair.0 < pair.1 })
    }

    /// D-10 compares a grid of equal tiles with a varied one. Fails if the
    /// same sizes vary or the varied grid stops alternating.
    @Test func variedTilesAlternateAndSameTilesDoNot() {
        for row in 0..<ProbeGeometry.lookRows {
            for column in 0..<ProbeGeometry.lookColumns {
                #expect(ProbeGeometry.lookTileScale(row: row, column: column, sizing: .same) == 1)
                let varied = ProbeGeometry.lookTileScale(row: row, column: column, sizing: .varied)
                #expect(varied == ((row + column).isMultiple(of: 2) ? 1 : 0.7))
            }
        }
        #expect(ProbeGeometry.lookRows * ProbeGeometry.lookColumns == 12)
    }

    /// The Rings station's middle button comes in Apple's minimum and two
    /// larger sizes. Fails if the smallest drops below 44 points.
    @Test func theSmallestRingTargetIsApplesMinimum() {
        #expect(ProbeRingTarget.allCases.map(\.side) == [44, 88, 120])
    }
}

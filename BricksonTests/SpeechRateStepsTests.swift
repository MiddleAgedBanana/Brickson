import AVFoundation
import Testing
@testable import Brickson

/// The rate control is two plain Buttons, not a Slider: a slider needs a
/// drag, which neither dwell nor switch access does well (invariant 1).
struct SpeechRateStepsTests {
    @Test func stepsMoveInFixedIncrementsAndLandOnTheGrid() {
        let normal = AVSpeechUtteranceDefaultSpeechRate
        #expect(SpeechRateSteps.slower(normal) == 0.45)
        #expect(SpeechRateSteps.faster(normal) == 0.55)

        var rate = normal
        for _ in 0..<7 { rate = SpeechRateSteps.faster(rate) }
        for _ in 0..<7 { rate = SpeechRateSteps.slower(rate) }
        #expect(rate == normal, "repeated steps must not drift")

        // An off-grid stored value (from the old slider) snaps onto the grid.
        #expect(SpeechRateSteps.faster(0.512) == 0.55)
    }

    @Test func stepsStopAtTheSynthesizerLimits() {
        let minimum = AVSpeechUtteranceMinimumSpeechRate
        let maximum = AVSpeechUtteranceMaximumSpeechRate
        #expect(SpeechRateSteps.slower(minimum) == minimum)
        #expect(SpeechRateSteps.faster(maximum) == maximum)
        #expect(!SpeechRateSteps.canSlowDown(minimum))
        #expect(!SpeechRateSteps.canSpeedUp(maximum))
        #expect(SpeechRateSteps.canSlowDown(AVSpeechUtteranceDefaultSpeechRate))
        #expect(SpeechRateSteps.canSpeedUp(AVSpeechUtteranceDefaultSpeechRate))
    }

    @Test func rateIsDescribedRelativeToNormal() {
        #expect(SpeechRateSteps.description(of: AVSpeechUtteranceDefaultSpeechRate) == "Normal")
        #expect(SpeechRateSteps.description(of: 0.45) == "90% of normal")
        #expect(SpeechRateSteps.description(of: 0.6) == "120% of normal")
    }
}

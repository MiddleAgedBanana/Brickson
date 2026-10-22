import AVFoundation
import Testing
@testable import Brickson

/// Voice Settings' speeds are fixed choices, so a repeated activation never
/// walks the speed (AGENTS.md, invariant 10).
@MainActor
struct SpeedChoiceTests {
    private let normal = AVSpeechUtteranceDefaultSpeechRate

    /// Fails if a choice's step depends on the rate it starts from, which is
    /// how Slower and Faster walked the speed.
    @Test func choosingASpeedSetsItWhateverTheRateWas() {
        for choice in SpeedChoice.all {
            let step = choice.step(normal: normal)
            let expected = choice.rate(normal: normal)
            #expect(step(AVSpeechUtteranceMinimumSpeechRate) == expected)
            #expect(step(AVSpeechUtteranceMaximumSpeechRate) == expected)
            #expect(step(step(normal)) == expected)
        }
    }

    @Test func theChoicesRunFromSlowToFastWithNormalAmongThem() {
        let rates = SpeedChoice.all.map { $0.rate(normal: normal) }
        #expect(rates == rates.sorted())
        #expect(Set(rates).count == rates.count)
        #expect(SpeedChoice.all.filter(\.isNormal).map { $0.rate(normal: normal) } == [normal])
        #expect(rates.allSatisfy { $0 >= AVSpeechUtteranceMinimumSpeechRate && $0 <= AVSpeechUtteranceMaximumSpeechRate })
    }

    /// The choices are where the old Slower and Faster steps landed, so a
    /// speed saved with them still shows as chosen.
    @Test func theChoicesSitOnTheRateGrid() {
        for choice in SpeedChoice.all {
            let rate = choice.rate(normal: normal)
            #expect(SpeechRateSteps.faster(SpeechRateSteps.slower(rate)) == rate, "\(choice.percent)%")
        }
    }

    @Test func theCurrentSpeedIsFoundAndAnOffGridOneIsNamedByItsShare() {
        #expect(SpeedChoice.matching(0.4, normal: normal) == SpeedChoice(percent: 80))
        #expect(SpeedChoice.matching(normal, normal: normal)?.isNormal == true)
        #expect(SpeedChoice.matching(0.73, normal: normal) == nil)
        #expect(SpeedChoice.fraction(of: 0.75, normal: normal) == 1.5)
    }

    /// Each speed keys its own sample: another speed chosen while one plays
    /// always takes effect. Fails if the speeds shared one control.
    @Test func eachSpeedHasItsOwnSampleControl() {
        let controls = SpeedChoice.all.map(\.previewControl)
        for (index, control) in controls.enumerated() {
            #expect(!controls[(index + 1)...].contains(control))
        }
    }

    // MARK: With the speech service

    /// A held look that fires a speed again after its sample finished
    /// changes nothing. Fails if the second activation changes the rate.
    @Test func aSpeedChosenAgainAfterItsSampleChangesNothing() {
        let harness = AudioHarness()
        let slow = SpeedChoice(percent: 80)

        harness.speech.stepRate(slow.step(normal: normal), from: slow.previewControl)
        harness.synthesizer.finish()
        harness.speech.stepRate(slow.step(normal: normal), from: slow.previewControl)

        #expect(harness.speech.speechRate == slow.rate(normal: normal))
        #expect(harness.synthesizer.requests.count == 2)
    }

    /// A different speed chosen while a sample plays is a deliberate change.
    @Test func anotherSpeedWhileASamplePlaysTakesEffect() {
        let harness = AudioHarness()
        let slow = SpeedChoice(percent: 80)
        let slower = SpeedChoice(percent: 70)

        harness.speech.stepRate(slow.step(normal: normal), from: slow.previewControl)
        harness.speech.stepRate(slower.step(normal: normal), from: slower.previewControl)

        #expect(harness.speech.speechRate == slower.rate(normal: normal))
    }
}

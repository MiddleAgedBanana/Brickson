import AVFoundation

/// Discrete speaking-rate steps for the Slower / Faster buttons in Settings.
/// Values snap to a fixed grid so repeated presses never drift, and clamp to
/// the synthesizer's limits.
nonisolated enum SpeechRateSteps {
    static let step: Float = 0.05

    static func slower(_ rate: Float) -> Float {
        clamped(snapped(rate) - step)
    }

    static func faster(_ rate: Float) -> Float {
        clamped(snapped(rate) + step)
    }

    static func canSlowDown(_ rate: Float) -> Bool {
        slower(rate) < rate
    }

    static func canSpeedUp(_ rate: Float) -> Bool {
        faster(rate) > rate
    }

    static func description(of rate: Float) -> String {
        let percent = Int((rate / AVSpeechUtteranceDefaultSpeechRate * 100).rounded())
        return percent == 100 ? "Normal" : "\(percent)% of normal"
    }

    private static func snapped(_ rate: Float) -> Float {
        (rate / step).rounded() * step
    }

    private static func clamped(_ rate: Float) -> Float {
        let lower = AVSpeechUtteranceMinimumSpeechRate
        let upper = AVSpeechUtteranceMaximumSpeechRate
        // Round to the grid's precision so 0.5 + 0.05 is exactly 0.55.
        let gridded = (rate * 100).rounded() / 100
        return min(max(gridded, lower), upper)
    }
}

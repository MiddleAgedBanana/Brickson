/// The speaking speeds Voice Settings offers, as fixed choices.
///
/// Each choice sets one speed, so choosing it again changes nothing. Slower
/// and Faster buttons could not promise that: a held look or a switch's
/// auto-select that fired one again after its sample finished would walk the
/// speed to the end of its range (AGENTS.md, invariant 10; docs/DECISIONS.md,
/// "Speed is a set of fixed choices"). The values sit on `SpeechRateSteps`'
/// grid, a twentieth of the synthesizer's range apart.
nonisolated struct SpeedChoice: Identifiable, Hashable, Sendable {
    /// Percent of the system's normal speaking rate.
    let percent: Int
    var id: Int { percent }

    /// Slowest first, in steps of a tenth of normal.
    static let all: [SpeedChoice] = [60, 70, 80, 90, 100, 110, 120].map(SpeedChoice.init(percent:))

    var isNormal: Bool { percent == 100 }

    /// The share of normal, for a localized percent format.
    var fraction: Double { Double(percent) / 100 }

    /// The synthesizer's rate for this speed, given its normal rate,
    /// rounded to the grid's precision.
    func rate(normal: Float) -> Float {
        (normal * Float(percent)).rounded() / 100
    }

    /// What choosing it does to the current rate: sets this speed, whatever
    /// the rate was.
    func step(normal: Float) -> (Float) -> Float {
        let rate = rate(normal: normal)
        return { _ in rate }
    }

    /// The control its sample is keyed to, one per speed.
    var previewControl: VoicePreviewControl { .speed(percent: percent) }

    /// The choice the current rate is, if it is one of them.
    static func matching(_ rate: Float, normal: Float) -> SpeedChoice? {
        all.first { abs($0.rate(normal: normal) - rate) < 0.001 }
    }

    /// How fast the current rate is, as a share of normal, whatever it is.
    static func fraction(of rate: Float, normal: Float) -> Double {
        (Double(rate / normal) * 100).rounded() / 100
    }
}

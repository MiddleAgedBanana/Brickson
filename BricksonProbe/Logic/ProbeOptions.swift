import CoreGraphics
import Foundation
import Observation

nonisolated enum ProbeTileSizing: String, CaseIterable, Identifiable, Sendable {
    case same = "Same sizes"
    case varied = "Varied sizes"
    var id: String { rawValue }
}

nonisolated enum ProbeTileShape: String, CaseIterable, Identifiable, Sendable {
    case rounded = "Rounded"
    case capsule = "Capsule"
    var id: String { rawValue }
}

nonisolated enum ProbeHover: String, CaseIterable, Identifiable, Sendable {
    case off = "No hover effect"
    case highlight = "Highlight"
    case lift = "Lift"
    var id: String { rawValue }
}

nonisolated enum ProbeIndicatorEffect: String, CaseIterable, Identifiable, Sendable {
    case variableColor = "Variable colour"
    case pulse = "Pulse"
    case breathe = "Breathe"
    var id: String { rawValue }
}

/// The trait on Speak sentence (A-17 and A3-U10).
nonisolated enum ProbeSpeakTrait: String, CaseIterable, Identifiable, Sendable {
    case noTrait = "No trait"
    case startsMediaSession = "Starts media session"
    case playsSound = "Plays sound"
    var id: String { rawValue }
}

/// Which assistive technology the probe asks to pause while it speaks
/// (A-18 and B1-U7).
nonisolated enum ProbePause: String, CaseIterable, Identifiable, Sendable {
    case nothing = "Pause nothing"
    case voiceOver = "Pause VoiceOver"
    case switchControl = "Pause Switch Control"
    var id: String { rawValue }
}

/// The Rings station's middle button: Apple's minimum, Brickson's quick
/// controls and its gaze tiles are each about one of these sizes.
nonisolated enum ProbeRingTarget: Int, CaseIterable, Identifiable, Sendable {
    case small = 44
    case medium = 88
    case large = 120
    var id: Int { rawValue }
    var side: CGFloat { CGFloat(rawValue) }
}

/// Fixed geometry the stations draw, kept here so it is tested and the
/// run sheet can quote it.
nonisolated enum ProbeGeometry {
    /// The Rings station's ring radii, in points from the middle button's
    /// centre.
    static let ringRadii: [CGFloat] = [25, 50, 100, 150, 200, 300]
    /// The Ruler station's grid: a line every `rulerStep` points, numbered
    /// every `rulerLabelEvery` points.
    static let rulerStep: CGFloat = 20
    static let rulerLabelEvery: CGFloat = 100
    /// The Look station's grid.
    static let lookColumns = 4
    static let lookRows = 3

    /// How much of its cell a Look tile fills: all of it with same sizes,
    /// and alternately all and 70% (a checkerboard) with varied sizes.
    static func lookTileScale(row: Int, column: Int, sizing: ProbeTileSizing) -> CGFloat {
        switch sizing {
        case .same: 1
        case .varied: (row + column).isMultiple(of: 2) ? 1 : 0.7
        }
    }
}

/// The settings each station reads, set from the probe's list so that no
/// option control sits on a station's own screen.
@Observable
final class ProbeOptions {
    var tileSizing = ProbeTileSizing.same
    var tileShape = ProbeTileShape.rounded
    var hover = ProbeHover.off
    var motionElsewhere = false
    var ringTarget = ProbeRingTarget.medium
    var speakTrait = ProbeSpeakTrait.noTrait
    var pause = ProbePause.nothing
    var postsLayoutChanged = false
    var indicatorEffect = ProbeIndicatorEffect.variableColor
    var keepsScreenAwake = true
    var containsGroups = true
    var sortsGroups = true
    var autocorrectionDisabled = false
    /// A voice's identifier, or nil for the system's default voice.
    var voiceIdentifier: String?
}

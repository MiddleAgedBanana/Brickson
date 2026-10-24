import CoreGraphics
import Testing
@testable import Brickson

/// How tall the first step of Set Up Step by Step keeps its opening words,
/// so Learn About Each Way starts where Family Setup's Set Up Step by Step
/// row started (`SettingsLanding`; docs/DECISIONS.md, "One chain engine for
/// dwell safety").
struct SettingsLandingTests {
    /// Both rows are measured in their screen's content, which starts at
    /// the top gutter; the first step's words start there too, and one
    /// row's spacing separates them from the link. Fails if the gutter or
    /// the spacing is left out, which would put the link below or above
    /// the row's place.
    @Test func theOpeningWordsReachWhereTheRowWas() {
        let landing = SettingsLanding()
        landing.guidedSetupRowTop = 152
        #expect(landing.firstStepOpeningHeight == 120)
        #expect(SettingsMetrics.gutter + landing.firstStepOpeningHeight + SettingsMetrics.rowSpacing == 152)
    }

    /// Fails if a row not measured yet (the first step opened some other
    /// way), or one nearer the top than the gutter and spacing, asks for a
    /// negative height.
    @Test func anUnmeasuredRowAsksForNoHeight() {
        let landing = SettingsLanding()
        #expect(landing.firstStepOpeningHeight == 0)
        landing.guidedSetupRowTop = 20
        #expect(landing.firstStepOpeningHeight == 0)
    }
}

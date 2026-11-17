import Foundation
import Testing
@testable import Brickson

/// The spacing scale (`Spacing`; docs/DECISIONS.md, "One spacing scale"):
/// its steps, and the input profiles' gaps that are made from them.
/// `EqualGapsTests` checks that the gaps the layout engine makes equal come
/// out equal.
struct SpacingTests {
    private typealias Profile = HomeLayout.Profile

    /// Fails if a step is added out of order, repeats another, or leaves
    /// the two-point grid (an odd value, or a fraction of a point).
    @Test func theStepsRunSmallestToLargestOnATwoPointGrid() {
        #expect(Spacing.steps.count == 7)
        for (smaller, larger) in zip(Spacing.steps, Spacing.steps.dropFirst()) {
            #expect(smaller < larger, "\(smaller) is not smaller than \(larger)")
        }
        for step in Spacing.steps {
            #expect(step > 0 && step.truncatingRemainder(dividingBy: 2) == 0, "\(step) is off the two-point grid")
        }
    }

    /// The steps are the values the app drew before it had a scale, so
    /// moving onto them changed no frame. Fails if a step changes: that
    /// changes what people see, and is a decision for the look, recorded in
    /// docs/DECISIONS.md with this list.
    @Test func theStepsAreTheValuesTheAppDrewBefore() {
        #expect(Spacing.steps == [2, 4, 6, 8, 12, 16, 24])
        #expect(Spacing.xxxSmall == 2)
        #expect(Spacing.xxSmall == 4)
        #expect(Spacing.xSmall == 6)
        #expect(Spacing.small == 8)
        #expect(Spacing.medium == 12)
        #expect(Spacing.large == 16)
        #expect(Spacing.xLarge == 24)
    }

    /// Home's fixed measures are steps, and touch's gaps are the ones the
    /// engine's fixed measures name. Fails if one of them leaves the scale
    /// or the two stop agreeing.
    @Test func homesFixedMeasuresAreSteps() {
        #expect(HomeLayout.margins.horizontal == Spacing.large)
        #expect(HomeLayout.margins.vertical == Spacing.small)
        #expect(HomeLayout.labelInset.horizontal == Spacing.xxSmall)
        #expect(HomeLayout.labelInset.vertical == Spacing.xSmall)
        #expect(HomeLayout.statusSpacing == Spacing.xxSmall)
        #expect(HomeLayout.controlSpacing == Spacing.small)
        #expect(HomeLayout.regionSpacing == Spacing.medium)
        #expect(HomeLayout.minimumRegionSpacing == Spacing.small + Spacing.xxxSmall)
        #expect(Profile.touch.controlSpacing == HomeLayout.controlSpacing)
        #expect(Profile.touch.regionSpacing == HomeLayout.regionSpacing)
        #expect(Profile.touch.minimumRegionSpacing == HomeLayout.minimumRegionSpacing)
    }

    /// Settings' gutter and its gap between rows are one step, and the gap
    /// beside Settings' first row is that same gap (`SettingsRowPlace`).
    @Test func settingsGapsAreSteps() {
        #expect(SettingsMetrics.gutter == Spacing.large)
        #expect(SettingsMetrics.rowSpacing == Spacing.large)
        #expect(SettingsRowPlace.columnSpacing == SettingsMetrics.rowSpacing)
        #expect(SettingsSafetyBar.gapBelow == Spacing.small)
    }

    /// Every profile's gap between controls is a step, but Eye Tracking's
    /// and the late stage's: the reference app's 12-point gaze gap (the
    /// medium step) on a 13-inch iPad at about 132 points per inch, held at
    /// the densest supported screens' 163, as the profile's floors are.
    /// Fails if a profile's gap leaves the scale, or Eye Tracking's stops
    /// being that physical size.
    @Test func everyProfilesGapIsAStepButTheGazeGapHeldAtTheDensestScreen() {
        for profile in Profile.allCases {
            switch profile {
            case .eyeTracking, .lateStage:
                #expect(profile.controlSpacing == (Spacing.medium * 163 / 132).rounded(), "\(profile)")
                #expect(!Spacing.steps.contains(profile.controlSpacing), "\(profile)")
            case .touch, .switchControl, .headTracking:
                #expect(Spacing.steps.contains(profile.controlSpacing), "\(profile): \(profile.controlSpacing)")
            }
            #expect(profile.minimumRegionSpacing == profile.controlSpacing + Spacing.xxxSmall, "\(profile)")
            #expect(profile.regionSpacing == profile.controlSpacing + Spacing.xxSmall, "\(profile)")
        }
    }
}

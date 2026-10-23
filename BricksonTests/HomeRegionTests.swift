import Testing
@testable import Brickson

/// The order in which VoiceOver, Switch Control and Full Keyboard Access
/// reach Home's regions. The running app's order is checked in
/// `HomeAccessibilityOrderTests` (UI tests).
struct HomeRegionTests {
    /// Fails if a change to the priorities lets another region come before
    /// Yes, No and Emergency, or swaps two regions.
    @Test func quickControlsComeFirstThenTheMessageCategoriesAndPhrases() {
        let order = HomeRegion.allCases.sorted { $0.sortPriority > $1.sortPriority }
        #expect(order == [.safety, .message, .categories, .phrases])
    }

    /// Fails if two regions tie, which leaves SwiftUI to order them by
    /// where they are (the message would then come first), or if a region
    /// falls to the default priority of zero, where it would tie with the
    /// library warnings.
    @Test func everyRegionHasItsOwnPriorityAboveTheDefault() {
        let priorities = HomeRegion.allCases.map(\.sortPriority)
        #expect(Set(priorities).count == priorities.count)
        #expect(priorities.allSatisfy { $0 > 0 })
    }

    /// Fails if Again or Settings, given `lastInRegion`, could come before
    /// the controls beside them, which keep the default priority of zero.
    @Test func lastInRegionComesAfterTheDefault() {
        #expect(HomeRegion.lastInRegion < 0)
    }

    /// Fails if two regions share an identifier, so a UI test could not
    /// tell which region holds a control.
    @Test func everyRegionHasItsOwnIdentifier() {
        let identifiers = HomeRegion.allCases.map(\.identifier)
        #expect(Set(identifiers).count == identifiers.count)
        #expect(!identifiers.contains(""))
    }
}

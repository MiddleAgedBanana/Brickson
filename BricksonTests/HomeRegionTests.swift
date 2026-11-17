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

    /// Fails if Stop could come after the first category, or the first
    /// category after the others, which keep the default of zero: in the
    /// band the first category sits under Stop, lower than the others'
    /// tops, so only these priorities put it first.
    @Test func stopThenTheFirstCategoryComeBeforeTheDefault() {
        #expect(HomeRegion.firstInRegion > HomeRegion.secondInRegion)
        #expect(HomeRegion.secondInRegion > 0)
    }

    /// Fails if Home declares its regions in an order other than the one
    /// their priorities give. Until SwiftUI has applied
    /// `accessibilitySortPriority`, it hands assistive technologies a
    /// container's elements in the order they are declared; Home declares
    /// its regions in `allCases` order, so that order must already be the
    /// one they are reached in. Declaring them top to bottom, as Home did,
    /// put the message before Yes, No and Emergency
    /// (docs/log/2026-11-17-home-order-before-sorting.md).
    @Test func homeDeclaresItsRegionsInTheOrderTheyAreReached() {
        let order = HomeRegion.allCases.sorted { $0.sortPriority > $1.sortPriority }
        #expect(HomeRegion.allCases == order)
    }

    /// Fails if the safety row's declared order (`safetyRowOrder`) differs
    /// from the order its controls' priorities and places give, in any
    /// layout the engine makes: SwiftUI reaches controls of equal priority
    /// by where they are, top to bottom, then leading to trailing. Home
    /// once declared the row as it stands on screen: Emergency first on
    /// regular widths, and Again before Get Attention on compact ones,
    /// which assistive technologies were offered before the sort applied.
    @Test func theSafetyRowIsDeclaredInTheOrderItIsReached() {
        var wrong: [String] = []
        for (layout, _, context) in HomeLayoutEngineTests.everyLayout {
            let reached = HomeLayout.Slot.safetyRow.sorted { first, second in
                let priorities = (HomeRegion.sortPriority(inSafetyRow: first), HomeRegion.sortPriority(inSafetyRow: second))
                if priorities.0 != priorities.1 {
                    return priorities.0 > priorities.1
                }
                let frames = (layout.frame(first), layout.frame(second))
                if abs(frames.0.minY - frames.1.minY) > 0.5 {
                    return frames.0.minY < frames.1.minY
                }
                return frames.0.minX < frames.1.minX
            }
            if reached != HomeRegion.safetyRowOrder {
                wrong.append("\(context): \(reached)")
            }
        }
        #expect(wrong.isEmpty, "\(wrong.count) layouts, first: \(wrong.prefix(3))")
        #expect(Set(HomeRegion.safetyRowOrder) == Set(HomeLayout.Slot.safetyRow))
        #expect(HomeRegion.safetyRowOrder.count == HomeLayout.Slot.safetyRow.count)
    }

    /// Fails if Yes, No, Emergency and Get Attention are not reached before
    /// Again, whatever order the row is declared in (invariant 10).
    @Test func theQuickControlsComeBeforeAgainInTheSafetyRow() {
        #expect(Array(HomeRegion.safetyRowOrder.prefix(4)) == [.yes, .no, .emergency, .getAttention])
        #expect(HomeRegion.safetyRowOrder.last == .again)
    }

    /// Fails if two regions share an identifier, so a UI test could not
    /// tell which region holds a control.
    @Test func everyRegionHasItsOwnIdentifier() {
        let identifiers = HomeRegion.allCases.map(\.identifier)
        #expect(Set(identifiers).count == identifiers.count)
        #expect(!identifiers.contains(""))
    }
}

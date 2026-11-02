import Foundation
import Testing
@testable import Brickson

/// What a Home control draws around its words in each state, with Show
/// Borders off and on, in light and dark mode (`HomeButtonLook`). The
/// colours themselves are measured in `PaletteTests`.
struct HomeButtonLookTests {
    private typealias Ring = HomeButtonLook.Ring

    /// Every state a Home control can be in: off, or on and any mix of
    /// selected and pressed.
    private static let states: [(isEnabled: Bool, isSelected: Bool, isPressed: Bool)] = [
        (false, false, false),
        (false, true, false),
        (true, false, false),
        (true, true, false),
        (true, false, true),
        (true, true, true),
    ]

    /// What a person sees at each half point in from the edge, as far as a
    /// ring may reach: white, black or the fill (nil), in dark mode or in
    /// light.
    private static func bands(_ look: HomeButtonLook, darkMode: Bool) -> [Bool?] {
        let samples = Int((HomeButtonLook.maximumDepth * 2).rounded(.up))
        return (0..<samples).map { index in
            look.ink(atDepth: (CGFloat(index) + 0.5) / 2)?.isWhite(inDarkMode: darkMode)
        }
    }

    /// The points in from the edge where two looks show something
    /// different.
    private static func pointsThatDiffer(_ first: HomeButtonLook, _ second: HomeButtonLook, darkMode: Bool) -> CGFloat {
        let differing = zip(bands(first, darkMode: darkMode), bands(second, darkMode: darkMode)).filter { $0 != $1 }
        return CGFloat(differing.count) / 2
    }

    /// Every combination of the two things that give a control its edge.
    private static let settings: [(showsBorders: Bool, darkMode: Bool)] = [
        (false, false), (false, true), (true, false), (true, true),
    ]

    /// Fails if light mode with Show Borders off changes how a control
    /// looks: these are the rings Home drew before the setting was read.
    @Test func inLightModeWithShowBordersOffEveryStateLooksAsItDidBefore() {
        func look(_ isEnabled: Bool, _ isSelected: Bool, _ isPressed: Bool) -> HomeButtonLook {
            HomeButtonLook(
                isEnabled: isEnabled, isSelected: isSelected, isPressed: isPressed,
                showsBorders: false, darkMode: false
            )
        }
        let selection = Ring(ink: .white, inset: 2, width: 3)
        let pressed = Ring(ink: .primary, inset: 0, width: 3)
        let border = Ring(ink: .primary, inset: 0, width: 2)

        #expect(look(true, false, false).isFilled)
        #expect(look(true, false, false).rings == [])
        #expect(look(true, true, false).rings == [selection])
        #expect(look(true, false, true).rings == [pressed])
        #expect(look(true, true, true).rings == [selection, pressed])
        for isSelected in [false, true] {
            #expect(!look(false, isSelected, false).isFilled)
            #expect(look(false, isSelected, false).rings == [border])
        }
    }

    /// Fails if, with Show Borders on or in dark mode, any control in any
    /// state lacks a primary-ink border at least `borderWidth` deep at its
    /// very edge, or if either fills or empties a control.
    @Test func withShowBordersOnOrInDarkModeEveryControlHasAPrimaryInkEdge() {
        for setting in Self.settings where setting.showsBorders || setting.darkMode {
            for state in Self.states {
                let look = HomeButtonLook(
                    isEnabled: state.isEnabled, isSelected: state.isSelected,
                    isPressed: state.isPressed, showsBorders: setting.showsBorders, darkMode: setting.darkMode
                )
                let plain = HomeButtonLook(
                    isEnabled: state.isEnabled, isSelected: state.isSelected,
                    isPressed: state.isPressed, showsBorders: false, darkMode: false
                )
                for depth in stride(from: CGFloat(0.25), to: HomeButtonLook.borderWidth, by: 0.5) {
                    #expect(look.ink(atDepth: depth) == .primary, "\(state), \(setting), \(depth)pt in from the edge")
                }
                #expect(look.isFilled == plain.isFilled, "\(state), \(setting)")
            }
        }
    }

    /// Fails if a control in dark mode looks any different from the same
    /// control with Show Borders on, in any state. A fill's own edge stands
    /// out only about 3.5:1 from the black screen, and Apple's audit read
    /// two neighbouring phrase tiles' first lines as one line across the
    /// black gap between them, belonging to no control (pull request #74):
    /// so in dark mode every control draws the border Show Borders draws,
    /// and the pressed and selection rings that go with it
    /// (docs/DECISIONS.md, "Show Borders and the Large Content Viewer on
    /// Home").
    @Test func inDarkModeEveryControlLooksAsItDoesWithShowBorders() {
        for state in Self.states {
            func look(showsBorders: Bool, darkMode: Bool) -> HomeButtonLook {
                HomeButtonLook(
                    isEnabled: state.isEnabled, isSelected: state.isSelected,
                    isPressed: state.isPressed, showsBorders: showsBorders, darkMode: darkMode
                )
            }
            #expect(look(showsBorders: false, darkMode: true) == look(showsBorders: true, darkMode: false), "\(state)")
            #expect(look(showsBorders: true, darkMode: true) == look(showsBorders: true, darkMode: false), "\(state)")
        }
    }

    /// Fails if a ring could reach past a label's margin, measured along
    /// the straight edges: no ring deeper than the label inset plus half
    /// `WordFit`'s slack, where a label's words sit at the size it chose; the
    /// rings drawn from the edge (the borders and the pressed ring) within
    /// the label inset itself, which even a label SwiftUI shrinks to fit
    /// never crosses; and a vertical inset no smaller. Also fails if a ring
    /// has no width or starts outside the control.
    @Test func everyRingStaysInTheLabelsMargin() {
        #expect(HomeButtonLook.maximumDepth == HomeLayout.labelInset.horizontal + WordFit.widthSlack / 2)
        #expect(HomeLayout.labelInset.vertical >= HomeButtonLook.maximumDepth)
        for setting in Self.settings {
            for state in Self.states {
                let look = HomeButtonLook(
                    isEnabled: state.isEnabled, isSelected: state.isSelected,
                    isPressed: state.isPressed, showsBorders: setting.showsBorders, darkMode: setting.darkMode
                )
                for ring in look.rings {
                    let context = "\(state), \(setting), \(ring)"
                    #expect(ring.inset >= 0, "\(context)")
                    #expect(ring.width > 0, "\(context)")
                    #expect(ring.depth <= HomeButtonLook.maximumDepth, "\(context)")
                    if ring.inset == 0 {
                        #expect(ring.depth <= HomeLayout.labelInset.horizontal, "\(context)")
                    }
                }
            }
        }
    }

    /// Fails if a ring could reach the words of a control that shows
    /// selected, Emergency or a category: its label inset is set back to
    /// the usual one, which the selection ring passes. A label SwiftUI
    /// shrinks to fit spreads to its inset, and Emergency's, a column wide
    /// on a phone at the largest text sizes, did: its last letter met the
    /// ring while the emergency phrases showed, and the rendered-label UI
    /// test read "Emergenc" (PR #38's CI). A category's label shrinks the
    /// same way at the largest sizes.
    @Test func noRingReachesTheWordsOfAControlThatShowsSelected() {
        for setting in Self.settings {
            for state in Self.states {
                let look = HomeButtonLook(
                    isEnabled: state.isEnabled, isSelected: state.isSelected,
                    isPressed: state.isPressed, showsBorders: setting.showsBorders, darkMode: setting.darkMode
                )
                for ring in look.rings {
                    #expect(
                        ring.depth < HomeLayout.selectableSideInset,
                        "\(state), \(setting), \(ring)"
                    )
                }
            }
        }
    }

    /// Fails if, in light or dark mode, with Show Borders off or on, a
    /// press does not visibly change a control, selected or not, or a
    /// selected control looks like one that is not. "Visibly" is at least
    /// a point of difference all the way round. Without the selection ring
    /// taking the screen's ink with the border (under Show Borders, and in
    /// dark mode), a selected control in dark mode would look the same
    /// pressed as not: primary ink and the usual selection ring are both
    /// white there.
    @Test func pressedSelectedAndNeitherLookDifferentInBothAppearances() {
        for (showsBorders, darkMode) in Self.settings {
            let setting = "Show Borders \(showsBorders ? "on" : "off"), \(darkMode ? "dark" : "light")"
            func look(isSelected: Bool, isPressed: Bool) -> HomeButtonLook {
                HomeButtonLook(
                    isEnabled: true, isSelected: isSelected, isPressed: isPressed,
                    showsBorders: showsBorders, darkMode: darkMode
                )
            }
            for isSelected in [false, true] {
                let resting = look(isSelected: isSelected, isPressed: false)
                let pressed = look(isSelected: isSelected, isPressed: true)
                let points = Self.pointsThatDiffer(resting, pressed, darkMode: darkMode)
                #expect(points >= 1, "a press changes \(points)pt, \(isSelected ? "selected" : "not selected"), \(setting)")
            }
            let unselected = look(isSelected: false, isPressed: false)
            let selected = look(isSelected: true, isPressed: false)
            let points = Self.pointsThatDiffer(unselected, selected, darkMode: darkMode)
            #expect(points >= 1, "selection changes \(points)pt, \(setting)")
        }
    }

    /// Fails if primary ink and the screen's ink are ever the same, which
    /// the Show Borders selection ring depends on, or if white is not white
    /// in both appearances.
    @Test func theInksAreBlackAndWhiteAsDocumented() {
        #expect(!HomeButtonLook.Ink.primary.isWhite(inDarkMode: false))
        #expect(HomeButtonLook.Ink.primary.isWhite(inDarkMode: true))
        #expect(HomeButtonLook.Ink.screen.isWhite(inDarkMode: false))
        #expect(!HomeButtonLook.Ink.screen.isWhite(inDarkMode: true))
        #expect(HomeButtonLook.Ink.white.isWhite(inDarkMode: false))
        #expect(HomeButtonLook.Ink.white.isWhite(inDarkMode: true))
    }

    /// Fails if the ink at a depth is not the last ring drawn there: the
    /// pressed ring is drawn over the selection ring and the border.
    @Test func theLastRingDrawnShows() {
        let look = HomeButtonLook(isEnabled: true, isSelected: true, isPressed: true, showsBorders: true, darkMode: false)
        #expect(look.ink(atDepth: 0.5) == .primary)
        #expect(look.ink(atDepth: 3.5) == .primary)
        #expect(look.ink(atDepth: 4.5) == .screen)
        #expect(look.ink(atDepth: 5.5) == nil)
        let plain = HomeButtonLook(isEnabled: true, isSelected: false, isPressed: false, showsBorders: false, darkMode: false)
        #expect(plain.ink(atDepth: 0.5) == nil)
    }
}

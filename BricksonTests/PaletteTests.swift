import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Brickson

/// Invariant 6: contrast is measured, never eyeballed. Every colour token
/// has four values, one for each appearance a person can choose (light,
/// dark, and each with Increase Contrast), and every pair the app draws is
/// measured in all four: the words on every fill at 4.5:1 or better
/// (control labels are normal-size text under WCAG), and every fill's edge,
/// or the border that carries it, at 3:1 or better against the screen
/// behind it (docs/DECISIONS.md, "Colour tokens in four appearances").
///
/// The contrast budget (`everyFillKeepsItsContrastBudget`) asks both at
/// once, on each screen level a window can have, and the fills must tell
/// apart in every colour vision (`theFillsTellApartInEveryVision`). Where
/// today's values miss, the miss is a named, strict known issue: it is
/// listed in docs/HANDOFF.md, *Known gaps*, for the design that chooses new
/// values, and the test fails the day a value passes until its line here
/// is removed.
///
/// Reduce Transparency is not a trait colours resolve against, and every
/// fill here is opaque, so it changes none of these values. How system
/// button styles draw under these settings is not something a unit test
/// can see; the UI tests' accessibility audit and a device check cover it.
struct PaletteTests {
    private typealias SRGB = ColourArithmetic.SRGB

    /// The four appearances a person can choose, one for each slot of a
    /// token.
    private enum Appearance: CaseIterable, Hashable {
        case light
        case dark
        case increasedContrastLight
        case increasedContrastDark

        var isDark: Bool {
            self == .dark || self == .increasedContrastDark
        }

        var hasIncreasedContrast: Bool {
            self == .increasedContrastLight || self == .increasedContrastDark
        }

        var name: String {
            switch self {
            case .light: "light"
            case .dark: "dark"
            case .increasedContrastLight: "light with Increase Contrast"
            case .increasedContrastDark: "dark with Increase Contrast"
            }
        }

        /// The same appearance with Increase Contrast off.
        var withoutIncreasedContrast: Appearance {
            isDark ? .dark : .light
        }

        /// UIKit's traits for this appearance. Lifted, the window is at the
        /// elevated level, where iPad multitasking can put it: in dark mode
        /// its screen is a gray, not black (docs/HANDOFF.md, *Known gaps*).
        func traits(lifted: Bool = false) -> UITraitCollection {
            let style: UIUserInterfaceStyle = isDark ? .dark : .light
            let contrast: UIAccessibilityContrast = hasIncreasedContrast ? .high : .normal
            return UITraitCollection { traits in
                traits.userInterfaceStyle = style
                traits.accessibilityContrast = contrast
                if lifted {
                    traits.userInterfaceLevel = .elevated
                }
            }
        }
    }

    /// A colour token in the asset catalog and the value each of its four
    /// slots holds.
    private struct Token {
        let asset: String
        let light: String
        let dark: String
        let increasedContrastLight: String
        let increasedContrastDark: String

        init(_ asset: String, light: String, dark: String, increasedContrastLight: String, increasedContrastDark: String) {
            self.asset = asset
            self.light = light
            self.dark = dark
            self.increasedContrastLight = increasedContrastLight
            self.increasedContrastDark = increasedContrastDark
        }

        /// One value in all four slots.
        init(_ asset: String, all value: String) {
            self.init(asset, light: value, dark: value, increasedContrastLight: value, increasedContrastDark: value)
        }

        func value(in appearance: Appearance) -> String {
            switch appearance {
            case .light: light
            case .dark: dark
            case .increasedContrastLight: increasedContrastLight
            case .increasedContrastDark: increasedContrastDark
            }
        }
    }

    /// Every colour token's four values, as measured in `Palette`'s table.
    /// Today each holds the value the app always had, in all four, so
    /// nothing looks different; choosing new values is design work, and
    /// a value enters here only with the budget below measured.
    private static let tokens = [
        Token("AccentColor", all: "#0A60D6"),
        Token("ControlFill", all: "#5A6474"),
        Token("EmergencyFill", all: "#C8161E"),
        Token("AttentionFill", all: "#B45309"),
        Token("StopFill", all: "#0F766E"),
        Token("FillLabel", all: "#FFFFFF"),
    ]

    /// Where the fills are drawn, and so what meets the screen at their
    /// edge.
    private enum Surface: CaseIterable, Hashable {
        /// Home's controls and Settings' safety bar (`HomeButtonStyle`),
        /// drawn as `HomeButtonLook` says, with Show Borders off (on, it
        /// only adds a border): the fill's own edge in light mode, the
        /// primary-ink border in dark mode.
        case homeControl
        /// The system's bordered prominent button tinted with a fill:
        /// Settings' rows (`SettingsRowButtonStyle`), Voice Settings'
        /// speeds and setup's choices. The system draws the fill with no
        /// border.
        case systemButton
        /// The typing fields' 2-point edge, Home's message field and the
        /// Library's `LibraryTextField`: the control fill drawn as a line
        /// on the screen, with no words on it.
        case fieldEdge

        var fills: [String] {
            switch self {
            case .homeControl: Palette.assetNames
            case .systemButton: ["AccentColor", "ControlFill"]
            case .fieldEdge: ["ControlFill"]
            }
        }

        var carriesWords: Bool {
            self != .fieldEdge
        }

        var name: String {
            switch self {
            case .homeControl: "on Home"
            case .systemButton: "as a system button"
            case .fieldEdge: "as a typing field's edge"
            }
        }
    }

    /// One place the budget measures an edge.
    private struct BudgetCase: Hashable {
        let surface: Surface
        let fill: String
        let appearance: Appearance
        let lifted: Bool
    }

    /// Where today's values miss the budget's 3:1 edge: a fill drawn with
    /// no border on the lifted dark screen, whose gray leaves it under
    /// 3:1 (2.59 to 2.96:1). Breaches of invariant 6 this test found, not
    /// exceptions to it: the owner decides whether they wait for the
    /// design that chooses new values or get a border now (docs/HANDOFF.md,
    /// *Known gaps*); remove a line when its value passes.
    private static let knownEdgeFailures: Set<BudgetCase> = [
        BudgetCase(surface: .systemButton, fill: "AccentColor", appearance: .dark, lifted: true),
        BudgetCase(surface: .systemButton, fill: "AccentColor", appearance: .increasedContrastDark, lifted: true),
        BudgetCase(surface: .systemButton, fill: "ControlFill", appearance: .dark, lifted: true),
        BudgetCase(surface: .systemButton, fill: "ControlFill", appearance: .increasedContrastDark, lifted: true),
        BudgetCase(surface: .fieldEdge, fill: "ControlFill", appearance: .dark, lifted: true),
        BudgetCase(surface: .fieldEdge, fill: "ControlFill", appearance: .increasedContrastDark, lifted: true),
    ]

    /// How far apart, in CIEDE2000, two fills that mean different things
    /// must be: the colour search's step for colours that must not be
    /// taken for each other, with typical vision and each simulated
    /// dichromacy (its rules R3 and R4; docs/DECISIONS.md, "Colour tokens
    /// in four appearances").
    private static let tellApart = 15.0

    /// Two fills that look alike to someone with `vision` in `appearance`.
    private struct Lookalike: Hashable {
        let fills: [String]
        let vision: ColourArithmetic.Vision
        let appearance: Appearance

        init(_ first: String, _ second: String, _ vision: ColourArithmetic.Vision, _ appearance: Appearance) {
            fills = [first, second].sorted()
            self.vision = vision
            self.appearance = appearance
        }
    }

    /// The fills today's values leave under `tellApart`, in every
    /// appearance because each token holds one value in all four (split a
    /// line by appearance when a slot changes). Emergency and Get Attention
    /// come to 2.7 for deuteranopia, nearly one colour. Their words, icons
    /// and places still tell them apart, so nothing depends on colour
    /// alone; these are inputs for the design that chooses new values
    /// (docs/HANDOFF.md, *Known gaps*).
    private static let knownLookalikes: Set<Lookalike> = {
        let pairs: [(String, String, ColourArithmetic.Vision)] = [
            ("ControlFill", "StopFill", .protanopia),
            ("EmergencyFill", "AttentionFill", .protanopia),
            ("ControlFill", "StopFill", .deuteranopia),
            ("EmergencyFill", "AttentionFill", .deuteranopia),
            ("AccentColor", "ControlFill", .tritanopia),
            ("AccentColor", "StopFill", .tritanopia),
            ("ControlFill", "StopFill", .tritanopia),
            ("EmergencyFill", "AttentionFill", .tritanopia),
        ]
        var result: Set<Lookalike> = []
        for (first, second, vision) in pairs {
            for appearance in Appearance.allCases {
                result.insert(Lookalike(first, second, vision, appearance))
            }
        }
        return result
    }()

    private static let white = SRGB(red: 1, green: 1, blue: 1)
    private static let black = SRGB(red: 0, green: 0, blue: 0)

    /// A token as UIKit resolves it from the asset catalog in `traits`.
    private func token(named name: String, in traits: UITraitCollection) throws -> SRGB {
        let color = try #require(
            UIColor(named: name, in: .main, compatibleWith: traits),
            "\(name) is missing from the asset catalog"
        )
        return Self.srgb(color.resolvedColor(with: traits))
    }

    /// The screen behind Home, Settings and setup: the system background.
    private func screen(_ appearance: Appearance, lifted: Bool) -> SRGB {
        Self.srgb(UIColor.systemBackground.resolvedColor(with: appearance.traits(lifted: lifted)))
    }

    /// What meets the screen at the edge of `fill` drawn on `surface`: the
    /// fill, or a border drawn over its edge.
    private func edgeColour(of fill: SRGB, on surface: Surface, in appearance: Appearance) -> SRGB {
        guard surface == .homeControl else { return fill }
        let look = HomeButtonLook(
            isEnabled: true,
            isSelected: false,
            isPressed: false,
            showsBorders: false,
            darkMode: appearance.isDark
        )
        guard let ink = look.ink(atDepth: 0) else { return fill }
        return ink.isWhite(inDarkMode: appearance.isDark) ? Self.white : Self.black
    }

    // Plain loops rather than parameterized tests, so each check shows up by
    // name in the test log.

    /// Every token holds the value measured for it in each appearance, so
    /// a typo in the asset catalog cannot pass unnoticed just because it
    /// still happens to clear the contrast bars, and every token the app
    /// draws is in the table.
    @Test func everyTokenHoldsItsValueInEachAppearance() throws {
        #expect(
            Set(Self.tokens.map(\.asset)) == Set(Palette.assetNames + [Palette.fillLabelAssetName])
        )
        for token in Self.tokens {
            for appearance in Appearance.allCases {
                let resolved = try self.token(named: token.asset, in: appearance.traits())
                #expect(resolved.hex == token.value(in: appearance), "\(token.asset), \(appearance.name)")
            }
        }
    }

    /// Every colour set in the asset catalog is a token in the table above,
    /// with the four slots Apple's colour sets offer: any (light), dark,
    /// high contrast, and dark with high contrast, each for every device
    /// and in sRGB, the space this file's arithmetic measures. Read from
    /// the catalog's source, which the simulator can reach on the machine
    /// that built the tests; the compiled catalog keeps no slot it does
    /// not need.
    @Test func everyTokenHasFourSlots() throws {
        let catalog = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Brickson/Resources/Assets.xcassets")
        let names = try FileManager.default.contentsOfDirectory(atPath: catalog.path(percentEncoded: false))
            .filter { $0.hasSuffix(".colorset") }
            .map { String($0.dropLast(".colorset".count)) }
        #expect(Set(names) == Set(Self.tokens.map(\.asset)))
        let expected: Set<Set<String>> = [
            [],
            ["luminosity=dark"],
            ["contrast=high"],
            ["luminosity=dark", "contrast=high"],
        ]
        for name in names.sorted() {
            let data = try Data(contentsOf: catalog.appending(path: "\(name).colorset/Contents.json"))
            let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            let entries = try #require(object["colors"] as? [[String: Any]], "\(name) has no colours")
            var slots: [Set<String>] = []
            for entry in entries {
                #expect(entry["idiom"] as? String == "universal", "\(name): a slot not for every device")
                let color = entry["color"] as? [String: Any]
                #expect(color?["color-space"] as? String == "srgb", "\(name): a slot not in sRGB")
                let appearances = entry["appearances"] as? [[String: String]] ?? []
                slots.append(Set(appearances.map { "\($0["appearance"] ?? "")=\($0["value"] ?? "")" }))
            }
            #expect(slots.count == 4, "\(name) has \(slots.count) slots")
            #expect(Set(slots) == expected, "\(name)'s slots: \(slots)")
        }
    }

    /// The contrast budget (E-02 of the stage 5 foundations): on every
    /// surface, in each appearance, the words on each fill at 4.5:1, and
    /// what meets the screen at the fill's edge, the fill or the border
    /// drawn over it, at 3:1, on the base screen and on the lifted one.
    /// In dark mode the two pull against each other: white words at 4.5:1
    /// leave a fill at most 3.78:1 from the lifted gray, so a border must
    /// carry the edge there or the fill falls under 3:1. The misses today
    /// are `knownEdgeFailures`.
    @Test func everyFillKeepsItsContrastBudget() throws {
        for surface in Surface.allCases {
            for name in surface.fills {
                for appearance in Appearance.allCases {
                    let traits = appearance.traits()
                    let fill = try token(named: name, in: traits)
                    if surface.carriesWords {
                        let label = try token(named: Palette.fillLabelAssetName, in: traits)
                        let words = ColourArithmetic.contrast(label, fill)
                        #expect(words >= 4.5, "words on \(name) \(surface.name), \(appearance.name): \(words):1")
                    }
                    let carrier = edgeColour(of: fill, on: surface, in: appearance)
                    for lifted in [false, true] {
                        let ratio = ColourArithmetic.contrast(carrier, screen(appearance, lifted: lifted))
                        let place = "\(name)'s edge \(surface.name), \(appearance.name)\(lifted ? ", lifted" : ""): \(ratio):1"
                        let known = BudgetCase(surface: surface, fill: name, appearance: appearance, lifted: lifted)
                        if Self.knownEdgeFailures.contains(known) {
                            withKnownIssue("docs/DECISIONS.md, \"Colour tokens in four appearances\": \(place)") {
                                #expect(ratio >= 3, "\(place)")
                            }
                        } else {
                            #expect(ratio >= 3, "\(place)")
                        }
                    }
                }
            }
        }
    }

    /// Increase Contrast never lowers what a token gives: in each Increase
    /// Contrast appearance, the words on every fill and every fill against
    /// the screen measure at least what they do without it. Measured on
    /// the base screen, which Increase Contrast leaves white or black: the
    /// lifted gray is itself lighter with Increase Contrast, an Apple value
    /// no token can change, and the budget holds 3:1 there.
    @Test func increasedContrastNeverLowersContrast() throws {
        for name in Palette.assetNames {
            for appearance in [Appearance.increasedContrastLight, .increasedContrastDark] {
                let plain = appearance.withoutIncreasedContrast
                let fill = try token(named: name, in: appearance.traits())
                let plainFill = try token(named: name, in: plain.traits())
                let words = ColourArithmetic.contrast(try token(named: Palette.fillLabelAssetName, in: appearance.traits()), fill)
                let plainWords = ColourArithmetic.contrast(try token(named: Palette.fillLabelAssetName, in: plain.traits()), plainFill)
                #expect(words >= plainWords, "words on \(name), \(appearance.name): \(words):1, without it \(plainWords):1")
                let edge = ColourArithmetic.contrast(fill, screen(appearance, lifted: false))
                let plainEdge = ColourArithmetic.contrast(plainFill, screen(plain, lifted: false))
                #expect(edge >= plainEdge, "\(name) on the screen, \(appearance.name): \(edge):1, without it \(plainEdge):1")
            }
        }
    }

    /// Fills that mean different things never look alike: every two at
    /// least `tellApart` from each other with typical colour vision and as
    /// simulated for protanopia, deuteranopia and tritanopia, in each
    /// appearance. "Avoid using the same color to mean different things"
    /// (Apple's guidelines, Color). Greyscale is not asked: with words at
    /// 4.5:1 there is no room for these fills to differ in gray (the colour
    /// search proved it), so their words and icons carry it, as Apple asks.
    @Test func theFillsTellApartInEveryVision() throws {
        let names = Palette.assetNames
        for appearance in Appearance.allCases {
            let traits = appearance.traits()
            for (index, first) in names.enumerated() {
                for second in names.dropFirst(index + 1) {
                    let one = try token(named: first, in: traits)
                    let two = try token(named: second, in: traits)
                    for vision in ColourArithmetic.Vision.allCases {
                        let distance = ColourArithmetic.difference(one, two, as: vision)
                        let place = "\(first) and \(second), \(vision), \(appearance.name): \(distance)"
                        if Self.knownLookalikes.contains(Lookalike(first, second, vision, appearance)) {
                            withKnownIssue("docs/DECISIONS.md, \"Colour tokens in four appearances\": \(place)") {
                                #expect(distance >= Self.tellApart, "\(place)")
                            }
                        } else {
                            #expect(distance >= Self.tellApart, "\(place)")
                        }
                    }
                }
            }
        }
    }

    /// Settings and setup draw `Palette.screen`. Changing it, or the UIKit
    /// colour it is made from, to anything but the system background
    /// measured below fails this. UIKit checks `screenColor` in all four
    /// appearances. SwiftUI resolves `screen` itself in light and dark: a
    /// SwiftUI colour turned back into a `UIColor` keeps one appearance
    /// only, and SwiftUI's environment cannot set Increase Contrast.
    @Test func theFamilyScreensUseTheMeasuredScreen() {
        for appearance in Appearance.allCases {
            let drawn = Palette.screenColor.resolvedColor(with: appearance.traits())
            let measured = UIColor.systemBackground.resolvedColor(with: appearance.traits())
            #expect(drawn == measured, "Palette.screenColor, \(appearance.name)")
        }
        var resolved: [Color.Resolved] = []
        for scheme in [ColorScheme.light, .dark] {
            var environment = EnvironmentValues()
            environment.colorScheme = scheme
            let drawn = Palette.screen.resolve(in: environment)
            let measured = Color(uiColor: .systemBackground).resolve(in: environment)
            #expect(drawn == measured, "Palette.screen, \(scheme)")
            resolved.append(drawn)
        }
        // Light and dark differ, so the environment reached the colour.
        #expect(resolved.first != resolved.last)
    }

    /// Every fill's own edge against the base screen, in each appearance.
    @Test func everyFillStandsOutFromTheScreen() throws {
        for name in Palette.assetNames {
            for appearance in Appearance.allCases {
                let ratio = ColourArithmetic.contrast(screen(appearance, lifted: false), try token(named: name, in: appearance.traits()))
                #expect(ratio >= 3, "\(name) against the screen, \(appearance.name): \(ratio):1")
            }
        }
    }

    /// The fill label on every fill, in each appearance.
    @Test func theFillLabelIsReadableOnEveryFill() throws {
        for name in Palette.assetNames {
            for appearance in Appearance.allCases {
                let traits = appearance.traits()
                let ratio = ColourArithmetic.contrast(
                    try token(named: Palette.fillLabelAssetName, in: traits),
                    try token(named: name, in: traits)
                )
                #expect(ratio >= 4.5, "the fill label on \(name), \(appearance.name): \(ratio):1")
            }
        }
    }

    /// Primary ink on the screen: the message text, the status warnings,
    /// Again's look while it is off, and a dimmed Settings row's
    /// (`SettingsRowButtonStyle`), text and border.
    @Test func primaryInkIsReadableOnTheScreen() {
        for appearance in Appearance.allCases {
            let traits = appearance.traits()
            let ratio = Self.ratio(UIColor.label.resolvedColor(with: traits), UIColor.systemBackground.resolvedColor(with: traits))
            #expect(ratio >= 4.5, "primary ink on the screen, \(appearance.name): \(ratio):1")
        }
    }

    /// The pressed ring every Home control shows (`HomeButtonStyle`): primary
    /// ink drawn inside the edge of the control's fill. As a control edge it
    /// needs 3:1 against each fill it can sit on.
    @Test func pressedRingStandsOutFromEveryFill() throws {
        for name in Palette.assetNames {
            for appearance in Appearance.allCases {
                let traits = appearance.traits()
                let ink = Self.srgb(UIColor.label.resolvedColor(with: traits))
                let ratio = ColourArithmetic.contrast(ink, try token(named: name, in: traits))
                #expect(ratio >= 3, "primary ink on \(name), \(appearance.name): \(ratio):1")
            }
        }
    }

    /// Every ink a Home control's rings are drawn in (`HomeButtonLook`), in
    /// the colour the look draws it in each appearance, against every fill:
    /// the pressed ring, the selection ring, and with Show Borders the
    /// border and the screen-coloured selection ring, all drawn on a
    /// control's fill as an edge, so each needs 3:1. (The border of a
    /// control that is off sits on the screen instead:
    /// `primaryInkIsReadableOnTheScreen`.)
    @Test func everyRingInkStandsOutFromEveryFill() throws {
        for ink in HomeButtonLook.Ink.allCases {
            for appearance in Appearance.allCases {
                let drawn = ink.isWhite(inDarkMode: appearance.isDark) ? Self.white : Self.black
                for name in Palette.assetNames {
                    let ratio = ColourArithmetic.contrast(drawn, try token(named: name, in: appearance.traits()))
                    #expect(ratio >= 3, "\(ink) ring on \(name), \(appearance.name): \(ratio):1")
                }
            }
        }
    }

    /// In dark mode, iPad multitasking can lift a window's screen from
    /// black to the system's elevated background, where the fills' own
    /// edges come to under 3:1 (docs/HANDOFF.md, *Known gaps*). In dark
    /// mode every Home control draws a primary-ink border inside its edge
    /// (`HomeButtonLook`, since pull request #74), and that border, white,
    /// is what meets the lifted screen; primary ink's words (the message,
    /// a control that is off) sit on it too. Fails if either comes under
    /// 4.5:1 there, or if the lift does not reach the screen's colour.
    @Test func primaryInkIsReadableOnTheLiftedScreenInDarkMode() {
        for appearance in [Appearance.dark, .increasedContrastDark] {
            let name = "\(appearance.name), lifted"
            let lifted = appearance.traits(lifted: true)
            let screen = UIColor.systemBackground.resolvedColor(with: lifted)
            #expect(
                Self.components(screen) != Self.components(UIColor.systemBackground.resolvedColor(with: appearance.traits())),
                "the screen did not lift, \(name)"
            )
            let border = HomeButtonLook.Ink.primary.isWhite(inDarkMode: true) ? Self.white : Self.black
            let borderRatio = ColourArithmetic.contrast(border, Self.srgb(screen))
            #expect(borderRatio >= 4.5, "the border on the screen, \(name): \(borderRatio):1")
            let wordsRatio = Self.ratio(UIColor.label.resolvedColor(with: lifted), screen)
            #expect(wordsRatio >= 4.5, "primary ink on the screen, \(name): \(wordsRatio):1")
        }
    }

    /// The rings are drawn in plain black and white. Primary ink must be
    /// the system's label colour, the words of a control that is off and
    /// the ink the tests above measure on the screen, and the screen's ink
    /// must be the screen behind Home at the base level, in light, dark and
    /// Increase Contrast. If Apple's colours change, this fails before a
    /// ring stops matching them.
    @Test func ringInksAreTheSystemColoursTheyStandFor() {
        for appearance in Appearance.allCases {
            let expected: [(HomeButtonLook.Ink, UIColor, String)] = [
                (.primary, .label, "the label colour"),
                (.screen, .systemBackground, "the system background"),
            ]
            for (ink, system, systemName) in expected {
                let drawn: UIColor = ink.isWhite(inDarkMode: appearance.isDark) ? .white : .black
                #expect(
                    Self.components(drawn) == Self.components(system.resolvedColor(with: appearance.traits())),
                    "\(ink) ink is not \(systemName), \(appearance.name)"
                )
            }
        }
    }

    /// The helper itself, checked against WCAG's own extremes, so a broken
    /// formula cannot make every test above pass.
    @Test func theContrastFormulaMatchesWCAG() {
        #expect(abs(Self.ratio(.white, .black) - 21) < 0.01)
        #expect(abs(Self.ratio(.white, .white) - 1) < 0.01)
        // #767676 is the classic lightest gray that passes 4.5:1 on white.
        let gray = UIColor(red: 0x76 / 255, green: 0x76 / 255, blue: 0x76 / 255, alpha: 1)
        #expect(abs(Self.ratio(.white, gray) - 4.54) < 0.01)
        // WCAG's own coefficients, not the CIE Y of linear sRGB: #B60015 on
        // black is 2.99985:1 by WCAG and would pass at 3.00021:1 by CIE Y.
        let boundary = ColourArithmetic.contrast(
            ColourArithmetic.SRGB(red: 0xB6 / 255, green: 0, blue: 0x15 / 255),
            ColourArithmetic.SRGB(red: 0, green: 0, blue: 0)
        )
        #expect(boundary < 3, "#B60015 on black: \(boundary):1")
        #expect(abs(boundary - 2.999845) < 0.000001, "#B60015 on black: \(boundary):1")
    }

    /// The arithmetic agrees with the colour search's Python (`colourmath.py`)
    /// to four decimals, and its colour difference with Sharma, Wu and
    /// Dalal's published test pairs, so a slip in the port cannot pass the
    /// budget or the colour-vision test above. Contrast is WCAG's, with
    /// WCAG's coefficients (`theContrastFormulaMatchesWCAG`), so its values
    /// here are the Python's formula with those coefficients.
    @Test func theArithmeticMatchesTheColourSearch() throws {
        let tolerance = 0.00005
        func colour(_ hex: String) throws -> SRGB {
            try #require(SRGB(hex: hex), "\(hex)")
        }
        // Sharma, Wu and Dalal (2005), pairs 1, 17 and 33.
        let sharma: [(ColourArithmetic.Lab, ColourArithmetic.Lab, Double)] = [
            (.init(lightness: 50, a: 2.6772, b: -79.7751), .init(lightness: 50, a: 0, b: -82.7485), 2.0425),
            (.init(lightness: 50, a: 2.5, b: 0), .init(lightness: 73, a: 25, b: -18), 27.1492),
            (.init(lightness: 2.0776, a: 0.0795, b: -1.1350), .init(lightness: 0.9033, a: -0.0636, b: -0.5514), 0.9082),
        ]
        for (first, second, expected) in sharma {
            let difference = ColourArithmetic.ciede2000(first, second)
            #expect(abs(difference - expected) < tolerance, "Sharma's \(expected): \(difference)")
        }
        // Values the colour search's Python computed (contrast with WCAG's
        // coefficients, 0.2126, 0.7152 and 0.0722).
        let contrasts: [(String, String, Double)] = [
            ("#FFFFFF", "#0A60D6", 5.7423),
            ("#5A6474", "#1C1C1E", 2.8437),
        ]
        for (first, second, expected) in contrasts {
            let ratio = ColourArithmetic.contrast(try colour(first), try colour(second))
            #expect(abs(ratio - expected) < tolerance, "\(first) on \(second): \(ratio)")
        }
        let emergency = ColourArithmetic.lab(try colour("#C8161E"))
        #expect(abs(emergency.lightness - 42.6865) < tolerance)
        #expect(abs(emergency.a - 64.5562) < tolerance)
        #expect(abs(emergency.b - 44.7495) < tolerance)
        let differences: [(String, String, ColourArithmetic.Vision, Double)] = [
            ("#C8161E", "#B45309", .typical, 16.4031),
            ("#C8161E", "#B45309", .protanopia, 9.8515),
            ("#C8161E", "#B45309", .deuteranopia, 2.7487),
            ("#5A6474", "#0F766E", .tritanopia, 14.7618),
        ]
        for (first, second, vision, expected) in differences {
            let difference = ColourArithmetic.difference(try colour(first), try colour(second), as: vision)
            #expect(abs(difference - expected) < tolerance, "\(first) and \(second), \(vision): \(difference)")
        }
        // Tritanopia takes #0A60D6's red below none, which is clipped.
        let simulated = ColourArithmetic.simulate(try colour("#0A60D6").linear, as: .tritanopia)
        #expect(simulated[0] == 0)
        #expect(abs(simulated[1] - 0.2079) < tolerance)
        #expect(abs(simulated[2] - 0.2852) < tolerance)
        #expect(try colour("#0a60d6").hex == "#0A60D6")
        #expect(SRGB(hex: "#12345") == nil)
    }

    /// WCAG 2.x contrast between two UIKit colours, as drawn.
    private static func ratio(_ first: UIColor, _ second: UIColor) -> Double {
        ColourArithmetic.contrast(srgb(first), srgb(second))
    }

    /// A UIKit colour as the 8-bit sRGB value it is drawn with.
    private static func srgb(_ color: UIColor) -> SRGB {
        let channels = components(color)
        return SRGB(red: Double(channels[0]) / 255, green: Double(channels[1]) / 255, blue: Double(channels[2]) / 255)
    }

    /// Red, green, blue and alpha, each out of 255.
    private static func components(_ color: UIColor) -> [Int] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }
}

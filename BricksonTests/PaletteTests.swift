import Testing
import UIKit
@testable import Brickson

/// Invariant 6: contrast is measured, never eyeballed. Every fill behind a
/// control must carry white text at 4.5:1 or better (control labels are
/// normal-size text under WCAG), and its edge must stand out at 3:1 or
/// better against the screen behind it. Checked in light and dark mode,
/// each with and without Increase Contrast.
///
/// Reduce Transparency is not a trait colours resolve against, and every
/// fill here is opaque, so it changes none of these values. How system
/// button styles draw under these settings is not something a unit test
/// can see; the UI tests' accessibility audit and a device check cover it.
struct PaletteTests {
    private struct Appearance {
        let traits: UITraitCollection
        let name: String
    }

    private static var appearances: [Appearance] {
        var result: [Appearance] = []
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection { traits in
                    traits.userInterfaceStyle = style
                    traits.accessibilityContrast = contrast
                }
                var name = style == .dark ? "dark" : "light"
                if contrast == .high {
                    name += " with Increase Contrast"
                }
                result.append(Appearance(traits: traits, name: name))
            }
        }
        return result
    }

    private func fill(named name: String, in traits: UITraitCollection) throws -> UIColor {
        let color = try #require(
            UIColor(named: name, in: .main, compatibleWith: traits),
            "\(name) is missing from the asset catalog"
        )
        return color.resolvedColor(with: traits)
    }

    // Plain loops rather than parameterized tests, so each check shows up by
    // name in the test log.

    @Test func whiteTextIsReadableOnEveryFill() throws {
        for name in Palette.assetNames {
            for appearance in Self.appearances {
                let ratio = Contrast.ratio(.white, try fill(named: name, in: appearance.traits))
                #expect(ratio >= 4.5, "white on \(name), \(appearance.name): \(ratio):1")
            }
        }
    }

    @Test func everyFillStandsOutFromTheScreen() throws {
        for name in Palette.assetNames {
            for appearance in Self.appearances {
                let screen = UIColor.systemBackground.resolvedColor(with: appearance.traits)
                let ratio = Contrast.ratio(screen, try fill(named: name, in: appearance.traits))
                #expect(ratio >= 3, "\(name) against the screen, \(appearance.name): \(ratio):1")
            }
        }
    }

    /// Primary ink on the screen: the message text, the status warnings, and
    /// Again's look while it is off (text and border).
    @Test func primaryInkIsReadableOnTheScreen() {
        for appearance in Self.appearances {
            let screen = UIColor.systemBackground.resolvedColor(with: appearance.traits)
            let ink = UIColor.label.resolvedColor(with: appearance.traits)
            let ratio = Contrast.ratio(ink, screen)
            #expect(ratio >= 4.5, "primary ink on the screen, \(appearance.name): \(ratio):1")
        }
    }

    /// Again's pressed ring: primary ink drawn inside the edge of the control
    /// fill. As a control edge it needs 3:1 against the fill it sits on.
    @Test func pressedRingStandsOutFromTheFill() throws {
        for appearance in Self.appearances {
            let ink = UIColor.label.resolvedColor(with: appearance.traits)
            let ratio = Contrast.ratio(ink, try fill(named: "ControlFill", in: appearance.traits))
            #expect(ratio >= 3, "primary ink on ControlFill, \(appearance.name): \(ratio):1")
        }
    }

    /// The fills are the measured values in `Palette`'s table, so a typo in
    /// the asset catalog cannot pass unnoticed just because it still
    /// happens to clear the contrast bars.
    @Test func theFillsAreTheMeasuredValues() throws {
        let expected = [
            "AccentColor": "#0A60D6",
            "ControlFill": "#5A6474",
            "EmergencyFill": "#C8161E",
        ]
        #expect(Set(expected.keys) == Set(Palette.assetNames))
        for (name, hex) in expected {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            let color = try fill(named: name, in: UITraitCollection(userInterfaceStyle: .light))
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let actual = String(
                format: "#%02X%02X%02X",
                Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded())
            )
            #expect(actual == hex, "\(name)")
        }
    }

    /// The helper itself, checked against WCAG's own extremes, so a broken
    /// formula cannot make every test above pass.
    @Test func theContrastFormulaMatchesWCAG() {
        #expect(abs(Contrast.ratio(.white, .black) - 21) < 0.01)
        #expect(abs(Contrast.ratio(.white, .white) - 1) < 0.01)
        // #767676 is the classic lightest gray that passes 4.5:1 on white.
        let gray = UIColor(red: 0x76 / 255, green: 0x76 / 255, blue: 0x76 / 255, alpha: 1)
        #expect(abs(Contrast.ratio(.white, gray) - 4.54) < 0.01)
    }
}

/// WCAG 2.x contrast ratio between two opaque sRGB colours.
private enum Contrast {
    static func ratio(_ first: UIColor, _ second: UIColor) -> Double {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

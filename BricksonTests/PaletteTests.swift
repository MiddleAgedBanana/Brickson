import Testing
import UIKit
@testable import Brickson

/// Invariant 6: contrast is measured, never eyeballed. Every fill behind a
/// control must carry white text at 4.5:1 or better (control labels are
/// normal-size text under WCAG), and its edge must stand out at 3:1 or
/// better against the screen behind it, in light and dark mode.
struct PaletteTests {
    private static let appearances: [UIUserInterfaceStyle] = [.light, .dark]

    private func fill(named name: String, in style: UIUserInterfaceStyle) throws -> UIColor {
        let traits = UITraitCollection(userInterfaceStyle: style)
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
            for style in Self.appearances {
                let ratio = Contrast.ratio(.white, try fill(named: name, in: style))
                #expect(ratio >= 4.5, "white on \(name) in \(style == .dark ? "dark" : "light") mode is \(ratio):1")
            }
        }
    }

    @Test func everyFillStandsOutFromTheScreen() throws {
        for name in Palette.assetNames {
            for style in Self.appearances {
                let traits = UITraitCollection(userInterfaceStyle: style)
                let screen = UIColor.systemBackground.resolvedColor(with: traits)
                let ratio = Contrast.ratio(screen, try fill(named: name, in: style))
                #expect(ratio >= 3, "\(name) against the \(style == .dark ? "dark" : "light") screen is \(ratio):1")
            }
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
            let color = try fill(named: name, in: .light)
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

import Foundation

/// The colour arithmetic `PaletteTests` measures with, ported from the
/// stage 5 colour search's checked Python (`colourmath.py`, in the
/// project's shared foundations folder, `ui-kit/colour-search/scripts/`),
/// so the app's tests and the search agree to the last decimal. Every
/// formula is here, with no colour library:
///
/// - sRGB's transfer curve (IEC 61966-2-1).
/// - WCAG 2.x relative luminance and contrast ratio, with luminance as the
///   CIE Y of linear sRGB (the same coefficients the search uses).
/// - CIELAB (D65) and CIEDE2000 colour difference (Sharma, Wu and Dalal,
///   2005).
/// - Colour-vision deficiency: Machado, Oliveira and Fernandes (2009) at
///   severity 1.0 (dichromacy, the hardest case), applied to linear RGB.
///
/// `PaletteTests.theArithmeticMatchesTheColourSearch` checks it against
/// values the Python computed and against Sharma's published pairs.
nonisolated enum ColourArithmetic {
    /// A colour as its three sRGB channels, each 0 to 1 as stored.
    struct SRGB: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// From `#RRGGBB`; nil for anything else.
        init?(hex: String) {
            var digits = Substring(hex)
            if digits.hasPrefix("#") {
                digits = digits.dropFirst()
            }
            guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
                return nil
            }
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        }

        /// `#RRGGBB`, each channel rounded to the nearest of 256 steps.
        var hex: String {
            let channels = [red, green, blue].map { Int(($0 * 255).rounded()) }
            return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
        }

        /// The channels with sRGB's transfer curve undone: light, not code.
        var linear: [Double] {
            [red, green, blue].map(ColourArithmetic.decode)
        }
    }

    /// CIELAB, with D65 white.
    struct Lab: Equatable, Sendable {
        let lightness: Double
        let a: Double
        let b: Double
    }

    /// How a colour is seen: with typical colour vision, or as simulated
    /// for each kind of dichromacy.
    enum Vision: CaseIterable, Sendable {
        case typical
        /// No long-wavelength (red) cones.
        case protanopia
        /// No medium-wavelength (green) cones.
        case deuteranopia
        /// No short-wavelength (blue) cones; the least validated model.
        case tritanopia
    }

    // MARK: WCAG

    /// sRGB's transfer curve, undone.
    static func decode(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    /// WCAG 2.x relative luminance: the CIE Y of the linear colour.
    static func luminance(_ colour: SRGB) -> Double {
        luminance(linear: colour.linear)
    }

    static func luminance(linear: [Double]) -> Double {
        linear[0] * 0.2126390059 + linear[1] * 0.7151686788 + linear[2] * 0.0721923054
    }

    /// WCAG 2.x contrast ratio between two opaque colours, 1 to 21.
    static func contrast(_ first: SRGB, _ second: SRGB) -> Double {
        let one = luminance(first)
        let two = luminance(second)
        return (max(one, two) + 0.05) / (min(one, two) + 0.05)
    }

    // MARK: CIELAB

    /// Linear sRGB to CIE XYZ (D65).
    private static let toXYZ: [[Double]] = [
        [0.4123907993, 0.3575843394, 0.1804807884],
        [0.2126390059, 0.7151686788, 0.0721923054],
        [0.0193308187, 0.1191947798, 0.9505321522],
    ]
    private static let whitePoint = [0.95047, 1.0, 1.08883]

    private static func multiply(_ matrix: [[Double]], _ vector: [Double]) -> [Double] {
        matrix.map { row in row[0] * vector[0] + row[1] * vector[1] + row[2] * vector[2] }
    }

    /// CIELAB of a linear sRGB colour.
    static func lab(linear: [Double]) -> Lab {
        let xyz = multiply(toXYZ, linear)
        let delta = 6.0 / 29
        let f = (0..<3).map { index -> Double in
            let t = xyz[index] / whitePoint[index]
            return t > delta * delta * delta ? cbrt(t) : t / (3 * delta * delta) + 4.0 / 29
        }
        return Lab(lightness: 116 * f[1] - 16, a: 500 * (f[0] - f[1]), b: 200 * (f[1] - f[2]))
    }

    /// CIELAB of a colour as seen with `vision`.
    static func lab(_ colour: SRGB, as vision: Vision = .typical) -> Lab {
        lab(linear: simulate(colour.linear, as: vision))
    }

    /// CIEDE2000 colour difference (Sharma, Wu and Dalal, 2005): about 1 is
    /// the smallest difference people notice; the colour search asks for
    /// 15 between colours that mean different things.
    static func ciede2000(_ first: Lab, _ second: Lab) -> Double {
        func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
        func degrees(_ radians: Double) -> Double {
            let value = (radians * 180 / .pi).truncatingRemainder(dividingBy: 360)
            return value < 0 ? value + 360 : value
        }
        let (l1, a1, b1) = (first.lightness, first.a, first.b)
        let (l2, a2, b2) = (second.lightness, second.a, second.b)
        let c1 = hypot(a1, b1)
        let c2 = hypot(a2, b2)
        let cMean = (c1 + c2) / 2
        let pow25to7: Double = pow(25.0, 7.0)
        let g = 0.5 * (1 - sqrt(pow(cMean, 7.0) / (pow(cMean, 7.0) + pow25to7)))
        let a1p = (1 + g) * a1
        let a2p = (1 + g) * a2
        let c1p = hypot(a1p, b1)
        let c2p = hypot(a2p, b2)
        let h1p = degrees(atan2(b1, a1p))
        let h2p = degrees(atan2(b2, a2p))
        let deltaLp = l2 - l1
        let deltaCp = c2p - c1p
        var deltaH = h2p - h1p
        if deltaH > 180 {
            deltaH -= 360
        } else if deltaH < -180 {
            deltaH += 360
        }
        if c1p * c2p == 0 {
            deltaH = 0
        }
        let deltaHp = 2 * sqrt(c1p * c2p) * sin(radians(deltaH) / 2)
        let lMeanP = (l1 + l2) / 2
        let cMeanP = (c1p + c2p) / 2
        let hSum = h1p + h2p
        let hMeanP: Double
        if c1p * c2p == 0 {
            hMeanP = hSum
        } else if abs(h1p - h2p) > 180 {
            hMeanP = hSum < 360 ? (hSum + 360) / 2 : (hSum - 360) / 2
        } else {
            hMeanP = hSum / 2
        }
        let t = 1 - 0.17 * cos(radians(hMeanP - 30)) + 0.24 * cos(radians(2 * hMeanP))
            + 0.32 * cos(radians(3 * hMeanP + 6)) - 0.20 * cos(radians(4 * hMeanP - 63))
        let deltaTheta = 30 * exp(-pow((hMeanP - 275) / 25, 2.0))
        let rc = 2 * sqrt(pow(cMeanP, 7.0) / (pow(cMeanP, 7.0) + pow25to7))
        let sl = 1 + 0.015 * pow(lMeanP - 50, 2.0) / sqrt(20 + pow(lMeanP - 50, 2.0))
        let sc = 1 + 0.045 * cMeanP
        let sh = 1 + 0.015 * cMeanP * t
        let rt = -sin(radians(2 * deltaTheta)) * rc
        let lightness = deltaLp / sl
        let chroma = deltaCp / sc
        let hue = deltaHp / sh
        return sqrt(lightness * lightness + chroma * chroma + hue * hue + rt * chroma * hue)
    }

    /// CIEDE2000 between two colours, both seen with `vision`.
    static func difference(_ first: SRGB, _ second: SRGB, as vision: Vision) -> Double {
        ciede2000(lab(first, as: vision), lab(second, as: vision))
    }

    // MARK: Colour-vision deficiency

    /// Machado, Oliveira and Fernandes (2009), severity 1.0, on linear RGB.
    private static func matrix(for vision: Vision) -> [[Double]]? {
        switch vision {
        case .typical:
            return nil
        case .protanopia:
            return [[0.152286, 1.052583, -0.204868],
                    [0.114503, 0.786281, 0.099216],
                    [-0.003882, -0.048116, 1.051998]]
        case .deuteranopia:
            return [[0.367322, 0.860646, -0.227968],
                    [0.280085, 0.672501, 0.047413],
                    [-0.011820, 0.042940, 0.968881]]
        case .tritanopia:
            return [[1.255528, -0.076749, -0.178779],
                    [-0.078411, 0.930809, 0.147602],
                    [0.004733, 0.691367, 0.303900]]
        }
    }

    /// A linear colour as seen with `vision`. Negative light is clipped to
    /// none, as the search does; light over 1 is kept.
    static func simulate(_ linear: [Double], as vision: Vision) -> [Double] {
        guard let matrix = matrix(for: vision) else { return linear }
        return multiply(matrix, linear).map { max($0, 0) }
    }
}

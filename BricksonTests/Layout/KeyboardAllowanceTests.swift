import Foundation
import Testing
@testable import Brickson

/// The room Home keeps for Apple's keyboard (`KeyboardAllowance`), checked
/// against every keyboard measured so far. Each row is a measurement on a
/// simulator with the full software keyboard (US English, predictions on):
/// where SwiftUI saw the keyboard's top, in points from the window's top.
/// A new measurement is a new row here, never a new branch in the app; the
/// UI tests measure CI's windows again on every run (`KeyboardProbeTests`).
/// Each test's comment names the change that would make it fail.
struct KeyboardAllowanceTests {
    nonisolated struct Measured: CustomTestStringConvertible, Sendable {
        let window: CGSize
        let keyboardTop: CGFloat
        let source: String

        var keyboardHeight: CGFloat { window.height - keyboardTop }
        var testDescription: String { "\(source), window \(window.width)×\(window.height)" }
    }

    /// docs/log/2026-10-21-typing-foundation.md, *Keyboard measurements*,
    /// and docs/DECISIONS.md, "Typing is a state of Home". The 13-inch
    /// iPad's numbers were the same at the default and the largest text size,
    /// and the same on iOS 26.5 (Brickson's CI) and iOS 27.0 (the reference
    /// app's), so text size is not one of the allowance's inputs.
    nonisolated static let measured: [Measured] = [
        Measured(
            window: CGSize(width: 1032, height: 1376), keyboardTop: 973,
            source: "13-inch iPad, portrait, Full Screen, iOS 26.5 and 27.0"
        ),
        Measured(
            window: CGSize(width: 1376, height: 1032), keyboardTop: 534,
            source: "13-inch iPad, landscape, Full Screen, iOS 26.5 and 27.0"
        ),
        Measured(
            window: CGSize(width: 1032, height: 774), keyboardTop: 276,
            source: "13-inch iPad, landscape, Display Zoom Larger Text, iOS 27.0 (reference app)"
        ),
        Measured(
            window: CGSize(width: 402, height: 874), keyboardTop: 546,
            source: "iPhone 17 Pro, portrait, iOS 27.0 (reference app)"
        ),
    ]

    /// Fails if any measured keyboard reaches higher than the allowance
    /// keeps for its window: lowering a shape's reference keyboard, or
    /// moving the narrow width so a window takes a shorter reference.
    @Test(arguments: measured)
    func everyMeasuredKeyboardFitsInsideTheAllowance(_ row: Measured) {
        let allowance = KeyboardAllowance(windowSize: row.window)
        #expect(allowance.height >= row.keyboardHeight)
        #expect(allowance.bandLimit <= row.keyboardTop)
    }

    /// Fails if a window shorter than its shape's reference window is
    /// given a keyboard shorter than the reference: Display Zoom shrank the
    /// 13-inch iPad's landscape window from 1032 to 774 points tall and the
    /// keyboard stayed 498 points tall, so a shorter window is no reason
    /// to expect a shorter keyboard.
    @Test func aShorterWindowKeepsTheWholeReferenceKeyboard() {
        #expect(KeyboardAllowance(windowSize: CGSize(width: 1133, height: 744)).height == 498)
        #expect(KeyboardAllowance(windowSize: CGSize(width: 744, height: 1133)).height == 403)
        #expect(KeyboardAllowance(windowSize: CGSize(width: 375, height: 667)).height == 328)
    }

    /// Fails if a window taller than its shape's reference window is given
    /// no more than the reference keyboard: a taller window gets a keyboard
    /// that grows in proportion, which no measured keyboard has outgrown.
    @Test func aTallerWindowGetsAKeyboardInProportion() {
        // 328 × 956 / 874 = 358.8, rounded up.
        #expect(KeyboardAllowance(windowSize: CGSize(width: 440, height: 956)).height == 359)
    }

    /// Fails if the allowance ever claims more than the whole window, which
    /// would put the band's limit above the window's top.
    @Test func theAllowanceIsNeverTallerThanTheWindow() {
        for size in [CGSize(width: 874, height: 402), CGSize(width: 600, height: 300), CGSize(width: 320, height: 200), .zero] {
            let allowance = KeyboardAllowance(windowSize: size)
            #expect(allowance.height <= size.height, "window \(size)")
            #expect(allowance.bandLimit >= 0, "window \(size)")
        }
    }

    /// Fails if the shape is chosen by anything but the window's size, or
    /// if the narrow width moves past a phone's window or an iPad's full
    /// screen: every window up to 440 points wide (the widest iPhone in
    /// portrait) takes the narrow reference, and every window from 744
    /// (the narrowest iPad in portrait) the wide one.
    @Test func theShapeComesFromTheWindowAlone() {
        #expect(KeyboardAllowance.Reference.forWindow(CGSize(width: 320, height: 568)) == .narrow)
        #expect(KeyboardAllowance.Reference.forWindow(CGSize(width: 440, height: 956)) == .narrow)
        #expect(KeyboardAllowance.Reference.forWindow(CGSize(width: 744, height: 1133)) == .tall)
        #expect(KeyboardAllowance.Reference.forWindow(CGSize(width: 1032, height: 1376)) == .tall)
        #expect(KeyboardAllowance.Reference.forWindow(CGSize(width: 1032, height: 774)) == .wide)
        #expect(KeyboardAllowance.Reference.forWindow(CGSize(width: 874, height: 402)) == .wide)
        // A square window is not wider than tall.
        #expect(KeyboardAllowance.Reference.forWindow(CGSize(width: 800, height: 800)) == .tall)
    }

    /// Fails if, within one shape, a taller window ever gets less room for
    /// the keyboard than a shorter one, which would let a safety control
    /// that fits on the shorter window be covered on the taller.
    @Test func aTallerWindowNeverGetsLessRoom() {
        // Each width with the heights that keep its window in one shape:
        // wide, taller than wide, and taller than wide but narrow.
        let shapes: [(width: CGFloat, heights: StrideThrough<CGFloat>)] = [
            (1376, stride(from: 100, through: 1375, by: 25)),
            (1032, stride(from: 1050, through: 1400, by: 25)),
            (402, stride(from: 425, through: 1000, by: 25)),
        ]
        for shape in shapes {
            var previous: CGFloat = 0
            for height in shape.heights {
                let allowance = KeyboardAllowance(windowSize: CGSize(width: shape.width, height: height))
                #expect(allowance.height >= previous, "width \(shape.width), height \(height)")
                previous = allowance.height
            }
        }
    }
}

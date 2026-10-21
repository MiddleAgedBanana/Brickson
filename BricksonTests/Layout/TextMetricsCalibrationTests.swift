import SwiftUI
import Testing
import UIKit
@testable import Brickson

/// Measures what SwiftUI actually draws for the text styles Home uses, at
/// every Dynamic Type size, so the pure layout code can be tested with real
/// numbers (docs/LESSONS.md, "Measure the running app, not a proxy").
///
/// Temporary: this first version only reports what it measured. It is
/// replaced in the same pull request by a fixture of these values and a test
/// that fails when the system fonts drift from it.
private func r(_ value: CGFloat) -> String { String(format: "%.2f", Double(value)) }

struct TextMetricsCalibrationTests {
    private static let styles: [(name: String, font: Font, textStyle: UIFont.TextStyle, weight: UIFont.Weight)] = [
        ("title.semibold", .title.weight(.semibold), .title1, .semibold),
        ("title2.semibold", .title2.weight(.semibold), .title2, .semibold),
        ("title3.semibold", .title3.weight(.semibold), .title3, .semibold),
        ("headline", .headline, .headline, .semibold),
        ("body.semibold", .body.weight(.semibold), .body, .semibold),
        ("subheadline.semibold", .subheadline.weight(.semibold), .subheadline, .semibold),
    ]

    private static let sizes: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
    ]

    private static let words: [String] = {
        let labels = [
            "Yes", "No", "Emergency", "Again", "Get Attention", "Stop Alert", "Speak", "Phrases",
            "Type", "Clear", "Speaking", "Sounding", "Choose a phrase to speak it.",
            "Basics", "Needs", "Conversation", "Feelings", "Volume low", "Audio failed",
        ]
        let phrases = [
            "Maybe.", "I don't know.", "Please.", "Thank you.", "Wait a moment, please.", "I'm not finished.",
            "Hello.", "Goodbye.", "I need help now.", "Please come here.", "I can't breathe.", "I'm choking.",
            "I'm in pain.", "Something is wrong.", "I'm thirsty.", "I'm hungry.", "I need the bathroom.",
            "I'm too hot.", "I'm too cold.", "Please move me.", "I need my medication.", "I'm tired.",
            "Give me a moment to answer.", "Can you repeat that?", "I understand.", "I don't understand.",
            "That's not what I meant.", "Please ask me yes or no questions.", "I love you.", "I'm happy.",
            "I'm okay.", "I'm worried.", "I'm frustrated.", "That's funny.",
        ]
        var seen = Set<String>()
        var result: [String] = []
        for text in labels + phrases {
            for word in [text] + text.split(separator: " ").map(String.init) where seen.insert(word).inserted {
                result.append(word)
            }
        }
        return result
    }()

    private static func fitting<V: View>(_ view: V, width: CGFloat = 10_000) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 10_000))
    }

    private static func uiFont(_ textStyle: UIFont.TextStyle, _ weight: UIFont.Weight, _ size: DynamicTypeSize) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        let pointSize = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits).pointSize
        return .systemFont(ofSize: pointSize, weight: weight)
    }

    @Test func reportLineHeights() {
        for style in Self.styles {
            var rows: [String] = []
            for size in Self.sizes {
                let font = Self.uiFont(style.textStyle, style.weight, size)
                let preferred = UIFont.preferredFont(
                    forTextStyle: style.textStyle,
                    compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
                )
                let one = Self.fitting(Text(verbatim: "Ag").font(style.font).dynamicTypeSize(size))
                let two = Self.fitting(Text(verbatim: "Ag\nAg").font(style.font).dynamicTypeSize(size))
                let symbol = Self.fitting(
                    Image(systemName: "exclamationmark.triangle.fill").font(style.font).dynamicTypeSize(size)
                )
                let label = Self.fitting(
                    Label("Emergency", systemImage: "exclamationmark.triangle.fill").font(style.font).dynamicTypeSize(size)
                )
                let text = Self.fitting(Text(verbatim: "Emergency").font(style.font).dynamicTypeSize(size))
                rows.append("[\(r(font.pointSize)),\(r(one.height)),\(r(two.height)),\(r(font.lineHeight)),\(r(preferred.lineHeight)),\(r(symbol.width)),\(r(label.width - text.width))]")
            }
            Issue.record("CALIBRATION lines \(style.name) [pt,one,two,uiLine,prefLine,symbolW,labelExtra]: \(rows.joined(separator: ","))")
        }
    }

    @Test func reportWordWidthsAtTheDefaultSize() {
        for style in Self.styles {
            let font = Self.uiFont(style.textStyle, style.weight, .large)
            var rows: [String] = []
            for word in Self.words {
                let swiftUI = Self.fitting(Text(verbatim: word).font(style.font).dynamicTypeSize(.large)).width
                let measured = (word as NSString).size(withAttributes: [.font: font]).width
                rows.append("\"\(word)\":[\(r(swiftUI)),\(r(measured))]")
            }
            Issue.record("CALIBRATION words \(style.name) [swiftUI,nsString]: {\(rows.joined(separator: ","))}")
        }
    }

    @Test func reportTheScreen() throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let screen = scene.screen
        Issue.record("CALIBRATION screen idiom=\(scene.traitCollection.userInterfaceIdiom.rawValue) bounds=\(screen.bounds) nativeBounds=\(screen.nativeBounds) scale=\(screen.scale) nativeScale=\(screen.nativeScale) displayScale=\(scene.traitCollection.displayScale) os=\(UIDevice.current.systemVersion)")
    }
}

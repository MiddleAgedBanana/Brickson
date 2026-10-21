#if DEBUG
import SwiftUI

/// One typing field and a line of numbers saying where Apple's keyboard
/// starts, for `KeyboardProbeTests`. Debug builds only, opened by
/// `KeyboardProbeLaunch`. Nothing typed here is saved.
///
/// The field has the settings Home's typing field will have
/// (`typingFieldTraits()`), so the keyboard measured is the one people will
/// meet. The numbers are SwiftUI's own view of the keyboard: a view that
/// ignores every safe area but the keyboard's ends where the keyboard
/// starts, and that is the edge a layout built the same way meets.
struct KeyboardProbeScreen: View {
    private static let prompt = "Type here"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var text = ""
    @State private var window = CGRect.zero
    @State private var aboveKeyboard = CGRect.zero
    @FocusState private var isTyping: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The whole window.
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { window = $0 }
            // The window down to the keyboard's top.
            Color.clear
                .ignoresSafeArea(.container)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { aboveKeyboard = $0 }
            VStack(alignment: .leading, spacing: 16) {
                TextField(Self.prompt, text: $text, axis: .vertical)
                    .typingFieldTraits()
                    .textFieldStyle(.roundedBorder)
                    .focused($isTyping)
                    .accessibilityIdentifier("keyboardProbe.field")
                Text(verbatim: readout)
                    .font(.footnote.monospaced())
                    .accessibilityIdentifier("keyboardProbe.readout")
            }
            .padding()
        }
        .onAppear { isTyping = true }
    }

    /// For example
    /// `window=1376.0x1032.0;keyboardTop=534.0;keyboardHeight=498.0;dynamicType=large`,
    /// in points from the window's top-left corner, to the nearest half point.
    private var readout: String {
        [
            "window=\(Self.points(window.width))x\(Self.points(window.height))",
            "keyboardTop=\(Self.points(aboveKeyboard.maxY))",
            "keyboardHeight=\(Self.points(max(0, window.maxY - aboveKeyboard.maxY)))",
            "dynamicType=\(dynamicTypeSize)",
        ].joined(separator: ";")
    }

    private static func points(_ value: CGFloat) -> String {
        "\((Double(value) * 2).rounded() / 2)"
    }
}
#endif

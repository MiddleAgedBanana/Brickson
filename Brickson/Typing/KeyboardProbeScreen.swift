import SwiftUI

extension View {
    /// This view, or the keyboard probe when the launch asked for it
    /// (`--screen=keyboard-probe`, read by `LaunchOptions`). Only debug
    /// builds read launch arguments, and only they have a probe screen: in a
    /// release build this is always the view itself.
    @ViewBuilder
    func replacedByKeyboardProbe(when isRequested: Bool) -> some View {
        #if DEBUG
        if isRequested {
            KeyboardProbeScreen()
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if DEBUG
/// One typing field and a line of numbers saying where Apple's keyboard
/// starts, for `KeyboardProbeTests`. Debug builds only, opened by the
/// launch argument `--screen=keyboard-probe` in place of Home. Nothing typed
/// here is saved.
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
    @State private var aboveKeyboard = CGRect.zero
    @FocusState private var isTyping: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The window down to the keyboard's top (the window's bottom
            // while no keyboard shows).
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

    /// For example `keyboardTop=534.0;dynamicType=large`, in points from the
    /// window's top, to the nearest half point. The UI test compares it with
    /// the window's height, which it reads itself.
    private var readout: String {
        [
            "keyboardTop=\(Self.points(aboveKeyboard.maxY))",
            "dynamicType=\(dynamicTypeSize)",
        ].joined(separator: ";")
    }

    private static func points(_ value: CGFloat) -> String {
        "\((Double(value) * 2).rounded() / 2)"
    }
}
#endif

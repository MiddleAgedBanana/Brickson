import SwiftUI

extension View {
    /// The settings every field that types a message to speak shares, so the
    /// keyboard people meet is the one `KeyboardProbeTests` measured
    /// (docs/DECISIONS.md, "Typing uses Apple's keyboard"):
    ///
    /// - **Writing Tools off.** It could rewrite a person's words before
    ///   they are spoken in that person's voice (docs/DECISIONS.md,
    ///   "Writing Tools off while typing").
    /// - **Sentences start with a capital**, as people expect.
    /// - **The standard keyboard**, with predictions and autocorrection left
    ///   on: they save keystrokes, and keystrokes are expensive for someone
    ///   typing with a switch or their eyes.
    ///
    /// Return is left as it is. A typed line break never reaches the draft:
    /// `MessageComposer` turns it into Speak (docs/DECISIONS.md, "Return
    /// speaks").
    func typingFieldTraits() -> some View {
        writingToolsBehavior(.disabled)
            .textInputAutocapitalization(.sentences)
            .keyboardType(.default)
    }
}

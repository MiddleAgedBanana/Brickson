import SwiftUI

/// The building blocks every Settings screen shares, so each screen looks
/// and measures the same.
///
/// Colours are only pairs `PaletteTests` already pins: white on
/// `Palette.controlFill` or `Palette.phraseFill` for controls, and primary
/// ink on the screen for text and card edges. The system's secondary gray and
/// grouped-list headers are not used: they measure under 4.5:1
/// (AGENTS.md, invariant 6).
enum SettingsMetrics {
    static let gutter: CGFloat = 16
    static let rowSpacing: CGFloat = 16
    /// Settings is mostly used by a family member's touch, but the person
    /// may reach it by a stray dwell, so its controls keep Home's size
    /// rather than a list row's.
    static let rowHeight: CGFloat = 64
}

/// A full-width row that opens another screen or does one thing. The words
/// wrap between words beside the icon, never shrinking; a full-width row
/// leaves room for every word with its icon (AGENTS.md, "Words never
/// break"). Settings' root gives its row half the width only where the
/// half holds the words on one line (`SettingsRootColumns`).
struct SettingsRowLabel: View {
    let title: Text
    let systemImage: String

    init(title: LocalizedStringKey, systemImage: String) {
        self.title = Text(title)
        self.systemImage = systemImage
    }

    /// For words that are formatted rather than looked up, such as a
    /// localized percent.
    init(text: Text, systemImage: String) {
        title = text
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            title
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight, alignment: .leading)
    }
}

/// The label of a button that shares its row with another, such as Hear and
/// Use, or Back to Talking in the safety bar. As on Home's quick controls,
/// the icon sits in a slot of its own above the words, so it never takes
/// width from them, and the words wrap between words without shrinking.
/// (A label that dropped its icon only when the words did not fit, through
/// `ViewThatFits`, failed Apple's Dynamic Type audit.)
struct SettingsPairLabel: View {
    let title: Text
    let systemImage: String

    init(title: LocalizedStringKey, systemImage: String) {
        self.title = Text(title)
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(height: 22)
                .accessibilityHidden(true)
            title
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight)
    }
}

extension View {
    /// The look of every row and action button in Settings: white on the
    /// control fill (5.98:1).
    func settingsRowStyle() -> some View {
        buttonStyle(.borderedProminent)
            .tint(Palette.controlFill)
    }

    /// Keeps the view at the tallest it has been since its screen opened,
    /// so words that get shorter while the screen is open (Personal Voice
    /// turned on in the Settings app, say) pull nothing below them up under
    /// a resting pointer (AGENTS.md, invariant 10). Words that get longer
    /// still push what is below down; where every version is known,
    /// reserve them all instead (`SettingsReservedParagraph`).
    func settingsKeepsItsTallestHeight() -> some View {
        modifier(SettingsTallestHeight())
    }
}

private struct SettingsTallestHeight: ViewModifier {
    @State private var tallest: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tallest = max(tallest, $0) }
            .frame(minHeight: tallest, alignment: .top)
    }
}

/// A heading inside a screen. Primary ink, never the system's gray.
struct SettingsHeading: View {
    let text: Text

    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    /// For words already localized, such as `PersonalVoiceGuidance`'s.
    init(verbatim: String) {
        text = Text(verbatim: verbatim)
    }

    var body: some View {
        text
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Passive reading text: never a control.
struct SettingsParagraph: View {
    let text: Text

    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    init(verbatim: String) {
        text = Text(verbatim: verbatim)
    }

    /// For words that are formatted rather than looked up, such as a
    /// localized percent.
    init(text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Numbered steps in the Settings app. VoiceOver reads each step as one
/// element, number first.
struct SettingsSteps: View {
    let steps: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // Read with its step, so the order is clear when
                    // VoiceOver moves backward or straight to one step.
                    Text(verbatim: "\(index + 1).")
                        .font(.body.weight(.semibold))
                    Text(step)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Passive text whose words change with a choice made on the same screen.
/// Every version is laid out, hidden, under the current one, so the text
/// keeps the height of its longest version and choosing never moves the
/// controls below it (AGENTS.md, "Controls keep their frames across every
/// state of a screen"). Only the current words are read.
struct SettingsReservedParagraph: View {
    let text: Text
    let alternatives: [Text]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(alternatives.indices, id: \.self) { index in
                SettingsParagraph(text: alternatives[index])
                    .hidden()
                    .accessibilityHidden(true)
            }
            SettingsParagraph(text: text)
        }
    }
}

/// A passive, outlined block of text, such as a check-in or a warning.
/// The outline is primary ink, so it clears 3:1 everywhere.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary, lineWidth: 2)
        }
    }
}

/// A scrolling Settings screen with the shared gutters, scroll activity and
/// title.
struct SettingsScreen<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
                content
            }
            .padding(SettingsMetrics.gutter)
        }
        .recordsSettingsScrolling()
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

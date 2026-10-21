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

/// A full-width row that opens another screen or does one thing.
struct SettingsRowLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight, alignment: .leading)
    }
}

extension View {
    /// The look of every row and action button in Settings: white on the
    /// control fill (5.98:1).
    func settingsRowStyle() -> some View {
        buttonStyle(.borderedProminent)
            .tint(Palette.controlFill)
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

    var body: some View {
        text
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Numbered steps in the Settings app, read as one list by VoiceOver.
struct SettingsSteps: View {
    let steps: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "\(index + 1).")
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
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

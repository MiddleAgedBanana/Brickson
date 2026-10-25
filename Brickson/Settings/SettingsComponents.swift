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
    /// The name of each screen's content as a coordinate space, from the
    /// top leading corner of its first view (`SettingsScreen`). Every
    /// screen's content starts at the same height, under the same safety
    /// bar and navigation bar, so a frame measured in one screen's content
    /// means the same place in the next (`SettingsLanding`).
    nonisolated static let contentSpace = "settingsContent"
}

/// A full-width row that opens another screen or does one thing. The words
/// wrap between words beside the icon, never shrinking; a full-width row
/// leaves room for every word with its icon (AGENTS.md, "Words never
/// break"). Settings' root gives its row a narrower width only where it
/// holds the words on one line (`SettingsRowPlace`).
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
/// Use. As on Home's quick controls,
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
///
/// It gives its content where the screen sits in the window
/// (`\.settingsScreenFrames`), from the cover's navigation stack and what
/// the screen keeps at its top for the navigation bar, and names its
/// content as a coordinate space (`SettingsMetrics.contentSpace`).
struct SettingsScreen<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    @Environment(\.settingsCover) private var cover
    /// What the system keeps at each edge of this screen: the navigation
    /// bar at its top.
    @State private var safeArea: HomeLayout.Insets?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
                content
            }
            .coordinateSpace(.named(SettingsMetrics.contentSpace))
            .padding(SettingsMetrics.gutter)
            .environment(\.settingsScreenFrames, frames)
        }
        .onGeometryChange(for: HomeLayout.Insets.self) { proxy in
            let insets = proxy.safeAreaInsets
            return HomeLayout.Insets(top: insets.top, leading: insets.leading, bottom: insets.bottom, trailing: insets.trailing)
        } action: { safeArea = $0 }
        .recordsSettingsScrolling()
        .background(Palette.screen)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }

    private var frames: SettingsScreenFrames? {
        guard let cover, let safeArea else { return nil }
        return SettingsScreenFrames(stack: cover.stack, safeArea: safeArea, gutter: SettingsMetrics.gutter)
    }
}

/// What Settings' cover gives every screen in it (`SettingsView`): Home's
/// frames in the same window and at the same text size, and the frame of
/// the navigation stack the screens are pages of, in the window.
nonisolated struct SettingsCover: Equatable, Sendable {
    let home: HomeLayout
    let stack: CGRect
}

extension EnvironmentValues {
    /// Set by Settings' cover; nil anywhere else.
    @Entry var settingsCover: SettingsCover? = nil
    /// Where this Settings screen sits in the window, once it has measured
    /// what it keeps for its navigation bar (`SettingsScreen`).
    @Entry var settingsScreenFrames: SettingsScreenFrames? = nil
}

/// Places a Settings screen's first control and the words about it where
/// `SettingsLeadIn` says, with the control where `placement` puts it. It
/// measures the control with its words on one line and at each width it
/// might get, and the words at the width they get. Its two views are the
/// control and the words, in the order VoiceOver reads them.
nonisolated struct SettingsLeadInLayout: Layout {
    /// Where the control goes, in the content.
    enum Placement: Equatable, Sendable {
        /// Where `SettingsRowPlace` puts Settings' first row, from Home's
        /// frames and where the screen sits in the window.
        case fromHome(HomeLayout, SettingsScreenFrames)
        /// Across the width at `top`, and at least `minHeight` tall:
        /// Family Setup's Set Up Step by Step, in the place of the row that
        /// opened it.
        case across(top: CGFloat, minHeight: CGFloat)
        /// Across the width at the top, until anything else is known.
        case atTheTop
    }

    let placement: Placement
    /// Whether the control comes first; otherwise the words do.
    let controlFirst: Bool
    /// The gap between the control and the words: the rows' gap.
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        leadIn(width: proposal.width, subviews: subviews)?.size ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let leadIn = leadIn(width: bounds.width, subviews: subviews) else { return }
        let frames = controlFirst ? [leadIn.control, leadIn.words] : [leadIn.words, leadIn.control]
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    /// Nothing but the control and the words is placed: a lead-in has
    /// exactly these two.
    private func leadIn(width: CGFloat?, subviews: Subviews) -> SettingsLeadIn? {
        guard subviews.count == 2 else { return nil }
        let control = subviews[controlFirst ? 0 : 1]
        let words = subviews[controlFirst ? 1 : 0]
        let idealWidth = control.sizeThatFits(.unspecified).width
        let height = { (proposed: CGFloat) in control.sizeThatFits(ProposedViewSize(width: proposed, height: nil)).height }
        // Asked for its own width, it stacks at the control's.
        let width = width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth
        let frame: CGRect
        switch placement {
        case .fromHome(let home, let screen):
            let row = SettingsRowPlace(
                home: home, rowIdealWidth: idealWidth, rowHeight: height, content: screen.content, navigationBar: screen.navigationBar
            ).row
            // At the trailing side, as `SettingsRowPlace` puts it, and never
            // wider than the content this screen was given.
            let rowWidth = min(row.width, width)
            frame = CGRect(
                x: width - rowWidth, y: row.minY - screen.content.minY,
                width: rowWidth, height: rowWidth == row.width ? row.height : height(rowWidth)
            )
        case .across(let top, let minHeight):
            frame = CGRect(x: 0, y: top, width: width, height: max(minHeight, height(width)))
        case .atTheTop:
            frame = CGRect(x: 0, y: 0, width: width, height: height(width))
        }
        return SettingsLeadIn(
            width: width, spacing: spacing, control: frame, besideWidth: idealWidth,
            wordsHeight: { words.sizeThatFits(ProposedViewSize(width: $0, height: nil)).height }
        )
    }
}

import Observation
import SwiftUI

/// Settings: a full-screen cover over Home, for the family.
///
/// Because it covers Home's quick controls, every Settings screen sits under
/// one fixed safety bar: a large Back to Talking over the place of Home's
/// Phrases, at the same frame on every screen, with the place for a
/// start-only Get Attention kept empty at its leading side (docs/DECISIONS.md,
/// "Settings is a cover with a fixed safety bar", "Typing on Home"). The
/// settings themselves start a screen below the root, so a stray dwell that
/// opens Settings meets only the way back and the one Family Setup row.
///
/// When nobody has used it for 90 seconds it goes back to its root and
/// stays open; only Back to Talking closes it (docs/DECISIONS.md, "Settings
/// resets when idle and never closes").
///
/// At the foot of the cover, a line kept for it shows any sound problem,
/// because the cover hides Home's: a sample that cannot be heard always
/// says why (AGENTS.md, invariant 4). It sits below the screens rather
/// than under the bar, so each screen starts right under the bar, where
/// the root's Family Setup row covers the spot Home's Settings was
/// (docs/DECISIONS.md, "Settings on Home").
struct SettingsView: View {
    let close: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(AttentionAlertPlayer.self) private var attention
    @Environment(SpeechService.self) private var speech
    @State private var path: [SettingsRoute] = []
    @State private var activity: SettingsActivity
    @State private var landing = SettingsLanding()

    /// - Parameter idleLimit: `SettingsIdleClock.standardLimit`, or the
    ///   short limit UI tests ask for (`AppTimeouts`).
    init(idleLimit: Duration = SettingsIdleClock.standardLimit, close: @escaping () -> Void) {
        self.close = close
        _activity = State(initialValue: SettingsActivity(limit: idleLimit))
    }

    var body: some View {
        let text = HomeLayout.Text.measured(at: dynamicTypeSize, boldText: legibilityWeight == .bold)
        GeometryReader { proxy in
            // Home's own engine, given the same window and text size, so
            // Back to Talking lands where Home's Phrases is.
            let space = HomeLayout.Space(proxy)
            let home = HomeLayout(space: space, text: text, modes: .phrasesAndTyping)
            VStack(spacing: 0) {
                SettingsSafetyBar(backToTalking: home.backToTalking, safeArea: space.safeArea, close: close)
                NavigationStack(path: $path) {
                    SettingsRootView()
                        .navigationDestination(for: SettingsRoute.self) { route in
                            destination(for: route)
                        }
                }
                // A new identity after an idle reset rebuilds every screen
                // scrolled to the top, as if Settings had just opened.
                .id(activity.resetCount)
                SettingsAudioStatus()
            }
        }
        // As on Home, the window is the space, whatever a keyboard leaves of
        // it (Settings has no field of its own, but Home's keyboard can
        // still be going away as Settings opens), so Back to Talking never
        // moves.
        .ignoresSafeArea(.keyboard)
        .background(Palette.screen)
        .environment(activity)
        .environment(landing)
        .onChange(of: path) {
            activity.recordActivity()
        }
        .onChange(of: attention.isSounding, initial: true) { _, isSounding in
            // Never change the screen under someone answering the alarm.
            activity.setHold(.alarm, isSounding)
        }
        .onChange(of: speech.isAskingForPersonalVoice, initial: true) { _, isAsking in
            // Voice Settings' question is open over the screen: the screen
            // under it must still be there when it is answered.
            activity.setHold(.personalVoiceRequest, isAsking)
        }
        .onChange(of: scenePhase) { _, phase in
            // Time in another app or with the screen off never counts.
            if phase == .active {
                activity.recordActivity()
            }
        }
        .task(id: IdleWait(deadline: activity.clock.deadline, isActive: scenePhase == .active)) {
            guard scenePhase == .active, let deadline = activity.clock.deadline else { return }
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard !Task.isCancelled else { return }
            if activity.resetIfDue() {
                path = []
            }
        }
    }

    @ViewBuilder
    private func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .familySetup:
            FamilySetupView()
        case .guidedSetup(let step):
            GuidedSetupView(step: step, path: $path)
        case .voice:
            VoiceSettingsView()
        case .reachingTheScreen:
            ReachingTheScreenView()
        case .keepOpen:
            KeepOpenView()
        case .callsSiriAndShortcuts:
            CallsSiriAndShortcutsView()
        case .moreAccessibility:
            MoreAccessibilityView()
        case .privacy:
            PrivacyPolicyView()
        case .about:
            AboutView()
        }
    }

    /// What the idle task waits on: it restarts whenever the deadline moves
    /// or Brickson stops or starts being the active app.
    private struct IdleWait: Hashable {
        let deadline: ContinuousClock.Instant?
        let isActive: Bool
    }
}

/// The row above every Settings screen: Back to Talking, in the frame Home's
/// layout engine gives it over Phrases (`HomeLayout.backToTalking`), from
/// the same window and text size. Settings always closes onto the phrases,
/// so a look still resting on Back to Talking meets Phrases, which does
/// nothing while they show (docs/DECISIONS.md, "Typing on Home"). It looks
/// like Home's controls, in the categories' font: its words are on one
/// line where it is wide enough, on two where Phrases is tall enough for
/// them, and drop the icon before they shrink, never below their default
/// size (`FittedLabel`).
///
/// Its leading side is the place kept for a start-only Get Attention,
/// which the owner decides on (docs/DECISIONS.md, "Get Attention in
/// Settings' bar: the owner decides"). The bar ends a gap below Back to
/// Talking, so every screen starts at the same height.
struct SettingsSafetyBar: View {
    /// The room between Back to Talking and the screen below it.
    static let gapBelow: CGFloat = 8

    /// Back to Talking's frame, in the window's coordinates.
    let backToTalking: CGRect
    /// What the system keeps at the window's edges: the bar starts inside
    /// them, as the engine's frames do.
    let safeArea: HomeLayout.Insets
    let close: () -> Void

    var body: some View {
        Button(action: close) {
            FittedLabel(
                String(localized: "Back to Talking"), systemImage: "bubble.left.and.text.bubble.right.fill", font: .category
            )
        }
        .buttonStyle(HomeButtonStyle(fill: Palette.phraseFill))
        .accessibilityIdentifier("backToTalking")
        .frame(width: backToTalking.width, height: backToTalking.height)
        // Leading, so the bar mirrors with the language, as Home does.
        .padding(.leading, backToTalking.minX - safeArea.leading)
        .padding(.top, backToTalking.minY - safeArea.top)
        .padding(.bottom, Self.gapBelow)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sound problems while Settings covers Home, as passive text in a line kept
/// for it at the foot of the cover, so nothing moves when one appears
/// (AGENTS.md, invariant 4). The words are `AudioSafetyPolicy`'s for a
/// screen over Home: they name Back, then Again or Get Attention. Home's own
/// warnings still announce each problem to VoiceOver under the cover, in
/// the same words, so this line does not announce them again.
private struct SettingsAudioStatus: View {
    @Environment(SpeechService.self) private var speech
    @Environment(AudioSafetyMonitor.self) private var audioSafety
    @Environment(AttentionAlertPlayer.self) private var attention

    private var issue: HomeAudioIssue? {
        AudioSafetyPolicy(
            attentionState: attention.state,
            speechInterruptionState: speech.speechInterruptionState,
            speechRecoveryAction: .dismissThenRepeat,
            audioSessionHealthy: audioSafety.audioSessionHealthy,
            outputVolume: audioSafety.outputVolume
        ).issue
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(HomeAudioIssue.allCases, id: \.self) { candidate in
                warning(candidate)
                    .hidden()
                    .accessibilityHidden(true)
            }
            if let issue {
                warning(issue)
                    .accessibilityLabel(issue.message)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SettingsMetrics.gutter)
        .padding(.vertical, 8)
        .allowsHitTesting(false)
    }

    private func warning(_ issue: HomeAudioIssue) -> some View {
        Label(issue.compactMessage, systemImage: issue.systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}

/// The root's Family Setup row as drawn, its button style's insets
/// included. Family Setup's opening text is at least this tall, so the
/// whole of the spot just activated lands on words (AGENTS.md,
/// invariant 10). It is measured, because the style's insets are the
/// system's, not ours.
@Observable
final class SettingsLanding {
    var rootRowHeight: CGFloat = 0
}

/// Settings' first screen: one large way into Family Setup, and a short
/// note on what lies there. Nothing here changes a setting.
///
/// The row starts right under the safety bar, over the spot where Home's
/// Settings was, so a look still resting there meets a row that only
/// navigates (docs/DECISIONS.md, "Settings on Home"). Where half the width
/// holds the row's words on one line, the row takes the trailing half, with
/// the note beside it (`SettingsRootColumns`). Across a wide window, a
/// full-width row's centre lies farther from that spot than Back to
/// Talking's, so by the nearest centre a held look could close Settings
/// again (modelled from CI's frames on PR #33). Where half the width is too
/// narrow, as on a phone, the row spans the width, which keeps its words
/// whole.
struct SettingsRootView: View {
    @Environment(SettingsLanding.self) private var landing: SettingsLanding?

    var body: some View {
        SettingsScreen(title: "Settings") {
            // The rows' gap, between the two columns too.
            SettingsRootLayout(spacing: SettingsMetrics.rowSpacing) {
                familySetup
                note
            }
        }
    }

    private var familySetup: some View {
        NavigationLink(value: SettingsRoute.familySetup) {
            familySetupLabel
        }
        .settingsRowStyle()
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { landing?.rootRowHeight = $0 }
        .accessibilityIdentifier("familySetup")
    }

    private var familySetupLabel: some View {
        SettingsRowLabel(title: "Family Setup", systemImage: "person.2.fill")
            .frame(minHeight: FamilySetupView.openingHeight)
    }

    private var note: some View {
        SettingsParagraph("Voices, help with reaching the screen, keeping \(AppName.display) open, and the privacy policy are in Family Setup.")
    }
}

/// Places Settings' root where `SettingsRootColumns` says: its first view is
/// the Family Setup row, its second the note. It measures the row with its
/// words on one line, then each view at the width it gets.
nonisolated struct SettingsRootLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        columns(width: proposal.width, subviews: subviews)?.size ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let columns = columns(width: bounds.width, subviews: subviews) else { return }
        for (subview, frame) in zip(subviews, [columns.row, columns.note]) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    /// Nothing but the row and the note is placed: the root has exactly
    /// these two.
    private func columns(width: CGFloat?, subviews: Subviews) -> SettingsRootColumns? {
        guard subviews.count == 2 else { return nil }
        let row = subviews[0]
        let note = subviews[1]
        let rowIdealWidth = row.sizeThatFits(.unspecified).width
        // Asked for its own width, the root stacks at the row's.
        let width = width.flatMap { $0.isFinite ? $0 : nil } ?? rowIdealWidth
        return SettingsRootColumns(
            width: width,
            spacing: spacing,
            rowIdealWidth: rowIdealWidth,
            rowHeight: { row.sizeThatFits(ProposedViewSize(width: $0, height: nil)).height },
            noteHeight: { note.sizeThatFits(ProposedViewSize(width: $0, height: nil)).height }
        )
    }
}

// MARK: - Presenting Settings from Home

/// Home's way into Settings. Home places it, at the trailing end of its
/// categories (docs/DECISIONS.md, "Settings on Home"), and gives it its
/// frame; everything it opens lives here. It looks like Home's other
/// controls, and its gear drops before its word shrinks (`FittedLabel`).
/// Where Home has room beside the categories only for the gear
/// (`HomeLayout.settingsShowsName`), it shows the gear alone, named
/// "Settings" for VoiceOver, Voice Control and Switch Control, with a large
/// copy of its name for the large content viewer, rather than take a row
/// from the phrases.
struct SettingsButton: View {
    static let symbol = "gearshape.fill"
    /// The gear alone at the default text size. `StarterLabelFitTests`
    /// checks the narrowest gear-only Settings has room for it, and that it
    /// is no smaller than the gear beside the word.
    static let symbolSide: CGFloat = 24

    @Binding var isPresented: Bool
    var showsName = true
    /// The gear alone grows with the text, up to the room the button has.
    @ScaledMetric(relativeTo: .headline) private var gearSide = SettingsButton.symbolSide

    var body: some View {
        let button = Button {
            isPresented = true
        } label: {
            if showsName {
                FittedLabel(HomeControlNames.settings.visible, systemImage: Self.symbol, font: .category)
            } else {
                Image(systemName: Self.symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: gearSide, maxHeight: gearSide)
                    .accessibilityLabel(Text(verbatim: HomeControlNames.settings.visible))
            }
        }
        .buttonStyle(HomeButtonStyle(fill: Palette.controlFill))
        .accessibilityInputLabels(HomeControlNames.settings.inputLabels)
        .accessibilityIdentifier("settings")

        if showsName {
            button
        } else {
            // The gear stops growing where the button's room ends.
            button.accessibilityShowsLargeContentViewer {
                Label(HomeControlNames.settings.visible, systemImage: Self.symbol)
            }
        }
    }
}

extension View {
    /// Presents Settings over this view as a full-screen cover.
    func settingsCover(isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            SettingsCoverContent(isPresented: isPresented)
        }
    }
}

/// Reads this launch's idle limits, which only a view can, and opens
/// Settings with them.
private struct SettingsCoverContent: View {
    @Binding var isPresented: Bool
    @Environment(\.appTimeouts) private var timeouts

    var body: some View {
        SettingsView(idleLimit: timeouts.limit(SettingsIdleClock.standardLimit, short: .seconds(3))) {
            isPresented = false
        }
    }
}

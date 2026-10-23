import Observation
import SwiftUI

/// Settings: a full-screen cover over Home, for the family.
///
/// Because it covers Home's quick controls, every Settings screen sits under
/// one fixed safety bar: a start-only Get Attention at the top leading edge
/// and a large Back to Talking at the top trailing edge, at the same frames
/// on every screen (docs/DECISIONS.md, "Settings is a cover with a fixed
/// safety bar"). The settings themselves start a screen below the root, so
/// a stray dwell that opens Settings meets only the way back, Get Attention
/// and the one Family Setup row.
///
/// When nobody has used it for 90 seconds it goes back to its root and
/// stays open; only Back to Talking closes it (docs/DECISIONS.md, "Settings
/// resets when idle and never closes").
///
/// Under the bar, a line kept for it shows any sound problem, because the
/// cover hides Home's: a sample that cannot be heard always says why
/// (AGENTS.md, invariant 4).
struct SettingsView: View {
    let close: () -> Void

    @Environment(\.scenePhase) private var scenePhase
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
        VStack(spacing: 0) {
            SettingsSafetyBar(close: close)
            SettingsAudioStatus()
            NavigationStack(path: $path) {
                SettingsRootView()
                    .navigationDestination(for: SettingsRoute.self) { route in
                        destination(for: route)
                    }
            }
            // A new identity after an idle reset rebuilds every screen
            // scrolled to the top, as if Settings had just opened.
            .id(activity.resetCount)
        }
        .background(Color(uiColor: .systemBackground))
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

/// The row above every Settings screen.
///
/// Get Attention's place is kept empty until Home shows Get Attention and
/// Stop: starting the alarm here while Home has no Stop would leave it
/// sounding with no way to stop it. Because the place is kept, adding it
/// moves nothing. Back to Talking's words are never shrunk: its icon sits
/// above them, so it never takes their width (`SettingsPairLabel`).
struct SettingsSafetyBar: View {
    let close: () -> Void

    var body: some View {
        HStack(spacing: SettingsMetrics.rowSpacing) {
            // Get Attention (start only) joins here with Home's Stop.
            Color.clear
                .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight)
                .accessibilityHidden(true)

            Button(action: close) {
                SettingsPairLabel(title: "Back to Talking", systemImage: "bubble.left.and.text.bubble.right.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.phraseFill)
            .accessibilityIdentifier("backToTalking")
        }
        .padding(.horizontal, SettingsMetrics.gutter)
        .padding(.vertical, 8)
    }
}

/// Sound problems while Settings covers Home, as passive text in a line kept
/// for it, so nothing moves when one appears (AGENTS.md, invariant 4). The
/// words are `AudioSafetyPolicy`'s for a screen over Home: they name Back,
/// then Again. Home's own warnings still announce each problem to
/// VoiceOver under the cover, so this line does not announce them again.
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
        .padding(.bottom, 8)
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
struct SettingsRootView: View {
    @Environment(SettingsLanding.self) private var landing: SettingsLanding?

    var body: some View {
        SettingsScreen(title: "Settings") {
            NavigationLink(value: SettingsRoute.familySetup) {
                SettingsRowLabel(title: "Family Setup", systemImage: "person.2.fill")
                    .frame(minHeight: FamilySetupView.openingHeight)
            }
            .settingsRowStyle()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { landing?.rootRowHeight = $0 }
            .accessibilityIdentifier("familySetup")

            SettingsParagraph("Voices, help with reaching the screen, keeping \(AppName.display) open, and the privacy policy are in Family Setup.")
        }
    }
}

// MARK: - Presenting Settings from Home

/// Home's way into Settings. Home places it, at the trailing end of its
/// categories (docs/DECISIONS.md, "Settings on Home"), and gives it its
/// frame; everything it opens lives here. It looks like Home's other
/// controls, and its gear drops before its word shrinks (`FittedLabel`).
/// Where Home has room beside the categories only for the gear
/// (`HomeShape.settingsShowsName`), it shows the gear alone, named
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

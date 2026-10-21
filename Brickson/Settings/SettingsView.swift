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
    @State private var path: [SettingsRoute] = []
    @State private var activity: SettingsActivity

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
        .onChange(of: path) {
            activity.recordActivity()
        }
        .onChange(of: attention.isSounding, initial: true) { _, isSounding in
            // Never change the screen under someone answering the alarm.
            activity.setHold(.alarm, isSounding)
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
/// moves nothing. Back to Talking's words are never shrunk.
struct SettingsSafetyBar: View {
    let close: () -> Void

    var body: some View {
        HStack(spacing: SettingsMetrics.rowSpacing) {
            // Get Attention (start only) joins here with Home's Stop.
            Color.clear
                .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight)
                .accessibilityHidden(true)

            Button(action: close) {
                Label("Back to Talking", systemImage: "bubble.left.and.text.bubble.right.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight)
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

/// Settings' first screen: one large way into Family Setup, and a short
/// note on what lies there. Nothing here changes a setting.
struct SettingsRootView: View {
    var body: some View {
        SettingsScreen(title: "Settings") {
            NavigationLink(value: SettingsRoute.familySetup) {
                SettingsRowLabel(title: "Family Setup", systemImage: "person.2.fill")
                    .frame(minHeight: FamilySetupView.openingHeight)
            }
            .settingsRowStyle()
            .accessibilityIdentifier("familySetup")

            SettingsParagraph("Voices, help with reaching the screen, keeping \(AppName.display) open, and the privacy policy are in Family Setup.")
        }
    }
}

// MARK: - Presenting Settings from Home

/// Home's way into Settings. Home places it (where it sits is part of
/// Home's layout); everything it opens lives here.
struct SettingsButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("Settings", systemImage: "gearshape.fill")
        }
        .accessibilityIdentifier("settings")
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

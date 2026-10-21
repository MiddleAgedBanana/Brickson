import SwiftUI

/// Set Up Step by Step: five short screens a family member goes through
/// once, and again at each check-in.
///
/// 1. How is the screen reached? (any number of answers)
/// 2. The voice and speed.
/// 3. Turning on what was chosen in step 1.
/// 4. Keeping Brickson open.
/// 5. A summary.
///
/// Every step can be left at any time with the standard Back button or
/// Back to Talking; whatever was answered is kept, and nothing is recorded
/// as "finished" (docs/DECISIONS.md, "Setup answers are kept as offered,
/// never as completed"). Next and Done sit in the same fixed bar at the
/// bottom of every step. A held look on Next can walk through the steps,
/// which only navigates; Back undoes it.
struct GuidedSetupView: View {
    let step: GuidedSetupStep
    @Binding var path: [SettingsRoute]

    @Environment(SetupStore.self) private var setup
    /// Step 1's answers, held here until Next saves them, so a failed save
    /// keeps them on screen to try again.
    @State private var draft: Set<AccessMethod>? = nil
    @State private var saveFailed = false

    var body: some View {
        SettingsScreen(title: "Step \(step.number) of \(GuidedSetupStep.count)") {
            content
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .access:
            accessQuestion
        case .voice:
            SettingsHeading("Choose the voice")
            VoiceContent()
        case .turnOn:
            SettingsHeading("Turn on what is used")
            ReachingTheScreenContent(methods: setup.record.plannedAccessMethods ?? Set(AccessMethod.allCases))
        case .keepOpen:
            SettingsHeading("Keep \(AppName.display) open")
            KeepOpenContent()
        case .ready:
            readySummary
        }
    }

    private var chosen: Set<AccessMethod> {
        draft ?? setup.record.accessMethods ?? []
    }

    /// Choices only ever select: a repeated activation of a choice leaves it
    /// chosen rather than undoing it (AGENTS.md, invariant 10). Clear My
    /// Choices is a separate button at the end.
    @ViewBuilder
    private var accessQuestion: some View {
        SettingsHeading("How is the screen reached?")
        SettingsParagraph("Choose every way that is used now. This sets how large \(AppName.display)’s buttons are. If nothing is chosen, it uses its largest sizes.")

        ForEach(AccessMethod.allCases, id: \.self) { method in
            let isChosen = chosen.contains(method)
            Button {
                draft = chosen.union([method])
            } label: {
                SettingsRowLabel(title: method.title, systemImage: isChosen ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(isChosen ? Palette.phraseFill : Palette.controlFill)
            .accessibilityAddTraits(isChosen ? .isSelected : [])
        }

        Button {
            draft = []
        } label: {
            SettingsRowLabel(title: "Clear My Choices", systemImage: "xmark.circle")
        }
        .settingsRowStyle()
        .padding(.top, 24)

        if saveFailed {
            SettingsParagraph("These answers could not be saved. Choose Next to try again.")
        }
    }

    @ViewBuilder
    private var readySummary: some View {
        SettingsHeading("Ready")
        if let methods = setup.record.plannedAccessMethods {
            SettingsParagraph("\(AppName.display) is set up for:")
            ForEach(AccessMethod.allCases.filter(methods.contains), id: \.self) { method in
                SettingsParagraph(method.title)
            }
        } else {
            SettingsParagraph("No way of reaching the screen was chosen, so \(AppName.display) uses its largest sizes.")
        }
        SettingsParagraph("Everything here can be changed later in Family Setup. In about three months, Family Setup will ask whether anything has changed.")
    }

    private var bottomBar: some View {
        Button {
            advance()
        } label: {
            SettingsRowLabel(
                title: step.next == nil ? "Done" : "Next",
                systemImage: step.next == nil ? "checkmark" : "arrow.right"
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.phraseFill)
        .padding(SettingsMetrics.gutter)
        .background(Color(uiColor: .systemBackground))
        .accessibilityIdentifier("guidedSetupNext")
    }

    private func advance() {
        if step == .access {
            // Next is the answer, even unchanged: going through the step
            // again is what a check-in asks for.
            let answer = chosen
            guard setup.update({ CheckInPolicy.answered(&$0, methods: answer, now: .now) }) else {
                saveFailed = true
                return
            }
            saveFailed = false
            draft = nil
        }
        if let next = step.next {
            path.append(.guidedSetup(next))
        } else {
            // Back to Family Setup, wherever the steps were started from.
            if let start = path.firstIndex(where: { if case .guidedSetup = $0 { true } else { false } }) {
                path.removeSubrange(start...)
            }
        }
    }
}

extension AccessMethod {
    var title: LocalizedStringKey {
        switch self {
        case .touch: "Touch"
        case .voiceControl: "Voice Control"
        case .switchControl: "Switch Control"
        case .eyeTracking: "Eye Tracking"
        case .headTracking: "Head Tracking"
        case .someoneElse: "Someone else helps"
        }
    }
}

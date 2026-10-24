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
/// Back to Talking; each answer is saved the moment it is chosen, and
/// nothing is recorded as "finished" (docs/DECISIONS.md, "Setup answers are
/// kept as offered, never as completed"). Next and Done sit in the same
/// fixed bar at the bottom of every step. A held look on Next can walk
/// through the steps, which only navigates; Back undoes it.
struct GuidedSetupView: View {
    let step: GuidedSetupStep
    @Binding var path: [SettingsRoute]

    @Environment(SetupStore.self) private var setup
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
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
            SettingsHeading("Keep \(AppName.display) Open")
            KeepOpenContent()
        case .ready:
            readySummary
        }
    }

    private var chosen: Set<AccessMethod> {
        setup.record.accessMethods ?? []
    }

    /// Choices only ever select: a repeated activation of a choice leaves it
    /// chosen rather than undoing it (AGENTS.md, invariant 10). Clear My
    /// Choices is a separate button at the end.
    @ViewBuilder
    private var accessQuestion: some View {
        SettingsHeading("How is the screen reached?")
        // Nothing reads these answers yet, so the words promise no change
        // to the buttons; the layout engine adds that sentence when it reads
        // them (docs/log/2026-10-21-settings-and-first-run.md, follow-up 5).
        SettingsParagraph("Choose every way that is used now. Each answer is saved as soon as it is chosen.")

        ForEach(AccessMethod.allCases, id: \.self) { method in
            let isChosen = chosen.contains(method)
            Button {
                answer(chosen.union([method]))
            } label: {
                SettingsRowLabel(title: method.title, systemImage: isChosen ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(isChosen ? Palette.phraseFill : Palette.controlFill)
            .accessibilityAddTraits(isChosen ? .isSelected : [])
        }

        Button {
            answer([])
        } label: {
            SettingsRowLabel(title: "Clear My Choices", systemImage: "xmark.circle")
        }
        .settingsRowStyle()
        .padding(.top, 24)

        if saveFailed {
            SettingsParagraph("That answer could not be saved. Try again.")
        }
    }

    @ViewBuilder
    private var readySummary: some View {
        SettingsHeading("Ready")
        if let methods = setup.record.plannedAccessMethods {
            SettingsParagraph("Ways of reaching the screen chosen:")
            ForEach(AccessMethod.allCases.filter(methods.contains), id: \.self) { method in
                SettingsParagraph(method.title)
            }
        } else {
            SettingsParagraph("No way of reaching the screen was chosen.")
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
        .background(Palette.screen)
        .accessibilityIdentifier("guidedSetupNext")
    }

    /// Saves an answer at once, so leaving the step any way keeps it. A
    /// failed save changes nothing on screen and says so.
    private func answer(_ methods: Set<AccessMethod>) {
        activity?.recordActivity()
        saveFailed = !setup.update { CheckInPolicy.answered(&$0, methods: methods, now: .now) }
    }

    private func advance() {
        activity?.recordActivity()
        if step == .access {
            // Next answers too, even unchanged: going through the step
            // again is what a check-in asks for.
            answer(chosen)
            guard !saveFailed else { return }
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

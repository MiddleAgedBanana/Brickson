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
/// fixed bar at the bottom of every step, and only move on: a held look on
/// Next can walk through the steps, and Back undoes it. Going through
/// setup again from the check-in card answers the check-in there
/// (`CheckInPolicy.wentThroughAgain`), so Next never saves.
///
/// The first step opens on Learn About Each Way, which opens the Reaching
/// the Screen guide as a cover of its own (`EachWayCover`), and starts its
/// answers below every place a look can be resting on the way in
/// (`SetupAccessQuestion`; docs/DECISIONS.md, "The first step's own rows").
struct GuidedSetupView: View {
    let step: GuidedSetupStep
    @Binding var path: [SettingsRoute]

    @Environment(SetupStore.self) private var setup
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    // The guide's cover shows the sound line, as Settings' cover does.
    @Environment(SpeechService.self) private var speech
    @Environment(AudioSafetyMonitor.self) private var audioSafety
    @Environment(AttentionAlertPlayer.self) private var attention
    @State private var saveFailed = false
    @State private var showsEachWay = false

    var body: some View {
        SettingsScreen(title: "Step \(step.number) of \(GuidedSetupStep.count)") {
            content
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .fullScreenCover(isPresented: $showsEachWay) {
            EachWayCover {
                activity?.recordActivity()
                showsEachWay = false
            }
            .environment(activity)
            .environment(speech)
            .environment(audioSafety)
            .environment(attention)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .access:
            SetupAccessQuestion(chosen: chosen, saveFailed: saveFailed, answer: answer) {
                activity?.recordActivity()
                showsEachWay = true
            }
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

/// The first step's question: how the screen is reached.
///
/// Learn About Each Way takes Set Up Step by Step's place as Family Setup
/// drew it (`SettingsLanding`), at least as tall, so a look still resting
/// there meets a control that only opens the guide; the question and its
/// sentence go beside it, above it or under it (`SettingsLeadIn`). The
/// answers start where every point of Home's Settings, the root's row and
/// Set Up Step by Step lies nearer the link than the first answer
/// (`SetupAnswersPlace`), so a held look on the way in saves nothing
/// (docs/DECISIONS.md, "The first step's own rows").
///
/// Choices only ever select: a repeated activation of a choice leaves it
/// chosen rather than undoing it (AGENTS.md, invariant 10). Clear My
/// Choices is a separate button at the end.
private struct SetupAccessQuestion: View {
    let chosen: Set<AccessMethod>
    let saveFailed: Bool
    let answer: (Set<AccessMethod>) -> Void
    let learnAboutEachWay: () -> Void

    @Environment(\.settingsCover) private var cover
    @Environment(\.settingsScreenFrames) private var frames
    @Environment(SettingsLanding.self) private var landing: SettingsLanding?

    var body: some View {
        SettingsLeadInLayout(placement: placement, controlFirst: false, spacing: SettingsMetrics.rowSpacing) {
            VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
                SettingsHeading("How is the screen reached?")
                // Nothing reads these answers yet, so the words promise no
                // change to the buttons; the layout engine adds that sentence
                // when it reads them
                // (docs/log/2026-10-21-settings-and-first-run.md, follow-up 5).
                SettingsParagraph("Choose every way that is used now. Each answer is saved as soon as it is chosen.")
            }

            Button(action: learnAboutEachWay) {
                // As tall as the place it is given.
                SettingsRowLabel(title: "Learn About Each Way", systemImage: "book.fill")
                    .frame(maxHeight: .infinity)
            }
            .settingsRowStyle()
            .accessibilityIdentifier("learnAboutEachWay")
        }
        .frame(minHeight: leadInHeight, alignment: .topLeading)

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

    private var placement: SettingsLeadInLayout.Placement {
        guard let row = landing?.guidedRow else { return .atTheTop }
        return .inPlaceOf(row)
    }

    /// The least height of the link and its words: down to a row's gap
    /// above where `SetupAnswersPlace` starts the answers, in the content.
    /// Until the screen knows where it sits and what led to it, nothing.
    private var leadInHeight: CGFloat {
        guard let cover, let frames, let guided = landing?.guidedRow else { return 0 }
        let origin = frames.content.origin
        let link = guided.offsetBy(dx: origin.x, dy: origin.y)
        let root = landing?.rootRow?.offsetBy(dx: origin.x, dy: origin.y) ?? .null
        let place = SetupAnswersPlace(
            arrivals: [cover.home.frame(.settings), root, link], link: link,
            answersMinX: frames.content.minX, answersWidth: frames.content.width,
            answerHeight: SettingsMetrics.rowHeight, earliest: link.maxY + SettingsMetrics.rowSpacing
        )
        return max(0, place.top - origin.y - SettingsMetrics.rowSpacing)
    }
}

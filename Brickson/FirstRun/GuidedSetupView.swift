import SwiftData
import SwiftUI

/// Set Up Step by Step: six short screens a family member goes through
/// once, and again at each check-in.
///
/// 1. How is the screen reached? (any number of answers)
/// 2. Which phrases does Home show? (every category, or one: the rest
///    board)
/// 3. The voice and speed.
/// 4. Turning on what was chosen in step 1.
/// 5. Keeping Brickson open.
/// 6. A summary.
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
/// The first step opens on Learn About Each Way, in the place of the control
/// that opened it (`GuidedSetupEntry`), which opens the Reaching the Screen
/// guide as a cover of its own (`EachWayCover`), and starts its answers
/// below every place a look can be resting on the way in
/// (`SetupAccessQuestion`; docs/DECISIONS.md, "The first step's own rows").
/// The second step places its choices where a look resting on Next meets
/// Next again, and once the check-in card was answered, where a look over
/// the card's place meets Next too (`SetupRestBoardQuestion`;
/// docs/DECISIONS.md, "The late-stage profile").
struct GuidedSetupView: View {
    let step: GuidedSetupStep
    /// What opened the steps: only the first and second steps' layouts
    /// depend on it.
    let entry: GuidedSetupEntry
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
            SetupAccessQuestion(entry: entry, chosen: chosen, saveFailed: saveFailed, answer: answer) {
                activity?.recordActivity()
                showsEachWay = true
            }
        case .restBoard:
            SetupRestBoardQuestion(entry: entry, chosen: setup.record.restBoardCategory, saveFailed: saveFailed, choose: chooseRestBoard)
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
        RestBoardSummary(chosen: setup.record.restBoardCategory)
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

    /// Saves the rest board's category, or nil for every category, at
    /// once, as `answer` does.
    private func chooseRestBoard(_ category: UUID?) {
        activity?.recordActivity()
        saveFailed = !setup.update { $0.chooseRestBoard(category) }
    }

    private func advance() {
        activity?.recordActivity()
        SettingsRoute.advance(&path, from: step, entry: entry)
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
/// Learn About Each Way takes the place of the control that opened the
/// steps as Family Setup drew it (`SettingsLanding`): Set Up Step by Step,
/// or the check-in card's Go Through Setup Again. It is at least as tall,
/// so a look still resting there meets a control that only opens the
/// guide; the question and its sentence go beside it, above it or under it
/// (`SettingsLeadIn`). The answers start where every point a look can be
/// resting on the way in lies nearer the link than the first answer
/// (`SetupAnswersPlace`): Home's Settings, the root's row and Set Up Step by
/// Step, with the check-in card's rows once the card was answered in its
/// place, or Go Through Setup Again. So a held look on the way in saves
/// nothing (docs/DECISIONS.md, "The first step's own rows").
///
/// Choices only ever select: a repeated activation of a choice leaves it
/// chosen rather than undoing it (AGENTS.md, invariant 10). Clear My
/// Choices is a separate button at the end.
private struct SetupAccessQuestion: View {
    let entry: GuidedSetupEntry
    let chosen: Set<AccessMethod>
    let saveFailed: Bool
    let answer: (Set<AccessMethod>) -> Void
    let learnAboutEachWay: () -> Void

    @Environment(\.settingsCover) private var cover
    @Environment(\.settingsScreenFrames) private var frames
    @Environment(SettingsLanding.self) private var landing: SettingsLanding?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverIsOn
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlIsOn
    @Environment(\.homeSizesFollowTheAnswer) private var sizesFollowTheAnswer

    var body: some View {
        SettingsLeadInLayout(placement: placement, controlFirst: false, spacing: SettingsMetrics.rowSpacing) {
            VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
                SettingsHeading("How is the screen reached?")
                SettingsParagraph("Choose every way that is used now. Each answer is saved as soon as it is chosen.")
                // Only where the owner's switch has Home follow the
                // answers (`ProfileChoice.followsTheAnswer`), or a UI test
                // asks it to; a test that fixes Home's sizes still shows
                // it, so the step is tested as people see it.
                if sizesFollowTheAnswer {
                    SettingsParagraph("Home's buttons take the size the answers need, as large as this screen has room for, and are largest until something is chosen. The new size shows when Settings closes.")
                }
                // What iOS reports only suggests an answer, and the words
                // depend on it alone, never on the answers, so nothing moves
                // under a choice just made.
                if let suggestion = ProfileChoice.suggestion(voiceOver: voiceOverIsOn, switchControl: switchControlIsOn) {
                    SettingsParagraph(Self.words(for: suggestion))
                }
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
        guard let row = landing?.opener(entry) else { return .atTheTop }
        return .inPlaceOf(row)
    }

    private static func words(for suggestion: ProfileChoice.Suggestion) -> LocalizedStringKey {
        switch suggestion {
        case .switchControlIsOn: "Switch Control is on, so Switch Control may be one of the answers."
        case .voiceOverIsOn: "VoiceOver is on, so Touch may be one of the answers."
        }
    }

    /// The least height of the link and its words: down to a row's gap
    /// above where `SetupAnswersPlace` starts the answers, in the content.
    /// Until the screen knows where it sits and what led to it, nothing.
    private var leadInHeight: CGFloat {
        guard let cover, let frames, let opener = landing?.opener(entry) else { return 0 }
        let origin = frames.content.origin
        let link = opener.offsetBy(dx: origin.x, dy: origin.y)
        let root = landing?.rootRow?.offsetBy(dx: origin.x, dy: origin.y) ?? .null
        let card = landing?.checkInRows?.offsetBy(dx: origin.x, dy: origin.y) ?? .null
        let place = SetupAnswersPlace(
            arrivals: SetupAnswersPlace.arrivals(
                from: entry, homesSettings: cover.home.frame(.settings), rootRow: root, opener: link, checkInRows: card
            ),
            link: link,
            answersMinX: frames.content.minX, answersWidth: frames.content.width,
            answerHeight: SettingsMetrics.rowHeight, earliest: link.maxY + SettingsMetrics.rowSpacing
        )
        return max(0, place.top - origin.y - SettingsMetrics.rowSpacing)
    }
}

/// The second step's question: which phrases Home shows (docs/DECISIONS.md,
/// "The late-stage profile").
///
/// Every Category, then each everyday category in Home's order, by its own
/// name, shown as written. Choices only ever select: choosing the chosen
/// one again keeps it, and choosing another moves the choice (AGENTS.md,
/// invariant 10). A look arrives here on the first step's Next, in the
/// same bar as this step's, so every choice lies where every point of
/// Next is nearer Next than the choice (`SetupChoicesPlace`): each under
/// the words, or the choice before it, where it holds there, and from the
/// first that does not, the rest below the bar, where the family scrolls
/// to them. Opened with Set Up Step by Step once the check-in card was
/// answered in its place, a look can arrive still over where the card's
/// rows were, which the first step's Next was nearest, so every point of
/// that place is kept nearer Next than each choice too
/// (`SetupChoicesPlace.arrivals(from:checkInRows:)`). The standard Back
/// button, where a look arrives from the third step, sits in the
/// navigation bar above the words. A choice the library no longer has as
/// an everyday category shows as Every Category, as Home does
/// (`RestBoard`). A category Home does not offer, with too few phrases, is
/// dimmed in its place, with a line under the words that says why, unless
/// it is already the board (docs/DECISIONS.md,
/// "Four phrases in every category").
private struct SetupRestBoardQuestion: View {
    let entry: GuidedSetupEntry
    let chosen: UUID?
    let saveFailed: Bool
    let choose: (UUID?) -> Void

    @Query private var categories: [PhraseCategory]
    /// Read for the counts, as Home reads them (`CategorySelection.phrases`).
    @Query private var phrases: [Phrase]
    @Environment(\.settingsScreenFrames) private var frames
    @Environment(SettingsLanding.self) private var landing: SettingsLanding?

    var body: some View {
        let everyday = CategorySelection.shownInCategoryRow(PhraseCategory.orderedForDisplay(categories))
        let current = everyday.first { $0.uuid == chosen }?.uuid
        let choices = CategorySelection.restBoardChoices(
            everyday, chosen: current, phraseCounts: CategorySelection.phraseCounts(phrases)
        )

        SetupChoicesLayout(screen: frames, arrivals: arrivals, choices: everyday.count + 1, spacing: SettingsMetrics.rowSpacing) {
            VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
                SettingsHeading("Which phrases does Home show?")
                SettingsParagraph("Home can show one category's phrases or Emergency's, with Yes, No, Emergency, Again and Get Attention as large as this screen has room for. The other categories stay where they are, dimmed, so nothing moves. The change shows when Settings closes.")
                if choices.saysWhy {
                    SettingsParagraph("A category with fewer than four phrases can't be chosen until it has four.")
                }
            }

            choice(Text("Every Category"), isChosen: current == nil, identifier: "restBoardEveryCategory") {
                choose(nil)
            }
            ForEach(everyday) { category in
                // A category's name is the family's own words, never translated.
                choice(Text(verbatim: category.name), isChosen: current == category.uuid, identifier: "restBoardCategory") {
                    choose(category.uuid)
                }
                .disabled(choices.dimmed.contains(category.uuid))
            }

            if saveFailed {
                SettingsParagraph("That answer could not be saved. Try again.")
            }
        }
    }

    /// Where else a look can be resting as the step appears, in the
    /// window: where the check-in card's rows were in Family Setup's
    /// content, which starts where this step's does. None until the screen
    /// knows where it sits.
    private var arrivals: [CGRect] {
        guard let frames, let rows = landing?.checkInRows else { return [] }
        return SetupChoicesPlace.arrivals(
            from: entry, checkInRows: rows.offsetBy(dx: frames.content.minX, dy: frames.content.minY)
        )
    }

    private func choice(_ title: Text, isChosen: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsRowLabel(text: title, systemImage: isChosen ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.borderedProminent)
        .tint(isChosen ? Palette.phraseFill : Palette.controlFill)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

/// Places the second step's words at the top of its content and its
/// choices where `SetupChoicesPlace` says, each measured at the width it
/// gets, with anything after the choices (the save-failure line)
/// `spacing` under the last. Its views are the words, then
/// the choices, then the rest, in the order VoiceOver reads them. It is
/// the step's only view, so its top is the content's.
nonisolated struct SetupChoicesLayout: Layout {
    /// Where the screen sits in the window, with Next at its foot; nil
    /// until the screen knows, when the choices follow the words.
    let screen: SettingsScreenFrames?
    /// Where else a look can be resting as the step appears, in the window
    /// (`SetupChoicesPlace.arrivals(from:checkInRows:)`).
    let arrivals: [CGRect]
    /// How many views after the words are choices.
    let choices: Int
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = Self.width(proposal.width, subviews: subviews)
        return CGSize(width: width, height: placed(width: width, subviews: subviews).map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, placed(width: bounds.width, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    /// The width given, or, asked for its own, the widest view's.
    private static func width(_ proposed: CGFloat?, subviews: Subviews) -> CGFloat {
        proposed.flatMap { $0.isFinite ? $0 : nil } ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
    }

    /// Each view's frame, from the layout's top-leading corner.
    private func placed(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        guard let words = heights.first else { return [] }
        let choiceHeights = Array(heights.dropFirst().prefix(choices))
        let earliest = words + spacing
        let origin = screen?.content.origin ?? .zero
        let tops = SetupChoicesPlace(
            next: screen?.foot ?? .zero, arrivals: arrivals, choicesMinX: origin.x, choicesWidth: width, heights: choiceHeights,
            spacing: spacing, earliest: origin.y + earliest
        ).tops.map { $0 - origin.y }
        var frames = [CGRect(x: 0, y: 0, width: width, height: words)]
        var y = earliest
        for (index, height) in heights.dropFirst().enumerated() {
            if index < tops.count {
                y = tops[index]
            }
            frames.append(CGRect(x: 0, y: y, width: width, height: height))
            y += height + spacing
        }
        return frames
    }
}

/// The summary's line about the second step: every category, or the rest
/// board's category by its own name. A choice the library no longer has
/// as an everyday category reads as every category, as Home shows it.
private struct RestBoardSummary: View {
    let chosen: UUID?

    @Query private var categories: [PhraseCategory]

    var body: some View {
        if let board = categories.first(where: { $0.uuid == chosen && !$0.isEmergency }) {
            SettingsParagraph("Home shows one category's phrases:")
            SettingsParagraph(verbatim: board.name)
        } else {
            SettingsParagraph("Home shows every category.")
        }
    }
}

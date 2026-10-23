import Accessibility
import SwiftData
import SwiftUI

/// Home, version 0: a plain stand-in that proves the foundations work end to
/// end. A phrase is chosen, the speech engine says it, and the message shows
/// it to the person listening.
///
/// It will be replaced when the layout engine and Home are ported
/// (docs/PORTING.md, steps 4 and 5). Even so, it keeps the rules that matter
/// from the first build: every control is a standard `Button` with a label
/// (invariant 1), every tile speaks on the first activation (invariant 2), a
/// lingering look cannot make a phrase stutter (`SpokenUtteranceTracker`),
/// and nothing moves when state changes (the message and its status lines
/// keep their size).
///
/// The arrangement comes from the space Home is given (`HomeShape`), never
/// from which device it is on. Top to bottom: the message with its status
/// lines, the safety row (Yes, No, Again and Emergency), the categories with
/// Settings at their trailing end, then the phrase grid, which takes what is
/// left. Everything a person needs while typing sits in the top
/// part, which the software keyboard never reaches (docs/LESSONS.md, "Lay
/// out against a measured keyboard"); the categories are nearest the
/// keyboard because a slip onto one is harmless. No control's label breaks a
/// word: each one fits itself (`FittedLabel`). The starter library needs no
/// scrolling on the windows `HomeLayoutTests` checks; the grid scrolls only
/// where its tiles would otherwise be shorter than
/// `HomeShape.minimumTileHeight`, or where a library warning takes its room.
///
/// Each region is an accessibility container, and assistive technologies
/// reach them in a fixed order that differs from the one on screen: Yes, No
/// and Emergency first, then Again, the message, the categories and
/// Settings, and the phrases (`HomeRegion`). Voice Control and Full Keyboard
/// Access know the fixed controls by the names in `HomeControlNames`, their
/// visible words first.
struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Query private var categories: [PhraseCategory]
    @State private var selectedCategoryID: UUID?
    /// Whether Settings covers Home. Its button sets it; Settings' Back to
    /// Talking clears it (`settingsCover`).
    @Binding var showsSettings: Bool

    init(showsSettings: Binding<Bool>) {
        _showsSettings = showsSettings
    }

    var body: some View {
        let ordered = PhraseCategory.orderedForDisplay(categories)
        let selected = CategorySelection.resolve(ordered, selectedID: selectedCategoryID)
        let emergency = CategorySelection.emergency(in: ordered)
        let largestCategoryCount = ordered.map(\.phrasesInOrder.count).max() ?? 0

        GeometryReader { proxy in
            let contentWidth = proxy.size.width
            let shape = HomeShape(
                contentWidth: contentWidth,
                quickControlLineHeight: LabelFont.quickControl.legible(legibilityWeight).lineHeight(at: dynamicTypeSize),
                categoryLineHeight: LabelFont.category.legible(legibilityWeight).lineHeight(at: dynamicTypeSize),
                boldText: legibilityWeight == .bold
            )

            VStack(alignment: .leading, spacing: HomeShape.regionSpacing) {
                MessageBlock(width: contentWidth)
                    .homeRegion(.message)
                SafetyRow(
                    shape: shape,
                    emergencyIsAvailable: emergency != nil,
                    isShowingEmergency: selected?.isEmergency == true,
                    showEmergency: { selectedCategoryID = emergency?.uuid }
                )
                .frame(height: shape.safetyRegionHeight)
                .homeRegion(.safety)
                CategoriesAndSettings(
                    shape: shape,
                    categories: CategorySelection.shownInCategoryRow(ordered),
                    selectedID: selected?.uuid,
                    select: { selectedCategoryID = $0 },
                    showsSettings: $showsSettings
                )
                .frame(height: shape.categoryRegionHeight)
                .homeRegion(.categories)
                PhraseGrid(
                    category: selected,
                    columns: shape.gridColumns,
                    rows: shape.gridRows(largestCategoryCount: largestCategoryCount),
                    minimumTileHeight: shape.minimumTileHeight,
                    tileFont: shape.isCompact ? .compactTile : .regularTile
                )
                .frame(maxHeight: .infinity)
                .homeRegion(.phrases)
                LibraryWarnings()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // The keyboard overlays the bottom of Home instead of pushing it up,
        // so no control moves when it appears (invariant 11).
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Message

/// The last sentence spoken, large enough for the listener to read, with
/// its status lines under it, across the full width. No control shares the
/// region: Again is in the safety row, so a look that rests on the message
/// and slips past its trailing end meets nothing there
/// (docs/DECISIONS.md, "Settings on Home").
private struct MessageBlock: View {
    /// The width of the message and its status line.
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MessageText()
            StatusLines(width: width)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The message itself. Two lines of the message font at the person's text
/// size are always reserved, by an invisible placeholder, so nothing below
/// moves when a message appears or changes. A longer message scrolls inside
/// them. It steps down through Apple's text sizes only as far as its widest
/// word needs to fit the width, never below the default size (AGENTS.md,
/// "Words never break"). Every phrase start, Again included, shows the
/// message from the top. Before anything is spoken it shows a placeholder,
/// or, until Family Setup has been opened once, the line that tells a family
/// where setup is (`FirstRunHint`).
private struct MessageText: View {
    @Environment(SpeechService.self) private var speech
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.showsSetupHint) private var showsSetupHint

    var body: some View {
        let font = LabelFont.message
        let text = speech.lastSpokenText ?? (showsSetupHint ? FirstRunHint.text : String(
            localized: "Choose a phrase to speak it.",
            comment: "Shown where the spoken message appears, before anything has been spoken."
        ))

        Text(verbatim: " ")
            .font(font.font)
            .lineLimit(2, reservesSpace: true)
            .frame(maxWidth: .infinity)
            .hidden()
            .accessibilityHidden(true)
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    ScrollView {
                        // Primary ink, not the system's secondary gray, which
                        // measures under 4.5:1 (invariant 6).
                        Text(verbatim: text)
                            .font(font.font)
                            .textSize(fittedSize(text, width: proxy.size.width))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    // A new view, so a new scroll position, on every phrase
                    // start: Again and the same phrase chosen again show the
                    // first words too, not where the last reader left it.
                    .id(speech.phraseStartCount)
                }
            }
    }

    /// The largest text size, from the person's own down to the default, at
    /// which the message's widest word fits the width. Only the width
    /// matters: a long message scrolls.
    private func fittedSize(_ text: String, width: CGFloat) -> DynamicTypeSize {
        let steps = LabelFont.steps(downFrom: dynamicTypeSize)
        let first = LabelFont.message.legible(legibilityWeight).choices(for: text, systemImage: nil, steps: steps, width: width).first
        return steps[first?.step ?? steps.count - 1]
    }
}

// MARK: - Status lines

/// What the person cannot hear: speech in progress, and audio that failed
/// or a very low volume (invariant 4). Passive text only, never a control.
///
/// They sit under the message, in the part of Home the software keyboard
/// never covers, so they stay visible while typing. Speech and audio share
/// one line that is always laid out: it holds invisible copies of
/// "Speaking" and of every audio warning and keeps the tallest one's height,
/// so nothing moves when one appears. A warning takes the line over from
/// "Speaking": when something cannot be heard, that is what the person needs
/// to know. To keep the line short, it shows each warning's compact text and
/// gives VoiceOver the full sentence, as the reference app did. The library
/// warnings sit under the phrase grid instead (`LibraryWarnings`).
private struct StatusLines: View {
    @Environment(SpeechService.self) private var speech
    @Environment(AudioSafetyMonitor.self) private var audioSafety
    let width: CGFloat

    private var audioIssue: HomeAudioIssue? {
        // Get Attention is not ported yet (docs/PORTING.md, step 1), so the
        // alarm is always idle here.
        AudioSafetyPolicy(
            attentionState: .idle,
            speechInterruptionState: speech.speechInterruptionState,
            speechRecoveryAction: .repeatLast,
            audioSessionHealthy: audioSafety.audioSessionHealthy,
            outputVolume: audioSafety.outputVolume
        ).issue
    }

    private static let speaking = String(
        localized: "Speaking",
        comment: "Shown under the message while a phrase is being spoken."
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                FittedLine(text: Self.speaking, systemImage: "speaker.wave.2.fill", font: .status, width: width)
                    .hidden()
                    .accessibilityHidden(true)
                ForEach(HomeAudioIssue.allCases, id: \.self) { candidate in
                    FittedLine(text: candidate.compactMessage, systemImage: candidate.systemImage, font: .status, width: width)
                        .hidden()
                        .accessibilityHidden(true)
                }
                if let audioIssue {
                    FittedLine(text: audioIssue.compactMessage, systemImage: audioIssue.systemImage, font: .status, width: width)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(audioIssue.message)
                } else if speech.isSpeaking {
                    FittedLine(text: Self.speaking, systemImage: "speaker.wave.2.fill", font: .status, width: width)
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .font(LabelFont.status.font)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        // Text appearing on screen is not announced, so VoiceOver users are
        // told each audio problem as it happens (invariant 4). Ambient
        // problems are announced when they appear, including one present at
        // launch. A cut-off phrase is announced on every cut-off, even when
        // the warning is already showing, because each one is a new event.
        .onChange(of: audioIssue, initial: true) { _, newIssue in
            guard let issue = AudioAnnouncementPolicy.ambientIssueToAnnounce(newIssue) else {
                return
            }
            announce(issue)
        }
        .onChange(of: speech.speechInterruptionSequence) {
            guard let issue = AudioAnnouncementPolicy.speechIssueToAnnounce(
                speech.speechInterruptionState,
                recoveryAction: .repeatLast
            ) else {
                return
            }
            announce(issue)
        }
    }

    private func announce(_ issue: HomeAudioIssue) {
        AccessibilityNotification.Announcement(
            AudioAnnouncementPolicy.announcement(for: issue)
        ).post()
    }

}

// MARK: - Library warnings

/// A library that could not be saved, or could not be filled (invariant 5).
/// Passive text only, never a control. Both are decided once at launch and
/// never change while the app runs.
///
/// They sit under the phrase grid, which gives up the height they need: a
/// long warning at a large text size shortens the grid (which then scrolls)
/// and never pushes Yes, No or Emergency off the screen.
private struct LibraryWarnings: View {
    @Environment(\.isVolatileStore) private var isVolatileStore
    @Environment(\.phraseLibraryIssue) private var phraseLibraryIssue

    var body: some View {
        if isVolatileStore || phraseLibraryIssue != nil {
            VStack(alignment: .leading, spacing: 4) {
                if isVolatileStore {
                    warning(
                        String(localized: "Phrases can't be saved right now. Changes will be lost when the app closes."),
                        systemImage: "externaldrive.badge.exclamationmark"
                    )
                }
                if let phraseLibraryIssue {
                    warning(phraseLibraryIssue.message, systemImage: "exclamationmark.bubble.fill")
                }
            }
            .font(LabelFont.status.font)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
        }
    }

    private func warning(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Safety row

/// Controls that stay in the same place in every state. Yes and No speak at
/// once, and Again repeats the last message; Emergency only switches to the
/// emergency phrases, so a stray look on it never says anything. While the
/// emergency phrases show, Emergency is marked selected the same way a
/// category is (a check mark, a ring and the Selected trait), because the
/// emergency category has no button of its own.
///
/// One row of Yes, No, Again and Emergency where Emergency and Again keep
/// their minimum widths; otherwise Yes, No and Emergency, with Again across
/// the row under them (`HomeShape.SafetyRow`). Either way Emergency is at
/// the trailing end of the first row, under Settings' Back to Talking, so a
/// look still resting there after Settings closes meets a control that says
/// nothing (invariant 10; docs/DECISIONS.md, "Settings on Home"). Again is
/// reached after Emergency by assistive technologies
/// (`HomeRegion.lastInRegion`).
///
/// Yes, No and Again carry no icon. Beside the word, No's thumbs-down was
/// read as part of it ("g)No") by the text recognizer in `LaunchTests`, and
/// PR #13 had dropped these icons for the same reason.
private struct SafetyRow: View {
    @Environment(SpeechService.self) private var speech
    let shape: HomeShape
    let emergencyIsAvailable: Bool
    let isShowingEmergency: Bool
    let showEmergency: () -> Void

    var body: some View {
        switch shape.safetyRow {
        case .oneRow:
            HStack(spacing: HomeShape.controlSpacing) {
                yes
                no
                again
                emergencyButton
            }
        case .twoRows:
            VStack(alignment: .leading, spacing: HomeShape.controlSpacing) {
                HStack(spacing: HomeShape.controlSpacing) {
                    yes
                    no
                    emergencyButton
                }
                again
            }
        }
    }

    private var yes: some View {
        Button {
            speech.speak(String(localized: "Yes.", comment: "Spoken when the Yes control is chosen."))
        } label: {
            FittedLabel(HomeControlNames.yes.visible, font: .quickControl)
        }
        .buttonStyle(HomeButtonStyle(fill: Palette.controlFill))
        .frame(width: shape.yesNoWidth, height: shape.quickControlHeight)
        .accessibilityInputLabels(HomeControlNames.yes.inputLabels)
    }

    private var no: some View {
        Button {
            speech.speak(String(localized: "No.", comment: "Spoken when the No control is chosen."))
        } label: {
            FittedLabel(HomeControlNames.no.visible, font: .quickControl)
        }
        .buttonStyle(HomeButtonStyle(fill: Palette.controlFill))
        .frame(width: shape.yesNoWidth, height: shape.quickControlHeight)
        .accessibilityInputLabels(HomeControlNames.no.inputLabels)
    }

    private var again: some View {
        Button {
            speech.repeatLast()
        } label: {
            FittedLabel(HomeControlNames.again.visible, font: .quickControl)
        }
        .buttonStyle(HomeButtonStyle(fill: Palette.controlFill))
        .frame(width: shape.againWidth, height: shape.quickControlHeight)
        .disabled(speech.lastSpokenText == nil)
        .accessibilityInputLabels(HomeControlNames.again.inputLabels)
        .accessibilitySortPriority(HomeRegion.lastInRegion)
    }

    private var emergencyButton: some View {
        Button {
            showEmergency()
        } label: {
            FittedLabel(
                HomeControlNames.emergency.visible,
                systemImage: isShowingEmergency ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                font: .quickControl
            )
        }
        .buttonStyle(HomeButtonStyle(fill: Palette.emergencyFill, isSelected: isShowingEmergency))
        .frame(width: shape.emergencyWidth, height: shape.quickControlHeight)
        .disabled(!emergencyIsAvailable)
        .accessibilityAddTraits(isShowingEmergency ? .isSelected : [])
        .accessibilityInputLabels(HomeControlNames.emergency.inputLabels)
    }
}

// MARK: - Categories and Settings

/// The category buttons, and Settings at their trailing end: a column as
/// tall as their rows, or a row of its own under them where the window is
/// too narrow for both words side by side (`HomeShape.SettingsPlacement`).
/// Settings is for the family. It opens a cover with its own safety bar
/// (`settingsCover`), and is reached after the categories by assistive
/// technologies (`HomeRegion.lastInRegion`). Only the categories scroll,
/// in a library with more than four of them; Settings stays where it is.
private struct CategoriesAndSettings: View {
    let shape: HomeShape
    let categories: [PhraseCategory]
    let selectedID: UUID?
    let select: (UUID) -> Void
    @Binding var showsSettings: Bool

    var body: some View {
        let grid = CategoryGrid(
            categories: categories,
            columns: shape.categoryColumns,
            buttonHeight: shape.categoryHeight,
            selectedID: selectedID,
            select: select
        )
        .frame(width: shape.categoryGridWidth, height: shape.categoryGridHeight)
        let settings = SettingsButton(isPresented: $showsSettings)
            .frame(width: shape.settingsWidth, height: shape.settingsHeight)
            .accessibilitySortPriority(HomeRegion.lastInRegion)

        switch shape.settingsPlacement {
        case .beside:
            HStack(alignment: .top, spacing: HomeShape.controlSpacing) {
                grid
                settings
            }
        case .below:
            VStack(alignment: .leading, spacing: HomeShape.controlSpacing) {
                grid
                settings
            }
        }
    }
}

/// One button per everyday category, in a fixed order and a fixed grid: two
/// by two on narrow windows, one row of four on wide ones, with room kept for
/// four whatever the library holds. Nothing scrolls sideways. A library
/// with more categories than that scrolls inside this grid; the starter
/// library never does. The selected category is filled with the phrase
/// colour and shows a check mark and a ring (so the choice never depends on
/// colour alone), and carries the Selected trait for VoiceOver and Voice
/// Control.
private struct CategoryGrid: View {
    let categories: [PhraseCategory]
    let columns: Int
    let buttonHeight: CGFloat
    let selectedID: UUID?
    let select: (UUID) -> Void

    var body: some View {
        let grid = FixedColumns(categories, columns: columns) { category in
            let isSelected = category.uuid == selectedID
            Button {
                select(category.uuid)
            } label: {
                FittedLabel(
                    category.name,
                    systemImage: isSelected ? "checkmark.circle.fill" : category.symbolName,
                    font: .category
                )
            }
            .buttonStyle(HomeButtonStyle(
                fill: isSelected ? Palette.phraseFill : Palette.controlFill,
                isSelected: isSelected
            ))
            .frame(height: buttonHeight)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }

        if categories.count > HomeShape.categoryCapacity {
            ScrollView { grid }
        } else {
            grid.frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Phrases

/// The selected category's phrases in a fixed grid. Position never depends
/// on use (invariant 8): the order is the stored order, and the rows come
/// from the largest category, so a tile keeps its place whichever category
/// is showing. Tiles share the height left for the grid; only where that
/// would make them shorter than the shape's minimum tile height does the grid
/// scroll instead.
private struct PhraseGrid: View {
    @Environment(SpeechService.self) private var speech
    @Environment(\.phraseLibraryIssue) private var phraseLibraryIssue
    let category: PhraseCategory?
    let columns: Int
    let rows: Int
    let minimumTileHeight: CGFloat
    let tileFont: LabelFont

    var body: some View {
        GeometryReader { proxy in
            let sizing = GridSizing(
                availableHeight: proxy.size.height,
                rows: rows,
                spacing: HomeShape.controlSpacing,
                minimumTileHeight: minimumTileHeight
            )
            if let category {
                let phrases = category.phrasesInOrder
                let grid = FixedColumns(phrases, columns: columns) { phrase in
                    Button {
                        speech.speak(phrase.text)
                    } label: {
                        FittedLabel(phrase.text, font: tileFont)
                    }
                    .buttonStyle(HomeButtonStyle(
                        fill: category.isEmergency ? Palette.emergencyFill : Palette.phraseFill
                    ))
                    .frame(height: sizing.tileHeight)
                    // Lets the UI tests tell phrase tiles from controls
                    // (LaunchTests' accessibility audit). Not spoken.
                    .accessibilityIdentifier("phraseTile")
                }

                // Always the same scroll view, turned off where the tiles fit,
                // so the tiles stay the same views when the grid starts to
                // scroll as the text grows (Apple's accessibility audit
                // compares each one with itself).
                ScrollView { grid }
                    .scrollDisabled(!(sizing.scrolls || phrases.count > rows * columns))
                    .scrollBounceBehavior(.basedOnSize)
            } else if phraseLibraryIssue == nil {
                Text("No phrases yet.")
                    .font(.title2)
            }
        }
    }
}

// MARK: - Fixed columns

/// Items in rows of `columns` equal cells, in order, with
/// `HomeShape.controlSpacing` between them. A short last row keeps its cells
/// at the leading edge, at the same width and place as the rows above, so a
/// slot is in the same place whatever fills it (invariant 8).
///
/// It is built from plain stacks rather than a lazy grid: lazy rows disappear
/// while Apple's accessibility audit increases the text size, so the audit
/// cannot compare them (docs/log/2026-10-21-ui-test-diagnosis.md).
private struct FixedColumns<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    let columns: Int
    let cell: (Item) -> Cell

    init(_ items: [Item], columns: Int, @ViewBuilder cell: @escaping (Item) -> Cell) {
        self.items = items
        self.columns = max(columns, 1)
        self.cell = cell
    }

    var body: some View {
        VStack(spacing: HomeShape.controlSpacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                HStack(spacing: HomeShape.controlSpacing) {
                    ForEach(items[start..<min(start + columns, items.count)]) { item in
                        cell(item)
                            .frame(maxWidth: .infinity)
                    }
                    // Empty cells keep a short row's tiles at the full rows'
                    // width and place.
                    ForEach(0..<(columns - min(columns, items.count - start)), id: \.self) { _ in
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: 0)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }
}

// MARK: - Regions

private extension View {
    /// Makes this view one of Home's regions: an accessibility container, so
    /// its controls are reached together and Switch Control can offer them as
    /// a group, at the region's fixed place in the order (`HomeRegion`). The
    /// container is applied after the region's frame, so its edges are the
    /// region's.
    func homeRegion(_ region: HomeRegion) -> some View {
        accessibilityElement(children: .contain)
            .accessibilitySortPriority(region.sortPriority)
            .accessibilityIdentifier(region.identifier)
    }
}

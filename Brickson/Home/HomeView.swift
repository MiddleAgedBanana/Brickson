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
/// lines, the quick controls, the categories, then the phrase grid, which
/// takes what is left. Everything a person needs while typing sits in the top
/// part, which the software keyboard never reaches (docs/LESSONS.md, "Lay
/// out against a measured keyboard"); the categories are nearest the
/// keyboard because a slip onto one is harmless. No control's label breaks a
/// word: each one fits itself (`FittedLabel`). The starter library needs no
/// scrolling on the windows `HomeLayoutTests` checks; the grid scrolls only
/// where its tiles would otherwise be shorter than
/// `HomeShape.minimumTileHeight`.
struct HomeView: View {
    @Query private var categories: [PhraseCategory]
    @State private var selectedCategoryID: UUID?

    var body: some View {
        let ordered = PhraseCategory.orderedForDisplay(categories)
        let selected = CategorySelection.resolve(ordered, selectedID: selectedCategoryID)
        let emergency = CategorySelection.emergency(in: ordered)
        let largestCategoryCount = ordered.map(\.phrasesInOrder.count).max() ?? 0

        GeometryReader { proxy in
            let contentWidth = proxy.size.width
            let shape = HomeShape(contentWidth: contentWidth)
            let quickWidths = HomeShape.quickControlWidths(contentWidth: contentWidth)

            VStack(alignment: .leading, spacing: HomeShape.regionSpacing) {
                MessageBlock(againWidth: quickWidths[0], againHeight: shape.quickControlHeight)
                QuickControlsRow(
                    widths: quickWidths,
                    emergencyIsAvailable: emergency != nil,
                    isShowingEmergency: selected?.isEmergency == true,
                    showEmergency: { selectedCategoryID = emergency?.uuid }
                )
                .frame(height: shape.quickControlHeight)
                CategoryGrid(
                    categories: CategorySelection.shownInCategoryRow(ordered),
                    columns: shape.categoryColumns,
                    buttonHeight: shape.categoryHeight,
                    selectedID: selected?.uuid,
                    select: { selectedCategoryID = $0 }
                )
                .frame(height: shape.categoryRegionHeight)
                PhraseGrid(
                    category: selected,
                    columns: shape.gridColumns,
                    rows: shape.gridRows(largestCategoryCount: largestCategoryCount),
                    minimumTileHeight: shape.minimumTileHeight,
                    tileFont: shape.isCompact ? .compactTile : .regularTile
                )
                .frame(maxHeight: .infinity)
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
/// its status lines under it and Again at its trailing edge. Again sits at
/// the bottom of the block, away from the screen's top corner (design rule
/// "Keep corners clear").
private struct MessageBlock: View {
    @Environment(SpeechService.self) private var speech
    let againWidth: CGFloat
    let againHeight: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: HomeShape.controlSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                MessageText()
                StatusLines()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                speech.repeatLast()
            } label: {
                FittedLabel(
                    String(localized: "Again", comment: "Repeats the last thing spoken."),
                    systemImage: "arrow.counterclockwise",
                    font: .quickControl
                )
            }
            .buttonStyle(HomeButtonStyle(fill: Palette.controlFill))
            .frame(width: againWidth, height: againHeight)
            .disabled(speech.lastSpokenText == nil)
        }
    }
}

/// The message itself. Two lines of the message font at the person's text
/// size are always reserved, by an invisible placeholder, so nothing below
/// moves when a message appears or changes. A longer message scrolls inside
/// them. It steps down through Apple's text sizes only as far as its widest
/// word needs to fit the width, never below the default size (AGENTS.md,
/// "Words never break"). Every phrase start, Again included, shows the
/// message from the top.
private struct MessageText: View {
    @Environment(SpeechService.self) private var speech
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let font = LabelFont.message
        let text = speech.lastSpokenText ?? String(
            localized: "Choose a phrase to speak it.",
            comment: "Shown where the spoken message appears, before anything has been spoken."
        )

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
                            .textSize(fittedSize(text, width: proxy.size.width), from: dynamicTypeSize)
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
        let first = LabelFont.message.choices(for: text, systemImage: nil, steps: steps, width: width).first
        return steps[first?.step ?? steps.count - 1]
    }
}

// MARK: - Status lines

/// What the person cannot hear: speech in progress, audio that failed or a
/// very low volume, and a library that could not be opened or filled
/// (invariants 4 and 5). Passive text only, never a control.
///
/// They sit under the message, in the part of Home the software keyboard
/// never covers, so they stay visible while typing. Speech and audio share
/// one line that is always laid out: it holds invisible copies of
/// "Speaking" and of every audio warning and keeps the tallest one's height,
/// so nothing moves when one appears. A warning takes the line over from
/// "Speaking": when something cannot be heard, that is what the person needs
/// to know. To keep the line short, it shows each warning's compact text and
/// gives VoiceOver the full sentence, as the reference app did. The two
/// library warnings are decided once at launch and never change while the
/// app runs, so they need no reserved space.
private struct StatusLines: View {
    @Environment(SpeechService.self) private var speech
    @Environment(AudioSafetyMonitor.self) private var audioSafety
    @Environment(\.isVolatileStore) private var isVolatileStore
    @Environment(\.phraseLibraryIssue) private var phraseLibraryIssue

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
                FittedLine(text: Self.speaking, systemImage: "speaker.wave.2.fill", font: .status)
                    .hidden()
                    .accessibilityHidden(true)
                ForEach(HomeAudioIssue.allCases, id: \.self) { candidate in
                    FittedLine(text: candidate.compactMessage, systemImage: candidate.systemImage, font: .status)
                        .hidden()
                        .accessibilityHidden(true)
                }
                if let audioIssue {
                    FittedLine(text: audioIssue.compactMessage, systemImage: audioIssue.systemImage, font: .status)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(audioIssue.message)
                } else if speech.isSpeaking {
                    FittedLine(text: Self.speaking, systemImage: "speaker.wave.2.fill", font: .status)
                        .accessibilityElement(children: .combine)
                }
            }
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

    private func warning(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Quick controls

/// Controls that stay in the same place in every state. Yes and No speak at
/// once; Emergency only switches to the emergency phrases, so a stray look
/// on it never says anything. While the emergency phrases show, Emergency is
/// marked selected the same way a category is (a check mark, a ring and the
/// Selected trait), because the emergency category has no button of its own.
private struct QuickControlsRow: View {
    @Environment(SpeechService.self) private var speech
    /// Yes, No and Emergency, from `HomeShape.quickControlWidths`.
    let widths: [CGFloat]
    let emergencyIsAvailable: Bool
    let isShowingEmergency: Bool
    let showEmergency: () -> Void

    var body: some View {
        HStack(spacing: HomeShape.controlSpacing) {
            Button {
                speech.speak(String(localized: "Yes.", comment: "Spoken when the Yes control is chosen."))
            } label: {
                FittedLabel(String(localized: "Yes"), systemImage: "hand.thumbsup.fill", font: .quickControl)
            }
            .buttonStyle(HomeButtonStyle(fill: Palette.controlFill))
            .frame(width: widths[0])

            Button {
                speech.speak(String(localized: "No.", comment: "Spoken when the No control is chosen."))
            } label: {
                FittedLabel(String(localized: "No"), systemImage: "hand.thumbsdown.fill", font: .quickControl)
            }
            .buttonStyle(HomeButtonStyle(fill: Palette.controlFill))
            .frame(width: widths[1])

            Button {
                showEmergency()
            } label: {
                FittedLabel(
                    String(localized: "Emergency"),
                    systemImage: isShowingEmergency ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    font: .quickControl
                )
            }
            .buttonStyle(HomeButtonStyle(fill: Palette.emergencyFill, isSelected: isShowingEmergency))
            .frame(width: widths[2])
            .disabled(!emergencyIsAvailable)
            .accessibilityAddTraits(isShowingEmergency ? .isSelected : [])
        }
    }
}

// MARK: - Categories

/// One button per everyday category, in a fixed order and a fixed grid: two
/// by two on narrow windows, one row of four on wide ones, with room kept for
/// four whatever the library holds. Nothing scrolls sideways. A library
/// with more categories than that scrolls inside this region; the starter
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
        let grid = LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: HomeShape.controlSpacing), count: columns),
            spacing: HomeShape.controlSpacing
        ) {
            ForEach(categories) { category in
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
                let grid = LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: HomeShape.controlSpacing), count: columns),
                    spacing: HomeShape.controlSpacing
                ) {
                    ForEach(phrases) { phrase in
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
                }

                if sizing.scrolls || phrases.count > rows * columns {
                    ScrollView { grid }
                } else {
                    grid
                }
            } else if phraseLibraryIssue == nil {
                Text("No phrases yet.")
                    .font(.title2)
            }
        }
    }
}

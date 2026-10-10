import SwiftData
import SwiftUI

/// Home, version 0: a plain stand-in that proves the foundations work end to
/// end. A phrase is chosen, the speech engine says it, and the message row
/// shows it to the person listening.
///
/// It will be replaced when the layout engine and Home are ported
/// (docs/PORTING.md, steps 4 and 5). Even so, it keeps the rules that matter from the first build:
/// every control is a standard `Button` with a label (invariant 1), every
/// tile speaks on the first activation (invariant 2), a lingering look cannot
/// make a phrase stutter (`SpokenUtteranceTracker`), and nothing moves when
/// state changes (the message row and status area keep their size).
struct HomeView: View {
    @Environment(SpeechService.self) private var speech
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var categories: [PhraseCategory]
    @State private var selectedCategoryID: UUID?

    var body: some View {
        let ordered = PhraseCategory.orderedForDisplay(categories)
        let selected = CategorySelection.resolve(ordered, selectedID: selectedCategoryID)
        let emergency = CategorySelection.emergency(in: ordered)

        VStack(alignment: .leading, spacing: 16) {
            MessageRow()
            QuickControlsRow(
                emergencyIsAvailable: emergency != nil,
                isShowingEmergency: selected?.isEmergency == true,
                showEmergency: { selectedCategoryID = emergency?.uuid }
            )
            CategoryRow(
                categories: CategorySelection.shownInCategoryRow(ordered),
                selectedID: selected?.uuid,
                select: { selectedCategoryID = $0 }
            )
            PhraseGrid(
                category: selected,
                columnCount: horizontalSizeClass == .regular ? 3 : 2
            )
            .frame(maxHeight: .infinity, alignment: .top)
            StatusArea()
        }
        .padding()
    }
}

// MARK: - Message row

/// The last sentence spoken, large enough for the listener to read, with
/// Again beside it. Its height is reserved for two lines, so a long message
/// shrinks to fit instead of pushing every control below it down.
private struct MessageRow: View {
    @Environment(SpeechService.self) private var speech

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Two lines of the message font are always reserved, by an
                // invisible placeholder. A longer message scrolls inside
                // them instead of shrinking, so the person's words keep their
                // full size (AGENTS.md, "Words never break") and nothing
                // below moves. A new message starts at the top.
                Text(verbatim: " ")
                    .font(.title.weight(.semibold))
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity)
                    .hidden()
                    .accessibilityHidden(true)
                    .overlay(alignment: .topLeading) {
                        ScrollView {
                            Group {
                                if let text = speech.lastSpokenText {
                                    Text(verbatim: text)
                                } else {
                                    // Primary ink, not the system's secondary
                                    // gray, which measures under 4.5:1
                                    // (invariant 6).
                                    Text("Choose a phrase to speak it.")
                                }
                            }
                            .font(.title.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .id(speech.lastSpokenText)
                    }

                // Always laid out, only shown while speaking, so it never
                // shifts anything when speech starts or stops.
                Label("Speaking", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityElement(children: .combine)
                    .opacity(speech.isSpeaking ? 1 : 0)
                    .accessibilityHidden(!speech.isSpeaking)
            }

            Button {
                speech.repeatLast()
            } label: {
                Label("Again", systemImage: "arrow.counterclockwise")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 88, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.controlFill)
            .disabled(speech.lastSpokenText == nil)
        }
    }
}

// MARK: - Quick controls

/// Controls that stay in the same place in every state. Yes and No speak at
/// once; Emergency only switches to the emergency phrases, so a stray look
/// on it never says anything. While the emergency phrases show, Emergency is
/// marked selected the same way a category is (a check mark and the Selected
/// trait), because the emergency category has no button of its own.
private struct QuickControlsRow: View {
    @Environment(SpeechService.self) private var speech
    let emergencyIsAvailable: Bool
    let isShowingEmergency: Bool
    let showEmergency: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                speech.speak(String(localized: "Yes.", comment: "Spoken when the Yes control is chosen."))
            } label: {
                QuickControlLabel(title: "Yes", systemImage: "hand.thumbsup.fill")
            }
            .tint(Palette.controlFill)

            Button {
                speech.speak(String(localized: "No.", comment: "Spoken when the No control is chosen."))
            } label: {
                QuickControlLabel(title: "No", systemImage: "hand.thumbsdown.fill")
            }
            .tint(Palette.controlFill)

            Button {
                showEmergency()
            } label: {
                QuickControlLabel(
                    title: "Emergency",
                    systemImage: isShowingEmergency ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
            }
            .tint(Palette.emergencyFill)
            .disabled(!emergencyIsAvailable)
            .accessibilityAddTraits(isShowingEmergency ? .isSelected : [])
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct QuickControlLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
    }
}

// MARK: - Categories

/// One button per everyday category, in a fixed order. The selected one is filled
/// with the phrase colour, shows a check mark instead of its symbol (so the
/// choice never depends on colour alone), and carries the Selected trait for
/// VoiceOver and Voice Control.
private struct CategoryRow: View {
    let categories: [PhraseCategory]
    let selectedID: UUID?
    let select: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    let isSelected = category.uuid == selectedID
                    Button {
                        select(category.uuid)
                    } label: {
                        Label {
                            Text(verbatim: category.name)
                        } icon: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : category.symbolName)
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(minHeight: 52)
                        .padding(.horizontal, 4)
                    }
                    .tint(isSelected ? Palette.phraseFill : Palette.controlFill)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Phrases

/// The selected category's phrases in a fixed number of columns. Position
/// never depends on use (invariant 8): the order is the stored order.
private struct PhraseGrid: View {
    @Environment(SpeechService.self) private var speech
    @Environment(\.phraseLibraryIssue) private var phraseLibraryIssue
    let category: PhraseCategory?
    let columnCount: Int

    var body: some View {
        if let category {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount),
                    spacing: 12
                ) {
                    ForEach(category.phrasesInOrder) { phrase in
                        Button {
                            speech.speak(phrase.text)
                        } label: {
                            Text(verbatim: phrase.text)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 96)
                        }
                        .tint(category.isEmergency ? Palette.emergencyFill : Palette.phraseFill)
                        // Lets the UI tests tell phrase tiles from controls
                        // (LaunchTests' accessibility audit). Not spoken.
                        .accessibilityIdentifier("phraseTile")
                    }
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
        } else if phraseLibraryIssue == nil {
            Text("No phrases yet.")
                .font(.title2)
        }
    }
}

// MARK: - Status

/// Problems the person cannot hear: audio that failed or a very low volume,
/// and a library that could not be opened or filled (invariants 4 and 5).
/// Passive text only, never a control.
///
/// The phrase grid above takes whatever height is left, so anything that
/// makes this area taller hides phrase tiles. The audio warning can appear
/// at any moment, so its slot always holds invisible copies of every audio
/// warning and keeps the tallest one's height: a warning appearing changes
/// nothing above it. To keep that reserved slot to one short line, it shows
/// each warning's compact text and gives VoiceOver the full sentence, as the
/// reference app did. The two library warnings are decided once at launch
/// and never change while the app runs, so they need no reserved space.
private struct StatusArea: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                ForEach(HomeAudioIssue.allCases, id: \.self) { candidate in
                    warning(candidate.compactMessage, systemImage: candidate.systemImage)
                        .hidden()
                        .accessibilityHidden(true)
                }
                if let audioIssue {
                    warning(audioIssue.compactMessage, systemImage: audioIssue.systemImage)
                        .accessibilityLabel(audioIssue.message)
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
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private func warning(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}

import SwiftData
import SwiftUI

/// Home, version 0: a plain stand-in that proves the foundations work end to
/// end. A phrase is chosen, the speech engine says it, and the message row
/// shows it to the person listening.
///
/// It will be replaced when the layout engine is ported (docs/PORTING.md,
/// step 4). Even so, it keeps the rules that matter from the first build:
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
                showEmergency: { selectedCategoryID = emergency?.uuid }
            )
            CategoryRow(
                categories: ordered,
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
                Group {
                    if let text = speech.lastSpokenText {
                        Text(verbatim: text)
                    } else {
                        // Primary ink, not the system's secondary gray, which
                        // measures under 4.5:1 (invariant 6).
                        Text("Choose a phrase to speak it.")
                    }
                }
                .font(.title.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Always laid out, only shown while speaking, so it never
                // shifts anything when speech starts or stops.
                Label("Speaking", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
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
/// on it never says anything.
private struct QuickControlsRow: View {
    @Environment(SpeechService.self) private var speech
    let emergencyIsAvailable: Bool
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
                QuickControlLabel(title: "Emergency", systemImage: "exclamationmark.triangle.fill")
            }
            .tint(Palette.emergencyFill)
            .disabled(!emergencyIsAvailable)
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

/// One button per category, in a fixed order. The selected one is filled
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
/// Passive text only, never a control, and placed last so that when a
/// warning appears nothing above it moves.
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
            if let audioIssue {
                Label(audioIssue.message, systemImage: audioIssue.systemImage)
            }
            if isVolatileStore {
                Label(
                    "Phrases can't be saved right now. Changes will be lost when the app closes.",
                    systemImage: "externaldrive.badge.exclamationmark"
                )
            }
            if let phraseLibraryIssue {
                Label(phraseLibraryIssue.message, systemImage: "exclamationmark.bubble.fill")
            }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

import Accessibility
import AVFoundation
import SwiftUI

/// Voice Settings: which voice Brickson speaks with, Personal Voice
/// guidance, and the speaking speed.
///
/// Hearing a voice and choosing it are separate buttons, so listening never
/// changes anything. Each sample is absorbed while it is still playing, so a
/// held look cannot restart it (`SpokenUtteranceTracker`). Speeds are fixed
/// choices, so a repeated activation never walks the speed (`SpeedChoice`).
/// Choosing a voice or a speed changes words on the screen, but never the
/// size of anything, so no control moves under the one just chosen.
struct VoiceSettingsView: View {
    var body: some View {
        SettingsScreen(title: "Voice Settings") {
            VoiceContent()
        }
    }
}

/// The screen's content, shared with step 2 of Set Up Step by Step.
///
/// The voices can change while it is open: a voice downloaded or deleted,
/// or Personal Voice turned on or off in the Settings app while Brickson
/// waits (`SpeechService.refreshPersonalVoiceAvailability()`). So the voice
/// list keeps the places it had when the screen opened
/// (`VoiceList.keepingPlaces`), and the words above it keep the tallest
/// height they have had, so no Hear, Use or speed button moves under a
/// resting pointer.
struct VoiceContent: View {
    @Environment(SpeechService.self) private var speech
    /// The voice list as it was when the screen opened, and whether the
    /// missing-voice note was needed then. Both hold until the screen
    /// closes.
    @State private var opened: OpenedVoiceList?

    var body: some View {
        let rows = VoiceList.rows(
            for: speech.availableVoices,
            selectedID: speech.selectedVoiceID,
            languageCode: Bundle.main.preferredLocalizations.first ?? "en",
            describeLanguage: { Locale.current.localizedString(forIdentifier: $0) ?? $0 }
        )
        let voiceIsMissing = VoiceList.chosenVoiceIsMissing(selectedID: speech.selectedVoiceID, from: speech.availableVoices)
        let personalVoiceAllowed = speech.personalVoiceStatus == .authorized

        // Which voice speaks now, from the service itself, so a kept
        // Personal Voice is named the same way speech chooses it. Reserved
        // over every voice listed now or when the screen opened.
        if let current = speech.currentVoice {
            let names = Set(speech.availableVoices.map(\.name) + (opened?.voiceNames ?? []))
            SettingsReservedParagraph(
                text: Text("Speaking with \(current.name)."),
                alternatives: names.sorted().map { Text("Speaking with \($0).") }
            )
        }

        PersonalVoiceSection()
            .settingsKeepsItsTallestHeight()

        SettingsHeading("Speed")
        let chosenSpeed = SpeedChoice.matching(speech.speechRate, normal: AVSpeechUtteranceDefaultSpeechRate)
        SettingsReservedParagraph(
            text: Self.speedSentence(for: speech.speechRate),
            alternatives: SpeedChoice.all.map { Self.speedSentence(for: $0.rate(normal: AVSpeechUtteranceDefaultSpeechRate)) }
        )
        ForEach(SpeedChoice.all) { choice in
            SpeedChoiceButton(choice: choice, isChosen: choice == chosenSpeed)
        }

        SettingsHeading("Voice")
            .onAppear {
                if opened == nil {
                    opened = OpenedVoiceList(rows: rows, voiceWasMissing: voiceIsMissing)
                }
            }
        // Only when the chosen voice was already missing as the screen
        // opened: its place is then kept, so choosing a voice pulls no row
        // up. A voice that goes while the screen is open says so in its
        // own row instead, so no note is pushed in above the rows.
        // Its words depend on whether Personal Voice is allowed, which can
        // change while the screen is open, so both versions are laid out.
        if opened?.voiceWasMissing ?? voiceIsMissing {
            SettingsReservedParagraph(
                text: Text(verbatim: VoiceList.missingVoiceNote(personalVoiceAllowed: personalVoiceAllowed)),
                alternatives: [true, false].map { Text(verbatim: VoiceList.missingVoiceNote(personalVoiceAllowed: $0)) }
            )
            .opacity(voiceIsMissing ? 1 : 0)
            .accessibilityHidden(!voiceIsMissing)
        }
        ForEach(VoiceList.keepingPlaces(of: opened?.rows ?? rows, in: rows)) { place in
            switch place {
            case .voice(let row):
                VoiceRowView(row: row)
            case .gone(let row):
                GoneVoiceRowView(row: row, personalVoiceAllowed: personalVoiceAllowed)
            }
        }
    }
}

/// What Voice Settings looked like when it opened (`VoiceContent`).
private struct OpenedVoiceList {
    let rows: [VoiceRow]
    let voiceWasMissing: Bool

    var voiceNames: [String] {
        rows.filter { $0.voiceID != nil }.map(\.name)
    }
}

extension VoiceContent {
    /// The speed line: normal, or the share of normal as a localized
    /// percent.
    static func speedSentence(for rate: Float) -> Text {
        if SpeedChoice.matching(rate, normal: AVSpeechUtteranceDefaultSpeechRate)?.isNormal == true {
            return Text("Speaking at normal speed.")
        }
        let share = SpeedChoice.fraction(of: rate, normal: AVSpeechUtteranceDefaultSpeechRate)
        return Text("Speaking at \(share, format: .percent) of normal speed.")
    }
}

/// One fixed speed. Choosing it sets that speed and plays the sample at
/// it; choosing it again changes nothing (`SpeedChoice`).
private struct SpeedChoiceButton: View {
    let choice: SpeedChoice
    let isChosen: Bool
    @Environment(SpeechService.self) private var speech
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?

    var body: some View {
        Button {
            activity?.recordActivity()
            speech.stepRate(choice.step(normal: AVSpeechUtteranceDefaultSpeechRate), from: choice.previewControl)
        } label: {
            SettingsRowLabel(text: title, systemImage: isChosen ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.borderedProminent)
        .tint(isChosen ? Palette.phraseFill : Palette.controlFill)
        .accessibilityLabel(spokenTitle)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private var title: Text {
        if choice.isNormal {
            return Text("Normal")
        }
        return Text(choice.fraction, format: .percent)
    }

    private var spokenTitle: Text {
        if choice.isNormal {
            return Text("Normal speed")
        }
        return Text("\(choice.fraction, format: .percent) of normal speed")
    }
}

private struct VoiceRowView: View {
    let row: VoiceRow
    @Environment(SpeechService.self) private var speech
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Always laid out, so the name keeps its width and the
                // row its height whichever voice is chosen.
                Image(systemName: "checkmark.circle.fill")
                    .opacity(row.isSelected ? 1 : 0)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    // A voice's name is its own, never translated.
                    Text(verbatim: row.name)
                        .font(.title3.weight(.semibold))
                    Text(verbatim: row.detail)
                        .font(.subheadline)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(row.isSelected ? .isSelected : [])

            HStack(spacing: SettingsMetrics.rowSpacing) {
                Button {
                    activity?.recordActivity()
                    speech.preview(from: .voice(id: row.voiceID))
                } label: {
                    SettingsPairLabel(title: "Hear", systemImage: "play.fill")
                }
                .settingsRowStyle()
                .accessibilityLabel(Text(verbatim: row.hearLabel))
                .accessibilityInputLabels([Text(verbatim: row.hearLabel)])

                Button {
                    activity?.recordActivity()
                    speech.selectedVoiceID = row.voiceID
                } label: {
                    // Both versions are laid out, so choosing a voice never
                    // changes the button's size.
                    ZStack {
                        SettingsPairLabel(title: "Use", systemImage: "checkmark.circle")
                            .hidden()
                        SettingsPairLabel(title: "In Use", systemImage: "checkmark")
                            .hidden()
                        SettingsPairLabel(
                            title: row.isSelected ? "In Use" : "Use",
                            systemImage: row.isSelected ? "checkmark" : "checkmark.circle"
                        )
                    }
                }
                .settingsRowStyle()
                .accessibilityLabel(Text(verbatim: row.useLabel))
                .accessibilityInputLabels([Text(verbatim: row.useLabel)])
                .accessibilityValue(row.isSelected ? Text("In Use") : Text(verbatim: ""))
            }
        }
        .padding(.bottom, 8)
    }
}

/// A voice listed when the screen opened that is no longer offered:
/// deleted, or a Personal Voice whose access was turned off. The row it had
/// is laid out hidden, so its place keeps its size, with passive words in
/// it and no button, until the screen closes (`VoiceList.keepingPlaces`).
private struct GoneVoiceRowView: View {
    let row: VoiceRow
    let personalVoiceAllowed: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            VoiceRowView(row: row)
                .hidden()
                .accessibilityHidden(true)
            // A voice's name is its own, never translated; it is inserted
            // into the localized sentence as it is.
            SettingsParagraph(verbatim: VoiceList.goneVoiceNote(for: row, personalVoiceAllowed: personalVoiceAllowed))
        }
        .allowsHitTesting(false)
    }
}

/// What Personal Voice needs next, from `PersonalVoiceGuidance`.
///
/// Under `PersonalVoiceAskPolicy.fromSettings` the card offers Ask to Use
/// Personal Voice, explained in the words above it. iOS's question then
/// covers the screen, Settings holds its idle reset until the answer lands
/// (`SettingsView`), and a second press meanwhile asks nothing more
/// (`SpeechService.requestPersonalVoiceAuthorization()`). The answer moves
/// nothing: while the button shows, the words above it keep room for every
/// answer's words (`PersonalVoiceGuidance.outcomesOfAsking()`); once it has
/// been used, its place holds passive words until the screen closes, and
/// no new button appears in the card on this visit (`askedOnThisVisit`), so
/// nothing that leaves the app lands beside the spot just activated
/// (AGENTS.md, invariant 10).
private struct PersonalVoiceSection: View {
    @Environment(SpeechService.self) private var speech
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @State private var couldNotOpenSettings = false
    /// The Ask button was used since the screen opened.
    @State private var asked = false

    var body: some View {
        let guidance = PersonalVoiceGuidance.make(
            access: PersonalVoiceAccess(speech.personalVoiceStatus),
            hasPersonalVoice: speech.hasPersonalVoice,
            // Brickson asks by itself when it opens, for now
            // (docs/DECISIONS.md, "Personal Voice permission is asked at
            // launch, for now"), so the button shows only under the policy
            // that leaves the question to this screen.
            canAsk: speech.personalVoiceAskPolicy == .fromSettings,
            canOpenSettings: Self.canOpenPersonalVoiceSettings,
            askedOnThisVisit: asked
        )
        let offersAsking = guidance.action == .askPermission

        SettingsCard {
            ZStack(alignment: .topLeading) {
                if offersAsking {
                    ForEach(Array(PersonalVoiceGuidance.outcomesOfAsking().enumerated()), id: \.offset) { _, outcome in
                        PersonalVoiceWords(guidance: outcome)
                            .hidden()
                            .accessibilityHidden(true)
                    }
                }
                PersonalVoiceWords(guidance: guidance)
            }
            .settingsKeepsItsTallestHeight()

            if offersAsking || asked {
                PersonalVoiceAskPlace(offersAsking: offersAsking) {
                    activity?.recordActivity()
                    asked = true
                    Task {
                        await speech.requestPersonalVoiceAuthorization()
                    }
                }
            }
            if guidance.action == .openPersonalVoiceSettings {
                Button {
                    activity?.recordActivity()
                    Task {
                        do {
                            try await AccessibilitySettings.openSettings(for: .personalVoiceAllowAppsToRequestToUse)
                            couldNotOpenSettings = false
                        } catch {
                            couldNotOpenSettings = true
                        }
                    }
                } label: {
                    SettingsRowLabel(title: "Open Personal Voice Settings", systemImage: "gear")
                }
                .settingsRowStyle()
                // Its place is kept, so a failure moves nothing below it.
                SettingsParagraph("Settings could not be opened. Follow the steps above in the Settings app.")
                    .opacity(couldNotOpenSettings ? 1 : 0)
                    .accessibilityHidden(!couldNotOpenSettings)
            }
        }
    }

    private static var canOpenPersonalVoiceSettings: Bool {
        if #available(iOS 26.4, *) {
            return AccessibilitySettings.canOpenSettings(for: .personalVoiceAllowAppsToRequestToUse)
        }
        // Before iOS 26.4 there is no way to ask; the button tries, and the
        // written path covers a failure.
        return true
    }
}

/// The card's words for one Personal Voice state: what it is, what to do,
/// and where in the Settings app.
private struct PersonalVoiceWords: View {
    let guidance: PersonalVoiceGuidance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsHeading(verbatim: guidance.title)
            SettingsParagraph(verbatim: guidance.message)
            if let path = guidance.settingsPath {
                Text(verbatim: path)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if guidance.suggestsMakingOne {
                SettingsParagraph("Making a Personal Voice means reading phrases aloud, so it is easiest while speaking is comfortable. Apple keeps it encrypted on this device, and in iCloud only if Share Across Devices is on. \(AppName.display) never receives the voice or its recordings.")
            }
        }
    }
}

/// The Ask button's place in the Personal Voice card. The button and the
/// words that replace it are both laid out, so the place keeps one size
/// before and after the answer, and once the button has been used its
/// place holds passive words, never another control, until the screen
/// closes.
private struct PersonalVoiceAskPlace: View {
    let offersAsking: Bool
    let ask: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            askButton
                .hidden()
                .accessibilityHidden(true)
            askedWords
                .hidden()
                .accessibilityHidden(true)
            if offersAsking {
                askButton
                    .accessibilityIdentifier("askPersonalVoice")
            } else {
                askedWords
                    .accessibilityIdentifier("personalVoiceAsked")
            }
        }
    }

    private var askButton: some View {
        Button(action: ask) {
            SettingsRowLabel(title: "Ask to Use Personal Voice", systemImage: "person.wave.2")
        }
        .settingsRowStyle()
    }

    private var askedWords: some View {
        SettingsParagraph("Answered. iOS asks only once, so any change is made in the Settings app.")
    }
}

extension PersonalVoiceAccess {
    init(_ status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .unsupported: self = .unsupported
        @unknown default: self = .notDetermined
        }
    }
}

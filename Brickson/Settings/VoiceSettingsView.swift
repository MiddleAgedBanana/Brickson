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
struct VoiceContent: View {
    @Environment(SpeechService.self) private var speech
    /// The missing-voice note was shown. Its place is kept until the screen
    /// closes, so choosing a voice does not pull the rows up under it.
    @State private var missingVoiceWasShown = false

    var body: some View {
        let rows = VoiceList.rows(
            for: speech.availableVoices,
            selectedID: speech.selectedVoiceID,
            languageCode: Bundle.main.preferredLocalizations.first ?? "en",
            describeLanguage: { Locale.current.localizedString(forIdentifier: $0) ?? $0 }
        )

        // Which voice speaks now, from the service itself, so a kept
        // Personal Voice is named the same way speech chooses it.
        if let current = speech.currentVoice {
            SettingsReservedParagraph(
                text: Text("Speaking with \(current.name)."),
                alternatives: speech.availableVoices.map { Text("Speaking with \($0.name).") }
            )
        }

        PersonalVoiceSection()

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
        let voiceIsMissing = VoiceList.chosenVoiceIsMissing(selectedID: speech.selectedVoiceID, from: speech.availableVoices)
        if voiceIsMissing || missingVoiceWasShown {
            SettingsParagraph("The voice chosen earlier is no longer on this device, so Automatic is used.")
                .opacity(voiceIsMissing ? 1 : 0)
                .accessibilityHidden(!voiceIsMissing)
                .onAppear { missingVoiceWasShown = true }
        }
        ForEach(rows) { row in
            VoiceRowView(row: row)
        }
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

/// What Personal Voice needs next, from `PersonalVoiceGuidance`.
private struct PersonalVoiceSection: View {
    @Environment(SpeechService.self) private var speech
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @State private var couldNotOpenSettings = false

    var body: some View {
        let guidance = PersonalVoiceGuidance.make(
            access: PersonalVoiceAccess(speech.personalVoiceStatus),
            hasPersonalVoice: speech.hasPersonalVoice,
            // Brickson asks by itself when it opens, for now
            // (docs/DECISIONS.md, "Personal Voice permission is asked at
            // launch, for now"); the Ask button arrives with that change.
            canAsk: false,
            canOpenSettings: Self.canOpenPersonalVoiceSettings
        )

        SettingsCard {
            SettingsHeading(verbatim: guidance.title)
            SettingsParagraph(verbatim: guidance.message)
            if let path = guidance.settingsPath {
                Text(verbatim: path)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if guidance.suggestsMakingOne {
                SettingsParagraph("Making a Personal Voice means reading phrases aloud, so it is easiest while speaking is comfortable. Apple keeps it encrypted on this device, and in iCloud only if Share Across Devices is on. \(AppName.display) never receives the voice or its recordings.")
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

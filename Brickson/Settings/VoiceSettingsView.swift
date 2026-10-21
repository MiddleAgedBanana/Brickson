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

    var body: some View {
        let rows = VoiceList.rows(
            for: speech.availableVoices,
            selectedID: speech.selectedVoiceID,
            languageCode: Bundle.main.preferredLocalizations.first ?? "en",
            describeLanguage: { Locale.current.localizedString(forIdentifier: $0) ?? $0 }
        )

        // Which voice speaks now, by the same rule speech uses.
        if let current = VoiceSelection.select(
            chosenID: speech.selectedVoiceID,
            from: speech.availableVoices,
            languageCode: Bundle.main.preferredLocalizations.first ?? "en"
        ) {
            SettingsParagraph("Speaking with \(current.name).")
                .accessibilityIdentifier("nowSpeaking")
        }

        PersonalVoiceSection()

        SettingsHeading("Speed")
        let chosenSpeed = SpeedChoice.matching(speech.speechRate, normal: AVSpeechUtteranceDefaultSpeechRate)
        if chosenSpeed?.isNormal == true {
            SettingsParagraph("Speaking at normal speed.")
        } else {
            let share = SpeedChoice.fraction(of: speech.speechRate, normal: AVSpeechUtteranceDefaultSpeechRate)
            SettingsParagraph("Speaking at \(share, format: .percent) of normal speed.")
        }
        ForEach(SpeedChoice.all) { choice in
            SpeedChoiceButton(choice: choice, isChosen: choice == chosenSpeed)
        }

        SettingsHeading("Voice")
        if VoiceList.chosenVoiceIsMissing(selectedID: speech.selectedVoiceID, from: speech.availableVoices) {
            SettingsParagraph("The voice chosen earlier is no longer on this device, so Automatic is used.")
        }
        ForEach(rows) { row in
            VoiceRowView(row: row)
        }
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
                if row.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityHidden(true)
                }
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
                    SettingsRowLabel(title: "Hear", systemImage: "play.fill")
                }
                .settingsRowStyle()
                .accessibilityLabel(Text(verbatim: row.hearLabel))
                .accessibilityInputLabels([Text(verbatim: row.hearLabel)])

                Button {
                    activity?.recordActivity()
                    speech.selectedVoiceID = row.voiceID
                } label: {
                    SettingsRowLabel(
                        title: row.isSelected ? "In Use" : "Use",
                        systemImage: row.isSelected ? "checkmark" : "checkmark.circle"
                    )
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
            hasPersonalVoice: speech.availableVoices.contains(where: \.isPersonalVoice),
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
                if couldNotOpenSettings {
                    SettingsParagraph("Settings could not be opened. Follow the steps above in the Settings app.")
                }
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
